#!/usr/bin/env python3
"""
Further Engine — Gradle release imzalamasini signing.properties ile cozer.

SORUN
    Lime'in android build.gradle template'i (lime/templates/android/
    template/app/build.gradle), Project.xml'de <certificate> YOKSA sunu yapar:

        File signingFile = file('signing.properties')
        if (signingFile.exists()) { ...storeFile file(signing["KEY_STORE"])... }
        else { signingConfigs { release } }        // BOS!

        buildTypes { release { signingConfig signingConfigs.release } }

    signing.properties yoksa signingConfig bos kalir ama release buildType
    yine de onu kullanir:

        Execution failed for task ':app:packageRelease'
        > SigningConfig "release" is missing required property "storeFile"

COZUM
    Compile'dan ONCE app/signing.properties yaz. Bu dosya template'in bir
    parcasi DEGIL, dolayisiyla Lime onu uretmez ve silmez -> onceden
    yazilabilir. Gradle release APK'yi dogrudan gercek anahtarla imzalar.

    Ayrica "Ensure release APK" fallback adimi da dosyayi tazeler, boylece
    Lime bin/ klasorunu temizlese bile ikinci deneme calisir.

NOT
    <certificate> etiketini geri acmak COZUM DEGIL: template o zaman
    KEY_STORE_PASSWORD == 'null' oldugunda getPassword() cagirir, bu da
    CI'da sonsuz hang'e yol acan interaktif prompttur (ilk sorunun kaynagi).

KULLANIM
    python fix-gradle-signing.py <repo>
    python fix-gradle-signing.py <repo> --dry-run
    python fix-gradle-signing.py <repo> --revert
"""

import argparse
import os
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


PREPARE_STEP = '''      # --- GRADLE IMZALAMA HAZIRLIGI ---
      # Lime'in build.gradle template'i, <certificate> yoksa
      # app/signing.properties dosyasini arar. Yoksa bos bir signingConfig
      # uretir ve packageRelease su hatayla duser:
      #   SigningConfig "release" is missing required property "storeFile"
      # signing.properties template'in parcasi degildir; Lime onu silmez,
      # bu yuzden Compile'dan once yazmak guvenlidir.
      - name: Prepare Android signing
        if: success() && inputs.name == 'Android'
        shell: bash
        env:
          KS_B64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          KS_PASS: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          KS_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          KS_ALIAS_PASS: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          set -euo pipefail

          if [ -z "${KS_B64:-}" ]; then
            echo "Keystore secret'i tanimli degil."
            echo "UYARI: packageRelease 'missing storeFile' hatasi verecek."
            exit 0
          fi

          APP_DIR="export/release/android/bin/app"
          mkdir -p "$APP_DIR"

          printf '%s' "$KS_B64" | base64 --decode > /tmp/release.keystore
          echo "keystore: $(wc -c < /tmp/release.keystore) bayt"

          umask 077
          {
            printf 'KEY_STORE=%s\\n'                "/tmp/release.keystore"
            printf 'KEY_STORE_PASSWORD=%s\\n'       "$KS_PASS"
            printf 'KEY_STORE_ALIAS=%s\\n'          "$KS_ALIAS"
            printf 'KEY_STORE_ALIAS_PASSWORD=%s\\n' "$KS_ALIAS_PASS"
          } > "$APP_DIR/signing.properties"
          chmod 600 "$APP_DIR/signing.properties"

          echo "signing.properties yazildi (sifreler gizlendi):"
          sed 's/\\(PASSWORD=\\).*/\\1***/' "$APP_DIR/signing.properties"

'''

