$ErrorActionPreference='Continue'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class CF {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lp);
  public delegate bool EnumProc(IntPtr h, IntPtr lp);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr ex);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
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
  public static IntPtr FindExplorer(string titlePart){
    IntPtr found=IntPtr.Zero;
    EnumWindows((h,l)=>{
      var cn=new StringBuilder(256); GetClassName(h,cn,256);
      if(cn.ToString()=="CabinetWClass"){
        var tx=new StringBuilder(512); GetWindowText(h,tx,512);
        if(tx.ToString().Contains(titlePart)){ found=h; }
      }
      return true;
    }, IntPtr.Zero);
    return found;
  }
  public static void Drag(int x1,int y1,int x2,int y2){
    SetCursorPos(x1,y1); System.Threading.Thread.Sleep(500);
    mouse_event(0x0002,0,0,0,IntPtr.Zero); System.Threading.Thread.Sleep(400);
    int steps=25;
    for(int i=1;i<=steps;i++){
      int x=x1+(x2-x1)*i/steps; int y=y1+(y2-y1)*i/steps;
      SetCursorPos(x,y); System.Threading.Thread.Sleep(70);
    }
    System.Threading.Thread.Sleep(500);
    mouse_event(0x0004,0,0,0,IntPtr.Zero);
  }
  public static int CountIcons(){
    var bmp=new System.Drawing.Bitmap(DW,DH);
    var g=System.Drawing.Graphics.FromImage(bmp); var hdc=g.GetHdc();
    PrintWindow(Dock,hdc,2); g.ReleaseHdc(hdc); g.Dispose();
    int[] cols=new int[DW];
    for(int x=0;x<DW;x++){ int c=0; for(int y=0;y<DH;y++){ var p=bmp.GetPixel(x,y); if((p.R+p.G+p.B)>45) c++; } cols[x]=c; }
    int runs=0; bool inRun=false; int start=0;
    for(int x=0;x<DW;x++){ bool on=cols[x]>=6; if(on&&!inRun){inRun=true;start=x;} else if(!on&&inRun){inRun=false; if((x-1-start)+1>=12) runs++;} }
    if(inRun){ if((DW-1-start)+1>=12) runs++; }
    bmp.Dispose(); return runs;
  }
}
'@ -ReferencedAssemblies System.Drawing
[void][CF]::SetProcessDPIAware()

# 1) 准备测试文件夹和快捷方式
$tf="$env:USERPROFILE\NexusDragTest"
New-Item -ItemType Directory -Path $tf -Force | Out-Null
$lnk="$tf\Nexus拖入测试.lnk"
if(-not (Test-Path $lnk)){
  $sh=New-Object -ComObject WScript.Shell
  $sc=$sh.CreateShortcut($lnk); $sc.TargetPath="C:\Windows\System32\notepad.exe"; $sc.Save()
}
"测试快捷方式: " + (Test-Path $lnk)

# 2) 打开资源管理器并定位窗口
Start-Process explorer.exe $tf
Start-Sleep 6
$h=$null
for($i=0;$i -lt 10 -and $h -eq [IntPtr]::Zero;$i++){ $h=[CF]::FindExplorer("NexusDragTest"); Start-Sleep 1 }
"资源管理器窗口: " + $h.ToInt64()
[void][CF]::SetWindowPos($h,[IntPtr]::Zero,200,500,900,520,0x0040)
[void][CF]::SetForegroundWindow($h)
Start-Sleep 3

# 3) 用 UI Automation 找快捷方式的屏幕位置
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes
$root=[System.Windows.Automation.AutomationElement]::FromHandle($h)
$cond=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty,[System.Windows.Automation.ControlType]::ListItem)
$items=$root.FindAll([System.Windows.Automation.TreeScope]::Descendants,$cond)
"列表项数: " + $items.Count
$target=$null
for($i=0;$i -lt $items.Count;$i++){
  $nm=$items.Item($i).Current.Name
  if($nm -match 'Nexus'){ $target=$items.Item($i); "找到项: $nm" }
}
if(-not $target){ "未找到目标项，改用第一个列表项"; if($items.Count -gt 0){ $target=$items.Item(0); "用: " + $target.Current.Name } }

[CF]::FindDock([uint32](Get-Process Nexus | Select-Object -First 1).Id)
"dock: $([CF]::DL),$([CF]::DT) $([CF]::DW)x$([CF]::DH)"
$before=[CF]::CountIcons()
"拖入前图标数: $before"

if($target){
  $r=$target.Current.BoundingRectangle
  $sx=[int]($r.X + $r.Width/2); $sy=[int]($r.Y + $r.Height/2)
  "源坐标: $sx,$sy"
  $dx=[CF]::DL + 30; $dy=[CF]::DT + 85
  "目标坐标: $dx,$dy"
  [CF]::Drag($sx,$sy,$dx,$dy)
  Start-Sleep 5
  $after=[CF]::CountIcons()
  "拖入后图标数: $after"
}
