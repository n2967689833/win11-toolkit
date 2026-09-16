$base = "HKCU:\Software\WinSTEP2000\NeXuS\Docks"
Get-Process Nexus -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 3

$d = Get-Item $base
$d.GetValueNames() | Where-Object { $_ -match '^1(Label|Path|Type|Icon|Command|Args)\d+$' } | ForEach-Object { Remove-ItemProperty -Path $base -Name $_ -ErrorAction SilentlyContinue }

$items = @(
  @{ L='开始菜单';       P='*20';   T='2' },
  @{ L='资源管理器';     P='C:\Windows\explorer.exe'; T='1' },
  @{ L='Microsoft Edge'; P='C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'; T='1' },
  @{ L='Steam';          P='D:\steam\Steam.exe'; T='1' },
  @{ L='微信';           P='D:\微信\Weixin\Weixin.exe'; T='1' },
  @{ L='QQ';             P='D:\QQ\QQ.exe'; T='1' },
  @{ L='无畏契约';       P='D:\ACLOS\aclos-launcher.exe'; T='1' },
  @{ L='WPS Office';     P='D:\WPS Office\ksolaunch.exe'; T='1' }
)
$i=0
foreach($o in $items){
  New-ItemProperty -Path $base -Name ("1Label"+$i) -Value $o.L -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $base -Name ("1Path"+$i)  -Value $o.P -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $base -Name ("1Type"+$i)  -Value $o.T -PropertyType String -Force | Out-Null
  $i++
}
# 全部用字符串（与 Nexus 自身一致）
New-ItemProperty -Path $base -Name "DockNoItems1"        -Value ([string]($i-1)) -PropertyType String -Force | Out-Null
New-ItemProperty -Path $base -Name "DockAutoHideMode1"   -Value "1" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $base -Name "DockReflectionSize1" -Value "128" -PropertyType String -Force | Out-Null
Write-Host "已写入 $i 个条目（字符串类型）"
