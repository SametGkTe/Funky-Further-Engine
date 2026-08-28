#!/usr/bin/env python3
"""
Further Engine — release APK uretimini garanti altina alir.

SORUN
    Lime'in AndroidPlatform.hx kodu:

        var build = "debug";
        if (project.keystore != null) build = "release";
        if (project.environment.exists("ANDROID_GRADLE_TASK")) { ... }

    Yani Lime, release varyantini SADECE Project.xml'de <certificate>
    tanimliysa derliyor. Biz <certificate>'i (CI hang'i yuzunden)
    kaldirdigimiz icin Lime 'assembleDebug' calistirdi:

        outputs/apk/debug/FurtherEngine-debug.apk   (310 MB, debug imzali)

    Ama artifactPath ve imzalama adimi apk/release bekliyor.

COZUM (iki katmanli)
    1. Job env'e ANDROID_GRADLE_TASK=assembleRelease eklenir.
       Lime bunu okursa dogrudan release derler.
    2. "Ensure release APK" adimi: release APK yoksa Gradle'i biz
       calistiririz (./gradlew assembleRelease). Boylece Lime env
       degiskenini yok saysa bile release APK garanti uretilir.
    3. Sign adimi hem *-unsigned.apk hem de Lime'in imzaladigi
       release APK'yi kabul eder (apksigner imzayi degistirir),
       ama debug APK'yi ASLA imzalamaz.

KULLANIM
    python fix-release-apk.py <repo>
    python fix-release-apk.py <repo> --dry-run
    python fix-release-apk.py <repo> --revert
"""

import argparse
import os
import re
import shutil
import sys

IS_WIN = os.name == "nt"


def _init():
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
        if k.GetConsoleMode(h, ctypes.byref(m)) and k.SetConsoleMode(h, m.value | 0x0004):
            return True
    except Exception:
        pass
    return False


_C = _init() and os.environ.get("NO_COLOR") is None
if _C:
    GRN = "\033[0;32m"; RED = "\033[0;31m"; YLW = "\033[1;33m"
    CYN = "\033[0;36m"; DIM = "\033[2m"; RST = "\033[0m"
    OK, SK, BK = "✓", "=", "↩"
else:
    GRN = RED = YLW = CYN = DIM = RST = ""
    OK, SK, BK = "[OK]", "[--]", "[<-]"


def read_text(p):
    t = open(p, "rb").read().decode("utf-8-sig")
    crlf = t.count("\r\n")
    lf = t.count("\n") - crlf
    return t.replace("\r\n", "\n"), ("\r\n" if crlf > lf else "\n")


def write_text(p, t, nl):
    open(p, "wb").write((t.replace("\n", nl) if nl != "\n" else t).encode("utf-8"))


ENSURE_STEP = '''      # --- RELEASE APK GARANTISI ---
      # Lime, <certificate> yoksa assembleDebug calistirir (AndroidPlatform.hx).
      # Release APK uretilmediyse Gradle'i dogrudan biz cagiriyoruz.
      - name: Ensure release APK
        if: success() && inputs.name == 'Android'
        shell: bash
        run: |
          set -euo pipefail

          REL="export/release/android/bin/app/build/outputs/apk/release"
          GP="export/release/android/bin"

          if ls "$REL"/*.apk >/dev/null 2>&1; then
            echo "Release APK zaten uretilmis:"
            ls -la "$REL"
            exit 0
          fi

          echo "Release APK yok - Gradle assembleRelease dogrudan calistiriliyor."

          if [ ! -f "$GP/gradlew" ]; then
            echo "gradlew bulunamadi: $GP"
            ls -la "$GP" 2>/dev/null || echo "(klasor yok)"
            exit 1
          fi

          cd "$GP"
          chmod +x gradlew
          # < /dev/null: olasi prompt sonsuz beklemesin
          ./gradlew assembleRelease --no-daemon --console=plain --stacktrace < /dev/null
          cd - >/dev/null

          echo "=== assembleRelease sonrasi ==="
          if ! ls -la "$REL" 2>/dev/null; then
            echo "Release klasoru hala yok. Bulunan tum APK'lar:"
            find export -name "*.apk" 2>/dev/null || true
            exit 1
          fi

'''

NEW_TARGET_BLOCK = '''          # Imzalanacak APK'yi sec.
          # Oncelik: *-unsigned.apk  ->  diger release APK'lar
          # Debug APK ASLA imzalanmaz (android:debuggable=true tasir).
          TARGET=$(ls "$APK_DIR"/*-unsigned.apk 2>/dev/null | head -n1 || true)

          if [ -z "$TARGET" ]; then
            TARGET=$(ls "$APK_DIR"/*.apk 2>/dev/null | grep -v -- "-debug\\.apk$" | head -n1 || true)
            if [ -n "$TARGET" ]; then
              echo "Imzasiz APK yok; mevcut release APK yeniden imzalanacak."
              echo "(apksigner eski imzayi kaldirip yenisini uygular)"
            fi
          fi

          if [ -z "$TARGET" ]; then
            echo "Imzalanacak release APK bulunamadi."
            echo "Klasordeki dosyalar:"
            ls -la "$APK_DIR"
            case "$APK_DIR" in
              *"/debug") echo "UYARI: sadece DEBUG APK var. 'Ensure release APK' adimi calisti mi?" ;;
            esac
            exit 1
          fi
          echo "Imzalanacak: $TARGET"'''

OLD_TARGET_RE = re.compile(
    r'          UNSIGNED=\$\(ls "\$APK_DIR"/\*-unsigned\.apk 2>/dev/null \| head -n1 \|\| true\)\n'
    r'          if \[ -z "\$UNSIGNED" \]; then\n'
    r'            echo "Imzasiz APK bulunamadi \(Project\.xml\'de <certificate> hala acik olabilir\)\."\n'
    r'            echo "Mevcut APK\'lar yukarida\. Imzalama atlaniyor\."\n'
    r'            exit 0\n'
    r'          fi\n'
    r'          echo "Imzalanacak: \$UNSIGNED"'
)


