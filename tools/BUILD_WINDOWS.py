# -*- coding: utf-8 -*-
"""
BUILD_WINDOWS.py

Trình build Windows ổn định cho lich_am_gia_toc.

Mục tiêu:
- Không dùng nhiều label phức tạp trong BAT để tránh CMD tự thoát hoặc mất biến.
- Copy source sang đường dẫn ngắn C:\\_lich_am_gia_toc_build.
- Loại trừ build/android/windows/dist/logs/.dart_tool.
- Build debug/release trong đường dẫn ngắn để tránh MSVC FileTracker FTK1011.
- Luôn ghi log vào thư mục gốc logs/.
- Tự xóa build tạm sau khi xong.
"""

from __future__ import annotations

from pathlib import Path
from datetime import datetime
import os
import shutil
import subprocess
import sys
import zipfile

ORIGIN = Path(__file__).resolve().parents[1]
WORK = Path(r"C:\_lich_am_gia_toc_build")
LOG_DIR = ORIGIN / "logs"

EXCLUDE_DIRS = {
    "build", ".dart_tool", "android", "windows", "ios", "macos", "linux",
    "dist", "logs", ".git", ".gradle", ".idea", ".vscode", "__pycache__",
}
EXCLUDE_SUFFIXES = {".log", ".jks"}
EXCLUDE_NAMES = {"pubspec.lock"}


def now_tag() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")


class Logger:
    def __init__(self, mode: str):
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        self.path = LOG_DIR / f"windows_{mode}_{now_tag()}.log"
        self.fp = self.path.open("w", encoding="utf-8", errors="ignore")

    def write(self, text: str = "") -> None:
        print(text)
        self.fp.write(text + "\n")
        self.fp.flush()

    def close(self) -> None:
        self.fp.close()

    def tail(self, n: int = 80) -> str:
        try:
            lines = self.path.read_text(encoding="utf-8", errors="ignore").splitlines()
            return "\n".join(lines[-n:])
        except Exception:
            return ""


def find_flutter() -> str:
    candidates = [
        Path(r"C:\src\flutter\bin\flutter.bat"),
        Path(r"C:\src\Flutter\bin\flutter.bat"),
        Path(r"D:\flutter\bin\flutter.bat"),
        Path(r"D:\Flutter\bin\flutter.bat"),
    ]
    for p in candidates:
        if p.exists():
            return str(p)
    return "flutter"


FLUTTER = find_flutter()


def run(cmd: list[str], log: Logger, cwd: Path | None = None, allow_fail: bool = False) -> int:
    log.write("> " + " ".join(f'"{x}"' if " " in str(x) else str(x) for x in cmd))
    env = os.environ.copy()
    env["PATH"] = r"C:\src\flutter\bin;C:\src\Flutter\bin;" + env.get("PATH", "")

    p = subprocess.Popen(
        cmd,
        cwd=str(cwd or WORK),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="ignore",
        env=env,
    )
    assert p.stdout is not None
    for line in p.stdout:
        line = line.rstrip("\n")
        print(line)
        log.fp.write(line + "\n")
        log.fp.flush()
    rc = p.wait()
    if rc != 0 and not allow_fail:
        raise RuntimeError(f"Lệnh lỗi mã {rc}: {' '.join(cmd)}")
    return rc


def should_skip(path: Path) -> bool:
    rel = path.relative_to(ORIGIN)
    if any(part in EXCLUDE_DIRS for part in rel.parts):
        return True
    if path.name in EXCLUDE_NAMES:
        return True
    if path.suffix.lower() in EXCLUDE_SUFFIXES:
        return True
    if ".bak" in path.name:
        return True
    return False


def copy_source(log: Logger) -> None:
    if WORK.exists():
        log.write(f"Xóa build tạm cũ: {WORK}")
        shutil.rmtree(WORK, ignore_errors=True)
    WORK.mkdir(parents=True, exist_ok=True)

    log.write(f"Copy source từ: {ORIGIN}")
    log.write(f"Sang đường dẫn ngắn: {WORK}")

    copied_files = 0
    for src in ORIGIN.rglob("*"):
        if should_skip(src):
            continue
        rel = src.relative_to(ORIGIN)
        dst = WORK / rel
        if src.is_dir():
            dst.mkdir(parents=True, exist_ok=True)
        elif src.is_file():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            copied_files += 1

    log.write(f"Đã copy {copied_files} file.")
    patch = WORK / "tools" / "PATCH_WINDOWS_CLEAN.py"
    if not patch.exists():
        raise RuntimeError(f"Thiếu file sau khi copy: {patch}")


def patch_windows(log: Logger) -> None:
    log.write("Tạo Windows platform nếu chưa có...")
    if not (WORK / "windows").exists():
        run(["cmd.exe", "/c", FLUTTER, "create", "-t", "app", "--platforms=windows", "."], log)

    log.write("Patch Windows project...")
    run([sys.executable, "tools/PATCH_WINDOWS_CLEAN.py"], log)

    icon = WORK / "assets" / "icons" / "app_icon.ico"
    res_dir = WORK / "windows" / "runner" / "resources"
    if icon.exists():
        res_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(icon, res_dir / "app_icon.ico")
        log.write("OK: đã gắn icon Windows.")
    else:
        log.write("CẢNH BÁO: không thấy assets/icons/app_icon.ico")

    log.write("flutter pub get...")
    run(["cmd.exe", "/c", FLUTTER, "pub", "get"], log)


