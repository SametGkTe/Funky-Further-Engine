#!/usr/bin/env python3
"""
Further Engine — Keystore/CI yamasını repoya uygular.

Kullanım:
    python3 apply-patch.py /yol/Funky-Further-Engine
    python3 apply-patch.py /yol/Funky-Further-Engine --dry-run
    python3 apply-patch.py /yol/Funky-Further-Engine --revert

Yaptıkları:
  1. .github/workflows/build.yml  -> yamalı sürümle değiştirilir
  2. Çağıran workflow'lara        -> "secrets: inherit" eklenir
  3. Project.xml                  -> <certificate> satırı yorum satırına alınır
  4. .gitignore                   -> keystore kuralları sıkılaştırılır
  5. key.keystore                 -> git takibinden çıkarılır (dosya diskte kalır)

Her değiştirilen dosyanın .bak yedeği alınır. --revert ile geri alınır.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
IS_WIN = os.name == "nt"

# ──────────────────────────────────────────────────────────────
# Windows konsol uyumu
# ──────────────────────────────────────────────────────────────
def _init_console():
    """Windows 10+ terminalinde ANSI renkleri ac; olmazsa renkleri kapat."""
    if not IS_WIN:
        return True
    # UTF-8 cikti (Turkce karakterler ve ✓ / ↩ icin)
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass
    try:
        import ctypes
        k = ctypes.windll.kernel32
        h = k.GetStdHandle(-11)
        mode = ctypes.c_ulong()
        if k.GetConsoleMode(h, ctypes.byref(mode)):
            # ENABLE_VIRTUAL_TERMINAL_PROCESSING
            if k.SetConsoleMode(h, mode.value | 0x0004):
                return True
    except Exception:
        pass
    return False


_COLOR = _init_console() and (os.environ.get("NO_COLOR") is None)

if _COLOR:
    GRN = "\033[0;32m"; RED = "\033[0;31m"; YLW = "\033[1;33m"
    CYN = "\033[0;36m"; DIM = "\033[2m"; RST = "\033[0m"
    S_OK, S_SKIP, S_BACK = "✓", "=", "↩"
else:
    GRN = RED = YLW = CYN = DIM = RST = ""
    S_OK, S_SKIP, S_BACK = "[OK]", "[--]", "[<-]"

changes = []
warnings = []


def log(sym, color, msg):
    print(f"  {color}{sym}{RST} {msg}")


# ──────────────────────────────────────────────────────────────
# Satir sonu koruyan dosya G/C
#
# Windows'ta Python varsayilan olarak yazarken \n -> \r\n cevirir.
# Repo LF kullaniyorsa bu, TUM dosyayi degismis gosteren dev bir diff
# uretir. Bu yuzden orijinal satir sonunu tespit edip aynen koruyoruz.
# ──────────────────────────────────────────────────────────────
def read_text(path):
    """(metin_LF_normalize, orijinal_satir_sonu) dondurur."""
    with open(path, "rb") as f:
        raw = f.read()
    text = raw.decode("utf-8-sig")
    crlf = text.count("\r\n")
    lf = text.count("\n") - crlf
    nl = "\r\n" if crlf > lf else "\n"
    return text.replace("\r\n", "\n"), nl


def write_text(path, text, nl):
    """LF normalize metni, orijinal satir sonuyla geri yazar."""
    data = text.replace("\n", nl) if nl != "\n" else text
    with open(path, "wb") as f:
        f.write(data.encode("utf-8"))


def backup(path):
    bak = path + ".bak"
    if not os.path.exists(bak):
        shutil.copy2(path, bak)
    return bak


# ──────────────────────────────────────────────────────────────
# 1. build.yml
# ──────────────────────────────────────────────────────────────
def patch_build_yml(repo, dry):
    dst = os.path.join(repo, ".github", "workflows", "build.yml")
    src = os.path.join(HERE, "..", "build.yml")
    src = os.path.normpath(src)

    if not os.path.exists(src):
        warnings.append(f"Kaynak bulunamadı: {src}")
        return
    if not os.path.exists(dst):
        warnings.append(f"Hedef bulunamadı: {dst}")
        return

    # Satir sonu farkina takilmadan karsilastir (CRLF repo'da idempotent kalsin)
    src_text, _ = read_text(src)
    dst_text, nl = read_text(dst)

    if src_text == dst_text:
        log(S_SKIP, DIM, "build.yml zaten yamalı")
        return

    if not dry:
        backup(dst)
        write_text(dst, src_text, nl)
    changes.append(".github/workflows/build.yml")
    log(S_OK, GRN, "build.yml yamalandı (stdin kapatma + apksigner + timeout)")

    # apply-patch build.yml'i KOMPLE degistirir. add-colyseus.py daha once
    # build.yml'e colyseus/tink_core satirlarini eklediyse, onlar silinir.
    if "haxelib set colyseus" in dst_text and "haxelib set colyseus" not in src_text:
        warnings.append(
            "build.yml'deki colyseus/tink_core satirlari uzerine yazildi. "
            "Geri getirmek icin SIMDI calistir:  python add-colyseus.py <repo>")


# ──────────────────────────────────────────────────────────────
# 2. secrets: inherit
# ──────────────────────────────────────────────────────────────
def patch_callers(repo, dry):
    wf_dir = os.path.join(repo, ".github", "workflows")
    if not os.path.isdir(wf_dir):
        warnings.append("workflows klasörü yok")
        return

    for fn in sorted(os.listdir(wf_dir)):
        if not fn.endswith((".yml", ".yaml")) or fn == "build.yml":
            continue
        path = os.path.join(wf_dir, fn)
        content, nl = read_text(path)
        lines = content.split("\n")

        out, i, touched = [], 0, False
        while i < len(lines):
            line = lines[i]
            out.append(line)

            m = re.match(r"^(\s*)uses:\s*\./\.github/workflows/build\.yml\s*$", line)
            if not m:
                i += 1
                continue

            indent = m.group(1)
            # bu job bloğunun sonunu bul
            j = i + 1
            has_secrets = False
            while j < len(lines):
                nxt = lines[j]
                if nxt.strip() == "":
                    j += 1
                    continue
                cur_ind = len(nxt) - len(nxt.lstrip())
                if cur_ind < len(indent):
                    break
                if cur_ind == len(indent) and re.match(r"^\s*secrets:", nxt):
                    has_secrets = True
                    break
                if cur_ind == len(indent) and not re.match(r"^\s*(with|secrets):", nxt):
                    break
                j += 1

            # i+1 .. j arasını kopyala
            for k in range(i + 1, j):
                out.append(lines[k])

            if not has_secrets:
                # sondaki boş satırları koru
                while out and out[-1].strip() == "":
                    out.pop()
                out.append(f"{indent}secrets: inherit")
                touched = True

            i = j

        if touched:
            if not dry:
                backup(path)
                write_text(path, "\n".join(out), nl)
            changes.append(f".github/workflows/{fn}")
            log(S_OK, GRN, f"{fn} → secrets: inherit eklendi")


# ──────────────────────────────────────────────────────────────
# 3. Project.xml
# ──────────────────────────────────────────────────────────────
CERT_RE = re.compile(r"^(\s*)(<certificate\b[^>]*?/>)\s*$")

def patch_project_xml(repo, dry):
    path = os.path.join(repo, "Project.xml")
    if not os.path.exists(path):
        warnings.append("Project.xml bulunamadı")
        return

    text, nl = read_text(path)

    if "İmzalama CI'da apksigner" in text:
        log(S_SKIP, DIM, "Project.xml zaten yamalı")
        return

    lines = text.split("\n")
    out, done = [], False
    for line in lines:
        m = CERT_RE.match(line)
        if m and not done:
            ind, tag = m.group(1), m.group(2)
            out.append(f"{ind}<!-- İmzalama CI'da apksigner ile yapılıyor.")
            out.append(f"{ind}     Bkz. .github/workflows/build.yml → 'Sign Android APK' adımı.")
            out.append(f"{ind}     Bu etiketi geri açarsan Lime, şifre boşsa CI'da")
            out.append(f"{ind}     System.console().readLine() üretir ve build sonsuza kadar takılır. -->")
            out.append(f"{ind}<!-- {tag} -->")
            done = True
            continue
        out.append(line)

    if not done:
        log(S_SKIP, DIM, "Project.xml içinde <certificate> yok (zaten kaldırılmış)")
        return

    if not dry:
        backup(path)
        write_text(path, "\n".join(out), nl)
    changes.append("Project.xml")
    log(S_OK, GRN, "Project.xml → <certificate> yorum satırına alındı")


# ──────────────────────────────────────────────────────────────
# 4. .gitignore
# ──────────────────────────────────────────────────────────────
GITIGNORE_BLOCK = """
### Android imzalama — ASLA commit etme
*.keystore
*.jks
*.p12
keystore.properties
keystore-out/
keystore.base64.txt
sha256-fingerprint.txt
SECRETS.txt