ENSURE_REFRESH = '''          # signing.properties'i tazele - Lime bin/ klasorunu yenilemis olabilir
          if [ -n "${KS_B64:-}" ]; then
            mkdir -p "$GP/app"
            umask 077
            printf '%s' "$KS_B64" | base64 --decode > /tmp/release.keystore
            {
              printf 'KEY_STORE=%s\\n'                "/tmp/release.keystore"
              printf 'KEY_STORE_PASSWORD=%s\\n'       "$KS_PASS"
              printf 'KEY_STORE_ALIAS=%s\\n'          "$KS_ALIAS"
              printf 'KEY_STORE_ALIAS_PASSWORD=%s\\n' "$KS_ALIAS_PASS"
            } > "$GP/app/signing.properties"
            chmod 600 "$GP/app/signing.properties"
            echo "signing.properties tazelendi."
          fi

'''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("repo")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--revert", action="store_true")
    a = ap.parse_args()

    repo = os.path.abspath(a.repo)
    path = os.path.join(repo, ".github", "workflows", "build.yml")
    bak = path + ".gradlesign.bak"

    if not os.path.exists(path):
        print(f"{RED}HATA:{RST} {path} yok")
        sys.exit(1)

    print()
    print(f"{CYN}+====================================================+{RST}")
    print(f"{CYN}|   build.yml - Gradle signing.properties duzeltmesi |{RST}")
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

    # 1) Prepare Android signing adimi (Compile'dan once)
    if "Prepare Android signing" in text:
        print(f"  {DIM}{SK}{RST} 'Prepare Android signing' adimi zaten var")
    else:
        anchor = "      - name: Compile"
        if anchor not in text:
            print(f"  {RED}HATA:{RST} 'Compile' adimi bulunamadi")
            sys.exit(1)
        # Compile'dan hemen onceki yorum blogunu da atlamak icin
        idx = text.index(anchor)
        # yukaridaki "# --- HANG FIX ---" yorum blogunun basini bul
        head = text[:idx]
        cut = head.rfind("      # --- HANG FIX ---")
        if cut == -1:
            cut = idx
        text = text[:cut] + PREPARE_STEP + text[cut:]
        print(f"  {GRN}{OK}{RST} 'Prepare Android signing' adimi eklendi (Compile oncesi)")

    # 2) Ensure release APK adimina secrets + tazeleme
    if "signing.properties tazelendi" in text:
        print(f"  {DIM}{SK}{RST} 'Ensure release APK' tazeleme zaten var")
    elif "Ensure release APK" in text:
        # env blogu ekle
        old_hdr = ("      - name: Ensure release APK\n"
                   "        if: success() && inputs.name == 'Android'\n"
                   "        shell: bash\n"
                   "        run: |\n")
        new_hdr = ("      - name: Ensure release APK\n"
                   "        if: success() && inputs.name == 'Android'\n"
                   "        shell: bash\n"
                   "        env:\n"
                   "          KS_B64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}\n"
                   "          KS_PASS: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}\n"
                   "          KS_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}\n"
                   "          KS_ALIAS_PASS: ${{ secrets.ANDROID_KEY_PASSWORD }}\n"
                   "        run: |\n")
        if old_hdr in text:
            text = text.replace(old_hdr, new_hdr, 1)

        marker = '          echo "Release APK yok - Gradle assembleRelease dogrudan calistiriliyor."\n'
        if marker in text:
            text = text.replace(marker, marker + "\n" + ENSURE_REFRESH, 1)
            print(f"  {GRN}{OK}{RST} 'Ensure release APK' -> signing.properties tazeleme eklendi")
        else:
            print(f"  {YLW}!{RST} Ensure adimi ic blogu eslesmedi")
    else:
        print(f"  {YLW}!{RST} 'Ensure release APK' adimi yok "
              f"(once fix-release-apk.py calistir)")

    # 3) Temizlik: signing.properties'i sil
    if 'signing.properties" 2>/dev/null' in text:
        print(f"  {DIM}{SK}{RST} signing.properties temizligi zaten var")
    else:
        anchor = "          rm -f /tmp/release.keystore /tmp/aligned.apk\n"
        if anchor in text:
            text = text.replace(
                anchor,
                anchor +
                '          rm -f "export/release/android/bin/app/signing.properties" 2>/dev/null || true\n',
                1)
            print(f"  {GRN}{OK}{RST} Sign adimi -> signing.properties siliniyor")
        else:
            print(f"  {YLW}!{RST} Temizlik satiri bulunamadi")

    if text == orig:
        print(f"\n{DIM}Degisiklik yok.{RST}\n")
        return

    try:
        import yaml
        yaml.safe_load(text)
        ok_yaml = True
    except ImportError:
        ok_yaml = None
    except Exception as e:
        print(f"\n  {RED}HATA:{RST} YAML bozuldu, yazilmadi: {e}\n")
        sys.exit(1)

    if not a.dry_run:
        if not os.path.exists(bak):
            shutil.copy2(path, bak)
        write_text(path, text, nl)

    if ok_yaml:
        print(f"  {GRN}{OK}{RST} YAML gecerli")

    if not a.dry_run:
        print(f"""
{CYN}Siradaki adimlar:{RST}
    git add -A
    git commit -m "ci: sign release via Gradle signing.properties"
    git push

    Actions -> Android ARM64 -> Run workflow

  Geri almak icin:
    python fix-gradle-signing.py "{repo}" --revert
""")
    print()


if __name__ == "__main__":
    main()
