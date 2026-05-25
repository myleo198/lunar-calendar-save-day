# lunar-calendar-save-day
Ứng dụng Flutter lịch âm Việt Nam cho gia đình/dòng họ: lưu giỗ chạp, sự kiện âm lịch, nhắc lịch, thống kê năm, thông báo Windows/Android, system tray, Google Calendar Sync và sao lưu JSON.
# 🌙 Lịch âm gia tộc

<p align="center">
  <img src="assets/icons/app_icon.png" width="128" alt="Lịch âm gia tộc">
</p>

<h2 align="center">Ứng dụng lịch âm Việt Nam cho gia đình và dòng họ</h2>

<p align="center">
  <b>Lưu giỗ chạp · Nhắc lịch âm · Đồng bộ Google Calendar · Build Windows/Android</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white">
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white">
  <img src="https://img.shields.io/badge/Windows-10%2F11-111827?style=for-the-badge&logo=windows&logoColor=white">
  <img src="https://img.shields.io/badge/Android-arm64%20%7C%20x64-00A86B?style=for-the-badge&logo=android&logoColor=white">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Lịch%20âm-Chính-00A86B?style=flat-square">
  <img src="https://img.shields.io/badge/Lịch%20dương-Phụ-111827?style=flat-square">
  <img src="https://img.shields.io/badge/Google%20Calendar-Sync-00A86B?style=flat-square">
  <img src="https://img.shields.io/badge/System%20Tray-Windows-111827?style=flat-square">
  <img src="https://img.shields.io/badge/Notification-Android%20%7C%20Windows-00A86B?style=flat-square">
</p>

---

## 📌 Giới thiệu

**Lịch âm gia tộc** là ứng dụng Flutter đa nền tảng dùng để xem lịch âm Việt Nam, lưu sự kiện theo âm lịch và tự nhắc lại theo tháng/quý/năm. Ứng dụng phù hợp cho việc quản lý các ngày quan trọng của gia đình, dòng họ như giỗ, chạp, giỗ họ, ngày sinh âm lịch, ngày mất, ngày kỵ và các sự kiện truyền thống.

Trọng tâm của ứng dụng là **lịch âm**. Ngày âm được hiển thị nổi bật, ngày dương chỉ đóng vai trò phụ trợ. Khi lưu sự kiện âm lịch, ứng dụng tự quy đổi sang dương lịch theo từng năm để hiển thị và lập lịch nhắc.

---

## ✨ Tính năng chính

### 1. Lịch âm là trung tâm

- Ngày âm hiển thị lớn, màu đỏ, nằm bên trái ô lịch.
- Chữ **âm** nằm dưới ngày âm.
- Ngày dương hiển thị phụ, màu đen, nằm bên phải ô lịch.
- Tuần bắt đầu từ **Thứ 2**.
- Thứ 7 và Chủ nhật có nền khác để dễ nhận biết.
- Ô lịch tự co giãn theo kích thước cửa sổ Windows và màn hình Android.
- Hỗ trợ xem theo:
  - Tuần.
  - Tháng.
  - Năm.
  - 5 năm.
  - Danh sách sự kiện.
  - Thống kê sự kiện trong năm.
  - Google / Sao lưu.

### 2. Sự kiện theo âm lịch

Có thể lưu các loại sự kiện:

- Giỗ ông, bà, cha, mẹ.
- Chạp họ.
- Giỗ họ.
- Ngày sinh âm lịch.
- Ngày mất.
- Ngày kỵ.
- Sự kiện truyền thống gia đình/dòng họ.

Mỗi sự kiện gồm:

- Tên sự kiện.
- Ghi chú.
- Ngày âm.
- Tháng âm.
- Tùy chọn tháng nhuận.
- Giờ nhắc.
- Phút nhắc.
- Chu kỳ nhắc:
  - Hằng tháng âm lịch.
  - Hằng quý âm lịch.
  - Hằng năm âm lịch.
- Nhắc trước theo:
  - Số ngày.
  - Số giờ.

### 3. Thông báo

#### Android

- Thông báo trên thanh thông báo.
- Thông báo trong bảng thông báo.
- Cấu hình ưu tiên cao để hỗ trợ thông báo nổi.
- Quyền Android:
  - `POST_NOTIFICATIONS`
  - `SCHEDULE_EXACT_ALARM`
  - `VIBRATE`
  - `RECEIVE_BOOT_COMPLETED`
  - `INTERNET`

#### Windows

