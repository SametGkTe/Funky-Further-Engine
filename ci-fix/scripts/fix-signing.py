#!/usr/bin/env python3
"""
Further Engine — .github/workflows/build.yml YERINDE yamalar.

Neden ayri bir script?
    apply-patch.py, build.yml'i ci-fix/build.yml ile KOMPLE degistirir.
    Bu, ci-fix/build.yml'i guncel tutmayi zorunlu kilar ve senkron kaymasina
    yol aciyor. Bu script dosyayi oldugu yerde duzenler; hicbir kaynak
    dosyaya bagimli degil ve idempotenttir.

Yaptiklari
    1. Kosullu adimlara "success() &&" ekler.
       GitHub Actions'ta bir adima "if:" yazinca ORTUK success() kontrolu
       kalkar -> Compile cokse bile Sign adimi calisir ve gercek hatayi gizler.
    2. Sign adimindaki APK klasoru kontrolunu akillandirir:
       bulamazsa hemen cokmez, alternatif yollari arar, sonra export
       agacinin tamamini dokerek nerede oldugunu gosterir.

Kullanim
    python fix-signing.py <repo>
    python fix-signing.py <repo> --dry-run
    python fix-signing.py <repo> --revert
"""

import argparse
import os
import re
import shutil
import sys

IS_WIN = os.name == "nt"


def _init_console():
    if not IS_WIN:
        return True
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    try:
        import ctypes
        k = ctypes.windll.kernel32
        h = k.GetStdHandle(-11)
        m = ctypes.c_ulong()
        if k.GetConsoleMode(h, ctypes.byref(m)):
            if k.SetConsoleMode(h, m.value | 0x0004):
                return True
    except Exception:
        pass
    return False


_C = _init_console() and os.environ.get("NO_COLOR") is None
if _C:
    GRN = "\033[0;32m"; RED = "\033[0;31m"; YLW = "\033[1;33m"
    CYN = "\033[0;36m"; DIM = "\033[2m"; RST = "\033[0m"
    OK, SK, BK = "✓", "=", "↩"
else:
    GRN = RED = YLW = CYN = DIM = RST = ""
    OK, SK, BK = "[OK]", "[--]", "[<-]"


def read_text(p):
    raw = open(p, "rb").read()
    t = raw.decode("utf-8-sig")
    crlf = t.count("\r\n")
    lf = t.count("\n") - crlf
    return t.replace("\r\n", "\n"), ("\r\n" if crlf > lf else "\n")


def write_text(p, t, nl):
    data = t.replace("\n", nl) if nl != "\n" else t
    open(p, "wb").write(data.encode("utf-8"))


# Sign adiminin yeni, teshis dostu APK bulma blogu
NEW_APK_BLOCK = '''          APK_DIR="export/release/android/bin/app/build/outputs/apk/release"

          if [ ! -d "$APK_DIR" ]; then
            echo "Beklenen APK klasoru yok: $APK_DIR"
            echo "Alternatif yollar araniyor..."
            FOUND=$(find export -type d -path "*outputs/apk/*" 2>/dev/null | head -n1 || true)
            if [ -n "$FOUND" ]; then
              echo "Bulundu: $FOUND"
              APK_DIR="$FOUND"
            else
              echo ""
              echo "############ TESHIS ############"
              echo "--- export agaci (4 seviye) ---"
              find export -maxdepth 4 -type d 2>/dev/null | head -n 60 || echo "(export klasoru yok)"
              echo "--- tum .apk dosyalari ---"
              find . -name "*.apk" -not -path "./.git/*" 2>/dev/null || echo "(hic apk yok)"
              echo "--- tum .aab dosyalari ---"
              find . -name "*.aab" -not -path "./.git/*" 2>/dev/null || echo "(hic aab yok)"
              echo "--- gradle cikti klasorleri ---"
              find export -type d -name "outputs" 2>/dev/null || echo "(outputs klasoru yok)"
              echo "--- android bin icerigi ---"
              ls -la export/release/android/bin 2>/dev/null || echo "(bin yok)"
              echo "################################"
              echo ""
              echo "Compile basarili gorundu ama APK uretilmemis."
              echo "Muhtemel sebep: lime Gradle assemble adimini calistirmadi."
              exit 1
            fi
          fi

          echo "=== APK klasoru: $APK_DIR ==="
          ls -la "$APK_DIR"'''

