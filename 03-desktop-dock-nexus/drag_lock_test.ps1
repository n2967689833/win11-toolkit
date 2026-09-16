$ErrorActionPreference='Continue'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class CE {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lp);
  public delegate bool EnumProc(IntPtr h, IntPtr lp);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr ex);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
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
  public static void Drag(int x1,int y1,int x2,int y2,int steps){
    SetCursorPos(x1,y1); System.Threading.Thread.Sleep(400);
    mouse_event(0x0002,0,0,0,IntPtr.Zero); System.Threading.Thread.Sleep(300);
    for(int i=1;i<=steps;i++){
      int x=x1+(x2-x1)*i/steps; int y=y1+(y2-y1)*i/steps;
      SetCursorPos(x,y); System.Threading.Thread.Sleep(60);
    }
    System.Threading.Thread.Sleep(300);
    mouse_event(0x0004,0,0,0,IntPtr.Zero);
  }
  public static int CountIcons(IntPtr hwnd,int w,int h){
    var bmp=new System.Drawing.Bitmap(w,h);
    var g=System.Drawing.Graphics.FromImage(bmp); var hdc=g.GetHdc();
    PrintWindow(hwnd,hdc,2); g.ReleaseHdc(hdc); g.Dispose();
    int[] cols=new int[w];
    for(int x=0;x<w;x++){ int c=0; for(int y=0;y<h;y++){ var p=bmp.GetPixel(x,y); if((p.R+p.G+p.B)>45) c++; } cols[x]=c; }
    int runs=0; bool inRun=false; int start=0;
    for(int x=0;x<w;x++){
      bool on=cols[x]>=6;
      if(on && !inRun){ inRun=true; start=x; }
      else if(!on && inRun){ inRun=false; if((x-1-start)+1>=12) runs++; }
    }
    if(inRun){ if((w-1-start)+1>=12) runs++; }
    bmp.Dispose();
    return runs;
  }
}
'@ -ReferencedAssemblies System.Drawing
[void][CE]::SetProcessDPIAware()

$p=Get-Process Nexus | Select-Object -First 1
[CE]::FindDock([uint32]$p.Id)
"起始 dock: $([CE]::DL),$([CE]::DT) $([CE]::DW)x$([CE]::DH)"
"起始图标数: " + [CE]::CountIcons([CE]::Dock,[CE]::DW,[CE]::DH)

$o=New-Object CE+POINT; [void][CE]::GetCursorPos([ref]$o)

# 测试1：拖 dock 空白处（第1、2个图标之间的间隙 x≈110），应无效
$gapX=[CE]::DL + 110
$gapY=[CE]::DT + 85
"--- 测试1：拖动 dock 空白处 ---"
[CE]::Drag($gapX,$gapY,$gapX+150,$gapY+120,10)
Start-Sleep 3
[CE]::FindDock([uint32]$p.Id)
"拖动后 dock: $([CE]::DL),$([CE]::DT) $([CE]::DW)x$([CE]::DH)"

# 测试2：把第 11 个图标往下拖出 dock，应无效（图标应保持）
"--- 测试2：把第11个图标拖出去 ---"
$iconX=[CE]::DL + 950
$iconY=[CE]::DT + 85
$cntBefore=[CE]::CountIcons([CE]::Dock,[CE]::DW,[CE]::DH)
[CE]::Drag($iconX,$iconY,$iconX,$iconY+400,12)
Start-Sleep 4
[void][CE]::SetCursorPos($o.X,$o.Y)
[CE]::FindDock([uint32]$p.Id)
$cntAfter=[CE]::CountIcons([CE]::Dock,[CE]::DW,[CE]::DH)
"图标数 拖前/拖后: $cntBefore / $cntAfter"
