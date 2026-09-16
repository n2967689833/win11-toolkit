@echo off
chcp 65001 >nul
title Network speed test
echo ============================================
echo   Dual-link speed test (Ethernet + Wi-Fi)
echo ============================================
echo.
"%LOCALAPPDATA%\Programs\Python\Python312\python.exe" "%~dp0speedtest_bond.py"
echo.
echo (Close this window when done)
pause
