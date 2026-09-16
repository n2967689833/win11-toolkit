@echo off
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
set "PY=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if not exist "%PY%" set "PY=py"
"%PY%" "%~dp0njupt_autologin.py" --uninstall
echo.
pause
