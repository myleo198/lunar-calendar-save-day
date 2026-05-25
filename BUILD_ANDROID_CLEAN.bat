@echo off
chcp 65001 >nul
setlocal EnableExtensions

cd /d "%~dp0"
set "PATH=C:\src\flutter\bin;C:\src\Flutter\bin;%PATH%"
if exist "C:\Program Files\Android\Android Studio\jbr\bin\java.exe" (
  set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
  set "PATH=C:\Program Files\Android\Android Studio\jbr\bin;%PATH%"
)

if not exist pubspec.yaml (
  echo LOI: Hay chay file nay trong thu muc project Flutter.
  pause
  exit /b 1
)

echo ==========================================
echo LICH AM GIA TOC - BUILD ANDROID FINAL
echo ==========================================
echo.
echo 1. APK debug cho may ao Android x86_64
echo 2. APK release DA KY cho dien thoai that arm64-v8a
echo 3. APK universal release DA KY: arm + arm64 + x64
echo.
set /p choice=Chon 1/2/3: 

echo.
echo [1/8] Tao Android platform sach...
if exist android rmdir /s /q android
call flutter create -t app --platforms=android .
if errorlevel 1 goto fail

echo.
echo [2/8] Patch Android Gradle/Manifest/MainActivity...
echo : Gradle khong validate keystore; APK release se duoc ky thu cong sau khi build.
python tools\PATCH_ANDROID_CLEAN.py
if errorlevel 1 goto fail

echo.
echo [3/8] Xoa cache...
if exist build rmdir /s /q build
if exist .dart_tool rmdir /s /q .dart_tool
if exist android\.gradle rmdir /s /q android\.gradle

echo.
echo [4/8] Pub get...
call flutter pub get
if errorlevel 1 goto fail

echo.
echo [5/8] Tao icon Android...
call dart run flutter_launcher_icons
if errorlevel 1 echo CANH BAO: Tao icon that bai, tiep tuc build.

echo.
echo [6/8] Build APK...
if "%choice%"=="1" (
  call flutter build apk --debug --target-platform android-x64
) else if "%choice%"=="2" (
  call flutter build apk --release --target-platform android-arm64 --no-tree-shake-icons
) else (
  call flutter build apk --release --target-platform android-arm,android-arm64,android-x64 --no-tree-shake-icons
)
if errorlevel 1 goto fail

if "%choice%"=="1" goto done_debug

echo.
echo [7/8] Ky APK release bang zipalign + apksigner va verify certificate...
python tools\SIGN_ANDROID_APK_FINAL.py
if errorlevel 1 goto fail

echo.
echo [8/8] Kiem tra file APK da ky...
if not exist "build\app\outputs\flutter-apk\app-release.apk" goto fail
echo OK: APK release da ky nam tai:
echo %CD%\build\app\outputs\flutter-apk\app-release.apk
goto done_release

:done_debug
echo.
echo DONE DEBUG.
echo APK debug:
echo %CD%\build\app\outputs\flutter-apk\app-debug.apk
pause
exit /b 0

:done_release
echo.
echo =====================================================
echo BUILD ANDROID RELEASE DA KY HOAN TAT
echo =====================================================
echo.
echo File cai dat dung:
echo %CD%\build\app\outputs\flutter-apk\app-release.apk
echo.
echo KHONG dung app-release-aligned.apk hay app-release-signed.apk.
echo Neu da cai ban cu, hay go app cu tren dien thoai/may ao roi cai lai.
echo.
pause
exit /b 0

:fail
echo.
echo =====================================================
echo BUILD ANDROID THAT BAI
echo =====================================================
echo Neu gap INSTALL_PARSE_FAILED_NO_CERTIFICATES:
echo - Hay build lai bang ban v12 nay, chon 2 hoac 3.
echo - Hay cai file build\app\outputs\flutter-apk\app-release.apk sau khi script bao verify thanh cong.
echo - Go app cu tren thiet bi roi cai lai.
echo.
pause
exit /b 1
