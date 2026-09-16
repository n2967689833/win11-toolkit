$ErrorActionPreference='Continue'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class CD {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lp);
  public delegate bool EnumProc(IntPtr h, IntPtr lp);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr ex);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X,Y; }
  public static IntPtr Dock=IntPtr.Zero; public static int DL,DT,DW,DH;
  public static void FindDock(uint t){
    EnumWindows((h,l)=>{
      uint pid; GetWindowThreadProcessId(h,out pid);
      if(pid==t){
        var cn=new StringBuilder(256); GetClassName(h,cn,256);
        var tx=new StringBuilder(256); GetWindowText(h,tx,256);
        if(cn.ToString().Contains("ThunderRT5Form") && tx.ToString()=="NxDock"){
          Dock=h; RECT r; GetWindowRect(h,out r); DL=r.L; DT=r.T; DW=r.R-r.L; DH=r.B-r.T;
        }
      }
      return true;
    }, IntPtr.Zero);
  }
  public static bool Vis(){ return IsWindowVisible(Dock); }
  public static string Find(string k){ var sb=new StringBuilder(); EnumWindows((h,l)=>{ if(IsWindowVisible(h)){ int n=GetWindowTextLength(h); if(n>0){ var t=new StringBuilder(n+2); GetWindowText(h,t,n+2); if(t.ToString().Contains(k)){ uint pid; GetWindowThreadProcessId(h,out pid); sb.AppendLine(t+" pid="+pid); } } } return true; }, IntPtr.Zero); return sb.ToString(); }
  public static void Click(int x,int y){ SetCursorPos(x,y); System.Threading.Thread.Sleep(450); mouse_event(0x0002,0,0,0,IntPtr.Zero); System.Threading.Thread.Sleep(90); mouse_event(0x0004,0,0,0,IntPtr.Zero); }
}
'@ -ReferencedAssemblies System.Drawing
[void][CD]::SetProcessDPIAware()

$p=Get-Process Nexus | Select-Object -First 1
[CD]::FindDock([uint32]$p.Id)
"dock: $([CD]::DL),$([CD]::DT) $([CD]::DW)x$([CD]::DH) 可见=$([CD]::Vis())"

if([CD]::DW -le 0){ "未找到 dock 窗口"; exit }

# 取第 11 个图标位置
$bmp=New-Object System.Drawing.Bitmap ([CD]::DW),([CD]::DH)
$g=[System.Drawing.Graphics]::FromImage($bmp); $hdc=$g.GetHdc()
[void][CD]::PrintWindow([CD]::Dock,$hdc,2)
$g.ReleaseHdc($hdc); $g.Dispose()
$w=[CD]::DW; $h=[CD]::DH
$cols=New-Object int[] $w
for($x=0;$x -lt $w;$x++){ $c=0; for($y=0;$y -lt $h;$y++){ $px=$bmp.GetPixel($x,$y); if(($px.R+$px.G+$px.B) -gt 45){ $c++ } }; $cols[$x]=$c }
$runs=New-Object System.Collections.ArrayList; $inRun=$false; $start=0
for($x=0;$x -lt $w;$x++){
  $on=($cols[$x] -ge 6)
  if($on -and (-not $inRun)){ $inRun=$true; $start=$x }
  elseif((-not $on) -and $inRun){ $inRun=$false; $e=$x; $e=$e-1; $wd=($e-$start)+1; if($wd -ge 12){ $pp=New-Object object[] 2; $pp[0]=$start; $pp[1]=$e; [void]$runs.Add($pp) } }
}
if($inRun){ $e=$w-1; $wd=($e-$start)+1; $pp=New-Object object[] 2; $pp[0]=$start; $pp[1]=$e; [void]$runs.Add($pp) }
"图标簇数: $($runs.Count)"
$bmp.Dispose()

$marker="C:\Users\Public\nexus_probe.txt"
if(Test-Path $marker){ [System.IO.File]::Delete($marker) }
"点击前探针: " + (Test-Path $marker)

if($runs.Count -ge 11){
  $r11=$runs[10]
  $cx=[CD]::DL + $r11[0] + [int](($r11[1]-$r11[0])/2)
  $cy=[CD]::DT + [int]($h/2)
  $o=New-Object CD+POINT; [void][CD]::GetCursorPos([ref]$o)
  "点击第11项: $cx,$cy"
  [CD]::Click($cx,$cy)
  Start-Sleep 12
  "点击后探针: " + (Test-Path $marker)
  if(Test-Path $marker){ Get-Content $marker }
  "控制中心窗口: [" + [CD]::Find("机械革命控制中心") + "]"
  [void][CD]::SetCursorPos($o.X,$o.Y)
}
