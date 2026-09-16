@echo off
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
set "PY=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if not exist "%PY%" set "PY=py"
echo This will log out first, then auto login again (about 5 seconds offline).
echo.
"%PY%" "%~dp0njupt_autologin.py" --logout
timeout /t 3 /nobreak >nul
"%PY%" "%~dp0njupt_autologin.py" --once
echo.
pause
