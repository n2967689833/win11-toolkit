$base = "HKCU:\Software\WinSTEP2000\NeXuS\Docks"
Get-Process Nexus -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 3

# 清理
$d = Get-Item $base
$d.GetValueNames() | Where-Object { $_ -match '^1(Label|Path|Type|Icon|Command|Args)\d+$' } | ForEach-Object { Remove-ItemProperty -Path $base -Name $_ -ErrorAction SilentlyContinue }

# 恢复默认条目（原样）
$orig = @(
  @{ L='开始菜单';   P='*20'; T='2' },
  @{ L='时钟';       P='';    T='3' },
  @{ L='回收站';     P='1';   T='3' },
  @{ L='CPU 计量器'; P='2';   T='3' },
  @{ L='天气';       P='4';   T='3' },
  @{ L='RAM 计量器'; P='7';   T='3' },
  @{ L='Microsoft Edge'; P='C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'; T='1' },
  @{ L='快速启动';   P='*95'; T='2' },
  @{ L='媒体播放器'; P='*97'; T='2' },
  @{ L='桌面截图';   P='*78'; T='2' }
)
$i=0
foreach($o in $orig){
  New-ItemProperty -Path $base -Name ("1Label"+$i) -Value $o.L -PropertyType String -Force | Out-Null
  if($o.P -ne ''){ New-ItemProperty -Path $base -Name ("1Path"+$i) -Value $o.P -PropertyType String -Force | Out-Null }
  New-ItemProperty -Path $base -Name ("1Type"+$i) -Value $o.T -PropertyType String -Force | Out-Null
  $i++
}
New-ItemProperty -Path $base -Name "DockNoItems1" -Value ($i-1) -PropertyType String -Force | Out-Null
Write-Host "已恢复 $i 个默认条目"
