import sys, time, threading, http.client, ssl, urllib.parse, urllib.request
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/126.0.0.0 Safari/537.36"

CAND = [
    "https://registry.npmmirror.com/-/binary/node/v22.22.0/node-v22.22.0-win-x64.zip",
    "https://mirrors.cloud.tencent.com/ubuntu-releases/22.04/ubuntu-22.04.5-desktop-amd64.iso",
    "https://mirrors.huaweicloud.com/ubuntu-releases/22.04/ubuntu-22.04.5-desktop-amd64.iso",
    "https://mirrors.ustc.edu.cn/ubuntu-releases/22.04/ubuntu-22.04.5-desktop-amd64.iso",
    "https://mirrors.163.com/ubuntu-releases/22.04/ubuntu-22.04.5-desktop-amd64.iso",
    "https://dldir1.qq.com/weixin/Windows/WeChatSetup.exe",
]

def single(url, budget=3.0):
    """单连接测速：返回 (final_url, size, MB/s)"""
    try:
        rq = urllib.request.Request(url, headers={"User-Agent": UA, "Range": "bytes=0-"})
        t0 = time.time()
        with urllib.request.urlopen(rq, timeout=15) as r:
            final = r.geturl()
            cr = r.headers.get("Content-Range", "")
            size = int(cr.split("/")[-1]) if "/" in cr else 0
            n = 0
            while time.time() - t0 < budget:
                b = r.read(256 * 1024)
                if not b:
                    break
                n += len(b)
            el = time.time() - t0
        return final, size, n / el / 1024 / 1024
    except Exception as e:
        print("  [X]", url.split("/")[2], type(e).__name__, str(e)[:50], flush=True)
        return None

print("=== 源站单连接测速 ===", flush=True)
results = []
for u in CAND:
    r = single(u)
    if r:
        print("  [OK] %-28s size=%4dMB  单连接=%.2f MB/s" % (urllib.parse.urlparse(u).hostname, r[1] / 1024 / 1024, r[2]), flush=True)
        results.append((u, r[0], r[2]))
if not results:
    print("no source"); sys.exit(0)

results.sort(key=lambda x: -x[2])
best_url, final_url, spd = results[0]
print(">>> 采用最快源:", best_url, " (%.2f MB/s)" % spd, flush=True)
print(">>> 最终地址:", final_url, flush=True)

pu = urllib.parse.urlparse(final_url)
HOST, PATH = pu.hostname, pu.path + ("?" + pu.query if pu.query else "")
PORT = pu.port or 443
CTX = ssl.create_default_context()

def worker(src_ip, a, b, out, i, errs):
    try:
        c = http.client.HTTPSConnection(HOST, PORT, timeout=30, context=CTX,
                                        source_address=(src_ip, 0) if src_ip else None)
        c.request("GET", PATH, headers={"User-Agent": UA, "Range": "bytes=%d-%d" % (a, b)})
        r = c.getresponse()
        d = r.read()
        if r.status not in (200, 206):
            errs.append("status=%d" % r.status)
        out[i] = len(d)
        c.close()
    except Exception as e:
        errs.append("%s: %s" % (type(e).__name__, str(e)[:60]))
        out[i] = 0

def run(label, src_ip, nthreads=8, seg=4 * 1024 * 1024):
    out = [0] * nthreads
    errs = []
    th = [threading.Thread(target=worker, args=(src_ip, i * seg, i * seg + seg - 1, out, i, errs)) for i in range(nthreads)]
    t0 = time.time()
    for t in th: t.start()
    for t in th: t.join()
    el = time.time() - t0
    s = sum(out)
    mb = s / el / 1024 / 1024
    print("  %-30s %6.1f MB / %5.2fs = %6.2f MB/s  (%4.0f Mbps)%s" %
          (label, s / 1024 / 1024, el, mb, s * 8 / el / 1000 / 1000,
           ("   errs:" + str(errs[:2])) if errs else ""), flush=True)
    return mb

print("=== 分链路并发测速（8线程 x 4MB） ===", flush=True)
e = run("有线 Ethernet (100M)", "192.168.1.10")
w = run("无线 Wi-Fi (400M)", "192.168.1.20")
a = run("自动(系统默认路由)", None)
m = run("两条一起 (16线程)", None, nthreads=16)
print("=== 结论 ===", flush=True)
print("  有线 %.2f MB/s | 无线 %.2f MB/s | 默认 %.2f MB/s | 16线程 %.2f MB/s" % (e, w, a, m), flush=True)
