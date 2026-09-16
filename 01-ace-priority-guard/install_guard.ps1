<#
    ACE 降级守护 - 安装/卸载/状态
    用法（需管理员）：
      powershell -File install_guard.ps1 -Install     安装开机守护（SYSTEM 权限，最高权限运行）
      powershell -File install_guard.ps1 -Uninstall    卸载守护并还原 ACE 设置为默认
      powershell -File install_guard.ps1 -Status       查看守护任务与当前 ACE 进程状态
#>
param([switch]$Install, [switch]$Uninstall, [switch]$Status)

$ErrorActionPreference = "Continue"
$TaskName   = "ACE_PriorityGuard"
$InstallDir = "C:\ProgramData\ACE_PriorityGuard"
$GuardName  = "ace_deprioritize.ps1"
$SrcGuard   = Join-Path $PSScriptRoot $GuardName
$DstGuard   = Join-Path $InstallDir $GuardName

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "❌ 需要管理员权限。请右键以管理员身份运行，或从 .cmd 入口启动。" -ForegroundColor Red
    exit 1
}

if ($Status) {
    Write-Host "=== 计划任务 ===" -ForegroundColor Cyan
    $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($t) {
        $i = Get-ScheduledTaskInfo -TaskName $TaskName
        Write-Host ("  任务: {0}  状态: {1}" -f $t.TaskName, $t.State)
        Write-Host ("  上次运行: {0}   下次运行: {1}" -f $i.LastRunTime, $i.NextRunTime)
    } else { Write-Host "  未安装" }
    Write-Host "=== 守护进程 ===" -ForegroundColor Cyan
    $gp = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
          Where-Object { $_.CommandLine -match 'ace_deprioritize' }
    if ($gp) { $gp | ForEach-Object { Write-Host ("  PID={0}  {1}" -f $_.ProcessId, ($_.CommandLine -replace '.*-File ','' -replace '"','')) } }
    else { Write-Host "  未在运行" }
    Write-Host "=== ACE 进程当前设置 ===" -ForegroundColor Cyan
    if (Test-Path $DstGuard) { & powershell -NoProfile -ExecutionPolicy Bypass -File $DstGuard -Status }
    exit 0
}

if ($Uninstall) {
    Write-Host "正在卸载 ACE 降级守护..." -ForegroundColor Yellow
    # 1) 停止并删除任务
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "  ✅ 计划任务已删除"
    } else { Write-Host "  (任务本来就不存在)" }
    # 2) 结束残留守护进程
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'ace_deprioritize' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    # 3) 还原 ACE 设置为默认
    if (Test-Path $DstGuard) { & powershell -NoProfile -ExecutionPolicy Bypass -File $DstGuard -Restore }
    # 4) 删除安装目录
    Start-Sleep -Seconds 1
    Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  ✅ 已还原 ACE 为默认设置并清理完成" -ForegroundColor Green
    exit 0
}

# ---------------- 安装 ----------------
if (-not (Test-Path $SrcGuard)) { Write-Host "❌ 找不到 $SrcGuard" -ForegroundColor Red; exit 1 }

Write-Host "正在安装 ACE 降级守护..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item $SrcGuard $DstGuard -Force
Write-Host "  ✅ 已部署: $DstGuard"

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument ("-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"{0}`" -IntervalSec 5" -f $DstGuard)
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null
Write-Host "  ✅ 计划任务已注册: $TaskName（开机自启 / SYSTEM / 最高权限）"

Start-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Write-Host "  ✅ 守护已启动（立即生效）"

Write-Host "`n=== 当前状态 ===" -ForegroundColor Green
& powershell -NoProfile -ExecutionPolicy Bypass -File $DstGuard -Status
Write-Host "`n提示：开游戏后 ACE 重新拉起进程时，守护会在 5 秒内自动重新降级。" -ForegroundColor DarkGray
Write-Host "想还原：运行 卸载ACE守护.cmd（会同时还原 ACE 为默认设置）。" -ForegroundColor DarkGray
