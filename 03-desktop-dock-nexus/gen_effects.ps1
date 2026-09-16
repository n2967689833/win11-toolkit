Add-Type -AssemblyName System.Drawing
$idir = "$env:USERPROFILE\Documents\Rainmeter\Skins\MiniDock\icons"
$names = @('folder','edge','steam','wechat','qq','valorant','wps')

# ---------- 1. 柔和阴影 (88x26) ----------
$sw = 88; $sh = 26
$shadow = New-Object System.Drawing.Bitmap $sw, $sh
$g = [System.Drawing.Graphics]::FromImage($shadow)
$g.Clear([System.Drawing.Color]::Transparent)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
for ($i = 0; $i -lt 18; $i++) {
  $ins = $i * 1.4
  $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(8, 0, 0, 0))
  $g.FillEllipse($b, $ins, ($ins * 0.5), ($sw - 2 * $ins), ($sh - 2 * ($ins * 0.5)))
  $b.Dispose()
}
$g.Dispose()
$shadow.Save("$idir\shadow.png", [System.Drawing.Imaging.ImageFormat]::Png)
$shadow.Dispose()
Write-Host "shadow.png OK"

# ---------- 2. 倒影 (翻转 + 渐变透明) ----------
foreach ($n in $names) {
  $p = "$idir\$n.png"
  if (-not (Test-Path $p)) { Write-Host "skip $n"; continue }
  $src = [System.Drawing.Bitmap]::FromFile($p)
  $w = $src.Width; $h = $src.Height
  $flip = New-Object System.Drawing.Bitmap $w, $h
  $gf = [System.Drawing.Graphics]::FromImage($flip)
  $m = New-Object System.Drawing.Drawing2D.Matrix(1, 0, 0, -1, 0, $h)
  $gf.Transform = $m
  $gf.DrawImage($src, 0, 0)
  $gf.Dispose()
  $half = [int]($h / 2)
  $refl = New-Object System.Drawing.Bitmap $w, $half
  for ($y = 0; $y -lt $half; $y++) {
    $f = [Math]::Pow(1.0 - ($y / $half), 1.7)
    for ($x = 0; $x -lt $w; $x++) {
      $c = $flip.GetPixel($x, $y)
      $na = [int]($c.A * $f)
      $refl.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($na, $c.R, $c.G, $c.B))
    }
  }
  $refl.Save("$idir\${n}_refl.png", [System.Drawing.Imaging.ImageFormat]::Png)
  $refl.Dispose(); $flip.Dispose(); $src.Dispose()
  Write-Host "OK ${n}_refl.png"
}
Get-ChildItem $idir | Select-Object Name, Length | Format-Table -AutoSize
