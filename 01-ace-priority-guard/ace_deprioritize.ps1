<#
    ACE 反作弊进程 降级守护脚本  (ACE Priority Guard)
    ------------------------------------------------------------------
    作用：把腾讯 ACE 反作弊的用户态进程，自动降到最低优先级 + 只绑 1 个核心，
          并在它们被游戏重新拉起时自动重新应用（守护模式）。

    处理对象：SGuard64 / SGuardSvc64 / ACE-Service64 / ACE-Tray
    处理方式：
      1) 优先级 -> Idle（最低；同时进程 I/O 优先级也会随之降到最低，减少扫盘抢占）
      2) CPU 相关性 -> 只保留 1 个逻辑核心（默认最后一个核）
      3) 关闭优先级提升（PriorityBoost）
      4) 可选：效能模式 EcoQoS（省电节流，进一步压低调度权重）

    用法：
      powershell -File ace_deprioritize.ps1 -Status          查看当前状态
      powershell -File ace_deprioritize.ps1 -Once            只执行一次
      powershell -File ace_deprioritize.ps1                  守护循环（默认每 5 秒）
      powershell -File ace_deprioritize.ps1 -Restore         还原为默认（正常优先级 + 全部核心）
      powershell -File ace_deprioritize.ps1 -IntervalSec 3 -CoreIndex 31
#>
param(
    [int]$IntervalSec = 5,
    [int]$CoreIndex = -1,      # -1 = 自动选最后一个逻辑核心
    [switch]$Once,
    [switch]$Restore,
    [switch]$Status,
    [switch]$NoEcoQoS,
    [string]$LogFile = "C:\ProgramData\ACE_PriorityGuard\guard.log"
)

$ErrorActionPreference = "Continue"
$TargetPattern = '^(SGuard64|SGuardSvc64|ACE-Service64|ACE-Tray)$'

# ---------------- 日志 ----------------
function Write-Log([string]$msg, [switch]$Quiet) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    if (-not $Quiet) { Write-Host $line }
    try {
        $d = Split-Path $LogFile -Parent
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
        if ((Test-Path $LogFile) -and ((Get-Item $LogFile).Length -gt 1MB)) {
            Move-Item $LogFile "$LogFile.old" -Force
        }
        Add-Content -Path $LogFile -Value $line -Encoding UTF8
    } catch { }
}

# ---------------- EcoQoS（效能模式）P/Invoke ----------------
$EcoReady = $false
if (-not $NoEcoQoS) {
    try {
        if (-not ("AceQoS" -as [type])) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class AceQoS {
    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_POWER_THROTTLING_STATE { public uint Version; public uint ControlMask; public uint StateMask; }
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool SetProcessInformation(IntPtr hProcess, int infoClass, ref PROCESS_POWER_THROTTLING_STATE info, uint size);
    public static bool SetEco(IntPtr h, bool on) {
        var s = new PROCESS_POWER_THROTTLING_STATE();
        s.Version = 1; s.ControlMask = 0x1; s.StateMask = on ? 0x1u : 0x0u;
        return SetProcessInformation(h, 4 /*ProcessPowerThrottling*/, ref s, (uint)Marshal.SizeOf(s));
    }
}
"@
        }
        $EcoReady = $true
    } catch { $EcoReady = $false }
}

# ---------------- 核心逻辑 ----------------
function Get-Targets {
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match $TargetPattern }
}

function New-AffinityMask([int]$cores) {
    if ($CoreIndex -ge 0 -and $CoreIndex -lt $cores) { return [IntPtr]([long]1 -shl $CoreIndex) }
    return [IntPtr]([long]1 -shl ($cores - 1))   # 最后一个逻辑核心
}

function Show-Status {
    $cores = [Environment]::ProcessorCount
    Write-Log ("当前逻辑核心数: {0}   目标优先级: Idle   目标相关性掩码: {1}" -f $cores, (New-AffinityMask $cores))
    $found = $false
    foreach ($p in Get-Targets) {
        $found = $true
        $pc = "?"; $af = "?"
        try { $pc = $p.PriorityClass } catch { $pc = "(受保护,读不到)" }
        try { $af = $p.ProcessorAffinity } catch { $af = "(受保护,读不到)" }
        Write-Log ("  PID={0,-7} {1,-14} 优先级={2,-12} 相关性={3}" -f $p.Id, $p.ProcessName, $pc, $af)
    }
    if (-not $found) { Write-Log "  (未发现 ACE 进程，可能没在运行)" }
}

