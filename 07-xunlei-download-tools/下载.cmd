@echo off
chcp 65001 >nul
title 多线程下载器
echo ================================
echo   多线程下载器 (dl.py)  纯并发提速
echo ================================
echo.
set /p URL=1) 粘贴下载直链(URL)，回车: 
if "%URL%"=="" (echo 未输入链接 & pause & exit /b)
set /p OUT=2) 保存路径(留空=保存到本脚本同目录): 
if "%OUT%"=="" set OUT=%~dp0download.bin
set /p HN=3) 并发连接数(留空=32): 
if "%HN%"=="" set HN=32
echo.
echo 提示: 若链接需要 Cookie/Referer，请先在下面粘贴（可留空直接回车跳过）
set /p CK=Cookie(形如 a=b; c=d): 
set /p RF=Referer(形如 https://pan.xunlei.com/): 
echo.
set EXTRA=
if not "%CK%"=="" set EXTRA=%EXTRA% -H "Cookie: %CK%"
if not "%RF%"=="" set EXTRA=%EXTRA% -H "Referer: %RF%"

where py >nul 2>nul
if %errorlevel%==0 (
  py -3 "%~dp0dl.py" "%URL%" -o "%OUT%" -n %HN% %EXTRA%
) else (
  "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" "%~dp0dl.py" "%URL%" -o "%OUT%" -n %HN% %EXTRA%
)
echo.
pause
