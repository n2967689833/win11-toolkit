# win11-toolkit

Windows 11 系统 / 网络 / 桌面 **自动化工具集** —— 每套工具都是在本机实测通过后打包的，双击或一行命令即可用。

> 产出方式：机主与 AI 助手（QClaw）协作开发，全部为「问题定位 → 反复实测 → 脚本化」的产物。
> 除个别需要 Python 3.8+ 外，其它均使用系统自带组件（PowerShell 5.1 / WPF / WinRT），**不依赖任何第三方软件**。

---

## 📦 工具索引

| # | 目录 | 功能一句话 | 依赖 | 风险 |
|---|------|-----------|------|------|
| 01 | [`01-ace-priority-guard`](01-ace-priority-guard/) | 把腾讯 ACE 反作弊进程自动降到**最低优先级 + 只绑 1 个核心**，开机守护、进游戏后自动重新套用 | PowerShell 5.1 | ⚠️ 中 |
| 02 | [`02-campus-network-autologin`](02-campus-network-autologin/) | 校园网 Dr.COM 认证**自动登录 + 掉线重连**（每分钟自检，开机自启） | Python 3.8+ | 低 |
| 03 | [`03-desktop-dock-nexus`](03-desktop-dock-nexus/) | Winstep Nexus 桌面 Dock 全自动配置：条目/图标/顺序/倒影/防误拖 + 高清图标提取 + 坏图标修复 | PowerShell + Nexus | 低 |
| 04 | [`04-kingsoft-duba-cleanup`](04-kingsoft-duba-cleanup/) | 金山毒霸卸载后的**残留清理**（目录 / 注册表 / 服务键，精细保留 WPS） | PowerShell（需管理员） | 中 |
| 05 | [`05-network-speed-tools`](05-network-speed-tools/) | 网卡节能/降速项优化 + **多链路聚合测速**（按源 IP 绑定指定网卡） | PowerShell / Python | 低 |
| 06 | [`06-bluetooth-diagnose`](06-bluetooth-diagnose/) | 蓝牙适配器 / 配对记录 / 服务状态取证与设备扫描 | PowerShell + WinRT | 低 |
| 07 | [`07-xunlei-download-tools`](07-xunlei-download-tools/) | 纯标准库**多线程下载器**（断点续传、自定义 Cookie/Referer）+ 迅雷任务真实直链读取 | Python 3.8+ | 低 |
| 08 | [`08-python-uv-setup`](08-python-uv-setup/) | Python / uv 环境检查 + **国内镜像一键配置**（pip / npm / uv） | PowerShell | 低 |
| 📄 | [`docs/case-nic-hardware-diagnosis.md`](docs/case-nic-hardware-diagnosis.md) | 案例：板载 2.5G 网卡**硬件故障定位**（事件日志取证 → 驱动溯源 → 售后文本） | — | — |

---

## 🧰 通用约定

- 含中文的 `.ps1` 必须以 **UTF-8 with BOM** 保存，否则 PowerShell 5.1 会按 GBK 解析成乱码（脚本内已处理）。
- 控制台中文乱码时，先执行：`[Console]::OutputEncoding=[System.Text.Encoding]::UTF8`
- 需要管理员的操作（服务 / 计划任务 / 系统设置）会**弹出 UAC**，脚本不会静默提权、不会绕过审批。
- 每套工具都提供**卸载 / 还原**入口，建议改动前先备份关键配置。

## ⚠️ 免责声明

本项目仅用于**优化自己的电脑**，不含任何破解、绕过限速或游戏作弊功能。
请先阅读每个目录内的 README 注意事项，尤其是 `01`（涉及游戏反作弊进程的资源调控）和 `04`（涉及注册表删除）。
使用造成的一切后果由使用者自行承担。

## 📄 License

[MIT](LICENSE) © 2026 boring
