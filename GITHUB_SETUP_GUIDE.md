# GitHub setup guide cho lich_am_gia_toc

Tài liệu này dùng để đưa source **lich_am_gia_toc** lên GitHub theo cấu trúc sạch, không phụ thuộc tên phiên bản.

---

## 1. Chuẩn bị thư mục project

Nên đặt source tại đường dẫn ngắn:

```text
M:\Flutter\lich_am_gia_toc
```

Không nên để lồng thư mục:

```text
M:\Flutter\lich_am_gia_toc\lich_am_gia_toc
```

---

## 2. File `.gitignore`

Tạo file `.gitignore`:

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

# iOS/macOS generated
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

---

## 3. Khởi tạo Git

```bash
cd /d M:\Flutter\lich_am_gia_toc

git init
git add .
git commit -m "Initial clean release of lich_am_gia_toc"
git branch -M main
git remote add origin https://github.com/<your-user>/lich_am_gia_toc.git
git push -u origin main
```

---

## 4. Cấu trúc repository khuyến nghị

```text
lich_am_gia_toc/
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
├─ BUILD_WINDOWS_DEBUG_ONLY.bat
├─ BUILD_WINDOWS_RELEASE_ONLY.bat
├─ RUN_WINDOWS.bat
├─ pubspec.yaml
├─ README.md
└─ .gitignore
```

---

## 5. GitHub Actions kiểm tra Flutter

Tạo file:

```text
.github/workflows/flutter_check.yml
```

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

## 6. GitHub Actions build Android

Tạo file:

```text
.github/workflows/flutter_android.yml
```

```yaml
name: Build Android APK

on:
  workflow_dispatch:
  push:
    tags:
      - "release-*"

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
          name: lich_am_gia_toc_android_apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

---

## 7. GitHub Actions build Windows

Tạo file:

```text
.github/workflows/flutter_windows.yml
```

```yaml
name: Build Windows

on:
  workflow_dispatch:
  push:
    tags:
      - "release-*"

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
          Copy-Item -Recurse build/windows/x64/runner/Release dist/lich_am_gia_toc
          Compress-Archive -Path dist/lich_am_gia_toc/* -DestinationPath dist/lich_am_gia_toc.zip -Force

      - name: Upload Windows artifact
        uses: actions/upload-artifact@v4
        with:
          name: lich_am_gia_toc_windows
          path: dist/lich_am_gia_toc.zip
```

---

## 8. GitHub Actions build iOS không ký

Tạo file:

```text
.github/workflows/flutter_ios.yml
```

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

---

## 9. Tạo GitHub Release

Có thể dùng tag dạng chung:

```bash
git tag release-stable
git push origin release-stable
```

Hoặc dùng tag theo ngày:

```bash
git tag release-2026-05-25
git push origin release-2026-05-25
```

---

## 10. Quản lý secret

Không commit:

```text
*.jks
*.keystore
key.properties
Google OAuth client secret
Apple certificate
Apple provisioning profile
```

Dùng:

```text
GitHub → Settings → Secrets and variables → Actions
```

để lưu secret nếu cần build release chính thức.
