$ErrorActionPreference='Continue'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class CJ {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lp);
  public delegate bool EnumProc(IntPtr h, IntPtr lp);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr ex);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X,Y; }
  public static IntPtr Dock=IntPtr.Zero; public static int DL,DT,DW,DH;
  public static void FindDock(uint t){
    EnumWindows((h,l)=>{
      uint pid; GetWindowThreadProcessId(h,out pid);
      if(pid==t){
        var cn=new StringBuilder(256); GetClassName(h,cn,256);
        var tx=new StringBuilder(256); GetWindowText(h,tx,256);
        if(cn.ToString().Contains("ThunderRT5Form") && tx.ToString()=="NxDock"){ Dock=h; RECT r; GetWindowRect(h,out r); DL=r.L; DT=r.T; DW=r.R-r.L; DH=r.B-r.T; }
      }
      return true;
    }, IntPtr.Zero);
  }
  public static void Drag(int x1,int y1,int x2,int y2){
    SetCursorPos(x1,y1); System.Threading.Thread.Sleep(400);
    mouse_event(0x0002,0,0,0,IntPtr.Zero); System.Threading.Thread.Sleep(300);
    for(int i=1;i<=20;i++){ SetCursorPos(x1+(x2-x1)*i/20, y1+(y2-y1)*i/20); System.Threading.Thread.Sleep(70); }
    System.Threading.Thread.Sleep(400);
    mouse_event(0x0004,0,0,0,IntPtr.Zero);
  }
}
'@ -ReferencedAssemblies System.Drawing
[void][CJ]::SetProcessDPIAware()

$base="HKCU:\Software\WinSTEP2000\NeXuS\Docks"
function GetItems(){ $d=Get-Item $base; $o=@(); for($i=0;$i -le 14;$i++){ $o += [string]$d.GetValue("1Label$i") }; return ($o -join '|') }

$p=Get-Process Nexus | Select-Object -First 1
[CJ]::FindDock([uint32]$p.Id)
"dock: $([CJ]::DL),$([CJ]::DT) $([CJ]::DW)x$([CJ]::DH)"
"拖动前: " + (GetItems)
$o=New-Object CJ+POINT; [void][CJ]::GetCursorPos([ref]$o)
[CJ]::Drag(([CJ]::DL+950),([CJ]::DT+85),([CJ]::DL+950),([CJ]::DT+500))
[void][CJ]::SetCursorPos($o.X,$o.Y)
Start-Sleep 6
"拖动后: " + (GetItems)
"DockNoItems1 = " + (Get-Item $base).GetValue("DockNoItems1")
