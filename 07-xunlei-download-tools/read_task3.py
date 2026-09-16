import os, shutil, sqlite3, sys, tempfile
try: sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception: pass
SRC=r"D:\Thunder\Profiles"; WORK=os.path.join(tempfile.gettempdir(),"thunder_db3")
os.makedirs(WORK,exist_ok=True)
for n in ["TaskDb.dat","TaskDb.dat-wal","TaskDb.dat-shm"]:
    s=os.path.join(SRC,n)
    if os.path.exists(s): shutil.copy2(s,os.path.join(WORK,n))
con=sqlite3.connect(os.path.join(WORK,"TaskDb.dat")); con.row_factory=sqlite3.Row
cur=con.cursor()
print("===== P2spTask for 201420204 =====")
rows=cur.execute("SELECT * FROM P2spTask").fetchall()
print("P2spTask 行数:", len(rows))
for r in rows:
    if r["TaskId"]==201420204:
        for k in r.keys():
            v=r[k]
            if isinstance(v,(bytes,bytearray)): v=v.decode("utf-8","replace")
            print(f"{k} = {str(v)[:500]}")
con.close()