def clean_work_build_dirs(log: Logger) -> None:
    for name in ["windows", "build", ".dart_tool", "dist"]:
        p = WORK / name
        if p.exists():
            log.write(f"Xóa {p}")
            shutil.rmtree(p, ignore_errors=True)


def build_debug() -> int:
    log = Logger("debug")
    try:
        log.write("=====================================================")
        log.write("LICH AM GIA TOC - DEBUG WINDOWS")
        log.write("=====================================================")
        log.write(f"Source: {ORIGIN}")
        log.write(f"Work  : {WORK}")
        log.write(f"Log   : {log.path}")

        copy_source(log)
        patch_windows(log)

        log.write("Chạy flutter run -d windows...")
        run(["cmd.exe", "/c", FLUTTER, "run", "-d", "windows"], log)

        log.write("DEBUG hoàn tất.")
        return 0
    except Exception as e:
        log.write("")
        log.write("DEBUG THẤT BẠI.")
        log.write(str(e))
        log.write("")
        log.write("80 dòng log cuối:")
        log.write(log.tail())
        return 1
    finally:
        cleanup_temp(log)
        log.write(f"Full log: {log.path}")
        log.close()


def build_release() -> int:
    log = Logger("release")
    try:
        log.write("=====================================================")
        log.write("LICH AM GIA TOC - RELEASE WINDOWS")
        log.write("=====================================================")
        log.write(f"Source: {ORIGIN}")
        log.write(f"Work  : {WORK}")
        log.write(f"Log   : {log.path}")

        copy_source(log)
        clean_work_build_dirs(log)

        log.write("Tạo Windows platform mới...")
        run(["cmd.exe", "/c", FLUTTER, "create", "-t", "app", "--platforms=windows", "."], log)

        patch_windows(log)

        log.write("Build Windows release...")
        run(["cmd.exe", "/c", FLUTTER, "build", "windows", "--release"], log)

        release_dir = WORK / "build" / "windows" / "x64" / "runner" / "Release"
        if not release_dir.exists():
            raise RuntimeError(f"Không thấy thư mục release: {release_dir}")

        dist_dir = WORK / "dist" / "lich_am_gia_toc"
        if dist_dir.exists():
            shutil.rmtree(dist_dir, ignore_errors=True)
        dist_dir.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(release_dir, dist_dir)

        icon = WORK / "assets" / "icons" / "app_icon.ico"
        if icon.exists():
            fallback_dir = dist_dir / "assets" / "icons"
            fallback_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(icon, fallback_dir / "app_icon.ico")

        zip_path = WORK / "dist" / "lich_am_gia_toc.zip"
        if zip_path.exists():
            zip_path.unlink()
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
            for p in dist_dir.rglob("*"):
                if p.is_file():
                    z.write(p, p.relative_to(dist_dir.parent))

        origin_dist = ORIGIN / "dist"
        origin_dist.mkdir(parents=True, exist_ok=True)

        origin_dir = origin_dist / "lich_am_gia_toc"
        origin_zip = origin_dist / "lich_am_gia_toc.zip"
        if origin_dir.exists():
            shutil.rmtree(origin_dir, ignore_errors=True)
        if origin_zip.exists():
            origin_zip.unlink()

        shutil.copytree(dist_dir, origin_dir)
        shutil.copy2(zip_path, origin_zip)

        log.write("")
        log.write("RELEASE hoàn tất.")
        log.write(f"Thư mục app: {origin_dir}")
        log.write(f"File zip: {origin_zip}")
        return 0
    except Exception as e:
        log.write("")
        log.write("RELEASE THẤT BẠI.")
        log.write(str(e))
        log.write("")
        log.write("80 dòng log cuối:")
        log.write(log.tail())
        return 1
    finally:
        cleanup_temp(log)
        log.write(f"Full log: {log.path}")
        log.close()


def cleanup_temp(log: Logger) -> None:
    try:
        if WORK.exists():
            log.write(f"Xóa build tạm: {WORK}")
            shutil.rmtree(WORK, ignore_errors=True)
            if WORK.exists():
                log.write("CẢNH BÁO: chưa xóa được build tạm. Có thể còn process đang dùng.")
            else:
                log.write("OK: đã xóa build tạm.")
    except Exception as e:
        log.write(f"CẢNH BÁO khi xóa build tạm: {e}")


def main() -> int:
    print("=====================================================")
    print("LICH AM GIA TOC - WINDOWS BUILD")
    print("=====================================================")
    print()
    print("1. DEBUG   - chạy app ngay trên máy này")
    print("2. RELEASE - build app độc lập để copy sang máy khác")
    print()
    choice = input("Nhập lựa chọn 1 hoặc 2: ").strip()

    if choice == "1":
        return build_debug()
    if choice == "2":
        return build_release()

    print(f"Lựa chọn không hợp lệ: {choice}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
