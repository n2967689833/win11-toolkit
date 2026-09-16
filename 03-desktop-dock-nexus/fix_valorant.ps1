$bytes = [System.IO.File]::ReadAllBytes("D:\ACLOS\Launcher\aclos.ico")
Write-Host ("ico 头: {0:X2} {1:X2} {2:X2} {3:X2}" -f $bytes[0],$bytes[1],$bytes[2],$bytes[3])

Add-Type -AssemblyName PresentationCore, WindowsBase, System.Xaml
$uri = New-Object System.Uri("D:\ACLOS\Launcher\aclos.ico")
$dec = [System.Windows.Media.Imaging.BitmapDecoder]::Create($uri, [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat, [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
Write-Host "帧数: $($dec.Frames.Count)"
$best = $null
foreach ($fr in $dec.Frames) {
  Write-Host "  帧 $($fr.PixelWidth)x$($fr.PixelHeight) $($fr.Format)"
  if (-not $best -or $fr.PixelWidth -gt $best.PixelWidth) { $best = $fr }
}
if ($best) {
  # 缩放到 64x64
  $scale = 64.0 / $best.PixelWidth
  $tb = New-Object System.Windows.Media.Imaging.TransformedBitmap($best, (New-Object System.Windows.Media.ScaleTransform($scale,$scale)))
  $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
  $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($tb))
  $out = "$env:USERPROFILE\Documents\Rainmeter\Skins\MiniDock\icons\valorant.png"
  $fs = [System.IO.File]::Create($out)
  $enc.Save($fs); $fs.Close()
  Write-Host "valorant.png 已从小 ICO 帧生成 ($($best.PixelWidth)px -> 64px)"
} else { Write-Host "无法解码" }