SAFE_SIGN_BLOCK = '''          OUT="$APK_DIR/${PROJECT_NAME}-release.apk"

          "$BT/zipalign" -p -f 4 "$TARGET" /tmp/aligned.apk

          # --ks-pass env: -> sifre ne komut satirinda gorunur ne de prompt acilir.
          # Once /tmp'ye imzala: TARGET ile OUT ayni dosya olabilir.
          "$BT/apksigner" sign \\
            --ks /tmp/release.keystore \\
            --ks-pass "env:KS_PASS" \\
            --ks-key-alias "$KS_ALIAS" \\
            --key-pass "env:KS_ALIAS_PASS" \\
            --out /tmp/signed.apk \\
            /tmp/aligned.apk

          echo "=== imza dogrulama ==="
          "$BT/apksigner" verify --print-certs /tmp/signed.apk

          # Kaynak APK'yi kaldir, imzalanmisi yerine koy
          rm -f "$TARGET"
          mv /tmp/signed.apk "$OUT"

          rm -f /tmp/release.keystore /tmp/aligned.apk
          echo "=== son durum ==="
          ls -la "$APK_DIR"'''

OLD_SIGN_RE = re.compile(
    r'          "\$BT/zipalign" -p -f 4 "\$(?:UNSIGNED|TARGET)" /tmp/aligned\.apk\n'
    r'.*?'
    r'          ls -la "\$APK_DIR"',
    re.S
)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("repo")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--revert", action="store_true")
    a = ap.parse_args()

    repo = os.path.abspath(a.repo)
    path = os.path.join(repo, ".github", "workflows", "build.yml")
    bak = path + ".relfix.bak"

    if not os.path.exists(path):
        print(f"{RED}HATA:{RST} {path} yok")
        sys.exit(1)

    print()
    print(f"{CYN}+====================================================+{RST}")
    print(f"{CYN}|   build.yml - release APK uretimi garantisi        |{RST}")
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

    # 1) ANDROID_GRADLE_TASK env
    if "ANDROID_GRADLE_TASK" in text:
        print(f"  {DIM}{SK}{RST} ANDROID_GRADLE_TASK zaten var")
    else:
        anchor = '      CI: "true"'
        if anchor in text:
            text = text.replace(
                anchor,
                anchor + "\n      # Lime bunu okursa assembleDebug yerine release derler\n"
                         "      ANDROID_GRADLE_TASK: assembleRelease",
                1)
            print(f"  {GRN}{OK}{RST} job env -> ANDROID_GRADLE_TASK: assembleRelease")
        else:
            print(f"  {YLW}!{RST} job env blogu bulunamadi, atlandi")

    # 2) Ensure release APK adimi
    if "Ensure release APK" in text:
        print(f"  {DIM}{SK}{RST} 'Ensure release APK' adimi zaten var")
    else:
        anchor = "      - name: Sign Android APK"
        if anchor in text:
            text = text.replace(anchor, ENSURE_STEP + anchor, 1)
            print(f"  {GRN}{OK}{RST} 'Ensure release APK' adimi eklendi (Gradle fallback)")
        else:
            print(f"  {RED}HATA:{RST} 'Sign Android APK' adimi bulunamadi")
            sys.exit(1)

    # 3) Sign adimi hedef secimi
    if "Debug APK ASLA imzalanmaz" in text:
        print(f"  {DIM}{SK}{RST} Sign adimi hedef secimi zaten guncel")
    elif OLD_TARGET_RE.search(text):
        text = OLD_TARGET_RE.sub(NEW_TARGET_BLOCK, text)
        print(f"  {GRN}{OK}{RST} Sign adimi -> unsigned + release APK kabul, debug reddedilir")
    else:
        print(f"  {YLW}!{RST} Sign adimi hedef blogu eslesmedi (elle degismis olabilir)")

    # 4) Imzalama/temizlik blogu — TARGET ile OUT ayni dosya olabilir
    if 'mv /tmp/signed.apk "$OUT"' in text:
        print(f"  {DIM}{SK}{RST} Imzalama blogu zaten guvenli")
    elif OLD_SIGN_RE.search(text):
        text = OLD_SIGN_RE.sub(SAFE_SIGN_BLOCK, text)
        print(f"  {GRN}{OK}{RST} Imzalama blogu -> /tmp'ye imzala, sonra tasi "
              f"(kaynak=hedef durumunda veri kaybini onler)")
    else:
        print(f"  {YLW}!{RST} Imzalama blogu eslesmedi")

    if text == orig:
        print(f"\n{DIM}Degisiklik yok.{RST}\n")
        return

    try:
        import yaml
        yaml.safe_load(text)
        yaml_ok = True
    except ImportError:
        yaml_ok = None
    except Exception as e:
        print(f"\n  {RED}HATA:{RST} YAML bozuldu, yazilmadi: {e}\n")
        sys.exit(1)

    if not a.dry_run:
        if not os.path.exists(bak):
            shutil.copy2(path, bak)
        write_text(path, text, nl)

    if yaml_ok:
        print(f"  {GRN}{OK}{RST} YAML gecerli")

    if not a.dry_run:
        print(f"""
{CYN}Siradaki adimlar:{RST}
    git add -A
    git commit -m "ci: force release variant and guarantee APK output"
    git push

    Actions -> Android ARM64 -> Run workflow

  Geri almak icin:
    python fix-release-apk.py "{repo}" --revert
""")
    print()


if __name__ == "__main__":
    main()
