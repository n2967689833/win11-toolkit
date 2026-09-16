# 案例：板载 2.5G 网卡「反复掉线」硬件故障定位

> 一台笔记本（AMD R9 8945HX + Realtek RTL8125 2.5GbE 板载网卡，Win11 25H2）出现**每隔一段时间随机断网**。
> 最终定位为：**网卡/主板网络电路硬件缺陷**，而非驱动或系统问题。下面是可复用的完整取证流程。

---

## 一、症状

- 上网中突然断网，任务栏网络图标显示"未连接"
- 设备管理器里网卡时有时无（有时完全消失）
- **普通重启无效**，必须**关机 + 拔电源适配器 + 长按电源键 30 秒放电**才能恢复
- 玩游戏时切出去开厂商控制中心，切回游戏的瞬间最容易触发

## 二、环境

| 项 | 值 |
|----|----|
| 网卡 | Realtek Gaming 2.5GbE（`PCI\VEN_10EC&DEV_8125`），驱动 `rt640x64.sys` |
| 系统 | Windows 11 25H2（Build 26200） |
| 无线 | MediaTek Wi-Fi 6E MT7922（故障时靠它上网） |
| 现象 | 故障时网卡速率变 `0 bps`、`MediaConnectionState=Unknown` |

## 三、取证命令（可直接复用）

```powershell
# 1) 网卡驱动相关错误事件（Realtek 驱动源 rt640x64 是 Event ID 2「Hardware IO error」）
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='rt640x64'} -MaxEvents 100 |
    Select-Object TimeCreated, Id, LevelDisplayName, Message

# 2) NDIS 复位事件（Event ID 10400 = 驱动请求重置网卡）
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='NDIS'} -MaxEvents 100 |
    Where-Object Id -eq 10400 | Select-Object TimeCreated, Id, Message

# 3) 排除硬件级错误（WHEA 无错误 → CPU/PCIe 物理层大概率没问题）
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'} -MaxEvents 50

# 4) 异常关机/断电记录
Get-WinEvent -FilterHashtable @{LogName='System'; Id=41,6008} -MaxEvents 20 |
    Select-Object TimeCreated, Id, Message

# 5) 驱动是什么时候、被谁装的（关键！）
Select-String -Path 'C:\Windows\INF\setupapi.dev.log' -Pattern 'rt640x64|RTINSTALLER|Realtek' |
    Select-Object -Last 40

# 6) 已安装的网卡驱动包与版本日期
pnputil /enum-drivers | Select-String -Context 0,6 'rt640x64|Realtek'

# 7) 网卡高级属性（节能项是重点嫌疑）
Get-NetAdapterAdvancedProperty -Name "以太网" | Select-Object DisplayName, DisplayValue
Get-NetAdapterPowerManagement -Name "以太网"
Get-NetAdapter -Name "以太网" | Select-Object LinkSpeed, MediaConnectionState, Status

# 8) 电源/快速启动相关
(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power').HiberbootEnabled
powercfg /q SCHEME_CURRENT SUB_PCIEXPRESS
```

## 四、证据链（时间线）

1. **事件日志**：`rt640x64` Event ID 2（Hardware IO error）+ `NDIS` 10400（驱动请求重置）共 **46 条**，集中在某天 21:20–21:39（40 秒内连续重置，单次计数最高 **42 次**）→ 典型的**芯片级锁死**表现。
2. **WHEA 错误 0 条** → 排除 CPU / PCIe 物理链路问题。
3. **节能项已全关**（`*EEE=0`、`EnableGreenEthernet=0`、`AdvancedEEE=0`），排除"节能导致掉线"。

## 五、软件侧的排查（都已排除）

| 假设 | 验证 | 结论 |
|------|------|------|
| Windows 更新引入 | 查更新历史：仅 Defender 定义、语言包，**无网卡/芯片组更新** | ❌ 排除 |
| 驱动版本旧 | 从 Realtek 官网下载最新版（`10.80.50`）安装 → **轻载下仍复发** | ❌ 排除 |
| 节能/绿色以太网 | 全部关闭后复现 | ❌ 排除 |
| 快速启动 / 电源方案 | 调整后复现 | ❌ 排除 |
| 厂商控制中心触发 | 观察到"玩游戏时切出去开控制中心 → 切回瞬间断网" | ⚠️ 是**触发开关**（切电源/PCIe 状态），不是根因 |

## 六、结论

> **板载 RTL8125 网卡（或主板网络电路）硬件缺陷。**
> 厂商控制中心切换电源/性能状态时叠加游戏高负载，是触发开关；软件层（驱动、节能、系统更新）均已排除。
> 此前也出现过同样故障，且**全新重装系统后仍复现** → 进一步排除软件因素。

## 七、处置建议

1. **保修期内** → 走售后（模板见下），要求检修主板网络电路 / 更换主板。
2. **过保或需立刻可用** → BIOS 里禁用板载网卡，改用 **USB 3.0 有线网卡**（还能额外获得一条链路参与多链路聚合，见 `05-network-speed-tools`）。
3. 顺带处理：故障恢复后把网卡设为**关闭节能**（`PnPCapabilities`）并把**快速启动关掉**，减少复发概率。

## 八、售后工单模板

```text
设备型号：（填写完整型号）
序列号  ：（填写 SN）
故障现象：有线网卡（Realtek 2.5GbE，板载）随机断网，设备管理器中网卡消失，
         重启无效；需关机+拔电源+长按电源键30秒放电后才能恢复。
证据    ：系统日志中 rt640x64 事件 ID 2（Hardware IO error）与 NDIS 事件 ID 10400
         （驱动请求重置）在同一时间段内连续出现数十次，速率降为 0 bps。
已排除  ：驱动已升级到官网最新版、节能相关选项全部关闭、系统已全新重装，故障依旧复现。
诉求    ：检查主板网络电路/网卡硬件，判定是否更换主板。
```

---

**复用价值**：这套「事件日志（Provider + Event ID）→ WHEA 排除 → 驱动安装溯源（setupapi.dev.log）→ 节能项核查 → 排除系统更新」的流程，适用于**任何网卡/外设随机性故障**的定性。
