$log="$env:USERPROFILE\.openclaw\workspace\desktop_theme\duba_defender.log"
"=== Defender 排除项 $(Get-Date) ===" | Out-File $log -Encoding UTF8
try{
  $p=Get-MpPreference
  "ExclusionPath: " + ($p.ExclusionPath -join ' | ') | Out-File $log -Append -Encoding UTF8
  "ExclusionProcess: " + ($p.ExclusionProcess -join ' | ') | Out-File $log -Append -Encoding UTF8
  "ExclusionExtension: " + ($p.ExclusionExtension -join ' | ') | Out-File $log -Append -Encoding UTF8
}catch{ "查询失败: $($_.Exception.Message)" | Out-File $log -Append -Encoding UTF8 }
# 若有指向 Kingsoft/毒霸 的排除路径则移除
try{
  $p=Get-MpPreference
  foreach($x in $p.ExclusionPath){
    if($x -match '(?i)kingsoft|duba|毒霸'){
      Remove-MpPreference -ExclusionPath $x -ErrorAction SilentlyContinue
      "已移除排除路径: $x" | Out-File $log -Append -Encoding UTF8
    }
  }
  foreach($x in $p.ExclusionProcess){
    if($x -match '(?i)kingsoft|duba|kxe|ksoft'){
      Remove-MpPreference -ExclusionProcess $x -ErrorAction SilentlyContinue
      "已移除排除进程: $x" | Out-File $log -Append -Encoding UTF8
    }
  }
}catch{ "清理排除项失败: $($_.Exception.Message)" | Out-File $log -Append -Encoding UTF8 }
"=== 结束 ===" | Out-File $log -Append -Encoding UTF8
