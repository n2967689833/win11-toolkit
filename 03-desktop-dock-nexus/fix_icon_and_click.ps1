$ErrorActionPreference='Continue'
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public class DPI9 { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
'@
[DPI9]::SetProcessDPIAware() | Out-Null

Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text;
public class WK {
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
  public static IntPtr Dock=IntPtr.Zero;
  public static int DL,DT,DW,DH;
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
  public static string FindTitle(string title){
    var sb=new StringBuilder();
    EnumWindows((h,lp)=>{
      if(IsWindowVisible(h)){
        int n=GetWindowTextLength(h);
        if(n>0){ var t=new StringBuilder(n+2); GetWindowText(h,t,n+2);
          if(t.ToString().Contains(title)){ uint pid; GetWindowThreadProcessId(h,out pid); sb.AppendLine("HWND="+h.ToInt64()+" pid="+pid+" title="+t); }
        }
      }
      return true;
    }, IntPtr.Zero);
    return sb.ToString();
  }
  public static void CloseAll(string title){
    EnumWindows((h,lp)=>{
      if(IsWindowVisible(h)){
        int n=GetWindowTextLength(h);
        if(n>0){ var t=new StringBuilder(n+2); GetWindowText(h,t,n+2);
          if(t.ToString().Contains(title)){ PostMessage(h,0x0010,IntPtr.Zero,IntPtr.Zero); }
        }
      }
      return true;
    }, IntPtr.Zero);
  }
  public static void Click(int x,int y){
    SetCursorPos(x,y); System.Threading.Thread.Sleep(250);
    mouse_event(0x0002,0,0,0,IntPtr.Zero); System.Threading.Thread.Sleep(60);
    mouse_event(0x0004,0,0,0,IntPtr.Zero);
  }
}
'@ -ReferencedAssemblies System.Drawing
Add-Type -AssemblyName System.Drawing

$base="HKCU:\Software\WinSTEP2000\NeXuS\Docks"
$dir="$env:USERPROFILE\.openclaw\workspace\desktop_theme"
$ico="C:\Program Files\OEM\机械革命控制中心\logo\gamingcenter_STD.ico"

# 关闭已打开的控制中心窗口，便于点击测试判定
[WK]::CloseAll("机械革命控制中心")
Start-Sleep 3
"关闭后残留窗口: " + ([WK]::FindTitle("机械革命控制中心"))

# 只保留 1IconPath10 + 1IconIndex10
Set-ItemProperty -Path $base -Name "1IconPath10" -Value $ico -Type String
Set-ItemProperty -Path $base -Name "1IconIndex10" -Value "0" -Type String
Start-Process "C:\Program Files (x86)\Winstep\Nexus.exe" -ErrorAction SilentlyContinue
Start-Sleep 22

$p=Get-Process Nexus -ErrorAction SilentlyContinue
[WK]::FindDock([uint32]$p.Id)
"dock 物理位置: $([WK]::DL),$([WK]::DT)  $([WK]::DW)x$([WK]::DH)"
$bmp=New-Object System.Drawing.Bitmap ([WK]::DW),([WK]::DH)
$g=[System.Drawing.Graphics]::FromImage($bmp); $hdc=$g.GetHdc()
[void][WK]::PrintWindow([WK]::Dock,$hdc,2)
$g.ReleaseHdc($hdc); $g.Dispose()
$bmp.Save("$dir\dock_iconcheck.png",[System.Drawing.Imaging.ImageFormat]::Png)
$src=$bmp.Clone((New-Object System.Drawing.Rectangle 900,0,100,[WK]::DH),$bmp.PixelFormat)
$big=New-Object System.Drawing.Bitmap 256,256
$g2=[System.Drawing.Graphics]::FromImage($big); $g2.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g2.DrawImage($src,0,0,256,256); $g2.Dispose()
$c1=[System.Drawing.Bitmap]::FromFile("$dir\ref_mec_icon.png")
$cmp=New-Object System.Drawing.Bitmap 560,290
$g3=[System.Drawing.Graphics]::FromImage($cmp); $g3.Clear([System.Drawing.Color]::FromArgb(25,25,30))
$g3.DrawImage($c1,10,20,256,256); $g3.DrawImage($big,290,20,256,256); $g3.Dispose()
$cmp.Save("$dir\mec_icon_compare4.png",[System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose();$src.Dispose();$bmp.Dispose();$c1.Dispose();$cmp.Dispose()

# 点击测试：点第 11 个图标中心
$cx=[WK]::DL + 948
$cy=[WK]::DT + 85
"点击坐标: $cx,$cy"
$o=New-Object WK+POINT; [void][WK]::GetCursorPos([ref]$o)
[WK]::Click($cx,$cy)
Start-Sleep 14
"点击后控制中心窗口: " + ([WK]::FindTitle("机械革命控制中心"))
[void][WK]::SetCursorPos($o.X,$o.Y)
"已恢复鼠标位置"