- Thông báo hệ thống.
- Thông báo nổi trong ứng dụng.
- Có nút tắt.
- Có nút nhắc lại 10 phút.
- Có nút nhắc lại 1 giờ.

### 4. Windows system tray

- Có biểu tượng ứng dụng ở system tray.
- Có tùy chọn ẩn xuống system tray khi đóng cửa sổ.
- Khi ẩn xuống tray:
  - Bấm chuột trái để hiện lại.
  - Chuột phải có menu:
    - Hiện cửa sổ.
    - Thoát hoàn toàn.
- Đã xử lý đường dẫn icon tray cho bản release:
  - `data/flutter_assets/assets/icons/app_icon.ico`
  - `assets/icons/app_icon.ico`

### 5. Build Windows ổn định

- Build trên đường dẫn ngắn:
  - `C:\_lagt_v15_build`
- Tránh lỗi MSVC/FileTracker do đường dẫn quá dài.
- Sau khi build xong, tự xóa thư mục build tạm.
- Giữ log build trong:
  - `logs/windows_build_YYYYMMDD_HHMMSS.log`
- Release Windows tạo:
  - `dist/LichAmGiaToc_Windows_v15_0/`
  - `dist/LichAmGiaToc_Windows_v15_0.zip`

### 6. Build Android đã ký APK

- Build debug cho máy ảo `x86_64`.
- Build release cho điện thoại thật `arm64-v8a`.
- Build universal cho `android-arm`, `android-arm64`, `android-x64`.
- APK release được ký thủ công bằng:
  - `zipalign`
  - `apksigner sign`
  - `apksigner verify`
- File cài đặt cuối cùng:
  - `build/app/outputs/flutter-apk/app-release.apk`

### 7. Google Calendar và sao lưu

- Đăng nhập Google bằng OAuth Device Code.
- Đẩy sự kiện âm lịch lên Google Calendar.
- Tải sự kiện từ Google Calendar về app.
- Sao lưu JSON.
- Khôi phục JSON.

---

## 🧭 Nền tảng hỗ trợ

| Nền tảng | Trạng thái |
|---|---|
| Windows 10/11 | Hỗ trợ |
| Android | Hỗ trợ |
| iOS | Mã nguồn dự phòng, cần macOS/Xcode để build |
| macOS | Có thể mở rộng |
| Linux | Có thể mở rộng |

---

## 📁 Cấu trúc thư mục

```text
lich_am_gia_toc_clean_v15_0_autoclean_logs/
├─ lib/
│  └─ main.dart
├─ assets/
│  └─ icons/
│     ├─ app_icon.png
│     ├─ app_icon_256.png
│     └─ app_icon.ico
├─ tools/
│  ├─ PATCH_ANDROID_CLEAN.py
│  ├─ PATCH_WINDOWS_CLEAN.py
│  └─ SIGN_ANDROID_APK_FINAL.py
├─ BUILD_ANDROID_CLEAN.bat
├─ BUILD_WINDOWS_CLEAN.bat
├─ RUN_WINDOWS.bat
├─ pubspec.yaml
└─ README.md
```

Các thư mục được sinh ra khi build và không nên commit:

```text
build/
.dart_tool/
android/
windows/
dist/
logs/
```

---

## ⚙️ Yêu cầu môi trường

### Windows

Cần cài:

- Flutter SDK.
- Git for Windows.
- Visual Studio Community với workload **Desktop development with C++**.
- Android Studio nếu build Android.
- Android SDK Command-line Tools.
- Android SDK Platform-Tools.
- Android SDK Build-Tools.

Kiểm tra:

```bat
flutter doctor -v
```

### Android

Trong Android Studio:

```text
SDK Manager → SDK Tools
```

Cài:

```text
Android SDK Command-line Tools latest
Android SDK Platform-Tools
Android SDK Build-Tools
Android Emulator
```

Chấp nhận license:

```bat
flutter doctor --android-licenses
```

### iOS

Không build iOS trực tiếp trên Windows. Cần:

- macOS.
- Xcode.
- CocoaPods.
- Apple Developer account nếu phát hành TestFlight/App Store.

---

## 🚀 Build Windows

Mở CMD/PowerShell:

```bat
cd /d M:\Flutter\lich_am_gia_toc_clean_v15_0_autoclean_logs
BUILD_WINDOWS_CLEAN.bat
```

Chọn:

```text
1 = DEBUG
2 = RELEASE
```

### DEBUG

Dùng để chạy thử ngay trên máy hiện tại:

```text
flutter run -d windows
```

### RELEASE

