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
        shutil.copy2(p, p.with_suffix(p.suffix + ".bak_clean_v4"))

def patch_pubspec():
    p = ROOT / "pubspec.yaml"
    if not p.exists():
        raise SystemExit("Không thấy pubspec.yaml")
    backup(p)
    s = read(p)
    s = re.sub(r"(?m)^(\s*)ios:\s*true\s*$", r"\1ios: false", s)
    s = re.sub(r"(?m)^(\s*)remove_alpha_ios:\s*true\s*$", r"\1remove_alpha_ios: false", s)
    write(p, s)

def patch_cmake():
    p = ROOT / "windows/CMakeLists.txt"
    if not p.exists():
        raise SystemExit("Không thấy windows/CMakeLists.txt. Hãy chạy flutter create -t app --platforms=windows . trước.")
    backup(p)
    s = read(p)

    bad_patterns = [
        r"^\s*r\s*$",
        r"^\s*nadd_compile_definitions.*$",
        r"^\s*`r`nadd_compile_definitions.*$",
        r"^\s*\\r\\nadd_compile_definitions.*$",
        r"^\s*add_compile_definitions\(_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS\)\s*$",
    ]
    lines = []
    for line in s.splitlines():
        if any(re.match(pat, line) for pat in bad_patterns):
            continue
        lines.append(line)
    s = "\n".join(lines) + "\n"

    if "_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS" not in s:
        s = re.sub(
            r"(project\([^)]+\)\s*)",
            r"\1\nadd_compile_definitions(_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)\n",
            s,
            count=1,
        )
    write(p, s)

if __name__ == "__main__":
    patch_pubspec()
    patch_cmake()
    print("OK: Windows project patched cleanly.")
