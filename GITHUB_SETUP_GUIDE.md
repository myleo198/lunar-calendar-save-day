# Hướng dẫn chuẩn GitHub cho dự án Lịch âm gia tộc

Tài liệu này dùng để đưa source Flutter lên GitHub, cấu hình `.gitignore`, GitHub Actions, release và quản lý build artifact.

---

## 1. Chuẩn bị thư mục source

Thư mục project nên đặt ngắn, không lồng nhiều cấp:

```text
M:\Flutter\lich_am_gia_toc_clean_v15_0_autoclean_logs
```

Tránh dạng:

```text
M:\Flutter\lich_am_gia_toc_clean_v15_0_autoclean_logs\lich_am_gia_toc_clean_v15_0_autoclean_logs
```

Các thư mục không cần có sẵn trong source:

```text
android/
windows/
ios/
build/
.dart_tool/
dist/
logs/
```

Script build sẽ tự tạo platform cần thiết.

---

## 2. File `.gitignore`

Tạo file `.gitignore` ở thư mục gốc:

```gitignore
# Flutter / Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/
pubspec.lock

# Generated platforms
android/
windows/
ios/
macos/
linux/

# Build output
dist/
logs/

# Android signing / generated files
*.jks
*.keystore
android/app/key.properties
android/local.properties

# iOS/macOS
ios/Pods/
ios/.symlinks/
ios/Flutter/Flutter.framework
ios/Flutter/Flutter.podspec
ios/Runner.xcworkspace/xcuserdata/
ios/Runner.xcodeproj/xcuserdata/
macos/Pods/
macos/.symlinks/

# Windows generated
windows/flutter/ephemeral/
windows/x64/
windows/build/

# IDE
.idea/
.vscode/
*.iml

# OS
.DS_Store
Thumbs.db

# Logs and backup
*.log
*.bak
*.bak_*
```

Ghi chú: project này cố ý không commit `android/` và `windows/` để tránh lỗi platform cũ. Script build sẽ chạy `flutter create -t app --platforms=... .` khi cần.

---

## 3. Khởi tạo Git

```bash
cd /d M:\Flutter\lich_am_gia_toc_clean_v15_0_autoclean_logs

git init
git add .
git commit -m "Initial clean release of Lunar Family Calendar"
git branch -M main
```

Tạo repo trên GitHub, sau đó:

```bash
git remote add origin https://github.com/<your-user>/<your-repo>.git
git push -u origin main
```

---

## 4. Cấu trúc repo khuyến nghị

```text
repo/
├─ .github/
│  └─ workflows/
│     ├─ flutter_check.yml
│     ├─ flutter_android.yml
│     └─ flutter_windows.yml
├─ assets/
│  └─ icons/
├─ lib/
│  └─ main.dart
├─ tools/
│  ├─ PATCH_ANDROID_CLEAN.py
│  ├─ PATCH_WINDOWS_CLEAN.py
│  └─ SIGN_ANDROID_APK_FINAL.py
├─ BUILD_ANDROID_CLEAN.bat
├─ BUILD_WINDOWS_CLEAN.bat
├─ RUN_WINDOWS.bat
├─ pubspec.yaml
├─ README.md
└─ .gitignore
```

---

## 5. GitHub Actions: kiểm tra Flutter

Tạo file:

```text
.github/workflows/flutter_check.yml
```

Nội dung:

```yaml
name: Flutter Check

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  analyze:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout source
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Flutter version
        run: flutter --version

      - name: Get dependencies
        run: flutter pub get

      - name: Analyze
        run: flutter analyze
```

---

## 6. GitHub Actions: build Android APK

Tạo file:

```text
.github/workflows/flutter_android.yml
```

Nội dung:

```yaml
name: Build Android APK

on:
  workflow_dispatch:
  push:
    tags:
      - "v*.*.*"

jobs:
  build-android:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout source
        uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"

      - name: Setup Android SDK
        uses: android-actions/setup-android@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Create Android platform
        run: flutter create -t app --platforms=android .

      - name: Patch Android project
        run: python3 tools/PATCH_ANDROID_CLEAN.py

      - name: Get dependencies
        run: flutter pub get

      - name: Generate launcher icons
        run: dart run flutter_launcher_icons

      - name: Build universal APK
        run: flutter build apk --release --target-platform android-arm,android-arm64,android-x64 --no-tree-shake-icons

      - name: Upload APK artifact
        uses: actions/upload-artifact@v4
        with:
          name: lunar-calendar-android-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

Ghi chú: workflow này build APK. Nếu muốn ký APK bằng keystore riêng cho phát hành chính thức, cấu hình GitHub Secrets và signingConfig riêng.

---

## 7. GitHub Actions: build Windows

Tạo file:

```text
.github/workflows/flutter_windows.yml
```

Nội dung:

```yaml
name: Build Windows

