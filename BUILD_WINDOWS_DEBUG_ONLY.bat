@echo off
chcp 65001 >nul
setlocal EnableExtensions

cd /d "%~dp0"
set "ORIGIN=%CD%"
set "WORK=C:\_lich_am_gia_toc_build"
if not exist "%ORIGIN%\logs" mkdir "%ORIGIN%\logs" >nul 2>nul
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%i"
set "LOG=%ORIGIN%\logs\windows_debug_%TS%.log"

call "%~dp0BUILD_WINDOWS_COMMON.bat"

call :log "====================================================="
call :log "LICH AM GIA TOC - DEBUG WINDOWS"
call :log "====================================================="
call :log "Source: %ORIGIN%"
call :log "Work  : %WORK%"
call :log "Log   : %LOG%"

call :copy_source
if errorlevel 1 goto fail

cd /d "%WORK%"
call :prepare_project
if errorlevel 1 goto fail

call :log "Chay flutter run -d windows..."
call flutter run -d windows >>"%LOG%" 2>&1
if errorlevel 1 goto fail

call :log "DEBUG HOAN TAT."
goto success

:copy_source
call :log "Xoa build tam cu neu co..."
cd /d "%ORIGIN%"
if exist "%WORK%" rmdir /s /q "%WORK%" >>"%LOG%" 2>&1
mkdir "%WORK%" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

call :log "Copy source sang duong dan ngan..."
robocopy "%ORIGIN%" "%WORK%" /MIR /XD build .dart_tool android windows ios macos linux dist logs .git .gradle .idea .vscode /XF *.log *.bak *.jks pubspec.lock >>"%LOG%" 2>&1
if %ERRORLEVEL% GEQ 8 exit /b 1
exit /b 0

:prepare_project
call :log "Tao Windows platform..."
if not exist windows (
  call flutter create -t app --platforms=windows . >>"%LOG%" 2>&1
  if errorlevel 1 exit /b 1
)

call :log "Patch Windows..."
python tools\PATCH_WINDOWS_CLEAN.py >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

call :log "Gan icon Windows..."
if exist "assets\icons\app_icon.ico" (
  if not exist "windows\runner\resources" mkdir "windows\runner\resources" >>"%LOG%" 2>&1
  copy /Y "assets\icons\app_icon.ico" "windows\runner\resources\app_icon.ico" >>"%LOG%" 2>&1
)

call :log "Flutter pub get..."
call flutter pub get >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
exit /b 0

:cleanup
cd /d "%ORIGIN%"
if exist "%WORK%" (
  call :log "Xoa build tam: %WORK%"
  rmdir /s /q "%WORK%" >>"%LOG%" 2>&1
)
exit /b 0

:success
call :cleanup
call :log "Log da luu tai: %LOG%"
echo.
echo DEBUG HOAN TAT.
echo Log da luu tai:
echo %LOG%
exit /b 0

:fail
set "ERR=%ERRORLEVEL%"
cd /d "%ORIGIN%"
call :log "BUILD DEBUG THAT BAI. Ma loi: %ERR%"
echo.
echo DEBUG THAT BAI. 80 dong log cuoi:
powershell -NoProfile -Command "if(Test-Path '%LOG%'){Get-Content -Path '%LOG%' -Tail 80}"
call :cleanup
echo.
echo Full log:
echo %LOG%
exit /b 1

:log
echo %~1
>>"%LOG%" echo %~1
exit /b 0