Dùng để tạo app Windows độc lập. Kết quả nằm tại:

```text
dist\LichAmGiaToc_Windows_v15_0
dist\LichAmGiaToc_Windows_v15_0.zip
```

Khi copy sang máy khác, phải copy **cả thư mục release**, không copy riêng file `.exe`.

### Build log

Mọi log build Windows được lưu tại:

```text
logs\windows_build_YYYYMMDD_HHMMSS.log
```

Khi lỗi, gửi file log mới nhất trong thư mục `logs`.

---

## 📱 Build Android

Chạy:

```bat
cd /d M:\Flutter\lich_am_gia_toc_clean_v15_0_autoclean_logs
BUILD_ANDROID_CLEAN.bat
```

Chọn:

```text
1 = APK debug cho máy ảo Android x86_64
2 = APK release đã ký cho điện thoại thật arm64-v8a
3 = APK universal release đã ký: arm + arm64 + x64
```

File APK nằm tại:

```text
build\app\outputs\flutter-apk\
```

File cài đúng khi chọn release:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Không dùng:

```text
app-release-aligned.apk
app-release-signed.apk
APK cũ
APK trong thư mục tạm
```

---

## 🔐 Google Calendar Sync

### Bước 1: Tạo Google Cloud project

Vào Google Cloud Console:

```text
APIs & Services → Credentials
```

Tạo OAuth Client ID phù hợp với Device Code Flow.

### Bước 2: Bật Google Calendar API

```text
APIs & Services → Library → Google Calendar API → Enable
```

### Bước 3: Nhập Client ID vào app

Trong ứng dụng:

```text
Google / Sao lưu → Google OAuth Client ID
```

Dán Client ID, bấm:

```text
Đăng nhập Google
```

### Bước 4: Đồng bộ

Có hai thao tác:

```text
Đẩy lên Google Calendar
Tải từ Google Calendar
```

Ứng dụng nhận diện sự kiện của mình bằng metadata:

```text
lunar_family_calendar = true
```

---

## 💾 Sao lưu và khôi phục JSON

Vào:

```text
Google / Sao lưu
```

### Sao lưu

Bấm:

```text
Copy sao lưu
```

Lưu JSON vào Google Drive, Gmail hoặc file riêng.

### Khôi phục

Dán JSON vào khung, bấm:

```text
Khôi phục JSON
```

---

## 🛠️ Lỗi thường gặp

### `INSTALL_PARSE_FAILED_NO_CERTIFICATES`

Nguyên nhân: APK chưa được ký hoặc cài nhầm file APK cũ.

Cách xử lý:

```bat
BUILD_ANDROID_CLEAN.bat
```

Chọn:

```text
2 hoặc 3
```

Cài file:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Nếu đã cài bản cũ khác chữ ký, gỡ app cũ rồi cài lại.

### `INSTALL_FAILED_NO_MATCHING_ABIS`

Nguyên nhân: APK không chứa ABI phù hợp với máy.

- Máy ảo Android Studio nên dùng `x86_64`.
- Điện thoại thật thường dùng `arm64-v8a`.
- Nếu cần một file cho nhiều máy, chọn universal.

### `JAVA_HOME is not set`

Bản build đã tự set Java từ Android Studio JBR nếu có. Nếu vẫn lỗi, kiểm tra:

```bat
where java
echo %JAVA_HOME%
```

Có thể set thủ công:

```bat
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set PATH=%JAVA_HOME%\bin;%PATH%
```

### `FileTracker : error FTK1011`

Nguyên nhân thường do đường dẫn build quá dài.

Bản build Windows đã xử lý bằng cách build tạm trong:

```text
C:\_lagt_v15_build
```

Sau build sẽ tự xóa thư mục này và giữ log trong `logs/`.

### `atlbase.h: No such file or directory`

Mở Visual Studio Installer, cài thêm:

```text
C++ ATL for latest build tools
C++ MFC for latest build tools
```

### iOS không build trên Windows

iOS cần macOS/Xcode. Trên macOS:

```bash
flutter create -t app --platforms=ios .
flutter pub get
flutter build ios --release
```

---

## 📦 Release

Quy ước version trong `pubspec.yaml`:

```yaml
version: 15.0.0+150
```

Quy tắc:

```text
major.minor.patch+buildNumber
```

Ví dụ:

```text
15.0.1+151
15.1.0+160
16.0.0+200
```

---

## 📄 License

Dự án dùng cho mục đích cá nhân/gia đình/dòng họ. Có thể chuyển sang MIT License nếu công khai mã nguồn.
