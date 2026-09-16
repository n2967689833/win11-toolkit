Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
public class JumboIcon {
  [DllImport("shell32.dll", CharSet=CharSet.Unicode)] static extern IntPtr SHGetFileInfo(string pszPath, uint attrs, ref SHFILEINFO psfi, uint cb, uint flags);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct SHFILEINFO { public IntPtr hIcon; public int iIcon; public uint dwAttributes; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=260)] public string szDisplayName; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=80)] public string szTypeName; }
  [DllImport("shell32.dll")] static extern int SHGetImageList(int iImageList, ref Guid riid, out IImageList ppv);
  [ComImport, Guid("46EB5926-582E-4017-9FDF-E8998DAA0950"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IImageList {
    int Add(IntPtr hbmImage, IntPtr hbmMask, ref int pi);
    int ReplaceIcon(int i, IntPtr hicon, ref int pi);
    int SetOverlayImage(int iImage, int iOverlay);
    int Replace(int i, IntPtr hbmImage, IntPtr hbmMask);
    int AddMasked(IntPtr hbmImage, int crMask, ref int pi);
    int Draw(IntPtr pimldp);
    int Remove(int i);
    int GetIcon(int i, int flags, out IntPtr picon);
  }
  [DllImport("user32.dll")] static extern bool DestroyIcon(IntPtr h);
  public static Bitmap Extract(string path, int shil, int outSize) {
    var info = new SHFILEINFO();
    IntPtr res = SHGetFileInfo(path, 0, ref info, (uint)Marshal.SizeOf(typeof(SHFILEINFO)), 0x4000);
    if (info.iIcon == 0) return null;
    Guid iid = new Guid("46EB5926-582E-4017-9FDF-E8998DAA0950");
    IImageList list;
    int hr = SHGetImageList(shil, ref iid, out list);
    if (hr != 0 || list == null) return null;
    IntPtr hicon;
    list.GetIcon(info.iIcon, 1, out hicon);
    if (hicon == IntPtr.Zero) return null;
    var ico = Icon.FromHandle(hicon);
    var src = ico.ToBitmap();
    var dst = new Bitmap(outSize, outSize);
    using (var g = Graphics.FromImage(dst)) {
      g.InterpolationMode = InterpolationMode.HighQualityBicubic;
      g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
      g.DrawImage(src, 0, 0, outSize, outSize);
    }
    src.Dispose(); ico.Dispose(); DestroyIcon(hicon);
    return dst;
  }
}
'@

$idir = "$env:USERPROFILE\Documents\Rainmeter\Skins\MiniDock\icons"
$targets = [ordered]@{
  'folder'   = 'C:\Windows\explorer.exe'
  'edge'     = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
  'steam'    = 'D:\steam\Steam.exe'
  'wechat'   = (Get-ChildItem 'D:\' -Directory -ErrorAction SilentlyContinue | ForEach-Object { $p = Join-Path $_.FullName 'Weixin\Weixin.exe'; if (Test-Path $p) { $p } } | Select-Object -First 1)
  'qq'       = 'D:\QQ\QQ.exe'
  'valorant' = 'D:\ACLOS\aclos-launcher.exe'
  'wps'      = 'D:\WPS Office\ksolaunch.exe'
}
foreach ($k in $targets.Keys) {
  $t = $targets[$k]
  if (-not $t -or -not (Test-Path $t)) { Write-Host "skip $k"; continue }
  try {
    $bmp = [JumboIcon]::Extract($t, 4, 64)   # SHIL_JUMBO=4 -> 64px output
    if (-not $bmp) { Write-Host "null $k"; continue }
    $bmp.Save("$idir\$k.png", [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "OK $k ($($bmp.Width)x$($bmp.Height))"
    $bmp.Dispose()
  } catch { Write-Host ("FAIL " + $k + " : " + $_.Exception.Message) }
}
Get-ChildItem $idir | Select-Object Name, Length | Format-Table -AutoSize
