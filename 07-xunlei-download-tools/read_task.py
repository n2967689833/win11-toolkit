import os, shutil, sqlite3, json, sys, tempfile

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

SRC = r"D:\Thunder\Profiles"
WORK = os.path.join(tempfile.gettempdir(), "thunder_db")
os.makedirs(WORK, exist_ok=True)

for name in ["TaskDb.dat", "TaskDb.dat-wal", "TaskDb.dat-shm"]:
    s = os.path.join(SRC, name)
    if os.path.exists(s):
        shutil.copy2(s, os.path.join(WORK, name))

db = os.path.join(WORK, "TaskDb.dat")
con = sqlite3.connect(db)
con.row_factory = sqlite3.Row
cur = con.cursor()

print("=== 表 ===")
tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'")]
print(tables)

for t in tables:
    try:
        n = cur.execute(f"SELECT COUNT(*) FROM [{t}]").fetchone()[0]
        cols = [d[1] for d in cur.execute(f"PRAGMA table_info([{t}])")]
        print(f"\n--- 表 {t} ({n} 行) 列: {cols}")
    except Exception as e:
        print(f"\n--- 表 {t} 读取失败: {e}")

# 查找包含 task 的表并输出第 201140840 号任务
for t in tables:
    cols = [d[1] for d in cur.execute(f"PRAGMA table_info([{t}])")]
    if any("task" in c.lower() and "id" in c.lower() for c in cols):
        print(f"\n===== {t} 中 taskId=201140840 的记录 =====")
        try:
            rows = cur.execute(f"SELECT * FROM [{t}] WHERE task_id = ?", (201140840,)).fetchall()
        except Exception:
            try:
                rows = cur.execute(f"SELECT * FROM [{t}] WHERE taskId = ?", (201140840,)).fetchall()
            except Exception as e:
                print("查询失败:", e)
                rows = []
        for r in rows:
            for k in r.keys():
                v = r[k]
                if isinstance(v, (bytes, bytearray)):
                    if len(v) > 400:
                        print(f"  {k}: <bytes {len(v)}>")
                        continue
                    try:
                        v = v.decode("utf-8", "replace")
                    except Exception:
                        v = repr(v)
                print(f"  {k}: {v}")
con.close()
