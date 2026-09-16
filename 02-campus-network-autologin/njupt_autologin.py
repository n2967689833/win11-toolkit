#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
南邮（NJUPT）校园网 Dr.COM 自动认证脚本
--------------------------------------------------------------------------
功能：
  * 自动识别本机所有已启用的网卡（有线 / 无线 / 多网卡）
  * 逐网卡检查是否已通过校园网认证（查询门户在线会话，最准确）
  * 仅在“该网卡未认证”时才发起登录，绝不重复登录（重复登录会把账号踢下线）
  * 密码使用 Windows DPAPI 加密存储（只有当前 Windows 用户能解密）
  * 支持开机自启 + 每分钟自检（掉线自动重连）

用法：
  python njupt_autologin.py --setup      首次配置账号密码（交互输入，密码隐藏）
  python njupt_autologin.py --status     查看各网卡认证状态
  python njupt_autologin.py --once       检查一次，必要时登录（供计划任务调用）
  python njupt_autologin.py --watch      常驻循环运行（默认间隔 60 秒）
  python njupt_autologin.py --logout     注销当前认证（测试用，会断网）
  python njupt_autologin.py --diag       诊断信息（接口/参数/连通性）
  python njupt_autologin.py --install    安装“每分钟自检”计划任务（开机自启）
  python njupt_autologin.py --uninstall  卸载计划任务

