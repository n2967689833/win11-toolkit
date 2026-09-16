$ErrorActionPreference = 'Continue'
$log = "$PSScriptRoot\duba_cleanup3.log"
function L($m){ $m | Out-File -FilePath $log -Append -Encoding UTF8 }
L "=== 注册开机清理任务 $(Get-Date) ==="

# 写一个 cmd 脚本，负责删除残留目录并自删任务
$cmdPath = "C:\Windows\Temp\cleanup_duba.cmd"
$cmdBody = @'
@echo off
rmdir /s /q "C:\Program Files (x86)\Kingsoft"
schtasks /delete /tn "Mechrevo_DubaCleanup" /f
del "%~f0"
'@
$cmdBody | Out-File -FilePath $cmdPath -Encoding ASCII
L "已写清理脚本: $cmdPath"

# 注册开机任务（SYSTEM）
try{
  $action = New-ScheduledTaskAction -Execute $cmdPath
  $trigger = New-ScheduledTaskTrigger -AtStartup
  $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
  Register-ScheduledTask -TaskName "Mechrevo_DubaCleanup" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
  L "任务已注册: Mechrevo_DubaCleanup (开机以SYSTEM运行，删除残留目录后自删)"
}catch{
  L "任务注册失败: $($_.Exception.Message)"
}

# 再检查一遍服务是否已无
$svcs = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '(?i)kavboot|kisknl|kisnet|ksapi' }
if($svcs){ L ("仍存在的服务键: " + (($svcs | Select-Object -ExpandProperty PSChildName) -join ',')) } else { L "服务键已清空" }
L "=== 结束 ==="
L ""
