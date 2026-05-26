# -*- coding: utf-8 -*-
"""
SIGN_ANDROID_APK_FINAL.py - v12

Ký thủ công APK release bằng zipalign + apksigner.

 sửa lỗi:
  ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.

Nguyên nhân:
- apksigner.bat cần java.exe.
- keytool.exe có thể tìm được trong Android Studio JBR, nhưng JAVA_HOME/PATH chưa được đặt cho apksigner.bat.

Script này tự:
1. Tìm Android Studio JBR/JDK.
2. Set JAVA_HOME và thêm JAVA_HOME/bin vào PATH cho subprocess.
3. Tạo keystore nếu chưa có.
4. zipalign.
5. apksigner sign.
6. apksigner verify.
7. Ghi đè app-release.apk bằng bản đã ký.
"""

from pathlib import Path
import os
import shutil
import subprocess
import sys

ROOT = Path.cwd()
STORE_PASS = "123456"
KEY_PASS = "123456"
KEY_ALIAS = "lunar"
KEYSTORE = ROOT / "android" / "app" / "lunar_sideload.jks"
APK = ROOT / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
ALIGNED = ROOT / "build" / "app" / "outputs" / "flutter-apk" / "app-release-aligned.apk"
SIGNED = ROOT / "build" / "app" / "outputs" / "flutter-apk" / "app-release-signed.apk"


def make_env():
    env = os.environ.copy()
    java_home = find_java_home()
    if java_home:
        env["JAVA_HOME"] = str(java_home)
        env["PATH"] = str(java_home / "bin") + os.pathsep + env.get("PATH", "")
        print(f"JAVA_HOME: {java_home}")
    else:
        print("CANH BAO: Khong tim thay JAVA_HOME tu dong. Se thu chay voi PATH hien tai.")
    return env


def run(cmd, check=True, env=None):
    print(">", " ".join(f'"{x}"' if " " in str(x) else str(x) for x in cmd))
    p = subprocess.run(cmd, shell=False, env=env)
    if check and p.returncode != 0:
        raise SystemExit(p.returncode)
    return p.returncode


def which(name):
    p = shutil.which(name)
    return Path(p) if p else None


def find_java_home():
    # Nếu người dùng đã set JAVA_HOME và có java.exe thì dùng luôn.
    env_home = os.environ.get("JAVA_HOME")
    if env_home:
        p = Path(env_home)
        if (p / "bin" / "java.exe").exists():
            return p

    candidates = [
        Path(r"C:\Program Files\Android\Android Studio\jbr"),
        Path(r"C:\Program Files\Android\Android Studio\jre"),
        Path(r"C:\Program Files\Java\jdk-21"),
        Path(r"C:\Program Files\Java\jdk-17"),
        Path(r"C:\Program Files\Eclipse Adoptium\jdk-21"),
        Path(r"C:\Program Files\Eclipse Adoptium\jdk-17"),
    ]

    for p in candidates:
        if (p / "bin" / "java.exe").exists():
            return p

    for base in [Path(r"C:\Program Files\Java"), Path(r"C:\Program Files\Eclipse Adoptium")]:
        if base.exists():
            for java in base.glob("**/bin/java.exe"):
                return java.parent.parent

    # Nếu java.exe đã nằm trong PATH, suy ra JAVA_HOME.
    java = which("java.exe") or which("java")
    if java and java.name.lower().startswith("java"):
        return java.parent.parent

    return None


def candidate_sdk_dirs():
    dirs = []
    for e in ["ANDROID_HOME", "ANDROID_SDK_ROOT", "ANDROID_SDK_HOME"]:
        v = os.environ.get(e)
        if v:
            dirs.append(Path(v))
    local = os.environ.get("LOCALAPPDATA")
    if local:
        dirs.append(Path(local) / "Android" / "Sdk")
    user = os.environ.get("USERPROFILE")
    if user:
        dirs.append(Path(user) / "AppData" / "Local" / "Android" / "Sdk")
    return [d for d in dirs if d.exists()]


