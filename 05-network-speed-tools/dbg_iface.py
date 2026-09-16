import http.client, ssl, traceback
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/126.0.0.0 Safari/537.36"
HOST="registry.npmmirror.com"; PATH="/-/binary/node/v22.22.0/node-v22.22.0-win-x64.zip"
for src in [None, "192.168.1.10", "192.168.1.20"]:
    try:
        c=http.client.HTTPSConnection(HOST,timeout=20,context=ssl.create_default_context(),
                                      source_address=(src,0) if src else None)
        c.request("GET",PATH,headers={"User-Agent":UA,"Range":"bytes=0-1048575"})
        r=c.getresponse()
        d=r.read()
        print(f"src={src} -> status={r.status} len={len(d)}")
        c.close()
    except Exception as e:
        print(f"src={src} -> EXC {type(e).__name__}: {e}")
        traceback.print_exc()