$log = "$PSScriptRoot\net_restore.log"
function L($m) { $m | Out-File -FilePath $log -Append -Encoding UTF8 }
L "=== 恢复自动协商 + 复查 $(Get-Date) ==="
$n = "以太网"
try {
    Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword "*SpeedDuplex" -DisplayValue "自动侦测" -NoRestart -ErrorAction Stop
    L "SpeedDuplex 已恢复为 自动侦测"
    Start-Sleep 2
    Restart-NetAdapter -Name $n -ErrorAction Stop
    L "网卡已重启"
    Start-Sleep 15
}
catch { L ("操作失败: " + $_.Exception.Message) }

$cur = Get-NetAdapter -Name $n
L ("当前: " + $cur.Status + " | " + $cur.LinkSpeed + " | 全双工=" + $cur.FullDuplex)
L "--- 节能类参数现状 ---"
Get-NetAdapterAdvancedProperty -Name $n | Where-Object { $_.RegistryKeyword -in @("GigaLite", "PowerSavingMode", "EnableGreenEthernet", "*EEE", "AdvancedEEE", "*SpeedDuplex") } | ForEach-Object { L ("  " + $_.RegistryKeyword + " = " + $_.DisplayValue) }
L "--- 近 2 小时网卡报错（rt640x64 / NDIS） ---"
$since = (Get-Date).AddHours(-2)
$ev = Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = $since } -ErrorAction SilentlyContinue |
Where-Object { $_.ProviderName -match 'rt640|Realtek|NDIS|Netwtw|Tcpip' -and $_.LevelDisplayName -ne 'Information' }
if ($ev) { $ev | Select-Object -First 20 | ForEach-Object { L ("  " + $_.TimeCreated + " [" + $_.LevelDisplayName + "] " + $_.ProviderName + " ID=" + $_.Id) } }
else { L "  无网卡相关错误日志（正常）" }
L "=== 结束 ==="
