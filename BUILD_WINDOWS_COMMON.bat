@echo off
REM COMMON FILE - duoc goi boi DEBUG/RELEASE script.
REM Khong chay truc tiep file nay.

set "PATH=C:\src\flutter\bin;C:\src\Flutter\bin;%PATH%"

if not defined ORIGIN set "ORIGIN=%CD%"
if not defined WORK set "WORK=C:\_lich_am_gia_toc_build"
if not defined LOG (
  if not exist "%ORIGIN%\logs" mkdir "%ORIGIN%\logs" >nul 2>nul
  for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%i"
  set "LOG=%ORIGIN%\logs\windows_build_%TS%.log"
)

exit /b 0
