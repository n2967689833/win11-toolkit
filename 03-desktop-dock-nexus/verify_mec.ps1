$ErrorActionPreference='Continue'
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public class DPIA { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
'@
[DPIA]::SetProcessDPIAware() | Out-Null
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text;
public class WX {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lp);
  public delegate bool EnumProc(IntPtr h, IntPtr lp);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr ex);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X,Y; }
  public static IntPtr Dock=IntPtr.Zero; public static int DL,DT,DW,DH;
  public static void FindDock(uint target){
    Dock=IntPtr.Zero;
    EnumWindows((h,lp)=>{
      uint pid; GetWindowThreadProcessId(h,out pid);
      if(pid==target && IsWindowVisible(h)){
        var cn=new StringBuilder(256); GetClassName(h,cn,256);
        var tx=new StringBuilder(256); GetWindowText(h,tx,256);
        if(cn.ToString().Contains("ThunderRT5Form") && tx.ToString()=="NxDock"){
          Dock=h; RECT r; GetWindowRect(h,out r); DL=r.L; DT=r.T; DW=r.R-r.L; DH=r.B-r.T;
        }
      }
      return true;
    }, IntPtr.Zero);
  }
  public static string Find(string k){
    var sb=new StringBuilder();
    EnumWindows((h,lp)=>{
      if(IsWindowVisible(h)){
        int n=GetWindowTextLength(h);
        if(n>0){ var t=new StringBuilder(n+2); GetWindowText(h,t,n+2);
          if(t.ToString().Contains(k)){ uint pid; GetWindowThreadProcessId(h,out pid); sb.AppendLine(t+" | pid="+pid); }
        }
      }
      return true;
    }, IntPtr.Zero);
    return sb.ToString();
  }
  public static void CloseAll(string k){
    EnumWindows((h,lp)=>{
      if(IsWindowVisible(h)){
        int n=GetWindowTextLength(h);
        if(n>0){ var t=new StringBuilder(n+2); GetWindowText(h,t,n+2);
          if(t.ToString().Contains(k)){ PostMessage(h,0x0010,IntPtr.Zero,IntPtr.Zero); }
        }
      }
      return true;
    }, IntPtr.Zero);
  }
  public static void Click(int x,int y){
    SetCursorPos(x,y); System.Threading.Thread.Sleep(300);
    mouse_event(0x0002,0,0,0,IntPtr.Zero); System.Threading.Thread.Sleep(70);
    mouse_event(0x0004,0,0,0,IntPtr.Zero);
  }
}
'@ -ReferencedAssemblies System.Drawing
Add-Type -AssemblyName System.Drawing

$base="HKCU:\Software\WinSTEP2000\NeXuS\Docks"
$dir="$PSScriptRoot"
$ico="C:\Program Files\OEM\机械革命控制中心\logo\gamingcenter_STD.ico"
$cmd="$env:LOCALAPPDATA\NexusLaunchers\机械革命控制中心.cmd"

[WX]::CloseAll("机械革命控制中心")
Start-Sleep 3
"关闭后残留: " + [WX]::Find("机械革命控制中心")

Set-ItemProperty -Path $base -Name "1Type10"     -Value "1"
Set-ItemProperty -Path $base -Name "1Path10"     -Value $cmd
Set-ItemProperty -Path $base -Name "1IconPath10" -Value $ico -Type String
Set-ItemProperty -Path $base -Name "1IconIndex10" -Value "0" -Type String

Get-Process Nexus -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 3
Start-Process "C:\Program Files (x86)\Winstep\Nexus.exe"
Start-Sleep 22

$p=Get-Process Nexus
[WX]::FindDock([uint32]$p.Id)
$w=[WX]::DW; $h=[WX]::DH
"dock 物理位置: $([WX]::DL),$([WX]::DT)  ${w}x${h}"
$bmp=New-Object System.Drawing.Bitmap $w,$h
$g=[System.Drawing.Graphics]::FromImage($bmp); $hdc=$g.GetHdc()
[void][WX]::PrintWindow([WX]::Dock,$hdc,2)
$g.ReleaseHdc($hdc); $g.Dispose()
$bmp.Save("$dir\dock_final.png",[System.Drawing.Imaging.ImageFormat]::Png)

# 逐列聚类数图标
$cols=New-Object int[] $w
for($x=0;$x -lt $w;$x++){ $c=0; for($y=0;$y -lt $h;$y++){ $px=$bmp.GetPixel($x,$y); if(($px.R+$px.G+$px.B) -gt 45){ $c++ } }; $cols[$x]=$c }
$runs=New-Object System.Collections.ArrayList; $inRun=$false; $start=0
for($x=0;$x -lt $w;$x++){
  $on=($cols[$x] -ge 6)
  if($on -and (-not $inRun)){ $inRun=$true; $start=$x }
  elseif((-not $on) -and $inRun){ $inRun=$false; $e=$x; $e=$e-1; $wd=($e-$start)+1; if($wd -ge 12){ $pp=New-Object object[] 2; $pp[0]=$start; $pp[1]=$e; [void]$runs.Add($pp) } }
}
if($inRun){ $e=$w-1; $wd=($e-$start)+1; $pp=New-Object object[] 2; $pp[0]=$start; $pp[1]=$e; [void]$runs.Add($pp) }
"图标簇数: " + $runs.Count
$idx=0
foreach($r in $runs){ $idx++; "  [$idx] x=$($r[0])..$($r[1])" }

# 裁第 11 个图标做对比
if($runs.Count -ge 11){
  $r11=$runs[10]
  $x0=$r11[0]-6; $ww=($r11[1]-$r11[0])+12
  if($x0 -lt 0){ $x0=0 }
  $src=$bmp.Clone((New-Object System.Drawing.Rectangle $x0,0,$ww,$h),$bmp.PixelFormat)
  $big=New-Object System.Drawing.Bitmap 256,256
  $g2=[System.Drawing.Graphics]::FromImage($big)
  $g2.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g2.DrawImage($src,0,0,256,256); $g2.Dispose()
  $c1=[System.Drawing.Bitmap]::FromFile("$dir\ref_mec_icon.png")
  $cmp=New-Object System.Drawing.Bitmap 560,290
  $g3=[System.Drawing.Graphics]::FromImage($cmp); $g3.Clear([System.Drawing.Color]::FromArgb(25,25,30))
  $g3.DrawImage($c1,10,20,256,256); $g3.DrawImage($big,290,20,256,256); $g3.Dispose()
  $cmp.Save("$dir\mec_final_compare.png",[System.Drawing.Imaging.ImageFormat]::Png)
  $big.Dispose();$src.Dispose();$c1.Dispose();$cmp.Dispose()
  $centerX=[WX]::DL + $r11[0] + [int](($r11[1]-$r11[0])/2)
  $centerY=[WX]::DT + [int]($h/2)
  "第11个图标中心(屏幕物理坐标): $centerX,$centerY"
  $o=New-Object WX+POINT; [void][WX]::GetCursorPos([ref]$o)
  [WX]::Click($centerX,$centerY)
  Start-Sleep 14
  "点击后控制中心窗口: " + [WX]::Find("机械革命控制中心")
  [void][WX]::SetCursorPos($o.X,$o.Y)
}
$bmp.Dispose()