function Apply-Once {
    $cores = [Environment]::ProcessorCount
    $mask = New-AffinityMask $cores
    $n = 0
    foreach ($p in Get-Targets) {
        $n++
        # 1) 优先级 -> Idle
        try {
            if ($p.PriorityClass -ne 'Idle') {
                $p.PriorityClass = 'Idle'
                Write-Log ("PID={0,-7} {1,-14} 优先级 -> Idle ✅" -f $p.Id, $p.ProcessName)
            }
        } catch { Write-Log ("PID={0} {1} 设置优先级失败: {2}" -f $p.Id, $p.ProcessName, $_.Exception.Message) }
        # 2) 相关性 -> 单核
        try {
            if ([Int64]$p.ProcessorAffinity -ne [Int64]$mask) {
                $p.ProcessorAffinity = $mask
                Write-Log ("PID={0,-7} {1,-14} 相关性 -> {2} (单核) ✅" -f $p.Id, $p.ProcessName, $mask)
            }
        } catch { Write-Log ("PID={0} {1} 设置相关性失败: {2}" -f $p.Id, $p.ProcessName, $_.Exception.Message) }
        # 3) 关闭优先级提升
        try { if ($p.PriorityBoostEnabled) { $p.PriorityBoostEnabled = $false } } catch { }
        # 4) 效能模式
        if ($EcoReady) { try { [AceQoS]::SetEco($p.Handle, $true) | Out-Null } catch { } }
    }
    return $n
}

function Restore-All {
    $cores = [Environment]::ProcessorCount
    if ($cores -ge 63) { $all = [IntPtr]::new(-1) }
    else { $all = [IntPtr](([long]1 -shl $cores) - 1) }
    foreach ($p in Get-Targets) {
        try { $p.PriorityClass = 'Normal'; Write-Log ("PID={0} {1} 优先级 -> Normal ✅" -f $p.Id, $p.ProcessName) } catch { Write-Log ("PID={0} 还原优先级失败: {1}" -f $p.Id, $_.Exception.Message) }
        try { $p.ProcessorAffinity = $all; Write-Log ("PID={0} {1} 相关性 -> 全部核心 ✅" -f $p.Id, $p.ProcessName) } catch { }
        try { $p.PriorityBoostEnabled = $true } catch { }
        if ($EcoReady) { try { [AceQoS]::SetEco($p.Handle, $false) | Out-Null } catch { } }
    }
}

# ---------------- 入口 ----------------
if ($Status) { Show-Status; return }
if ($Restore) { Write-Log "=== 还原 ACE 进程设置为默认 ==="; Restore-All; return }
if ($Once) { Write-Log "=== 执行一次降级 ==="; $c = Apply-Once; Write-Log "处理进程数: $c"; Show-Status; return }

# 守护循环（单实例互斥）
$mtx = New-Object System.Threading.Mutex($false, "Local\ACE_PriorityGuard_Mutex")
if (-not $mtx.WaitOne(0)) { Write-Log "已有守护实例在运行，本实例退出"; return }
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Log ("=== 守护启动 (管理员={0}, 间隔={1}s, 核心数={2}) ===" -f $isAdmin, $IntervalSec, [Environment]::ProcessorCount)
$tick = 0
try {
    while ($true) {
        $before = @{}
        foreach ($p in Get-Targets) { $before[$p.Id] = "{0}|{1}" -f $p.PriorityClass, $p.ProcessorAffinity }
        Apply-Once | Out-Null
        # 只在状态变化时写日志，避免刷屏
        foreach ($p in Get-Targets) {
            $now = "{0}|{1}" -f $p.PriorityClass, $p.ProcessorAffinity
            if ($before[$p.Id] -ne $now) {
                Write-Log ("PID={0,-7} {1,-14} 已降级 -> 优先级={2} 相关性={3}" -f $p.Id, $p.ProcessName, $p.PriorityClass, $p.ProcessorAffinity)
            }
        }
        $tick++
        if ($tick % 120 -eq 0) { Write-Log ("心跳：守护运行中，当前 ACE 进程数 {0}" -f (Get-Targets).Count) }
        Start-Sleep -Seconds $IntervalSec
    }
} finally {
    $mtx.ReleaseMutex()
}
