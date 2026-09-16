$ErrorActionPreference = 'Continue'
$log = "$PSScriptRoot\duba_cleanup.log"
function L($m){ $m | Out-File -FilePath $log -Append -Encoding UTF8 }

L "=== 毒霸残留清理 $(Get-Date) ==="

# 文件：毒霸安装目录（保留 WPS 相关）
$paths = @(
  "C:\Program Files (x86)\Kingsoft\kingsoft antivirus",
  "C:\ProgramData\Kingsoft\DaoHang",
  "C:\ProgramData\Kingsoft\dscan",
  "C:\ProgramData\Kingsoft\DubaGame",
  "C:\ProgramData\Kingsoft\kfc",
  "C:\ProgramData\Kingsoft\kheur",
  "C:\ProgramData\Kingsoft\KIS",
  "C:\ProgramData\Kingsoft\ksbw",
  "C:\ProgramData\Kingsoft\kwfsdata",
  "C:\ProgramData\Kingsoft\Rcmdlocal",
  "C:\ProgramData\Kingsoft\vduba"
)
foreach($p in $paths){
  if(Test-Path $p){
    try{ Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop; L "已删除: $p" }
    catch{ L "删除失败: $p -- $($_.Exception.Message)" }
  } else { L "不存在: $p" }
}
# 若 Kingsoft 目录空了则删除
foreach($d in @("C:\Program Files (x86)\Kingsoft")){
  if(Test-Path $d){
    $rest = Get-ChildItem $d -ErrorAction SilentlyContinue
    if($rest.Count -eq 0){ try{ Remove-Item -LiteralPath $d -Force; L "已删除空目录: $d" }catch{ L "删除失败: $d" } }
    else { L "保留(仍有内容): $d -> " + (($rest | Select-Object -ExpandProperty Name) -join ',') }
  }
}

# 注册表：毒霸专属键（保留 Office/PDF/WPS 等）
$regs = @(
  "HKLM:\SOFTWARE\WOW6432Node\Kingsoft\antivirus",
  "HKLM:\SOFTWARE\WOW6432Node\Kingsoft\installfail",
  "HKLM:\SOFTWARE\WOW6432Node\Kingsoft\KISCommon",
  "HKLM:\SOFTWARE\WOW6432Node\Kingsoft\KISWsc",
  "HKLM:\SOFTWARE\WOW6432Node\Kingsoft\kwspriEx",
  "HKLM:\SOFTWARE\WOW6432Node\Kingsoft\NeedReboot",
  "HKLM:\SOFTWARE\WOW6432Node\Kingsoft\shoujizhushou",
  "HKLM:\SOFTWARE\WOW6432Node\Kingsoft\kfp",
  "HKCU:\Software\Kingsoft\Antivirus",
  "HKCU:\Software\Kingsoft\KISCommon"
)
foreach($r in $regs){
  if(Test-Path $r){
    try{ Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction Stop; L "已删除注册表: $r" }
    catch{ L "注册表删除失败: $r -- $($_.Exception.Message)" }
  } else { L "注册表不存在: $r" }
}

L "=== 清理结束 ==="
L ""
