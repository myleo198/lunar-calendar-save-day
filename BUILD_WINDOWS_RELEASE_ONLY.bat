@echo off
chcp 65001 >nul
setlocal EnableExtensions

cd /d "%~dp0"
set "ORIGIN=%CD%"
set "WORK=C:\_lich_am_gia_toc_build"
if not exist "%ORIGIN%\logs" mkdir "%ORIGIN%\logs" >nul 2>nul
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%i"
set "LOG=%ORIGIN%\logs\windows_release_%TS%.log"

call "%~dp0BUILD_WINDOWS_COMMON.bat"

call :log "====================================================="
call :log "LICH AM GIA TOC - RELEASE WINDOWS"
call :log "====================================================="
call :log "Source: %ORIGIN%"
call :log "Work  : %WORK%"
call :log "Log   : %LOG%"
call :log "Script v16 tach rieng release de tranh CMD tu tat khi chon muc 2."

call :copy_source
if errorlevel 1 goto fail

cd /d "%WORK%"
call :prepare_project
if errorlevel 1 goto fail

call :log "Build Windows release..."
call flutter build windows --release >>"%LOG%" 2>&1
if errorlevel 1 goto fail

call :pack_release
if errorlevel 1 goto fail

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
call :log "Xoa cache trong thu muc ngan..."
if exist windows rmdir /s /q windows >>"%LOG%" 2>&1
if exist build rmdir /s /q build >>"%LOG%" 2>&1
if exist .dart_tool rmdir /s /q .dart_tool >>"%LOG%" 2>&1
if exist dist rmdir /s /q dist >>"%LOG%" 2>&1

call :log "Tao Windows platform moi..."
call flutter create -t app --platforms=windows . >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

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

:pack_release
call :log "Dong goi dist..."
if not exist "build\windows\x64\runner\Release" (
  call :log "LOI: Khong thay build\windows\x64\runner\Release"
  exit /b 1
)

mkdir dist >>"%LOG%" 2>&1
xcopy /E /I /Y "build\windows\x64\runner\Release" "dist\lich_am_gia_toc" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

call :log "Copy icon fallback cho system tray..."
if exist "assets\icons\app_icon.ico" (
  if not exist "dist\lich_am_gia_toc\assets\icons" mkdir "dist\lich_am_gia_toc\assets\icons" >>"%LOG%" 2>&1
  copy /Y "assets\icons\app_icon.ico" "dist\lich_am_gia_toc\assets\icons\app_icon.ico" >>"%LOG%" 2>&1
)

call :log "Nen zip..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "if(Test-Path 'dist\lich_am_gia_toc.zip'){Remove-Item 'dist\lich_am_gia_toc.zip' -Force}; Compress-Archive -Path 'dist\lich_am_gia_toc\*' -DestinationPath 'dist\lich_am_gia_toc.zip' -Force" >>"%LOG%" 2>&1

call :log "Copy ket qua ve thu muc goc..."
cd /d "%ORIGIN%"
if not exist dist mkdir dist >>"%LOG%" 2>&1
if exist "dist\lich_am_gia_toc" rmdir /s /q "dist\lich_am_gia_toc" >>"%LOG%" 2>&1
if exist "dist\lich_am_gia_toc.zip" del /f /q "dist\lich_am_gia_toc.zip" >>"%LOG%" 2>&1
xcopy /E /I /Y "%WORK%\dist\lich_am_gia_toc" "%ORIGIN%\dist\lich_am_gia_toc" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
if exist "%WORK%\dist\lich_am_gia_toc.zip" copy /Y "%WORK%\dist\lich_am_gia_toc.zip" "%ORIGIN%\dist\lich_am_gia_toc.zip" >>"%LOG%" 2>&1
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
call :log "RELEASE HOAN TAT."
call :log "Thu muc: %ORIGIN%\dist\lich_am_gia_toc"
call :log "Zip: %ORIGIN%\dist\lich_am_gia_toc.zip"
call :log "Log: %LOG%"
echo.
echo RELEASE HOAN TAT.
echo Thu muc:
echo %ORIGIN%\dist\lich_am_gia_toc
echo.
echo File zip:
echo %ORIGIN%\dist\lich_am_gia_toc.zip
echo.
echo Log:
echo %LOG%
exit /b 0

:fail
set "ERR=%ERRORLEVEL%"
cd /d "%ORIGIN%"
call :log "BUILD RELEASE THAT BAI. Ma loi: %ERR%"
echo.
echo RELEASE THAT BAI. 80 dong log cuoi:
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
