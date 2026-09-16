# 01 · ACE 反作弊进程降级守护（ACE Priority Guard）

> 把「手动在任务管理器里把 ACE 的优先级改成低、相关性只留一个核」这套操作，变成**开机自动生效、进游戏后自动重新套用**的守护程序。

## 功能

针对腾讯 ACE 反作弊的用户态进程（`SGuard64` / `SGuardSvc64` / `ACE-Service64` / `ACE-Tray`）：

| 动作 | 值 | 效果 |
|------|-----|------|
| 优先级 | **Idle（最低）** | 只在 CPU 空闲时被调度；**该进程的磁盘 I/O 优先级也随之降到最低**（这是"扫盘抢 IO / 掉帧"的主因） |
| CPU 相关性 | **只保留 1 个逻辑核心**（默认最后一个核） | 不再占用全部 32 线程，把大核让给游戏 |
| 优先级提升 | 关闭 | 防止它临时抢占 |
| 效能模式 EcoQoS | 开启 | 进一步压低调度权重、省电节流 |

**守护逻辑**：每 5 秒轮询，发现 ACE 进程（每次进游戏都会重新拉起、PID 会变）就立刻重新套用设置。

## 为什么需要它

手动设置的问题：**每次进游戏 ACE 都会重新加载**，PID 变化，手动设置全部失效 —— 于是需要这个常驻守护。

## 文件

| 文件 | 作用 |
|------|------|
| `ace_deprioritize.ps1` | 核心脚本，支持 `-Status / -Once / -Restore / -IntervalSec / -CoreIndex / -NoEcoQoS` |
| `install_guard.ps1` | 安装 / 卸载 / 查询：部署到 `C:\ProgramData\ACE_PriorityGuard\`，注册计划任务 `ACE_PriorityGuard`（开机自启 / SYSTEM / 最高权限） |
| `1-安装ACE降级守护.cmd` | 双击安装（自动请求 UAC） |
| `2-查看守护状态.cmd` | 双击查看任务 / 进程 / ACE 当前设置 |
| `3-卸载ACE守护(还原默认).cmd` | 双击卸载，并把 ACE 还原为默认（正常优先级 + 全部核心） |

日志：`C:\ProgramData\ACE_PriorityGuard\guard.log`（超 1MB 自动轮转）

## 用法

```powershell
# 双击 1-安装ACE降级守护.cmd 即可；也可手动：
powershell -File ace_deprioritize.ps1 -Status           # 查看
powershell -File ace_deprioritize.ps1 -Once             # 只执行一次
powershell -File ace_deprioritize.ps1 -Restore          # 还原默认
powershell -File ace_deprioritize.ps1                   # 守护循环
powershell -File ace_deprioritize.ps1 -CoreIndex 31     # 指定绑定核心
```

## 验证效果

打开游戏 → 任务管理器 → **详细信息** → `SGuard64.exe` 右键：

- 「设置优先级」应显示 **低**
- 「设置相关性」应只有 **最后一个 CPU** 一个勾

## 实测记录（本机）

- 非管理员修改受保护进程 → `Access is denied`；**管理员可改**，且 30 秒内未被回滚（本机 ACE 无 watchdog 回滚）。
- 安装后三个进程实测：`优先级=Idle`、`相关性=2147483648`（=CPU31）✅

## ⚠️ 注意

1. 只做**系统层资源调控**：不改动、不删除 ACE 任何文件，不禁用其服务/驱动，**不影响反作弊检测能力**。官方禁止的是"修改 ACE 核心文件"。
2. 副作用：极少数情况下 ACE 自检可能变慢。遇到游戏异常，先跑 `3-卸载ACE守护(还原默认).cmd`。
3. 若 ACE 改了进程名导致找不到，编辑 `ace_deprioritize.ps1` 顶部的 `$TargetPattern` 正则即可。
4. 反作弊厂商政策可能变化，请自行判断是否使用。