OLD_APK_BLOCK_RE = re.compile(
    r'          APK_DIR="export/release/android/bin/app/build/outputs/apk/release"\n'
    r'          echo "=== APK klasoru ==="\n'
    r'          ls -la "\$APK_DIR" \|\| \{ echo "APK klasoru yok!"; exit 1; \}'
)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("repo")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--revert", action="store_true")
    a = ap.parse_args()

    repo = os.path.abspath(a.repo)
    path = os.path.join(repo, ".github", "workflows", "build.yml")
    bak = path + ".signfix.bak"

    if not os.path.exists(path):
        print(f"{RED}HATA:{RST} {path} yok")
        sys.exit(1)

    print()
    print(f"{CYN}+====================================================+{RST}")
    print(f"{CYN}|   build.yml - success() guard + APK teshisi        |{RST}")
    print(f"{CYN}+====================================================+{RST}")
    print(f"  {path}")
    if a.dry_run:
        print(f"  {YLW}[DRY RUN]{RST}")
    print()

    if a.revert:
        if os.path.exists(bak):
            shutil.move(bak, path)
            print(f"  {YLW}{BK}{RST} build.yml geri alindi\n")
        else:
            print(f"  {DIM}{SK}{RST} yedek yok\n")
        return

    text, nl = read_text(path)
    orig = text
    n_guard = 0

    # 1) success() guard'lari
    def guard(m):
        nonlocal n_guard
        indent, cond = m.group(1), m.group(2)
        if cond.startswith("success()") or "failure()" in cond or "always()" in cond \
           or "cancelled()" in cond:
            return m.group(0)
        n_guard += 1
        return f"{indent}if: success() && {cond}"

    text = re.sub(r'^(\s+)if:[ \t]+(.+)$', guard, text, flags=re.M)

    if n_guard:
        print(f"  {GRN}{OK}{RST} {n_guard} adima success() guard'i eklendi")
    else:
        print(f"  {DIM}{SK}{RST} success() guard'lari zaten var")

    # 2) APK blogu
    if "############ TESHIS ############" in text:
        print(f"  {DIM}{SK}{RST} Sign adimi APK teshisi zaten guncel")
    elif OLD_APK_BLOCK_RE.search(text):
        text = OLD_APK_BLOCK_RE.sub(NEW_APK_BLOCK, text)
        print(f"  {GRN}{OK}{RST} Sign adimi -> akilli APK arama + teshis dokumu")
    else:
        print(f"  {YLW}!{RST} Eski APK blogu bulunamadi, atlandi "
              f"(elle degistirilmis olabilir)")

    if text == orig:
        print(f"\n{DIM}Degisiklik yok - her sey zaten guncel.{RST}\n")
        return

    if not a.dry_run:
        if not os.path.exists(bak):
            shutil.copy2(path, bak)
        write_text(path, text, nl)

    # dogrulama
    try:
        import yaml
        yaml.safe_load(text)
        print(f"  {GRN}{OK}{RST} YAML gecerli")
    except ImportError:
        pass
    except Exception as e:
        print(f"  {RED}HATA:{RST} YAML bozuldu: {e}")
        if not a.dry_run and os.path.exists(bak):
            shutil.move(bak, path)
            print("  Geri alindi.")
        sys.exit(1)

    if not a.dry_run:
        print(f"""
{CYN}Siradaki adimlar:{RST}
    git add -A
    git commit -m "ci: gate steps behind success(), add APK path diagnostics"
    git push

    Actions -> Android ARM64 -> Run workflow

  Geri almak icin:
    python fix-signing.py "{repo}" --revert
""")
    print()


if __name__ == "__main__":
    main()
