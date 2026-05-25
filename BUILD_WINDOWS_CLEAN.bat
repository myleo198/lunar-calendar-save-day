@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0"
set "ORIGIN=%CD%"
set "WORK=C:\_lagt_v15_build"
set "PATH=C:\src\flutter\bin;C:\src\Flutter\bin;%PATH%"

if not exist "%ORIGIN%\logs" mkdir "%ORIGIN%\logs" >nul 2>nul
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%i"
set "LOG=%ORIGIN%\logs\windows_build_%TS%.log"

call :log "====================================================="
call :log "LICH AM GIA TOC V15.0 - WINDOWS SHORT PATH BUILD"
call :log "====================================================="
call :log "Source : %ORIGIN%"
call :log "Work   : %WORK%"
call :log "Log    : %LOG%"
call :log ""

echo Chon che do:
echo.
echo   1. DEBUG - copy source sang duong dan ngan roi chay flutter run
echo   2. RELEASE - copy source sang duong dan ngan roi build app doc lap
echo.
set /p mode=Nhap lua chon 1 hoac 2: 
echo Lua chon: %mode%>>"%LOG%"

if "%mode%"=="1" goto debug
if "%mode%"=="2" goto release

call :log "LOI: Lua chon khong hop le."
pause
exit /b 1

:log
echo %~1
>>"%LOG%" echo %~1
exit /b 0

:copy_to_short_path
call :log ""
call :log "====================================================="
call :log "CHUAN BI THU MUC BUILD DUONG DAN NGAN"
call :log "====================================================="
call :log "Xoa build tam cu neu co..."

cd /d "%ORIGIN%"
if exist "%WORK%" (
  rmdir /s /q "%WORK%" >>"%LOG%" 2>&1
)

mkdir "%WORK%" >>"%LOG%" 2>&1
if errorlevel 1 (
  call :log "LOI: Khong tao duoc %WORK%"
  exit /b 1
)

call :log "Copy source sang duong dan ngan..."
robocopy "%ORIGIN%" "%WORK%" /MIR /XD build .dart_tool android windows ios macos linux dist logs .git .gradle .idea .vscode /XF *.log *.bak *.jks pubspec.lock >>"%LOG%" 2>&1
set "RBC=%ERRORLEVEL%"
if %RBC% GEQ 8 (
  call :log "LOI: Robocopy that bai, ma loi %RBC%."
  exit /b 1
)

cd /d "%WORK%"
exit /b 0

:prepare_common
if not exist pubspec.yaml (
  call :log "LOI: Khong thay pubspec.yaml trong %CD%."
  exit /b 1
)

if not exist "tools\PATCH_WINDOWS_CLEAN.py" (
  call :log "LOI: Khong thay tools\PATCH_WINDOWS_CLEAN.py."
  exit /b 1
)

call :log ""
call :log "Tao Windows platform neu chua co..."
if not exist windows (
  call flutter create -t app --platforms=windows . >>"%LOG%" 2>&1
  if errorlevel 1 exit /b 1
)

call :log ""
call :log "Patch Windows CMake + pubspec..."
python tools\PATCH_WINDOWS_CLEAN.py >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

call :log ""
call :log "Gan icon Windows tu file da gui..."
if exist "assets\icons\app_icon.ico" (
  if not exist "windows\runner\resources" mkdir "windows\runner\resources" >>"%LOG%" 2>&1
  copy /Y "assets\icons\app_icon.ico" "windows\runner\resources\app_icon.ico" >>"%LOG%" 2>&1
  call :log "OK: Da gan windows\runner\resources\app_icon.ico"
) else (
  call :log "CANH BAO: Khong thay assets\icons\app_icon.ico"
)

call :log ""
call :log "Pub get..."
call flutter pub get >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

exit /b 0

:debug
call :log ""
call :log "====================================================="
call :log "CHE DO 1: DEBUG TREN DUONG DAN NGAN"
call :log "====================================================="
call :log "Che do nay tranh loi MSVC FileTracker do duong dan qua dai."

call :copy_to_short_path
if errorlevel 1 goto fail

call :prepare_common
if errorlevel 1 goto fail

call :log ""
call :log "Chay app debug. Log chi tiet ghi vao file log..."
call flutter run -d windows >>"%LOG%" 2>&1
if errorlevel 1 goto fail

call :log ""
call :log "DEBUG KET THUC."
goto success_cleanup

:release
call :log ""
call :log "====================================================="
call :log "CHE DO 2: RELEASE APP DOC LAP TREN DUONG DAN NGAN"
call :log "====================================================="
call :log "Che do nay khac phuc loi MSVC FileTracker FTK1011 do duong dan qua dai."

call :copy_to_short_path
if errorlevel 1 goto fail

