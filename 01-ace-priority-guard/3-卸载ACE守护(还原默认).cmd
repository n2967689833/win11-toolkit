@echo off
chcp 65001 >nul
echo Uninstalling ACE Priority Guard and restoring defaults...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0install_guard.ps1','-Uninstall'"
echo.
pause
