Add-Type -AssemblyName System.Drawing
$idir = "$env:USERPROFILE\Documents\Rainmeter\Skins\MiniDock\icons"

# 1) 无畏契约图标（来自 aclos.ico）
$ico = New-Object System.Drawing.Icon("D:\ACLOS\Launcher\aclos.ico", 64, 64)
$bmp = $ico.ToBitmap()
$bmp.Save("$idir\valorant.png", [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "valorant.png OK $($bmp.Width)x$($bmp.Height)"

# 倒影（翻转 + 渐隐）
$w=$bmp.Width; $h=$bmp.Height
$flip = New-Object System.Drawing.Bitmap $w, $h
$gf = [System.Drawing.Graphics]::FromImage($flip)
$m = New-Object System.Drawing.Drawing2D.Matrix(1,0,0,-1,0,$h)
$gf.Transform = $m
$gf.DrawImage($bmp, 0, 0)
$gf.Dispose()
$half = [int]($h/2)
$refl = New-Object System.Drawing.Bitmap $w, $half
for ($y=0; $y -lt $half; $y++) {
  $f = [Math]::Pow(1.0 - ($y/$half), 1.7)
  for ($x=0; $x -lt $w; $x++) {
    $c = $flip.GetPixel($x,$y)
    $refl.SetPixel($x,$y,[System.Drawing.Color]::FromArgb([int]($c.A*$f), $c.R, $c.G, $c.B))
  }
}
$refl.Save("$idir\valorant_refl.png", [System.Drawing.Imaging.ImageFormat]::Png)
$refl.Dispose(); $flip.Dispose(); $bmp.Dispose(); $ico.Dispose()
Write-Host "valorant_refl.png OK"

# 2) 阴影（96x96 径向柔和，中心最深）
$sw=96
$shadow = New-Object System.Drawing.Bitmap $sw, $sw
$g = [System.Drawing.Graphics]::FromImage($shadow)
$g.Clear([System.Drawing.Color]::Transparent)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
for ($i=0; $i -lt 24; $i++) {
  $ins = $i * 2.0
  $a = [int](10 * (1.0 - $i/24.0) + 2)
  $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($a,0,0,0))
  $g.FillEllipse($b, $ins, $ins, ($sw-2*$ins), ($sw-2*$ins))
  $b.Dispose()
}
$g.Dispose()
$shadow.Save("$idir\shadow.png", [System.Drawing.Imaging.ImageFormat]::Png)
$shadow.Dispose()
Write-Host "shadow.png OK (96x96)"
Get-ChildItem $idir | Select-Object Name, Length | Format-Table -AutoSize
