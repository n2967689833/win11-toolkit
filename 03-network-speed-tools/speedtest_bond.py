import sys, time, threading, http.client, ssl, urllib.parse
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/126.0.0.0 Safari/537.36"
URL = "https://dldir1.qq.com/weixin/Windows/WeChatSetup.exe"
pu = urllib.parse.urlparse(URL)
HOST, PATH, PORT = pu.hostname, pu.path, pu.port or 443
CTX = ssl.create_default_context()
SEG = 4 * 1024 * 1024

def worker(src_ip, a, b, out, i, errs):
    try:
        c = http.client.HTTPSConnection(HOST, PORT, timeout=40, context=CTX,
                                        source_address=(src_ip, 0) if src_ip else None)
        c.request("GET", PATH, headers={"User-Agent": UA, "Range": "bytes=%d-%d" % (a, b)})
        r = c.getresponse()
        d = r.read()
        if r.status not in (200, 206):
            errs.append("st=%d" % r.status)
        out[i] = len(d)
        c.close()
    except Exception as e:
        errs.append("%s:%s" % (type(e).__name__, str(e)[:50]))
        out[i] = 0

def run(label, plan, tlimit=25.0):
    """plan: list of (src_ip, index)"""
    n = len(plan)
    out = [0] * n
    errs = []
    th = [threading.Thread(target=worker, args=(plan[i][0], plan[i][1] * SEG, plan[i][1] * SEG + SEG - 1, out, i, errs)) for i in range(n)]
    t0 = time.time()
    for t in th: t.start()
    for t in th: t.join()
    el = time.time() - t0
    s = sum(out)
    print("  %-34s %6.1f MB / %5.2fs = %6.2f MB/s  (%4.0f Mbps)%s" %
          (label, s / 1024 / 1024, el, s / el / 1024 / 1024, s * 8 / el / 1000 / 1000,
           ("   " + str(errs[:2])) if errs else ""), flush=True)
    return s / el / 1024 / 1024

ETH, WIFI = "192.168.1.10", "192.168.1.20"
print("=== 目标: %s ===" % URL, flush=True)
print("=== 单链路 ===", flush=True)
e = run("有线 12线程", [(ETH, i) for i in range(12)])
w = run("无线 12线程", [(WIFI, i) for i in range(12)])
print("=== 双链路同时（6+6） ===", flush=True)
both = run("有线6 + 无线6 同时", [(ETH, i) for i in range(6)] + [(WIFI, i + 6) for i in range(6)])
print("=== 双链路同时（12+12） ===", flush=True)
both2 = run("有线12 + 无线12 同时", [(ETH, i) for i in range(12)] + [(WIFI, i + 12) for i in range(12)])
print("=== 汇总 ===", flush=True)
print("  有线=%.2f MB/s | 无线=%.2f MB/s | 6+6=%.2f | 12+12=%.2f MB/s" % (e, w, both, both2), flush=True)
print("  理论: 有线上限 11.8 MB/s (100Mbps)" % (), flush=True)