call :log ""
call :log "Xoa cache/build trong thu muc ngan..."
if exist windows rmdir /s /q windows >>"%LOG%" 2>&1
if exist build rmdir /s /q build >>"%LOG%" 2>&1
if exist .dart_tool rmdir /s /q .dart_tool >>"%LOG%" 2>&1
if exist dist rmdir /s /q dist >>"%LOG%" 2>&1

call :log ""
call :log "Tao Windows platform moi..."
call flutter create -t app --platforms=windows . >>"%LOG%" 2>&1
if errorlevel 1 goto fail

call :prepare_common
if errorlevel 1 goto fail

call :log ""
call :log "Build Windows release..."
call flutter build windows --release >>"%LOG%" 2>&1
if errorlevel 1 goto fail

call :log ""
call :log "Tao goi dist trong thu muc ngan..."
mkdir dist >>"%LOG%" 2>&1
xcopy /E /I /Y "build\windows\x64\runner\Release" "dist\LichAmGiaToc_Windows_v15_0" >>"%LOG%" 2>&1
if errorlevel 1 goto fail

call :log "Copy icon fallback cho system tray..."
if exist "assets\icons\app_icon.ico" (
  if not exist "dist\LichAmGiaToc_Windows_v15_0\assets\icons" mkdir "dist\LichAmGiaToc_Windows_v15_0\assets\icons" >>"%LOG%" 2>&1
  copy /Y "assets\icons\app_icon.ico" "dist\LichAmGiaToc_Windows_v15_0\assets\icons\app_icon.ico" >>"%LOG%" 2>&1
)

call :log ""
call :log "Nen thanh file zip trong thu muc ngan..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "if(Test-Path 'dist\LichAmGiaToc_Windows_v15_0.zip'){Remove-Item 'dist\LichAmGiaToc_Windows_v15_0.zip' -Force}; Compress-Archive -Path 'dist\LichAmGiaToc_Windows_v15_0\*' -DestinationPath 'dist\LichAmGiaToc_Windows_v15_0.zip' -Force" >>"%LOG%" 2>&1
if errorlevel 1 (
  call :log "CANH BAO: Khong nen duoc zip, nhung thu muc dist da duoc tao."
)

call :log ""
call :log "Copy ket qua release ve thu muc goc..."
cd /d "%ORIGIN%"
if not exist dist mkdir dist >>"%LOG%" 2>&1
if exist "dist\LichAmGiaToc_Windows_v15_0" rmdir /s /q "dist\LichAmGiaToc_Windows_v15_0" >>"%LOG%" 2>&1
if exist "dist\LichAmGiaToc_Windows_v15_0.zip" del /f /q "dist\LichAmGiaToc_Windows_v15_0.zip" >>"%LOG%" 2>&1
xcopy /E /I /Y "%WORK%\dist\LichAmGiaToc_Windows_v15_0" "%ORIGIN%\dist\LichAmGiaToc_Windows_v15_0" >>"%LOG%" 2>&1
if errorlevel 1 goto fail
copy /Y "%WORK%\dist\LichAmGiaToc_Windows_v15_0.zip" "%ORIGIN%\dist\LichAmGiaToc_Windows_v15_0.zip" >>"%LOG%" 2>&1

call :log ""
call :log "====================================================="
call :log "RELEASE HOAN TAT"
call :log "====================================================="
call :log "Thu muc app doc lap: %ORIGIN%\dist\LichAmGiaToc_Windows_v15_0"
call :log "File zip: %ORIGIN%\dist\LichAmGiaToc_Windows_v15_0.zip"
goto success_cleanup

:success_cleanup
call :cleanup_temp
call :log ""
call :log "Build log da luu tai: %LOG%"
echo.
echo Build log da luu tai:
echo %LOG%
echo.
pause
exit /b 0

:cleanup_temp
cd /d "%ORIGIN%"
if exist "%WORK%" (
  call :log ""
  call :log "Tu dong xoa build tam: %WORK%"
  rmdir /s /q "%WORK%" >>"%LOG%" 2>&1
  if exist "%WORK%" (
    call :log "CANH BAO: Chua xoa duoc build tam. Co the app/debug process dang chay."
  ) else (
    call :log "OK: Da xoa build tam."
  )
)
exit /b 0

:fail
set "ERR=%ERRORLEVEL%"
cd /d "%ORIGIN%"
call :log ""
call :log "====================================================="
call :log "BUILD WINDOWS THAT BAI"
call :log "====================================================="
call :log "Ma loi: %ERR%"
call :log "Trich 80 dong log cuoi:"
powershell -NoProfile -Command "Get-Content -Path '%LOG%' -Tail 80" 2>nul
call :cleanup_temp
call :log ""
call :log "Build log da luu tai: %LOG%"
echo.
echo Build log da luu tai:
echo %LOG%
echo.
pause
exit /b 1
