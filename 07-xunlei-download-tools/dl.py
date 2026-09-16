#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
多线程下载器 dl.py  —— 纯标准库实现，无需 pip 安装任何东西

原理：把文件按字节区间切成 N 段并发下载（和 IDM / aria2 的多连接原理相同），
      在服务器/网盘不限设备的前提下，把带宽跑满，从而"加速"。
      支持断点续传、失败重试、自定义 UA / Referer / Cookie。

用法示例：
  python dl.py "https://example.com/big.zip"
  python dl.py "https://example.com/big.zip" -o D:\\Downloads\\big.zip -n 16
  python dl.py "https://pan.xunlei.com/..." -H "Cookie: xxx" -H "Referer: https://pan.xunlei.com/"
  （某些网盘直链需要带 Cookie/Referer，用 -H 传即可）
"""
import argparse
import json
import os
import sys
import threading
import time
import urllib.request
import urllib.error

try:  # Windows 控制台默认 GBK，强制 UTF-8 输出，避免中文/符号报错
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

CHUNK_MIN = 256 * 1024           # 每段最小 256KB
UA_DEFAULT = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
              "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")


def human(n):
    for u in ["B", "KB", "MB", "GB", "TB"]:
        if n < 1024 or u == "TB":
            return f"{n:.1f}{u}" if u != "B" else f"{int(n)}B"
        n /= 1024


class Downloader:
    def __init__(self, url, out, conns, headers, retries):
        self.url = url
        self.out = out
        self.part = out + ".part"
        self.state = out + ".state.json"
        self.conns = conns
        self.headers = headers
        self.retries = retries
        self.size = 0
        self.accept_ranges = False
        self.done = {}            # 已完成的段: index -> [start, end]
        self.lock = threading.Lock()
        self.downloaded = 0
        self.t0 = time.time()

    # ---------- 探测 ----------
    def probe(self):
        req = urllib.request.Request(self.url, headers=self.headers, method="GET")
        req.add_header("Range", "bytes=0-0")
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                cr = r.headers.get("Content-Range")
                if cr and "/" in cr:
                    self.size = int(cr.split("/")[-1])
                    self.accept_ranges = True
                else:
                    self.size = int(r.headers.get("Content-Length") or 0)
        except urllib.error.HTTPError as e:
            if e.code == 416:      # 服务器不支持 Range
                self.accept_ranges = False
                req2 = urllib.request.Request(self.url, headers=self.headers)
                with urllib.request.urlopen(req2, timeout=30) as r:
                    self.size = int(r.headers.get("Content-Length") or 0)
            else:
                raise
        print(f"文件大小: {human(self.size)}   分段支持: {'是' if self.accept_ranges else '否（将单线程下载）'}")

    # ---------- 断点状态 ----------
    def load_state(self):
        if os.path.exists(self.state) and os.path.exists(self.part):
            try:
                with open(self.state, "r", encoding="utf-8") as f:
                    st = json.load(f)
                if st.get("size") == self.size and st.get("url") == self.url:
                    self.done = {int(k): v for k, v in st.get("done", {}).items()}
                    self.downloaded = sum(v[1] - v[0] + 1 for v in self.done.values())
                    print(f"发现断点：已完成 {len(self.done)} 段 / {human(self.downloaded)}，继续下载")
                    return
            except Exception:
                pass
        self.done = {}
        self.downloaded = 0
        with open(self.part, "wb") as f:
            if self.size:
                f.truncate(self.size)

    def save_state(self):
        with self.lock:
            st = {"url": self.url, "size": self.size, "done": {str(k): v for k, v in self.done.items()}}
            with open(self.state, "w", encoding="utf-8") as f:
                json.dump(st, f)

    # ---------- 单段下载 ----------
    def fetch_range(self, idx, start, end):
        for attempt in range(1, self.retries + 1):
            try:
                h = dict(self.headers)
                if self.accept_ranges:
                    h["Range"] = f"bytes={start}-{end}"
                req = urllib.request.Request(self.url, headers=h)
                with urllib.request.urlopen(req, timeout=60) as r, open(self.part, "r+b") as fp:
                    fp.seek(start)
                    left = end - start + 1
                    while left > 0:
                        buf = r.read(min(256 * 1024, left))
                        if not buf:
                            break
                        fp.write(buf)
                        left -= len(buf)
                        with self.lock:
                            self.downloaded += len(buf)
                if left == 0:
                    with self.lock:
                        self.done[idx] = [start, end]
                    return True
                print(f"\n[段{idx}] 数据不完整，重试 {attempt}/{self.retries}")
            except Exception as e:
                print(f"\n[段{idx}] 出错({e.__class__.__name__}: {e})，重试 {attempt}/{self.retries}")
                time.sleep(2 * attempt)
        return False

    # ---------- 进度 ----------
    def progress(self, stop_evt):
        while not stop_evt.is_set():
            time.sleep(1)
            el = time.time() - self.t0
            sp = self.downloaded / el if el > 0 else 0
            pct = (self.downloaded / self.size * 100) if self.size else 0
            eta = ((self.size - self.downloaded) / sp) if sp > 0 else 0
            sys.stdout.write(f"\r进度 {pct:6.2f}%  {human(self.downloaded)}/{human(self.size)}  "
                             f"速度 {human(sp)}/s  剩余 {int(eta)}s   ")
            sys.stdout.flush()

    def run(self):
        self.probe()
        if not self.size:
            raise SystemExit("无法获取文件大小，请检查链接或加上 -H 头信息")
        self.load_state()

        if not self.accept_ranges:
            ok = self.fetch_range(0, 0, self.size - 1) if not self.done else True
        else:
            n = max(1, min(self.conns, max(1, self.size // CHUNK_MIN)))
            seg = self.size // n
            ranges = []
            for i in range(n):
                s = i * seg
                e = self.size - 1 if i == n - 1 else (s + seg - 1)
                ranges.append((i, s, e))
            todo = [(i, s, e) for (i, s, e) in ranges if i not in self.done]
            print(f"并发连接: {n}   待下载段: {len(todo)}")
            stop_evt = threading.Event()
            t = threading.Thread(target=self.progress, args=(stop_evt,), daemon=True)
            t.start()
            threads = []
            for (i, s, e) in todo:
                th = threading.Thread(target=self.fetch_range, args=(i, s, e))
                th.start()
                threads.append(th)
            for th in threads:
                th.join()
            stop_evt.set()
            print()
            if len(self.done) != len(ranges):
                self.save_state()
                raise SystemExit("部分分段未完成，已保存断点，重新运行本命令可续传")

        # 收尾
        os.replace(self.part, self.out)
        if os.path.exists(self.state):
            os.remove(self.state)
        el = time.time() - self.t0
        print(f"完成 OK -> {self.out}  ({human(self.size)}, 用时 {el:.1f}s, 平均 {human(self.size/el)}/s)")


def main():
    ap = argparse.ArgumentParser(description="多线程下载器（标准库实现）")
    ap.add_argument("url", help="下载地址（直链）")
    ap.add_argument("-o", "--out", help="保存路径（默认取链接里的文件名）")
    ap.add_argument("-n", "--conns", type=int, default=16, help="并发连接数，默认 16")
    ap.add_argument("-r", "--retries", type=int, default=5, help="每段重试次数，默认 5")
    ap.add_argument("-H", "--header", action="append", default=[], help='附加请求头，如 -H "Cookie: a=b"')
    ap.add_argument("-A", "--user-agent", default=UA_DEFAULT, help="User-Agent")
    args = ap.parse_args()

    out = args.out
    if not out:
        name = os.path.basename(args.url.split("?")[0].rstrip("/")) or "download.bin"
        out = os.path.join(os.getcwd(), urllib.parse.unquote(name))
    out = os.path.abspath(out)
    os.makedirs(os.path.dirname(out), exist_ok=True) if os.path.dirname(out) else None

    headers = {"User-Agent": args.user_agent, "Accept": "*/*", "Connection": "keep-alive"}
    for h in args.header:
        if ":" in h:
            k, v = h.split(":", 1)
            headers[k.strip()] = v.strip()

    d = Downloader(args.url, out, args.conns, headers, args.retries)
    try:
        d.run()
    except KeyboardInterrupt:
        d.save_state()
        print("\n已中断，进度已保存，重新运行同一命令可断点续传")


if __name__ == "__main__":
    import urllib.parse
    main()
