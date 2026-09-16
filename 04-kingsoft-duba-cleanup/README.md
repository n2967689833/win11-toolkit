# 04 · 金山毒霸残留清理（Kingsoft / Duba Cleanup）

> 场景：**金山毒霸被捆绑安装**后卸载，但服务 / 驱动 / 目录 / 注册表 / 启动项还有残留。
> 本目录是卸载后的**精细化残留清理**脚本，特点是：**保留 WPS Office 的一切**（同属金山，极易误删）。

## ⚠️ 使用前提

1. **必须先用官方卸载程序卸载毒霸本体**（`uni0nst.exe`），本脚本只做残留清理，**不是卸载器**。
2. 需要**管理员权限**，会删除目录与注册表键 —— 请先确认 `KEEP` 清单符合你的机器。

## 清理范围

| 类别 | 内容 |
|------|------|
| 目录 | `C:\Program Files (x86)\Kingsoft\kingsoft antivirus`；`C:\ProgramData\Kingsoft\{DaoHang, dscan, DubaGame, kfc, kheur, KIS, ksbw, kwfsdata, Rcmdlocal, vduba}`；`%APPDATA%\Kingsoft\duba`；`%LOCALAPPDATA%\Kingsoft\kvip` |
| 注册表 | `HKLM\SOFTWARE\WOW6432Node\Kingsoft\{antivirus, installfail, KISCommon, KISWsc, kwspriEx, NeedReboot, shoujizhushou, kfp}`、`HKCU\Software\Kingsoft\{Antivirus, KISCommon}` |
| 服务键 | `KAVBootC` / `kisknl` / `kisnetflt` / `kisnetm` / `ksapi64` |
| 其他 | 自启项、浏览器主页劫持检查、Defender 排除项检查 |

## 🚫 绝对不能删（WPS 相关）

- `C:\ProgramData\Kingsoft\office6`
- `HKCU\Software\Kingsoft\{Office, PDF, Schema Library, WPS365, wpscloud, kaccfavorite, kdcaccount, qing, KBinLayoutOpt, KVip, knetwork}`
- `C:\Program Files\Kingsoft\office6`、`D:\WPS Office\...`

> 脚本内已把它们列入 KEEP 白名单，请勿改动这部分。

## 文件

| 文件 | 作用 |
|------|------|
| `duba_cleanup.ps1` | 第 1 轮：目录 + 注册表键清理 |
| `duba_cleanup2.ps1` | 第 2 轮：服务键 / 自启项 / 深挖残留 |
| `duba_cleanup3.ps1` | 第 3 轮：收尾复查（剩余占用项） |
| `duba_defender_check.ps1` | 查询 / 清理 Windows Defender 中与毒霸相关的排除项（保留 QClaw 等自身排除） |

## 已知情况

- **内核驱动文件删不掉**：`kisnetflt64.sys` 等被已加载的驱动占用 → 删除服务注册后**重启**才会真正卸载；脚本的收尾方式是注册一个开机计划任务（SYSTEM，`onstart`）在下次开机时删除目录并自删任务。
- 清理完建议复查：`Get-Service | ? Name -match 'kxe|kis|kav|duba'`、`Get-Process | ? ProcessName -match 'kxe|duba'`，并打开 Windows 安全中心确认**实时保护为开启**。
