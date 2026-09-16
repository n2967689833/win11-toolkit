Add-Type -AssemblyName System.Drawing
$idir = "$env:USERPROFILE\Documents\Rainmeter\Skins\MiniDock\icons"
$targets = [ordered]@{
  'folder'   = 'C:\Windows\explorer.exe'
  'edge'     = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
  'steam'    = 'D:\steam\Steam.exe'
  'wechat'   = (Get-Item 'D:\We*\Weixin\Weixin.exe' -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
  'qq'       = 'D:\QQ\QQ.exe'
  'valorant' = 'D:\ACLOS\aclos-launcher.exe'
  'wps'      = 'D:\WPS Office\ksolaunch.exe'
}
foreach ($k in $targets.Keys) {
  $t = $targets[$k]
  if (-not $t -or -not (Test-Path $t)) { Write-Host "skip $k"; continue }
  try {
    $ico = New-Object System.Drawing.Icon($t, 64, 64)
    $bmp = $ico.ToBitmap()
    $bmp.Save("$idir\$k.png", [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "OK $k ($($bmp.Width)x$($bmp.Height))"
    $bmp.Dispose(); $ico.Dispose()
  } catch {
    Write-Host ("FAIL " + $k + " : " + $_.Exception.Message)
  }
}
Get-ChildItem $idir | Select-Object Name, Length | Format-Table -AutoSize
