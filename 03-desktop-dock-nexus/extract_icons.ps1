Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Continue'
$sdir = "$env:USERPROFILE\Documents\Rainmeter\Skins\MiniDock"
$idir = "$sdir\icons"
New-Item -ItemType Directory -Force -Path $idir | Out-Null
$shell = New-Object -ComObject WScript.Shell

$map = @{}   # key -> target exe path
function Add-Target($key, $path) { if ($path -and (Test-Path $path)) { if (-not $map.ContainsKey($key)) { $map[$key] = $path } } }

Add-Target 'folder' 'C:\Windows\explorer.exe'

$dirs = @("$env:USERPROFILE\Desktop", "C:\Users\Public\Desktop")
foreach ($d in $dirs) {
  if (-not (Test-Path $d)) { continue }
  Get-ChildItem $d -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object {
    try {
      $t = $shell.CreateShortcut($_.FullName).TargetPath
      if (-not $t) { return }
      $low = $t.ToLower()
      if ($low -match 'msedge') { Add-Target 'edge' $t }
      elseif ($low -match 'steam') { Add-Target 'steam' $t }
      elseif ($low -match 'wechat|weixin') { Add-Target 'wechat' $t }
      elseif ($low -match '\\qq\.exe|tencent.*qq') { Add-Target 'qq' $t }
      elseif ($low -match 'riot|valorant') { Add-Target 'valorant' $t }
      elseif ($low -match 'wps') { Add-Target 'wps' $t }
    } catch { }
  }
}

foreach ($k in $map.Keys) {
  $target = $map[$k]
  try {
    $ico = [System.Drawing.Icon]::ExtractAssociatedIcon($target)
    if (-not $ico) { Write-Host "no icon: $k"; continue }
    $bmp = $ico.ToBitmap()
    $big = New-Object System.Drawing.Bitmap -ArgumentList 48, 48
    $g = [System.Drawing.Graphics]::FromImage($big)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($bmp, 0, 0, 48, 48)
    $g.Dispose()
    $big.Save("$idir\$k.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $big.Dispose(); $bmp.Dispose(); $ico.Dispose()
    Write-Host "OK $k <- $target"
  } catch {
    Write-Host ("FAIL " + $k + " : " + $_.Exception.Message)
  }
}
Write-Host "---- output ----"
Get-ChildItem $idir -ErrorAction SilentlyContinue | Select-Object Name, Length | Format-Table -AutoSize
