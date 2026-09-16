$base = "HKCU:\Software\WinSTEP2000\NeXuS\Docks"
Get-Process Nexus -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 3

# 仅追加：现有 0..7 保持不变，新增 8..14
$items = @(
  @{ I=8;  L='QClaw';            P='D:\QClaw\v0.2.37.630\QClaw.exe';                        T='1' },
  @{ I=9;  L='雷神加速器';       P='D:\LeiGod_Acc\leigod_launcher.exe';                      T='1' },
  @{ I=10; L='机械革命控制中心'; P='C:\Users\Public\Desktop\机械革命控制中心.lnk';            T='1' },
  @{ I=11; L='壁纸引擎';         P='steam://rungameid/431960';                               T='1' },
  @{ I=12; L='Counter-Strike 2'; P='steam://rungameid/730';                                  T='1' },
  @{ I=13; L='PUBG';             P='steam://rungameid/578080';                               T='1' },
  @{ I=14; L='桌面';             P=($env:USERPROFILE + '\Desktop');                          T='1' }
)
foreach($o in $items){
  New-ItemProperty -Path $base -Name ("1Label"+$o.I) -Value $o.L -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $base -Name ("1Path"+$o.I)  -Value $o.P -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $base -Name ("1Type"+$o.I)  -Value $o.T -PropertyType String -Force | Out-Null
}
New-ItemProperty -Path $base -Name "DockNoItems1" -Value "14" -PropertyType String -Force | Out-Null
Write-Host "已追加 7 个条目，当前共 15 个"