### ci-fix yamasının yedekleri
*.bak
"""

def patch_gitignore(repo, dry):
    path = os.path.join(repo, ".gitignore")
    if not os.path.exists(path):
        warnings.append(".gitignore yok")
        return

    text, nl = read_text(path)

    if "keystore-out/" in text:
        log(S_SKIP, DIM, ".gitignore zaten yamalı")
        return

    # "!key.keystore" istisnasını kaldır — asıl güvenlik açığı bu
    new = re.sub(r"^\s*!key\.keystore\s*$\n?", "", text, flags=re.M)
    removed_exception = new != text

    # Zaten var olan kuralları tekrar ekleme
    existing = {l.strip() for l in new.split("\n")}
    block_lines = []
    for l in GITIGNORE_BLOCK.strip("\n").split("\n"):
        if l.strip() == "" or l.startswith("#") or l.strip() not in existing:
            block_lines.append(l)

    if not any(l.strip() and not l.startswith("#") for l in block_lines):
        log(S_SKIP, DIM, ".gitignore kuralları zaten mevcut")
        if not removed_exception:
            return
        new_text = new
    else:
        new_text = new.rstrip("\n") + "\n\n" + "\n".join(block_lines) + "\n"

    if not dry:
        backup(path)
        write_text(path, new_text, nl)
    changes.append(".gitignore")
    log(S_OK, GRN, ".gitignore → keystore kuralları sıkılaştırıldı")
    if removed_exception:
        log(S_OK, GRN, "  '!key.keystore' istisnası kaldırıldı")


# ──────────────────────────────────────────────────────────────
# 5. key.keystore untrack
# ──────────────────────────────────────────────────────────────
def untrack_keystore(repo, dry):
    path = os.path.join(repo, "key.keystore")
    if not os.path.exists(path):
        log(S_SKIP, DIM, "key.keystore diskte yok")
        return

    try:
        tracked = subprocess.run(
            ["git", "ls-files", "--error-unmatch", "key.keystore"],
            cwd=repo, capture_output=True, text=True
        ).returncode == 0
    except FileNotFoundError:
        warnings.append("git bulunamadı, key.keystore elle untrack edilmeli")
        return

    if not tracked:
        log(S_SKIP, DIM, "key.keystore zaten takip edilmiyor")
        return

    if not dry:
        subprocess.run(["git", "rm", "--cached", "key.keystore"],
                       cwd=repo, capture_output=True)
    changes.append("key.keystore (untracked)")
    log(S_OK, GRN, "key.keystore git takibinden çıkarıldı (dosya diskte duruyor)")
    warnings.append(
        "key.keystore geçmişte kalmaya devam eder — o public upstream key "
        "olduğu için sorun değil, ama yeni keystore'unu ASLA commit etme."
    )


# ──────────────────────────────────────────────────────────────
# revert
# ──────────────────────────────────────────────────────────────
def revert(repo):
    print(f"\n{CYN}Yama geri alınıyor...{RST}\n")
    n = 0
    for root, dirs, files in os.walk(repo):
        if ".git" in dirs:
            dirs.remove(".git")
        for f in files:
            if f.endswith(".bak"):
                bak = os.path.join(root, f)
                orig = bak[:-4]
                shutil.move(bak, orig)
                log(S_BACK, YLW, os.path.relpath(orig, repo))
                n += 1

    # key.keystore'un index'teki "silindi" durumunu da geri al
    try:
        st = subprocess.run(["git", "status", "--porcelain", "--", "key.keystore"],
                            cwd=repo, capture_output=True, text=True)
        if st.returncode == 0 and st.stdout.startswith("D "):
            subprocess.run(["git", "reset", "-q", "HEAD", "--", "key.keystore"],
                           cwd=repo, capture_output=True)
            log(S_BACK, YLW, "key.keystore (git takibine geri alındı)")
            n += 1
    except FileNotFoundError:
        pass

    print(f"\n{GRN}{n} dosya geri alındı.{RST}\n")


# ──────────────────────────────────────────────────────────────
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("repo", help="Funky-Further-Engine repo kökü")
    ap.add_argument("--dry-run", action="store_true", help="Sadece göster, değiştirme")
    ap.add_argument("--revert", action="store_true", help=".bak yedeklerinden geri al")
    args = ap.parse_args()

    repo = os.path.abspath(args.repo)
    if not os.path.isdir(repo):
        print(f"{RED}HATA:{RST} klasör yok: {repo}")
        sys.exit(1)
    if not os.path.exists(os.path.join(repo, "Project.xml")):
        print(f"{RED}HATA:{RST} {repo} bir Further/Psych Engine reposu değil "
              f"(Project.xml yok)")
        sys.exit(1)

    if args.revert:
        revert(repo)
        return

    print()
    print(f"{CYN}╔════════════════════════════════════════════════════╗{RST}")
    print(f"{CYN}║   Further Engine — Keystore/CI Yaması              ║{RST}")
    print(f"{CYN}╚════════════════════════════════════════════════════╝{RST}")
    print(f"  repo: {repo}")
    if args.dry_run:
        print(f"  {YLW}[DRY RUN — hiçbir dosya değişmeyecek]{RST}")
    print()

    patch_build_yml(repo, args.dry_run)
    patch_callers(repo, args.dry_run)
    patch_project_xml(repo, args.dry_run)
    patch_gitignore(repo, args.dry_run)
    untrack_keystore(repo, args.dry_run)

    print()
    if changes:
        print(f"{GRN}{len(changes)} değişiklik:{RST}")
        for c in changes:
            print(f"    • {c}")
    else:
        print(f"{DIM}Değişiklik yok — her şey zaten yamalı.{RST}")

    if warnings:
        print(f"\n{YLW}Notlar:{RST}")
        for w in warnings:
            print(f"    ! {w}")

    if not args.dry_run and changes:
        gen = ("ci-fix\\scripts\\generate-keystore.ps1" if IS_WIN
               else "ci-fix/scripts/generate-keystore.sh")
        ver = ("ci-fix\\scripts\\verify-apk.ps1" if IS_WIN
               else "ci-fix/scripts/verify-apk.sh")
        run = ("powershell -ExecutionPolicy Bypass -File " + gen) if IS_WIN else ("./" + gen)
        runv = ("powershell -ExecutionPolicy Bypass -File " + ver) if IS_WIN else ("./" + ver)
        print(f"""
{CYN}Sıradaki adımlar:{RST}
    1. Secret'ları yükle (henüz yapmadıysan):
         {run}

    2. Değişiklikleri gözden geçir:
         cd {repo}
         git diff

    3. Commit et:
         git add -A
         git commit -m "ci: sign Android release with apksigner, fix Gradle prompt hang"
         git push

    4. Actions → "Android ARM64" → Run workflow

    5. Çıkan APK'yı doğrula:
         {runv} FurtherEngine-release.apk

  Geri almak için:
         python apply-patch.py "{repo}" --revert
""")
    print()


if __name__ == "__main__":
    main()
