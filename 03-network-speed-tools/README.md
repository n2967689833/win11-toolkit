# 05 · 网络优化与多链路测速（Network Speed Tools）

> 从「下载只有 11MB/s」排查到「双链路聚合 ≈ 17MB/s」的全套工具：网卡高级参数优化 + 按网卡绑定的精确测速。

## 文件

| 文件 | 作用 |
|------|------|
| `net_opt.ps1` | **优化网卡**：关闭 GigaLite / PowerSavingMode / GreenEthernet / `*EEE`，`WolShutdownLinkSpeed` 不降速，可强制 `SpeedDuplex=1.0Gbps`（需管理员） |
| `net_restore.ps1` | **还原**：`SpeedDuplex=自动侦测`，并输出网卡错误日志（需管理员） |
| `speedtest_bond.py` | ✅ **双链路聚合测速**：按源 IP 绑定有线/无线，分别测 + 同时测（验证聚合效果） |
| `speedtest_iface.py` | 按源地址绑定网卡分别测速（多线程分片） |
| `speedtest_eth.py` / `speedtest_eth2.py` | 早期单链路测速（多镜像源对比） |
| `dbg_iface.py` | 调试：查看 302 跳转后的真实地址（测速 0 字节时排查用） |
| `speedtest.cmd` | 双击一键测速（调用 `speedtest_bond.py`） |

## 使用前改这里

测速脚本里写死了两条链路的源 IP（为脱敏已替换为占位符），请改成你自己的：

```python
ETH, WIFI = "192.168.1.10", "192.168.1.20"   # 有线 / 无线的本机 IPv4
```

用 `ipconfig` 或 `Get-NetIPAddress -AddressFamily IPv4` 查看。

## 实测结论（示例）

| 链路 | 单链路 | 同时使用 |
|------|--------|---------|
| 有线（协商 100Mbps） | 9.18 MB/s | 双链路同时：**10.94 MB/s** |
| 无线（Wi-Fi 6E） | 6.19 MB/s | 12+12 线程：**17.11 MB/s** |

- 网卡是 2.5G，但**链路只协商到 100Mbps** → 判定瓶颈在物理层（网线 / 路由器端口 / 墙口），软件层优化到头。
- **不要改接口跃点**：两条默认路由跃点等价（InterfaceMetric 相同）是多连接分流聚合的前提。
- 客户端侧：下载工具并发调高（16→32）、Steam 选国内节点。

## 注意

- `net_opt.ps1` / `net_restore.ps1` 需要**管理员**（改网卡高级属性），会弹 UAC。
- 强制 `SpeedDuplex=1.0Gbps` 后若对端不支持会**直接断网**，用 `net_restore.ps1` 还原为自动侦测即可。