def find_build_tool(tool):
    names = [tool + ".exe", tool + ".bat", tool]
    for name in names:
        direct = which(name)
        if direct:
            return direct

    candidates = []
    for sdk in candidate_sdk_dirs():
        build_tools = sdk / "build-tools"
        if build_tools.exists():
            for d in build_tools.iterdir():
                for name in names:
                    p = d / name
                    if p.exists():
                        candidates.append(p)

    if not candidates:
        return None

    def ver_key(p):
        nums = []
        for x in p.parent.name.replace("-", ".").split("."):
            try:
                nums.append(int(x))
            except Exception:
                nums.append(0)
        return nums

    candidates.sort(key=ver_key, reverse=True)
    return candidates[0]


def find_keytool():
    java_home = find_java_home()
    if java_home and (java_home / "bin" / "keytool.exe").exists():
        return java_home / "bin" / "keytool.exe"

    direct = which("keytool.exe") or which("keytool")
    if direct:
        return direct

    return None


def ensure_keystore(env):
    keytool = find_keytool()
    if not keytool:
        print("LOI: Khong tim thay keytool.exe.")
        print("Cach sua: cai JDK 17/21 hoac Android Studio, sau do mo CMD moi.")
        raise SystemExit(1)

    KEYSTORE.parent.mkdir(parents=True, exist_ok=True)
    if KEYSTORE.exists():
        print(f"OK: da co keystore: {KEYSTORE}")
        return

    print(f"Tao keystore: {KEYSTORE}")
    run([
        str(keytool),
        "-genkeypair",
        "-v",
        "-keystore", str(KEYSTORE),
        "-storepass", STORE_PASS,
        "-keypass", KEY_PASS,
        "-keyalg", "RSA",
        "-keysize", "2048",
        "-validity", "10000",
        "-alias", KEY_ALIAS,
        "-dname", "CN=Lich Am Gia Toc, OU=Family, O=Family, L=Hanoi, S=Hanoi, C=VN",
    ], env=env)


def signer_command(apksigner):
    # apksigner.bat phải chạy qua cmd /c và cần JAVA_HOME/PATH có java.exe.
    if apksigner.suffix.lower() == ".bat":
        return ["cmd.exe", "/c", str(apksigner)]
    return [str(apksigner)]


def sign_apk(env):
    if not APK.exists():
        print(f"LOI: Khong thay APK release: {APK}")
        raise SystemExit(1)

    zipalign = find_build_tool("zipalign")
    apksigner = find_build_tool("apksigner")

    if not zipalign:
        print("LOI: Khong tim thay zipalign trong Android SDK build-tools.")
        print("Hay cai Android SDK Build-Tools trong Android Studio SDK Manager.")
        raise SystemExit(1)

    if not apksigner:
        print("LOI: Khong tim thay apksigner trong Android SDK build-tools.")
        print("Hay cai Android SDK Build-Tools trong Android Studio SDK Manager.")
        raise SystemExit(1)

    if ALIGNED.exists():
        ALIGNED.unlink()
    if SIGNED.exists():
        SIGNED.unlink()

    print(f"zipalign: {zipalign}")
    print(f"apksigner: {apksigner}")

    run([str(zipalign), "-f", "-p", "4", str(APK), str(ALIGNED)], env=env)

    sign_cmd = signer_command(apksigner)
    run(sign_cmd + [
        "sign",
        "--ks", str(KEYSTORE),
        "--ks-key-alias", KEY_ALIAS,
        "--ks-pass", f"pass:{STORE_PASS}",
        "--key-pass", f"pass:{KEY_PASS}",
        "--out", str(SIGNED),
        str(ALIGNED),
    ], env=env)

    run(sign_cmd + [
        "verify",
        "--verbose",
        "--print-certs",
        str(SIGNED),
    ], env=env)

    shutil.copy2(SIGNED, APK)
    print("")
    print("DONE: APK release da duoc ky va verify thanh cong.")
    print(f"File cai dat: {APK}")
    print("Khong dung app-release-aligned.apk. Hay cai app-release.apk moi.")


def main():
    env = make_env()
    ensure_keystore(env)
    sign_apk(env)


if __name__ == "__main__":
    main()
