$ErrorActionPreference = 'Continue'
$base = "HKCU:\Software\WinSTEP2000\NeXuS\Docks"

# 1) 停掉 Nexus（避免退出时覆盖注册表）
Get-Process Nexus -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 3

# 2) 清理旧的条目值
$d = Get-Item $base
$d.GetValueNames() | Where-Object { $_ -match '^1(Label|Path|Type|Icon|Command|Args)\d+$' } | ForEach-Object {
  Remove-ItemProperty -Path $base -Name $_ -ErrorAction SilentlyContinue
}

# 3) 写入新条目
$items = @(
  @{ Label = "开始菜单";     Path = "*20";                                        Type = "2" },
  @{ Label = "资源管理器";   Path = "C:\Windows\explorer.exe";                    Type = "1" },
  @{ Label = "Microsoft Edge"; Path = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"; Type = "1" },
  @{ Label = "Steam";        Path = "D:\steam\Steam.exe";                          Type = "1" },
  @{ Label = "微信";         Path = "D:\微信\Weixin\Weixin.exe";                   Type = "1" },
  @{ Label = "QQ";           Path = "D:\QQ\QQ.exe";                                Type = "1" },
  @{ Label = "无畏契约";     Path = "D:\ACLOS\aclos-launcher.exe";                 Type = "1" },
  @{ Label = "WPS Office";   Path = "D:\WPS Office\ksolaunch.exe";                 Type = "1" }
)
$i = 0
foreach ($it in $items) {
  New-ItemProperty -Path $base -Name ("1Label" + $i) -Value $it.Label -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $base -Name ("1Path" + $i)  -Value $it.Path  -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $base -Name ("1Type" + $i)  -Value $it.Type  -PropertyType String -Force | Out-Null
  $i++
}
# last index
New-ItemProperty -Path $base -Name "DockNoItems1" -Value ($i - 1) -PropertyType DWord -Force | Out-Null

# 4) 外观设置：不显示名称；保留倒影
New-ItemProperty -Path $base -Name "DockShowLabels1" -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $base -Name "DockReflectionSize1" -Value 100 -PropertyType DWord -Force | Out-Null

Write-Host "条目写入完成: $i 个"
$d2 = Get-Item $base
$d2.GetValueNames() | Where-Object { $_ -match '^1(Label|Path|Type)\d+$|DockNoItems1|DockShowLabels1' } | Sort-Object | ForEach-Object { "{0} = {1}" -f $_, $d2.GetValue($_) }
