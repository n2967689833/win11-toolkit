@echo off
chcp 65001 >nul
echo Installing ACE Priority Guard (admin required)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0install_guard.ps1','-Install'"
echo.
echo Done (a UAC window should have appeared).
pause
