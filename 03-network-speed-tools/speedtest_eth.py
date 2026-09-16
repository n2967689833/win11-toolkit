import sys,time,threading,urllib.request
try: sys.stdout.reconfigure(encoding="utf-8",errors="replace")
except Exception: pass
URL="https://mirrors.aliyun.com/ubuntu-releases/22.04/ubuntu-22.04.5-desktop-amd64.iso"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/126.0.0.0 Safari/537.36"
req=urllib.request.Request(URL,headers={"User-Agent":UA,"Range":"bytes=0-0"})
with urllib.request.urlopen(req,timeout=30) as r:
    size=int(r.headers.get("Content-Range").split("/")[-1])
print(f"测试文件: {size/1024/1024:.0f} MB")
N=16; SEG=3*1024*1024
tot=[0]*N
def w(i):
    h={"User-Agent":UA,"Range":f"bytes={i*SEG}-{i*SEG+SEG-1}"}
    try:
        rq=urllib.request.Request(URL,headers=h)
        with urllib.request.urlopen(rq,timeout=60) as r: tot[i]=len(r.read())
    except Exception as e: tot[i]=0
t0=time.time()
th=[threading.Thread(target=w,args=(i,)) for i in range(N)]
[t.start() for t in th]; [t.join() for t in th]
el=time.time()-t0
s=sum(tot)
print(f"16线程并发: {s/1024/1024:.1f}MB / {el:.2f}s = {s/el/1024/1024:.2f} MB/s ({s*8/el/1000/1000:.0f} Mbps)")