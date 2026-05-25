@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "PATH=C:\src\flutter\bin;C:\src\Flutter\bin;%PATH%"
if not exist windows call flutter create -t app --platforms=windows .
call flutter pub get
call flutter run -d windows
pause
