# 03 · 桌面 Dock 全自动化（Winstep Nexus）

> Win11 上做 macOS 风格「顶部悬浮 Dock」：不装 Electron、不用 Rainmeter，最终用 **Winstep Nexus**（C++ 原生，内存约 12MB）+ 一批 PowerShell 自动化脚本完成配置。
> 本目录是**踩坑后固化的工具集**，可以直接复用到任何一台装 Nexus 的机器。

## 最终效果

- 顶部居中悬浮栏，深色圆角底座
- 鼠标悬停：图标放大 + 上浮 + 邻近图标渐变（原生效果）
- 图标倒影 / 立体感，**不显示名称**
- 15 个条目：开始菜单 / 资源管理器 / Edge / Steam / 微信 / QQ / 无畏契约 / WPS / QClaw / 雷神加速器 / 机械革命控制中心 / 壁纸引擎 / CS2 / PUBG / 桌面
- Dock 本体**防误拖**，图标可拖入添加、拖出不会误删

![hover](screenshots/dock-hover.jpg)
![final](screenshots/dock-final.jpg)

## 文件

| 文件 | 作用 |
|------|------|
| `config_nexus2.ps1` | ✅ **推荐**：按「全部字符串类型」写入 8 个 Dock 条目（修复版） |
| `config_nexus.ps1` | 初版（部分值写成了 DWORD → Dock 只显示一个图标，仅作反例保留） |
| `add_nexus_items.ps1` | 追加桌面全部图标（UWP / Steam 游戏 / 桌面文件夹入口） |
| `restore_nexus.ps1` | 恢复 Nexus 默认 10 条目 |
| `restore_order.ps1` | 恢复条目顺序 + 重写自定义图标字段 |
| `extract_icons.ps1` / `extract_icons64.ps1` | 从 exe 提取图标（32/64px） |
| `extract_jumbo.ps1` | ✅ 用 `SHGetImageList(SHIL_JUMBO)` 提取 **256px** 高清图标再降采样 |
| `fix_valorant.ps1` | 修复单帧 256px BGRA `.ico`（用 WPF `BitmapDecoder`，`System.Drawing.Icon` 会返回 null） |
| `fix_icons_shadow.ps1` | 重新生成图标阴影素材 |
| `gen_effects.ps1` | 生成倒影 / 阴影素材（纯脚本绘制） |
| `count_dock.ps1` | 诊断：枚举 `NxDock` 窗口 + `PrintWindow` 渲染 + 图标簇计数 |
| `click_test.ps1` | 合成鼠标点击验证条目是否可启动 |
| `drag_lock_test.ps1` / `drag_add_test2.ps1` / `drag_out_test.ps1` | 拖动行为测试（锁定 / 拖入 / 拖出） |
| `verify_mec.ps1` / `fix_icon_and_click.ps1` | 机械革命控制中心条目的图标与启动验证 |

## 关键经验（省你几小时）

1. **注册表值类型**：`HKCU\Software\WinSTEP2000\NeXuS\Docks` 里的值**几乎全是 `REG_SZ` 字符串**（含布尔/数字）。写成 DWORD 会导致 Dock 异常（只显示 1 个图标）。
2. **`DockNoItems1` = 最后一个条目的下标**（8 个条目 → `"7"`）。
3. **改注册表前必须先 `Stop-Process Nexus`**，否则 Nexus 退出时会把内存里的旧配置回写覆盖你的修改。
4. **条目类型**：`0`=文件夹、`1`=程序、`2`=内部命令、`3`=模块、`4`=分隔符、`5`=URL、`6`=NextSTART 热区。
   - `Program(1)` **只认可执行文件**：`.lnk` / `.url` / `steam://` / 文件夹都会导致**后续条目停止加载**（静默截断！）
   - UWP 应用（如机械革命控制中心）：用 `.cmd` 启动器 `start "" explorer.exe "shell:AppsFolder\<AppID>"`，条目类型设为 Program
   - Steam 游戏：直接指向真实 exe（`...\Counter-Strike Global Offensive\game\bin\win64\cs2.exe` 等）
5. **自定义图标字段是 `1IconPathN`**（+ `1IconIndexN`），不是 `1IconN`。
6. **防误拖**：`DockLocked1="True"`（锁定 Dock 本体位置）+ 根键 `LockIcons`（锁定图标拖动；设 False 可拖入添加）。实测**把图标拖出 Dock 不会删除条目**（删除只有右键 Remove from Dock）。
7. **DPI 陷阱**：Nexus 是 DPI-aware，而普通 PowerShell 不是 → 读到的窗口坐标要 **×1.5**（本机 150% 缩放）。测量前先 `SetProcessDPIAware()`。
8. 本机 `DockAutoHideMode1`：`1`=鼠标离开即隐藏、`0`=常显。
9. 自编译带图标的 exe 会被 **Smart App Control** 拦截，改用 `.cmd` 启动器即可。

## 用法

```powershell
# 1) 先退出 Nexus（重要）
Stop-Process -Name Nexus -Force
# 2) 写入配置（按需修改脚本顶部的条目表）
powershell -ExecutionPolicy Bypass -File config_nexus2.ps1
# 3) 重启 Nexus
Start-Process "C:\Program Files (x86)\Winstep\Nexus.exe"
```

## 依赖

- [Winstep Nexus](https://www.winstep.net/)（个人使用免费）
- PowerShell 5.1 + .NET（WPF / System.Drawing）
