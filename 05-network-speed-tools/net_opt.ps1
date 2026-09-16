$log = "$env:USERPROFILE\.openclaw\workspace\net_opt.log"
function L($m) { $m | Out-File -FilePath $log -Append -Encoding UTF8 }
L "=== 网卡降速项优化 $(Get-Date) ==="

$n = (Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Realtek' -and $_.Status -eq 'Up' } | Select-Object -First 1).Name
if (-not $n) { $n = "以太网" }
L "目标网卡: $n"
L ("优化前速率: " + (Get-NetAdapter -Name $n).LinkSpeed)

foreach ($t in @(
        @{ k = "GigaLite"; v = "关闭" },
        @{ k = "PowerSavingMode"; v = "关闭" },
        @{ k = "EnableGreenEthernet"; v = "关闭" },
        @{ k = "*EEE"; v = "关闭" },
        @{ k = "WolShutdownLinkSpeed"; v = "不降速" }
    )) {
    try {
        Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword $t.k -DisplayValue $t.v -NoRestart -ErrorAction Stop
        L ("设置 " + $t.k + " = " + $t.v + "  [OK]")
    }
    catch { L ("设置 " + $t.k + " 失败: " + $_.Exception.Message) }
}

L "重启网卡以应用..."
try { Restart-NetAdapter -Name $n -ErrorAction Stop; L "网卡已重启" } catch { L ("网卡重启失败: " + $_.Exception.Message) }
Start-Sleep 15
L ("第1轮后速率: " + (Get-NetAdapter -Name $n).LinkSpeed)

$vals = (Get-NetAdapterAdvancedProperty -Name $n -RegistryKeyword "*SpeedDuplex").ValidDisplayValues
L ("SpeedDuplex 全部可选值: " + ($vals -join " / "))

if ((Get-NetAdapter -Name $n).LinkSpeed -ne "1 Gbps" -and (Get-NetAdapter -Name $n).LinkSpeed -ne "2.5 Gbps") {
    $target = $vals | Where-Object { $_ -match '1\.0 Gbps' } | Select-Object -First 1
    if (-not $target) { $target = $vals | Where-Object { $_ -match 'Gbps' } | Select-Object -First 1 }
    L ("尝试强制: " + $target)
    try {
        Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword "*SpeedDuplex" -DisplayValue $target -NoRestart -ErrorAction Stop
        Start-Sleep 2
        Restart-NetAdapter -Name $n -ErrorAction Stop
        Start-Sleep 15
        L ("强制后速率: " + (Get-NetAdapter -Name $n).LinkSpeed)
    }
    catch { L ("强制失败: " + $_.Exception.Message) }
}

$cur = Get-NetAdapter -Name $n
L ("最终速率: " + $cur.LinkSpeed + " | 状态: " + $cur.Status)
L "=== 结束 ==="
L ""
