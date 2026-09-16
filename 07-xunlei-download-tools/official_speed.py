import sys, time, threading, urllib.request
try: sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception: pass
URL="https://lf3-package.vlabstatic.com/obj/faceu-packages/installer/jianying_jianyingpro_0_1.2.46_installer.exe"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
# 先看大小
req=urllib.request.Request(URL, headers={"User-Agent":UA,"Range":"bytes=0-0"})
with urllib.request.urlopen(req, timeout=30) as r:
    cr=r.headers.get("Content-Range"); print("Content-Range:", cr)
    size=int(cr.split("/")[-1]); print(f"官方安装包大小: {size/1024/1024:.1f} MB")
# 8 线程各下 1MB 测速
MB=1024*1024
res=[]
def get(i):
    h={"User-Agent":UA,"Range":f"bytes={i*MB}-{i*MB+MB-1}"}
    try:
        rq=urllib.request.Request(URL, headers=h)
        t0=time.time()
        with urllib.request.urlopen(rq, timeout=60) as r:
            data=r.read()
        res.append((len(data), time.time()-t0))
    except Exception as e:
        res.append((0, 1.0))
t0=time.time()
ths=[threading.Thread(target=get, args=(i,)) for i in range(8)]
[t.start() for t in ths]; [t.join() for t in ths]
el=time.time()-t0
tot=sum(x[0] for x in res)
print(f"8线程并发 1MB×8: 共 {tot/1024/1024:.2f}MB 用时 {el:.2f}s => 约 {tot/el/1024/1024:.2f} MB/s")