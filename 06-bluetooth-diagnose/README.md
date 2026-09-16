# 06 · 蓝牙诊断（Bluetooth Diagnose）

> 场景：蓝牙耳机搜不到 / 连不上时，快速判断是**耳机侧**还是**电脑侧**的问题。

## 功能

`bt_diag.ps1` 用 WinRT（`Windows.Devices.Bluetooth` / `Enumeration`）扫描附近蓝牙设备，输出设备名 / 地址 / 是否可配对。

配合手动取证命令（见下）可完整定位问题。

## 用法

```powershell
powershell -ExecutionPolicy Bypass -File bt_diag.ps1
```

> 注意：脚本含中文，必须保存为 **UTF-8 with BOM**（否则 PowerShell 5.1 按 GBK 解析报错）。

## 配套取证命令（判断电脑侧是否正常）

```powershell
# 1) 适配器与驱动状态
Get-PnpDevice -Class Bluetooth | Select-Object Status, FriendlyName, InstanceId

# 2) 蓝牙服务是否在跑
Get-Service bthserv, BTAGService, BthAvctpSvc, BluetoothUserService

# 3) 已配对记录
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices'

# 4) 关键结论判据：如果 BTHENUM 不存在 → 本机从未成功连接过蓝牙音频设备（问题在耳机侧）
Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Enum\BTHENUM'
```

## 排查思路

| 现象 | 判断 |
|------|------|
| 适配器状态 OK + 服务全在跑 + **搜不到设备** | 大概率**耳机没进配对模式**（或被手机占用、已连别的设备） |
| 能搜到、配不上 | 耳机侧配对记录冲突 → 耳机恢复出厂 / 长按重置 |
| 配上了但没声音 | 检查默认播放设备 / A2DP 服务（`BthAvctpSvc`） |
| `BTHENUM` 键不存在 | 从未有过蓝牙外设连接，先排除"耳机是否真的可被发现" |

## 状态

本机实测结论：适配器、驱动、服务、无线电开关全部正常 → 判定为耳机侧问题（未进配对模式）。
扫描脚本本身未完成端到端实测（当时会话被中断），使用时如报错请反馈。
