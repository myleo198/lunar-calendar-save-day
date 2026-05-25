@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo Dang chay trinh build Windows bang Python...
python tools\BUILD_WINDOWS.py
set "ERR=%ERRORLEVEL%"

echo.
if "%ERR%"=="0" (
  echo Hoan tat.
) else (
  echo Build that bai. Hay xem file log moi nhat trong thu muc logs.
)
echo.
pause
exit /b %ERR%
