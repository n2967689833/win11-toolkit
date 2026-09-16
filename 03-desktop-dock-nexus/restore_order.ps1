$base = "HKCU:\Software\WinSTEP2000\NeXuS\Docks"
Get-Process Nexus -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 3

$items = @(
  @{ L='开始菜单';         P='*20';   T='2' },
  @{ L='资源管理器';       P='C:\Windows\explorer.exe'; T='1' },
  @{ L='Microsoft Edge';   P='C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'; T='1' },
  @{ L='Steam';            P='D:\steam\Steam.exe'; T='1' },
  @{ L='微信';             P='D:\微信\Weixin\Weixin.exe'; T='1' },
  @{ L='QQ';               P='D:\QQ\QQ.exe'; T='1' },
  @{ L='无畏契约';         P='D:\ACLOS\aclos-launcher.exe'; T='1' },
  @{ L='WPS Office';       P='D:\WPS Office\ksolaunch.exe'; T='1' },
  @{ L='QClaw';            P='D:\QClaw\v0.2.37.630\QClaw.exe'; T='1' },
  @{ L='雷神加速器';       P='D:\LeiGod_Acc\leigod_launcher.exe'; T='1' },
  @{ L='机械革命控制中心'; P="$env:LOCALAPPDATA\NexusLaunchers\机械革命控制中心.cmd"; T='1' },
  @{ L='壁纸引擎';         P='D:\steam\steamapps\common\wallpaper_engine\launcher.exe'; T='1' },
  @{ L='Counter-Strike 2'; P='D:\steam\steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe'; T='1' },
  @{ L='PUBG';             P='D:\steam\steamapps\common\PUBG\TslGame\Binaries\Win64\TslGame.exe'; T='1' },
  @{ L='桌面';             P="$env:USERPROFILE\Desktop"; T='0' }
)
$i=0
foreach($o in $items){
  Set-ItemProperty -Path $base -Name ("1Label"+$i) -Value $o.L
  Set-ItemProperty -Path $base -Name ("1Path"+$i)  -Value $o.P
  Set-ItemProperty -Path $base -Name ("1Type"+$i)  -Value $o.T
  $i++
}
Set-ItemProperty -Path $base -Name "DockNoItems1" -Value "14"
Set-ItemProperty -Path $base -Name "DockLocked1" -Value "True"
Set-ItemProperty -Path "HKCU:\Software\WinSTEP2000\NeXuS" -Name "LockIcons" -Value "False"
Write-Host "顺序已恢复；DockLocked1=True；LockIcons=False"
