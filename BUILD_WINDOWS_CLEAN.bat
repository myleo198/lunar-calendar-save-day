@echo off
chcp 65001 >nul
setlocal EnableExtensions

cd /d "%~dp0"

echo =====================================================
echo LICH AM GIA TOC - WINDOWS BUILD
echo =====================================================
echo.
echo Chon che do:
echo.
echo   1. DEBUG   - chay app ngay tren may nay
echo   2. RELEASE - build app doc lap de copy sang may khac
echo.
set /p MODE=Nhap lua chon 1 hoac 2: 

if "%MODE%"=="1" (
  call "%~dp0BUILD_WINDOWS_DEBUG_ONLY.bat"
  echo.
  echo Da thoat che do DEBUG.
  pause
  exit /b %ERRORLEVEL%
)

if "%MODE%"=="2" (
  call "%~dp0BUILD_WINDOWS_RELEASE_ONLY.bat"
  echo.
  echo Da thoat che do RELEASE.
  pause
  exit /b %ERRORLEVEL%
)

echo.
echo Lua chon khong hop le: %MODE%
pause
exit /b 1
