import os, shutil, sqlite3, sys, tempfile
try: sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception: pass
SRC=r"D:\Thunder\Profiles"; WORK=os.path.join(tempfile.gettempdir(),"thunder_db2")
os.makedirs(WORK,exist_ok=True)
for n in ["TaskDb.dat","TaskDb.dat-wal","TaskDb.dat-shm"]:
    s=os.path.join(SRC,n)
    if os.path.exists(s): shutil.copy2(s,os.path.join(WORK,n))
con=sqlite3.connect(os.path.join(WORK,"TaskDb.dat")); con.row_factory=sqlite3.Row
cur=con.cursor()
print("===== P2spTask (全部列) =====")
for r in cur.execute("SELECT * FROM P2spTask WHERE TaskId=?", (201140840,)):
    for k in r.keys():
        v=r[k]
        if isinstance(v,(bytes,bytearray)):
            v=v.decode("utf-8","replace")
        print(f"{k} = {v}")
print()
print("===== 所有任务概览 =====")
for r in cur.execute("SELECT TaskId,Name,Status,ResourceSize,TotalReceiveSize,Url,Origin,SavePath FROM TaskBase ORDER BY TaskId DESC"):
    print(f"[{r['TaskId']}] {r['Name']} | status={r['Status']} | {r['TotalReceiveSize']}/{r['ResourceSize']} | origin={r['Origin']} | path={r['SavePath']}")
    print(f"    url={r['Url'][:200]}")
con.close()