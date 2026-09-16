$ErrorActionPreference = 'Continue'
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public class DPI { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
'@
[DPI]::SetProcessDPIAware() | Out-Null
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text;
public class NW {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lp);
  public delegate bool EnumProc(IntPtr h, IntPtr lp);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
  public static IntPtr Dock=IntPtr.Zero; public static int W=0,H=0;
  public static void Find(uint target){
    Dock=IntPtr.Zero;
    EnumWindows((h,lp)=>{
      uint pid; GetWindowThreadProcessId(h, out pid);
      if(pid==target && IsWindowVisible(h)){
        var cn=new StringBuilder(256); GetClassName(h,cn,256);
        var tx=new StringBuilder(256); GetWindowText(h,tx,256);
        if(cn.ToString().Contains("ThunderRT5Form") && tx.ToString()=="NxDock"){
          Dock=h; RECT r; GetWindowRect(h, out r); W=r.R-r.L; H=r.B-r.T;
        }
      }
      return true;
    }, IntPtr.Zero);
  }
}
'@ -ReferencedAssemblies System.Drawing
Add-Type -AssemblyName System.Drawing
$p=Get-Process Nexus -ErrorAction SilentlyContinue
if(-not $p){ "Nexus 未运行"; exit }
[NW]::Find([uint32]$p.Id)
"dock 窗口: " + [NW]::Dock.ToInt64() + "  尺寸 " + [NW]::W + "x" + [NW]::H
if([NW]::Dock -eq [IntPtr]::Zero){ "未找到 dock 窗口"; exit }
$w=[NW]::W; $h=[NW]::H
$bmp=New-Object System.Drawing.Bitmap $w,$h
$g=[System.Drawing.Graphics]::FromImage($bmp)
$hdc=$g.GetHdc()
$ok=[NW]::PrintWindow([NW]::Dock,$hdc,2)
$g.ReleaseHdc($hdc); $g.Dispose()
$out=$PSScriptRoot
$bmp.Save("$out\dock_now.png",[System.Drawing.Imaging.ImageFormat]::Png)
$cols=New-Object int[] $w
for($x=0;$x -lt $w;$x++){
  $c=0
  for($y=0;$y -lt $h;$y++){
    $px=$bmp.GetPixel($x,$y)
    if(($px.R+$px.G+$px.B) -gt 45){ $c++ }
  }
  $cols[$x]=$c
}
$runs=New-Object System.Collections.ArrayList
$inRun=$false; $start=0
for($x=0;$x -lt $w;$x++){
  $on=($cols[$x] -ge 6)
  if($on -and (-not $inRun)){ $inRun=$true; $start=$x }
  elseif((-not $on) -and $inRun){ $inRun=$false; $e=$x; $e=$e-1; $wd=($e-$start)+1; if($wd -ge 12){ $pp=New-Object object[] 2; $pp[0]=$start; $pp[1]=$e; [void]$runs.Add($pp) } }
}
if($inRun){ $e=$w-1; $wd=($e-$start)+1; if($wd -ge 12){ $pp=New-Object object[] 2; $pp[0]=$start; $pp[1]=$e; [void]$runs.Add($pp) } }
"渲染出的图标簇数: " + $runs.Count
$i=1
foreach($r in $runs){ "  [$i] x=$($r[0])..$($r[1]) 宽=" + (($r[1]-$r[0])+1); $i++ }
$bmp.Dispose()
