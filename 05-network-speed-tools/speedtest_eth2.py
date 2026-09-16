import sys,time,threading,urllib.request
try: sys.stdout.reconfigure(encoding="utf-8",errors="replace")
except Exception: pass
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/126.0.0.0 Safari/537.36"
CAND=[
 "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-releases/22.04/ubuntu-22.04.5-desktop-amd64.iso",
 "http://mirrors.aliyun.com/ubuntu-releases/22.04/ubuntu-22.04.5-desktop-amd64.iso",
 "https://registry.npmmirror.com/-/binary/node/v22.22.0/node-v22.22.0-win-x64.zip",
 "https://mirrors.ustc.edu.cn/ubuntu-releases/22.04/ubuntu-22.04.5-desktop-amd64.iso",
]
URL=None
for u in CAND:
    try:
        rq=urllib.request.Request(u,headers={"User-Agent":UA,"Range":"bytes=0-0"})
        with urllib.request.urlopen(rq,timeout=20) as r:
            cr=r.headers.get("Content-Range") or ("bytes 0-0/"+r.headers.get("Content-Length","0"))
            size=int(cr.split("/")[-1]); URL=u
            print(f"[OK] {u}  ({size/1024/1024:.0f} MB)")
            break
    except Exception as e:
        print(f"[X] {u} -> {type(e).__name__}: {str(e)[:80]}")
if not URL:
    print("所有测试源都不可用"); sys.exit(0)
N=16; SEG=4*1024*1024
tot=[0]*N
def w(i):
    h={"User-Agent":UA,"Range":f"bytes={i*SEG}-{i*SEG+SEG-1}"}
    try:
        rq=urllib.request.Request(URL,headers=h)
        with urllib.request.urlopen(rq,timeout=60) as r: tot[i]=len(r.read())
    except Exception: tot[i]=0
t0=time.time()
th=[threading.Thread(target=w,args=(i,)) for i in range(N)]
[t.start() for t in th]; [t.join() for t in th]
el=time.time()-t0
s=sum(tot)
print(f">>> 16线程并发: {s/1024/1024:.1f} MB / {el:.2f}s = {s/el/1024/1024:.2f} MB/s  ({s*8/el/1000/1000:.0f} Mbps)")
print(f">>> 8线程测:")
N=8; tot2=[0]*8
def w2(i):
    h={"User-Agent":UA,"Range":f"bytes={i*SEG}-{i*SEG+SEG-1}"}
    try:
        rq=urllib.request.Request(URL,headers=h)
        with urllib.request.urlopen(rq,timeout=60) as r: tot2[i]=len(r.read())
    except Exception: tot2[i]=0
t0=time.time()
th=[threading.Thread(target=w2,args=(i,)) for i in range(8)]
[t.start() for t in th]; [t.join() for t in th]
el=time.time()-t0; s=sum(tot2)
print(f">>> 8线程并发: {s/1024/1024:.1f} MB / {el:.2f}s = {s/el/1024/1024:.2f} MB/s ({s*8/el/1000/1000:.0f} Mbps)")