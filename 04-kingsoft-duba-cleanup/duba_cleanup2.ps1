$ErrorActionPreference = 'Continue'
$log = "$PSScriptRoot\duba_cleanup2.log"
function L($m){ $m | Out-File -FilePath $log -Append -Encoding UTF8 }
L "=== 毒霸驱动服务清理 $(Get-Date) ==="

# 1) 删除毒霸驱动服务
foreach($svc in @("KAVBootC","kisknl","kisnetflt","kisnetm","ksapi64","KAVBootC64")){
  $r = & sc.exe delete $svc 2>&1
  L "sc delete $svc -> $r"
}
# 删除空的服务注册表项（若存在）
foreach($svc in @("KAVBootC","kisknl","kisnetflt","kisnetm","ksapi64")){
  $p="HKLM:\SYSTEM\CurrentControlSet\Services\$svc"
  if(Test-Path $p){
    try{ Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop; L "已删除服务键: $svc" }
    catch{ L "服务键删除失败(重启后由系统清理): $svc -- $($_.Exception.Message)" }
  }
}

# 2) 再试删除安装目录
$dir="C:\Program Files (x86)\Kingsoft"
if(Test-Path $dir){
  try{
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction Stop
    L "已删除: $dir"
  }catch{
    L "仍被占用: $dir -- $($_.Exception.Message)"
    # 3) 创建开机(SYSTEM)一次性任务，重启后删除，然后自删
    $cmd = 'cmd.exe /c rmdir /s /q "C:\Program Files (x86)\Kingsoft" & schtasks /delete /tn Mechrevo_DubaCleanup /f'
    $r = & schtasks.exe /create /tn "Mechrevo_DubaCleanup" /tr $cmd /sc onstart /ru SYSTEM /rl highest /f 2>&1
    L "创建开机清理任务 -> $r"
  }
}

# 4) 检查其余残留
foreach($p in @("C:\ProgramData\Kingsoft\KIS","C:\ProgramData\Kingsoft\vduba","C:\Windows\System32\drivers\ksapi64.sys","C:\Windows\System32\drivers\KAVBootC64.sys","C:\Windows\System32\drivers\kisknl.sys")){
  L ("存在检查 " + $p + " => " + (Test-Path $p))
}
L "=== 结束 ==="
L ""
