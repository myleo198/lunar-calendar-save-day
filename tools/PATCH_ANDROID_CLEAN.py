# -*- coding: utf-8 -*-
from pathlib import Path
import re
import shutil

ROOT = Path.cwd()

def read(p):
    return p.read_text(encoding="utf-8", errors="ignore")

def write(p, s):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(s, encoding="utf-8")

def backup(p):
    if p.exists():
        shutil.copy2(p, p.with_suffix(p.suffix + ".bak_clean_v11"))

def pubspec_name():
    s = read(ROOT / "pubspec.yaml")
    m = re.search(r"(?m)^name:\s*([a-zA-Z0-9_]+)\s*$", s)
    return m.group(1) if m else "lunar_calendar_app"

def namespace():
    return "com.example." + pubspec_name()

def patch_app_gradle():
    ns = namespace()
    p = ROOT / "android/app/build.gradle.kts"
    backup(p)

    # : KHÔNG cấu hình signingConfig trong Gradle.
    # Lý do: nếu Gradle validate signing trước khi tạo keystore sẽ lỗi:
    # validateSigningRelease > Keystore file ... lunar_sideload.jks not found.
    # Quy trình v11 là:
    # 1) Flutter/Gradle build APK release trước.
    # 2) tools/SIGN_ANDROID_APK_FINAL.py tạo keystore, zipalign, apksigner sign, verify.
    content = f'''import com.android.build.api.dsl.ApplicationExtension

plugins {{
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}}

extensions.configure<ApplicationExtension>("android") {{
    namespace = "{ns}"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {{
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }}

    defaultConfig {{
        applicationId = "{ns}"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }}

    buildTypes {{
        getByName("release") {{
            isMinifyEnabled = false
            isShrinkResources = false
        }}
    }}
}}

flutter {{
    source = "../.."
}}

dependencies {{
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}}
'''
    write(p, content)

def patch_manifest():
    p = ROOT / "android/app/src/main/AndroidManifest.xml"
    backup(p)
    manifest = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

    <application
        android:name="${applicationName}"
        android:label="Lịch âm gia tộc"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        <meta-data android:name="flutterEmbedding" android:value="2" />
    </application>
</manifest>
'''
    write(p, manifest)

def patch_main_activity():
    ns = namespace()
    main_root = ROOT / "android/app/src/main"
    for old in main_root.rglob("MainActivity.kt"):
        backup(old)
        old.unlink()
    for old in main_root.rglob("MainActivity.java"):
        backup(old)
        old.unlink()
    rel = Path(*ns.split("."))
    p = main_root / "java" / rel / "MainActivity.java"
    content = f'''package {ns};

import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {{
}}
'''
    write(p, content)

def patch_gradle_properties():
    p = ROOT / "android/gradle.properties"
    s = read(p) if p.exists() else ""
    backup(p)
    lines = {
        "org.gradle.jvmargs": "org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G -XX:ReservedCodeCacheSize=512m -Dfile.encoding=UTF-8",
        "android.useAndroidX": "android.useAndroidX=true",
        "android.enableJetifier": "android.enableJetifier=true",
        "kotlin.incremental": "kotlin.incremental=false",
        "org.gradle.warning.mode": "org.gradle.warning.mode=all",
    }
    for key, line in lines.items():
        if re.search(rf"(?m)^{re.escape(key)}=", s):
            s = re.sub(rf"(?m)^{re.escape(key)}=.*$", line, s)
        else:
            s += ("\n" if s and not s.endswith("\n") else "") + line + "\n"
    write(p, s)

if __name__ == "__main__":
    if not (ROOT / "android/app/build.gradle.kts").exists():
        raise SystemExit("Chưa có Android platform. Hãy chạy flutter create -t app --platforms=android . trước.")
    patch_app_gradle()
    patch_gradle_properties()
    patch_manifest()
    patch_main_activity()
    print("OK: Android Gradle/Manifest/MainActivity da duoc patch sach. Release se duoc ky thu cong sau build.")