on:
  workflow_dispatch:
  push:
    tags:
      - "v*.*.*"

jobs:
  build-windows:
    runs-on: windows-latest

    steps:
      - name: Checkout source
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Enable Windows desktop
        run: flutter config --enable-windows-desktop

      - name: Create Windows platform
        run: flutter create -t app --platforms=windows .

      - name: Patch Windows project
        run: python tools/PATCH_WINDOWS_CLEAN.py

      - name: Copy Windows icon
        shell: pwsh
        run: |
          New-Item -ItemType Directory -Force windows/runner/resources
          Copy-Item assets/icons/app_icon.ico windows/runner/resources/app_icon.ico -Force

      - name: Get dependencies
        run: flutter pub get

      - name: Build Windows release
        run: flutter build windows --release

      - name: Pack Windows release
        shell: pwsh
        run: |
          New-Item -ItemType Directory -Force dist
          Copy-Item -Recurse build/windows/x64/runner/Release dist/LichAmGiaToc_Windows
          Compress-Archive -Path dist/LichAmGiaToc_Windows/* -DestinationPath dist/LichAmGiaToc_Windows.zip -Force

      - name: Upload Windows artifact
        uses: actions/upload-artifact@v4
        with:
          name: lunar-calendar-windows
          path: dist/LichAmGiaToc_Windows.zip
```

---

## 8. GitHub Actions: build iOS không ký

Tạo file:

```text
.github/workflows/flutter_ios.yml
```

Nội dung:

```yaml
name: Build iOS No Codesign

on:
  workflow_dispatch:

jobs:
  build-ios:
    runs-on: macos-latest

    steps:
      - name: Checkout source
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Create iOS platform
        run: flutter create -t app --platforms=ios .

      - name: Get dependencies
        run: flutter pub get

      - name: Build iOS without codesign
        run: flutter build ios --release --no-codesign
```

Để phát hành iOS thật, cần Apple certificate, provisioning profile và Apple Developer account.

---

## 9. Tạo GitHub Release

Sửa version trong `pubspec.yaml`:

```yaml
version: 15.0.0+150
```

Commit:

```bash
git add .
git commit -m "Release v15.0.0"
git tag v15.0.0
git push origin main
git push origin v15.0.0
```

Sau khi tag được push, GitHub Actions có thể tự build artifact.

---

## 10. Quy tắc đặt version

Dùng quy tắc:

```text
major.minor.patch+buildNumber
```

Ví dụ:

```text
15.0.0+150
15.0.1+151
15.1.0+160
16.0.0+200
```

Khi phát hành Android, `buildNumber` phải tăng.

---

## 11. Quản lý secrets

Không commit các file sau:

```text
*.jks
*.keystore
key.properties
Google OAuth client secret
Apple certificate
Apple provisioning profile
```

Dùng GitHub:

```text
Settings → Secrets and variables → Actions
```

để lưu secret nếu cần build release chính thức.

---

## 12. Lệnh kiểm tra nhanh trước khi push

```bash
flutter pub get
flutter analyze
```

Nếu muốn test build Windows local:

```bat
BUILD_WINDOWS_CLEAN.bat
```

Nếu muốn test build Android local:

```bat
BUILD_ANDROID_CLEAN.bat
```

---

## 13. Quy trình sửa lỗi khuyến nghị

1. Chạy script build.
2. Nếu lỗi Windows, lấy file mới nhất trong:
   ```text
   logs/
   ```
3. Nếu lỗi Android, copy toàn bộ đoạn lỗi từ CMD.
4. Không sửa trực tiếp platform sinh ra nếu chưa cần.
5. Ưu tiên sửa:
   - `lib/main.dart`
   - `tools/PATCH_ANDROID_CLEAN.py`
   - `tools/PATCH_WINDOWS_CLEAN.py`
   - script `.bat`
6. Sau khi ổn định mới tạo bản version mới.
