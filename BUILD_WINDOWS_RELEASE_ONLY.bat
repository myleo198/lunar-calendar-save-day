@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo 2| python tools\BUILD_WINDOWS.py
set "ERR=%ERRORLEVEL%"
echo.
pause
exit /b %ERR%