作者：QClaw 自动生成   门户：Dr.COM 4.x (p.njupt.edu.cn / 10.10.244.11)
"""

import argparse
import base64
import ctypes
import ctypes.wintypes as wt
import http.client
import json
import os
import re
import socket
import ssl
import subprocess
import sys
import time
from datetime import datetime
from urllib.parse import quote

import urllib.error
import urllib.request

# --------------------------------------------------------------------------
# 常量与默认配置
# --------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(SCRIPT_DIR, "njupt_config.json")
TASK_NAME = "NJUPT_AutoLogin"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")
NO_WINDOW = 0x08000000  # CREATE_NO_WINDOW

DEFAULT_CONFIG = {
    "account": "",                  # 上网账号（不含 @后缀）
    "isp": "",                      # 运营商后缀：""=校园网, "cmcc"=移动, "njxy"=电信
    "password_dpapi": "",           # DPAPI 加密后的密码（由 --setup 生成）
    "interfaces": [],               # 只管理指定网卡（别名包含匹配）；空=全部
    "interval": 60,                 # watch 模式检查间隔（秒）
    "portal_host": "10.10.244.11",  # 认证服务器
    "portal_https_port": 802,       # 新版 JSONP 接口（HTTPS）
    "portal_http_port": 801,        # 旧版 ACSetting 接口（HTTP，备用）
    "wlanacip": "10.255.252.150",   # 旧版接口备用参数（仙林校区）
    "wlanacname": "XL-BRAS-SR8806-X",
    "log_file": "autologin.log",
    "verbose": True,
}

# --------------------------------------------------------------------------
# 日志
# --------------------------------------------------------------------------
def log(msg, cfg=None, force=False):
    """打印并写入日志文件（超过 1MB 自动轮转）"""
    line = "[%s] %s" % (datetime.now().strftime("%Y-%m-%d %H:%M:%S"), msg)
    try:
        print(line, flush=True)
    except Exception:
        pass
    try:
        if cfg and not cfg.get("verbose", True) and not force:
            return
        name = (cfg or {}).get("log_file", "autologin.log")
        path = name if os.path.isabs(name) else os.path.join(SCRIPT_DIR, name)
        if os.path.exists(path) and os.path.getsize(path) > 1024 * 1024:
            try:
                os.replace(path, path + ".old")
            except Exception:
                pass
        with open(path, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


# --------------------------------------------------------------------------
# Windows DPAPI 加解密（密码安全存储：仅当前用户可解密）
# --------------------------------------------------------------------------
class _BLOB(ctypes.Structure):
    _fields_ = [("cbData", wt.DWORD), ("pbData", ctypes.POINTER(ctypes.c_char))]


def _dpapi(data: bytes, encrypt: bool) -> bytes:
    fn = ctypes.windll.crypt32.CryptProtectData if encrypt else ctypes.windll.crypt32.CryptUnprotectData
    buf = ctypes.create_string_buffer(data, len(data))
    blob_in = _BLOB(len(data), ctypes.cast(buf, ctypes.POINTER(ctypes.c_char)))
    blob_out = _BLOB()
    ok = fn(ctypes.byref(blob_in), None, None, None, None, 0, ctypes.byref(blob_out))
    if not ok:
        raise OSError(ctypes.GetLastError(), "DPAPI 调用失败")
    try:
        return ctypes.string_at(blob_out.pbData, blob_out.cbData)
    finally:
        ctypes.windll.kernel32.LocalFree(blob_out.pbData)


def dpapi_encrypt(text: str) -> str:
    return base64.b64encode(_dpapi(text.encode("utf-8"), True)).decode()


def dpapi_decrypt(b64: str) -> str:
    return _dpapi(base64.b64decode(b64), False).decode("utf-8")


# --------------------------------------------------------------------------
# 配置读写
# --------------------------------------------------------------------------
def load_config() -> dict:
    cfg = dict(DEFAULT_CONFIG)
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8-sig") as f:
                cfg.update(json.load(f))
        except Exception as e:
            log("读取配置失败：%s" % e, cfg=None)
    return cfg


def save_config(cfg: dict):
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)


def get_password(cfg: dict):
    enc = cfg.get("password_dpapi") or ""
    if not enc:
        return None
    try:
        return dpapi_decrypt(enc)
    except Exception as e:
        log("密码解密失败（可能换了 Windows 用户/重装系统）：%s" % e, cfg)
        return None


def full_account(cfg: dict) -> str:
    acct = (cfg.get("account") or "").strip()
    isp = (cfg.get("isp") or "").strip()
    if not acct:
        return ""
    if isp and acct.lower().endswith("@" + isp.lower()):
        return acct
    return acct + (("@" + isp) if isp else "")


# --------------------------------------------------------------------------
# 网卡枚举
# --------------------------------------------------------------------------
def list_interfaces(cfg=None):
    """返回 [{'alias':..,'ip':..,'mac':..}]，只含已就绪(Preferred)的 IPv4"""
    ps = (
        "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;"
        "Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | "
        "Where-Object { $_.AddressState -eq 'Preferred' -and $_.IPAddress -ne '127.0.0.1' } | "
        "ForEach-Object { $a=$_.InterfaceAlias; "
        "$m=(Get-NetAdapter -InterfaceAlias $a -ErrorAction SilentlyContinue).MacAddress; "
        "if($m){ \"$a|$($_.IPAddress)|$m\" } }"
    )
    result = []
    try:
        out = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", ps],
                             capture_output=True, timeout=30, creationflags=NO_WINDOW)
        for ln in out.stdout.decode("utf-8", "ignore").splitlines():
            parts = ln.strip().split("|")
            if len(parts) == 3 and re.match(r"^\d+\.\d+\.\d+\.\d+$", parts[1]):
                result.append({"alias": parts[0].strip(), "ip": parts[1],
                               "mac": parts[2].replace("-", "").strip()})
    except Exception as e:
        log("枚举网卡失败：%s" % e, cfg)

    if not result:  # 兜底：用 socket 拿本机 IPv4
        try:
            for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
                ip = info[4][0]
                if not ip.startswith("127.") and not ip.startswith("169.254."):
                    result.append({"alias": "", "ip": ip, "mac": ""})
        except Exception:
            pass

    only = cfg.get("interfaces") if cfg else None
    if only:
        filtered = [i for i in result if any(k in i["alias"] for k in only)]
        if filtered:
            result = filtered
    # 过滤掉非校园网段（避免对蓝牙/虚拟网卡做无意义认证），保留 10./172./192. 私有地址
    result = [i for i in result if re.match(r"^(10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.)", i["ip"])]
    return result


# --------------------------------------------------------------------------
# HTTP（绑定指定网卡源 IP、禁用代理、忽略自签证书）
# --------------------------------------------------------------------------
SSL_CTX = ssl.create_default_context()
SSL_CTX.check_hostname = False
SSL_CTX.verify_mode = ssl.CERT_NONE


class _BoundHTTPSHandler(urllib.request.HTTPSHandler):
    def __init__(self, bind_ip):
        super().__init__(context=SSL_CTX)
        self._bind = bind_ip

    def https_open(self, req):
        return self.do_open(self._mkconn, req, context=SSL_CTX)

    def _mkconn(self, host, timeout=None, context=None, **kw):
        kw["source_address"] = (self._bind, 0)
        return http.client.HTTPSConnection(host, timeout=timeout, context=context, **kw)


class _BoundHTTPHandler(urllib.request.HTTPHandler):
    def __init__(self, bind_ip):
        super().__init__()
        self._bind = bind_ip

    def http_open(self, req):
        return self.do_open(self._mkconn, req)

    def _mkconn(self, host, timeout=None, **kw):
        kw["source_address"] = (self._bind, 0)
        return http.client.HTTPConnection(host, timeout=timeout, **kw)


def make_opener(bind_ip):
    return urllib.request.build_opener(
        urllib.request.ProxyHandler({}),      # 明确禁用系统代理
        _BoundHTTPHandler(bind_ip),
        _BoundHTTPSHandler(bind_ip),
    )


def http_get(opener, url, timeout=15):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with opener.open(req, timeout=timeout) as r:
            return r.status, r.read().decode("utf-8", "ignore")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "ignore")
    except Exception as e:
        return None, "EXC:%s" % e


def parse_jsonp(text):
    if not text:
        return None
    m = re.search(r"\{.*\}", text, re.S)
    if not m:
        return None
    try:
        return json.loads(m.group(0))
    except Exception:
        return None


# --------------------------------------------------------------------------
# 门户接口
# --------------------------------------------------------------------------
def portal_base(cfg):
    return "https://%s:%s/eportal/portal" % (cfg["portal_host"], cfg["portal_https_port"])


def query_session(opener, cfg, ip):
    """查询该 IP 的在线会话；返回 dict(会话) 或 None(未认证) 或 'ERR'"""
    url = ("%s/online_list?callback=dr1003&login_method=1&wlan_user_ip=%s&page_index=1&page_size=10"
           % (portal_base(cfg), quote(ip)))
    st, body = http_get(opener, url)
    data = parse_jsonp(body)
    if not data:
        return "ERR"
    for it in (data.get("list") or []):
        if str(it.get("online_ip")) == ip:
            return it
    return None


def do_login(opener, cfg, ip, mac, password):
    """新版 JSONP 登录接口"""
    acct = full_account(cfg)
    url = ("%s/login?callback=dr1003&login_method=1&user_account=%s&user_password=%s&wlan_user_ip=%s"
           % (portal_base(cfg), quote(acct), quote(password), quote(ip)))
    if mac:
        url += "&wlan_user_mac=" + mac.upper()
    st, body = http_get(opener, url)
    data = parse_jsonp(body)
    if data is None:
        return False, "接口无响应或返回异常：%s" % (body or st)
    ok = str(data.get("result")) == "1" or "成功" in str(data.get("msg", ""))
    return ok, "%s | %s" % (data.get("result"), data.get("msg"))


def do_login_legacy(opener, cfg, ip, password):
    """旧版 ACSetting 接口（备用）"""
    acct = full_account(cfg)
    acip, acname = cfg.get("wlanacip", ""), cfg.get("wlanacname", "")
    url = ("http://%s:%s/eportal/?c=ACSetting&a=Login&protocol=http:&hostname=%s&iTermType=1"
           "&wlanuserip=%s&wlanacip=%s&wlanacname=%s&mac=00-00-00-00-00-00&ip=%s"
           "&enAdvert=0&queryACIP=0&loginMethod=1"
           % (cfg["portal_host"], cfg["portal_http_port"], cfg["portal_host"],
              quote(ip), quote(acip), quote(acname), quote(ip)))
    fields = {
        "DDDDD": ",0," + acct,
        "upass": password,
        "R1": "0", "R2": "0", "R3": "0", "R6": "0", "para": "00", "0MKKey": "123456",
        "buttonClicked": "", "redirect_url": "", "err_flag": "", "username": "",
        "password": "", "user": "", "cmd": "", "Login": "", "v6ip": "",
    }
    data = "&".join("%s=%s" % (k, quote(str(v))) for k, v in fields.items()).encode()
    req = urllib.request.Request(url, data=data, headers={
        "User-Agent": UA,
        "Content-Type": "application/x-www-form-urlencoded",
        "Referer": "http://%s/a70.htm" % cfg["portal_host"],
    })
    try:
        with opener.open(req, timeout=15) as r:
            body = r.read().decode("gbk", "ignore")
    except urllib.error.HTTPError as e:
        body = e.read().decode("gbk", "ignore")
    except Exception as e:
        return False, "旧版接口异常：%s" % e
    if "Dr.COMWebLoginID_3.htm" in body or re.search(r"Msg=0;", body):
        return True, "旧版接口返回成功"
    m = re.search(r"msga='([^']*)'", body)
    return False, "旧版接口失败：%s" % (m.group(1) if m else body[:120])


def do_logout(opener, cfg, ip):
    url = ("%s/logout?callback=dr1003&login_method=1&wlan_user_ip=%s"
           % (portal_base(cfg), quote(ip)))
    st, body = http_get(opener, url)
    data = parse_jsonp(body)
    ok = bool(data) and (str(data.get("result")) == "1" or "成功" in str(data.get("msg", "")))
    return ok, (data.get("msg") if data else body)


# --------------------------------------------------------------------------
# 核心：处理单个网卡
# --------------------------------------------------------------------------
def process_interface(cfg, iface, password, dry=False):
    ip, mac, alias = iface["ip"], iface.get("mac", ""), iface.get("alias", "")
    tag = "%s(%s)" % (alias or "网卡", ip)
    opener = make_opener(ip)

    sess = query_session(opener, cfg, ip)
    if isinstance(sess, dict):
        acct = sess.get("user_account", "?")
        log("[%s] 已认证在线｜账号=%s｜上线时间=%s → 无需操作" % (tag, acct, sess.get("online_time", "?")), cfg)
        return True
    if sess == "ERR":
        log("[%s] 无法查询门户状态（可能没接入校园网），跳过" % tag, cfg)
        return False

    log("[%s] 未认证 → 开始登录（账号 %s）" % (tag, full_account(cfg)), cfg)
    if dry:
        return False

    ok, msg = do_login(opener, cfg, ip, mac, password)
    log("[%s] 新版接口返回：%s" % (tag, msg), cfg)
    if not ok:
        ok2, msg2 = do_login_legacy(opener, cfg, ip, password)
        log("[%s] 备用接口返回：%s" % (tag, msg2), cfg)
        ok = ok or ok2

    time.sleep(2)
    sess2 = query_session(opener, cfg, ip)
    if isinstance(sess2, dict):
        log("[%s] ✅ 认证成功｜账号=%s" % (tag, sess2.get("user_account")), cfg, force=True)
        return True
    log("[%s] ❌ 认证后仍未在线（请检查账号密码/运营商后缀）" % tag, cfg, force=True)
    return False


# --------------------------------------------------------------------------
# 各模式
# --------------------------------------------------------------------------
def cmd_status(cfg):
    ifaces = list_interfaces(cfg)
    if not ifaces:
        log("没有找到已启用的 IPv4 网卡", cfg, force=True)
        return
    log("=== 网卡认证状态 ===", cfg, force=True)
    for i in ifaces:
        opener = make_opener(i["ip"])
        s = query_session(opener, cfg, i["ip"])
        if isinstance(s, dict):
            log("  %-14s %-16s ✅ 在线  账号=%s  上线=%s" %
                (i["alias"] or "?", i["ip"], s.get("user_account"), s.get("online_time")), cfg, force=True)
        elif s is None:
            log("  %-14s %-16s ❌ 未认证" % (i["alias"] or "?", i["ip"]), cfg, force=True)
        else:
            log("  %-14s %-16s ⚠ 门户不可达（未接入校园网？）" % (i["alias"] or "?", i["ip"]), cfg, force=True)


def cmd_once(cfg, dry=False):
    password = get_password(cfg)
    if not password and not dry:
        log("尚未配置密码，请先运行：python njupt_autologin.py --setup", cfg, force=True)
        return 2
    if not cfg.get("account"):
        log("尚未配置账号，请先运行：python njupt_autologin.py --setup", cfg, force=True)
        return 2
    ifaces = list_interfaces(cfg)
    if not ifaces:
        return 1
    done = False
    for i in ifaces:
        done = process_interface(cfg, i, password, dry) or done
    return 0 if done else 1


def cmd_watch(cfg):
    # 单实例保护
    handle = ctypes.windll.kernel32.CreateMutexW(None, False, "Local\\NJUPT_AutoLogin_Mutex")
    if ctypes.windll.kernel32.GetLastError() == 183:  # ERROR_ALREADY_EXISTS
        log("已有实例在运行，退出", cfg, force=True)
        return 0
    interval = max(15, int(cfg.get("interval", 60)))
    log("常驻模式启动，每 %d 秒检查一次（Ctrl+C 退出）" % interval, cfg, force=True)
    while True:
        try:
            cmd_once(cfg)
        except KeyboardInterrupt:
            log("收到退出信号", cfg, force=True)
            return 0
        except Exception as e:
            log("检查过程异常：%s" % e, cfg, force=True)
        time.sleep(interval)


def cmd_logout(cfg):
    ifaces = list_interfaces(cfg)
    for i in ifaces:
        opener = make_opener(i["ip"])
        ok, msg = do_logout(opener, cfg, i["ip"])
        log("[%s] 注销%s：%s" % (i["ip"], "成功" if ok else "失败", msg), cfg, force=True)
    return 0


def cmd_setup(cfg):
    print("=" * 60)
    print(" 南邮校园网自动认证 - 账号配置")
    print("=" * 60)
    acct = input("上网账号（学号/工号，不含 @后缀）[%s]: " % (cfg.get("account") or "")).strip()
    if acct:
        cfg["account"] = acct
    print("运营商：1=校园网   2=移动(@cmcc)   3=电信(@njxy)")
    cur = {"": "1", "cmcc": "2", "njxy": "3"}.get(cfg.get("isp", ""), "1")
    sel = input("选择 [%s]: " % cur).strip() or cur
    cfg["isp"] = {"1": "", "2": "cmcc", "3": "njxy"}.get(sel, "")
    import getpass
    while True:
        pw = getpass.getpass("上网密码（输入时不显示）: ")
        if not pw:
            print("密码不能为空")
            continue
        pw2 = getpass.getpass("再输入一次确认: ")
        if pw != pw2:
            print("两次输入不一致，请重新输入")
            continue
        break
    cfg["password_dpapi"] = dpapi_encrypt(pw)
    save_config(cfg)
    print("\n✅ 已保存到 %s" % CONFIG_PATH)
    print("   账号：%s" % full_account(cfg))
    print("   密码：已用 Windows DPAPI 加密（仅当前用户可解密）")
    print("\n接下来可运行：python njupt_autologin.py --once   测试登录")
    return 0


def cmd_diag(cfg):
    log("=== 配置 ===", cfg, force=True)
    for k in ("account", "isp", "interfaces", "interval", "portal_host",
              "portal_https_port", "portal_http_port"):
        log("  %s = %r" % (k, cfg.get(k)), cfg, force=True)
    log("  完整账号 = %s" % full_account(cfg), cfg, force=True)
    log("  密码 = %s" % ("已配置(DPAPI加密)" if cfg.get("password_dpapi") else "未配置"), cfg, force=True)
    ifaces = list_interfaces(cfg)
    log("=== 网卡（%d 个）===" % len(ifaces), cfg, force=True)
    for i in ifaces:
        log("  %-14s %-16s mac=%s" % (i["alias"] or "?", i["ip"], i["mac"]), cfg, force=True)
        opener = make_opener(i["ip"])
        st, body = http_get(opener, portal_base(cfg) + "/page/loadConfig?program_index=")
        log("     门户接口连通性: %s" % ("OK" if st == 200 else "失败(%s)" % st), cfg, force=True)
    log("=== 云端会话查询 ===", cfg, force=True)
    cmd_status(cfg)
    return 0


# --------------------------------------------------------------------------
# 计划任务（开机自启 + 每分钟自检）
# --------------------------------------------------------------------------
def cmd_install(cfg):
    pyw = os.path.join(os.path.dirname(sys.executable), "pythonw.exe")
    exe = pyw if os.path.exists(pyw) else sys.executable
    script = os.path.abspath(__file__)
    # 先用 schtasks 建任务（每分钟触发，语义最稳），再用 PowerShell 计划任务 API 精确写入动作：
    # subprocess 列表传参会把路径引号转义成 \" 并被 schtasks 原样存下来（任务的命令行会坏掉）
    cmd = ["schtasks", "/Create", "/F", "/TN", TASK_NAME, "/TR", "cmd /c exit", "/SC", "MINUTE", "/MO", "1"]
    r = subprocess.run(cmd, capture_output=True, timeout=60, creationflags=NO_WINDOW)
    ps = ("$a = New-ScheduledTaskAction -Execute '" + exe + "' -Argument '\"" + script + "\" --once'; "
          "Set-ScheduledTask -TaskName '" + TASK_NAME + "' -Action $a | Out-Null")
    r2 = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps],
                        capture_output=True, timeout=120, creationflags=NO_WINDOW)
    if r2.returncode != 0:
        log("⚠️ 计划任务动作写入失败，任务可能是空动作，请重跑 --install", cfg, force=True)
    out = (r.stdout or b"").decode("gbk", "ignore") + (r.stderr or b"").decode("gbk", "ignore")
    if r.returncode == 0:
        log("✅ 已安装计划任务「%s」：每分钟自动检查/登录" % TASK_NAME, cfg, force=True)
        # 立即跑一次
        subprocess.run(["schtasks", "/Run", "/TN", TASK_NAME], capture_output=True,
                       timeout=30, creationflags=NO_WINDOW)
        log("已触发一次立即检查", cfg, force=True)
        return 0
    log("❌ 安装计划任务失败：%s" % out.strip(), cfg, force=True)
    return 1


def cmd_uninstall(cfg):
    r = subprocess.run(["schtasks", "/Delete", "/F", "/TN", TASK_NAME],
                       capture_output=True, timeout=60, creationflags=NO_WINDOW)
    out = (r.stdout or b"").decode("gbk", "ignore") + (r.stderr or b"").decode("gbk", "ignore")
    log(("✅ 已卸载计划任务" if r.returncode == 0 else "❌ 卸载失败：%s" % out.strip()), cfg, force=True)
    return 0


# --------------------------------------------------------------------------
# 入口
# --------------------------------------------------------------------------
def main():
    p = argparse.ArgumentParser(description="南邮校园网自动认证 (Dr.COM)", add_help=True)
    g = p.add_mutually_exclusive_group()
    g.add_argument("--status", action="store_true", help="查看认证状态")
    g.add_argument("--once", action="store_true", help="检查一次并登录")
    g.add_argument("--dry-run", action="store_true", help="只检查不登录")
    g.add_argument("--watch", action="store_true", help="常驻循环")
    g.add_argument("--setup", action="store_true", help="配置账号密码")
    g.add_argument("--logout", action="store_true", help="注销认证（测试用）")
    g.add_argument("--diag", action="store_true", help="诊断信息")
    g.add_argument("--install", action="store_true", help="安装开机自启计划任务")
    g.add_argument("--uninstall", action="store_true", help="卸载计划任务")
    args = p.parse_args()

    cfg = load_config()
    if args.setup:
        return cmd_setup(cfg)
    if args.status:
        cmd_status(cfg)
        return 0
    if args.diag:
        return cmd_diag(cfg)
    if args.logout:
        return cmd_logout(cfg)
    if args.install:
        return cmd_install(cfg)
    if args.uninstall:
        return cmd_uninstall(cfg)
    if args.watch:
        return cmd_watch(cfg)
    if args.dry_run:
        return cmd_once(cfg, dry=True)
    # 默认：--once（供计划任务/双击使用）
    return cmd_once(cfg)


if __name__ == "__main__":
    try:
        sys.exit(main() or 0)
    except Exception as exc:
        log("未捕获异常：%s" % exc, None, force=True)
        sys.exit(1)
