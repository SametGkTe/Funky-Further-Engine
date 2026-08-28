#!/usr/bin/env python3
"""
Further Engine — Colyseus (Further Online) bagimliligini setup'a ekler.

SORUN
    Project.xml FURTHER_ONLINE define'i acikken 'colyseus' ve
    'colyseus-websocket' haxelib'lerini ister, ama setup script'leri
    bunlari kurmuyor. CI hatasi:
        Could not find haxelib "colyseus", does it need to be installed?

SURUM ESLESMESI (onemli)
    further-server/package.json  -> colyseus ^0.15.17, @colyseus/schema ^2.0.35
    Haxe istemcisinin son 0.15  -> colyseus 0.15.4  (bagimlilik: colyseus-websocket 1.0.12)

    haxelib varsayilan olarak EN YENI surumu (0.18.x) kurar. 0.16+ istemcileri
    0.15 sunucusuyla protokol seviyesinde UYUMSUZDUR: derleme gecse bile
    baglanti/schema decode calismaz. Bu yuzden her yerde surum pinliyoruz.

KULLANIM
    python add-colyseus.py <repo>              # colyseus'u ekle
    python add-colyseus.py <repo> --dry-run
    python add-colyseus.py <repo> --disable-online   # alternatif: online'i kapat
    python add-colyseus.py <repo> --revert
"""

import argparse
import os
import re
import shutil
import sys

IS_WIN = os.name == "nt"

COLYSEUS_VER = "0.15.4"
CWS_VER = "1.0.12"

# tink_io 0.9.0'in surum notu: "tink_core v2 compatibilities" -> v2 BEKLIYOR.
# Ama haxelib transitif cozumde tink_core 1.26.0 (6 yillik) kuruyor.
# 1.26.0 hem tink_io 0.9.0 ile hem de Haxe 4.3 ile uyumsuz:
#   tink/core/Promise.hx: "Recursive implicit cast"
# tink_core 2.1.1 surum notu: "Improve Lazy for Haxe 4.3" -> dogru surum.
TINK_CORE_VER = "2.1.1"


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


_COLOR = _init_console() and os.environ.get("NO_COLOR") is None
if _COLOR:
    GRN = "\033[0;32m"; RED = "\033[0;31m"; YLW = "\033[1;33m"
    CYN = "\033[0;36m"; DIM = "\033[2m"; RST = "\033[0m"
    S_OK, S_SKIP, S_BACK = "✓", "=", "↩"
else:
    GRN = RED = YLW = CYN = DIM = RST = ""
    S_OK, S_SKIP, S_BACK = "[OK]", "[--]", "[<-]"

changes = []
notes = []


def log(sym, color, msg):
    print(f"  {color}{sym}{RST} {msg}")


# ── CRLF koruyan G/C ────────────────────────────────────────
def read_text(path):
    with open(path, "rb") as f:
        raw = f.read()
    text = raw.decode("utf-8-sig")
    crlf = text.count("\r\n")
    lf = text.count("\n") - crlf
    return text.replace("\r\n", "\n"), ("\r\n" if crlf > lf else "\n")


def write_text(path, text, nl):
    data = text.replace("\n", nl) if nl != "\n" else text
    with open(path, "wb") as f:
        f.write(data.encode("utf-8"))


def backup(path):
    bak = path + ".colyseus.bak"
    if not os.path.exists(bak):
        shutil.copy2(path, bak)


# ── 1. setup/unix.sh ────────────────────────────────────────
UNIX_BLOCK = f"""
# Further Online (Colyseus)
# Surum, further-server/package.json (colyseus ^0.15.17) ile eslesmeli.
# 0.16+ istemcileri 0.15 sunucusuyla UYUMSUZ - pinli birakin.
haxelib install colyseus {COLYSEUS_VER} --quiet
haxelib install colyseus-websocket {CWS_VER} --quiet
# tink_core: haxelib transitif cozumde 1.26.0 kuruyor ama tink_io 0.9.0
# v2 bekliyor ve 1.26.0 Haxe 4.3 ile "Recursive implicit cast" veriyor.
haxelib install tink_core {TINK_CORE_VER} --quiet
"""

WIN_BLOCK = f"""
REM Further Online (Colyseus)
REM Surum, further-server/package.json (colyseus ^0.15.17) ile eslesmeli.
REM 0.16+ istemcileri 0.15 sunucusuyla UYUMSUZ - pinli birakin.
haxelib install colyseus {COLYSEUS_VER} --quiet
haxelib install colyseus-websocket {CWS_VER} --quiet
REM tink_core: haxelib 1.26.0 kuruyor ama tink_io 0.9.0 v2 bekliyor,
REM ayrica 1.26.0 Haxe 4.3 ile "Recursive implicit cast" veriyor.
haxelib install tink_core {TINK_CORE_VER} --quiet
"""

UNIX_FORCE = f"""haxelib set colyseus {COLYSEUS_VER}
haxelib set colyseus-websocket {CWS_VER}
haxelib set tink_core {TINK_CORE_VER}
"""


def patch_unix(repo, dry):
    path = os.path.join(repo, "setup", "unix.sh")
    if not os.path.exists(path):
        notes.append("setup/unix.sh bulunamadi")
        return
    text, nl = read_text(path)

    if "haxelib install colyseus" in text:
        log(S_SKIP, DIM, "setup/unix.sh zaten colyseus iceriyor")
        return

    marker = "echo Forcing correct library versions..."
    if marker in text:
        text = text.replace(marker, UNIX_BLOCK.lstrip("\n") + "\n" + marker, 1)
    else:
        # fallback: 'echo Finished!' oncesi
        text = text.replace("echo Finished!", UNIX_BLOCK.lstrip("\n") + "\necho Finished!", 1)

    # force-set bolumune ekle
    anchor = "haxelib set HtmlParser 3.4.0"
    if anchor in text and "haxelib set colyseus" not in text:
        text = text.replace(anchor, anchor + "\n" + UNIX_FORCE.rstrip("\n"), 1)

    if not dry:
        backup(path)
        write_text(path, text, nl)
    changes.append("setup/unix.sh")
    log(S_OK, GRN, f"setup/unix.sh -> colyseus {COLYSEUS_VER} + colyseus-websocket {CWS_VER}")


def patch_windows_bat(repo, dry):
    path = os.path.join(repo, "setup", "windows.bat")
    if not os.path.exists(path):
        notes.append("setup/windows.bat bulunamadi")
        return
    text, nl = read_text(path)

    if "haxelib install colyseus" in text:
        log(S_SKIP, DIM, "setup/windows.bat zaten colyseus iceriyor")
        return

    if "echo Finished!" in text:
        text = text.replace("echo Finished!", WIN_BLOCK.lstrip("\n") + "\necho Finished!", 1)
    else:
        text = text.rstrip("\n") + "\n" + WIN_BLOCK

    if not dry:
        backup(path)
        write_text(path, text, nl)
    changes.append("setup/windows.bat")
    log(S_OK, GRN, f"setup/windows.bat -> colyseus {COLYSEUS_VER} + colyseus-websocket {CWS_VER}")


# ── 2. Project.xml surum pinleme ────────────────────────────
def patch_project_xml(repo, dry):
    path = os.path.join(repo, "Project.xml")
    if not os.path.exists(path):
        notes.append("Project.xml bulunamadi")
        return
    text, nl = read_text(path)

    if f'name="colyseus" version="{COLYSEUS_VER}"' in text:
        log(S_SKIP, DIM, "Project.xml surumleri zaten pinli")
        return

    new = text
    new = re.sub(
        r'<haxelib\s+name="colyseus"(?!\-)((?:(?!version=)[^>])*?)/>',
        f'<haxelib name="colyseus" version="{COLYSEUS_VER}"\\1/>',
        new, count=1)
    new = re.sub(
        r'<haxelib\s+name="colyseus-websocket"((?:(?!version=)[^>])*?)/>',
        f'<haxelib name="colyseus-websocket" version="{CWS_VER}"\\1/>',
        new, count=1)

    if new == text:
        log(S_SKIP, DIM, "Project.xml'de colyseus haxelib satiri bulunamadi")
        return

    if not dry:
        backup(path)
        write_text(path, new, nl)
    changes.append("Project.xml")
    log(S_OK, GRN, f"Project.xml -> surumler pinlendi ({COLYSEUS_VER} / {CWS_VER})")


# ── 3. build.yml force-set ──────────────────────────────────
def patch_build_yml(repo, dry):
    path = os.path.join(repo, ".github", "workflows", "build.yml")
    if not os.path.exists(path):
        notes.append(".github/workflows/build.yml bulunamadi")
        return
    text, nl = read_text(path)

    if "haxelib set colyseus" in text:
        log(S_SKIP, DIM, "build.yml zaten colyseus surumunu sabitliyor")
        return

    anchor = "          haxelib set HtmlParser 3.4.0"
    if anchor not in text:
        notes.append("build.yml icinde 'Force correct haxelib versions' adimi bulunamadi")
        return

    add = (f"{anchor}\n"
           f"          haxelib set colyseus {COLYSEUS_VER}\n"
           f"          haxelib set colyseus-websocket {CWS_VER}\n"
           f"          haxelib install tink_core {TINK_CORE_VER} --quiet --always\n"
           f"          haxelib set tink_core {TINK_CORE_VER}")
    text = text.replace(anchor, add, 1)

    if not dry:
        backup(path)
        write_text(path, text, nl)
    changes.append(".github/workflows/build.yml")
    log(S_OK, GRN, "build.yml -> colyseus surumu CI'da da sabitlendi")


# ── Alternatif: online'i kapat ──────────────────────────────
def disable_online(repo, dry):
    path = os.path.join(repo, "Project.xml")
    if not os.path.exists(path):
        print(f"{RED}HATA:{RST} Project.xml yok")
        return
    text, nl = read_text(path)

    if "<!-- <define name=\"FURTHER_ONLINE\"" in text:
        log(S_SKIP, DIM, "FURTHER_ONLINE zaten kapali")
        return

    m = re.search(r'^(\s*)<define name="FURTHER_ONLINE"\s*/>\s*$', text, flags=re.M)
    if not m:
        print(f"{RED}HATA:{RST} FURTHER_ONLINE define'i bulunamadi")
        return

    ind = m.group(1)
    repl = (f'{ind}<!-- Further Online gecici olarak kapali (colyseus haxelib gerektirir).\n'
            f'{ind}     Acmak icin: python add-colyseus.py . ile bagimliliklari kur,\n'
            f'{ind}     sonra asagidaki satirin yorumunu kaldir. -->\n'
            f'{ind}<!-- <define name="FURTHER_ONLINE" /> -->')
    text = text[:m.start()] + repl + text[m.end():]

    if not dry:
        backup(path)
        write_text(path, text, nl)
    changes.append("Project.xml (FURTHER_ONLINE kapatildi)")
    log(S_OK, GRN, "Project.xml -> FURTHER_ONLINE kapatildi")
    notes.append("source/online/ kodu derlenmeyecek; oyun online menusuz derlenir.")


# ── revert ──────────────────────────────────────────────────
def revert(repo):
    print(f"\n{CYN}Colyseus yamasi geri aliniyor...{RST}\n")
    n = 0
    for root, dirs, files in os.walk(repo):
        if ".git" in dirs:
            dirs.remove(".git")
        for f in files:
            if f.endswith(".colyseus.bak"):
                bak = os.path.join(root, f)
                orig = bak[: -len(".colyseus.bak")]
                shutil.move(bak, orig)
                log(S_BACK, YLW, os.path.relpath(orig, repo))
                n += 1
    print(f"\n{GRN}{n} dosya geri alindi.{RST}\n")


# ── tink_core pini (colyseus zaten eklenmisse de calisir) ───
def patch_tink(repo, dry):
    """
    Colyseus yamasi daha once uygulandiysa tink_core pini eksik kalir.
    Bu fonksiyon uc dosyada da tink_core pinini bagimsiz olarak tamamlar.
    """
    # 1) setup/unix.sh
    p = os.path.join(repo, "setup", "unix.sh")
    if os.path.exists(p):
        text, nl = read_text(p)
        if "tink_core" in text:
            log(S_SKIP, DIM, "setup/unix.sh tink_core pini zaten var")
        else:
            ins = (f"# tink_core: haxelib 1.26.0 kuruyor ama tink_io 0.9.0 v2 bekliyor,\n"
                   f"# ayrica 1.26.0 Haxe 4.3 ile \"Recursive implicit cast\" veriyor.\n"
                   f"haxelib install tink_core {TINK_CORE_VER} --quiet\n")
            m = "echo Forcing correct library versions..."
            if m in text:
                text = text.replace(m, ins + "\n" + m, 1)
            else:
                text = text.replace("echo Finished!", ins + "\necho Finished!", 1)

            for anch in (f"haxelib set colyseus-websocket {CWS_VER}",
                         "haxelib set HtmlParser 3.4.0"):
                if anch in text:
                    text = text.replace(anch, anch + f"\nhaxelib set tink_core {TINK_CORE_VER}", 1)
                    break
            if not dry:
                backup(p); write_text(p, text, nl)
            changes.append("setup/unix.sh (tink_core)")
            log(S_OK, GRN, f"setup/unix.sh -> tink_core {TINK_CORE_VER} pinlendi")

    # 2) setup/windows.bat
    p = os.path.join(repo, "setup", "windows.bat")
    if os.path.exists(p):
        text, nl = read_text(p)
        if "tink_core" in text:
            log(S_SKIP, DIM, "setup/windows.bat tink_core pini zaten var")
        else:
            ins = (f"REM tink_core: haxelib 1.26.0 kuruyor ama tink_io 0.9.0 v2 bekliyor,\n"
                   f"REM ayrica 1.26.0 Haxe 4.3 ile \"Recursive implicit cast\" veriyor.\n"
                   f"haxelib install tink_core {TINK_CORE_VER} --quiet\n")
            if "echo Finished!" in text:
                text = text.replace("echo Finished!", ins + "\necho Finished!", 1)
            else:
                text = text.rstrip("\n") + "\n" + ins
            if not dry:
                backup(p); write_text(p, text, nl)
            changes.append("setup/windows.bat (tink_core)")
            log(S_OK, GRN, f"setup/windows.bat -> tink_core {TINK_CORE_VER} pinlendi")

    # 3) .github/workflows/build.yml
    p = os.path.join(repo, ".github", "workflows", "build.yml")
    if os.path.exists(p):
        text, nl = read_text(p)
        if "haxelib set tink_core" in text:
            log(S_SKIP, DIM, "build.yml tink_core pini zaten var")
        else:
            add = (f"          haxelib install tink_core {TINK_CORE_VER} --quiet --always\n"
                   f"          haxelib set tink_core {TINK_CORE_VER}")
            done = False
            for anch in (f"          haxelib set colyseus-websocket {CWS_VER}",
                         "          haxelib set HtmlParser 3.4.0"):
                if anch in text:
                    text = text.replace(anch, anch + "\n" + add, 1)
                    done = True
                    break
            if not done:
                notes.append("build.yml icinde force-set adimi bulunamadi, tink_core eklenemedi")
            else:
                if not dry:
                    backup(p); write_text(p, text, nl)
                changes.append(".github/workflows/build.yml (tink_core)")
                log(S_OK, GRN, f"build.yml -> tink_core {TINK_CORE_VER} pinlendi")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("repo")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--revert", action="store_true")
    ap.add_argument("--disable-online", action="store_true",
                    help="Colyseus kurmak yerine FURTHER_ONLINE define'ini kapat")
    a = ap.parse_args()

    repo = os.path.abspath(a.repo)
    if not os.path.exists(os.path.join(repo, "Project.xml")):
        print(f"{RED}HATA:{RST} {repo} bir Further Engine reposu degil (Project.xml yok)")
        sys.exit(1)

    if a.revert:
        revert(repo)
        return

    print()
    print(f"{CYN}+====================================================+{RST}")
    if a.disable_online:
        print(f"{CYN}|   Further Engine - Online'i Kapat                  |{RST}")
    else:
        print(f"{CYN}|   Further Engine - Colyseus Bagimliligi            |{RST}")
    print(f"{CYN}+====================================================+{RST}")
    print(f"  repo: {repo}")
    if a.dry_run:
        print(f"  {YLW}[DRY RUN - hicbir dosya degismeyecek]{RST}")
    print()

    if a.disable_online:
        disable_online(repo, a.dry_run)
    else:
        patch_unix(repo, a.dry_run)
        patch_windows_bat(repo, a.dry_run)
        patch_project_xml(repo, a.dry_run)
        patch_build_yml(repo, a.dry_run)
        patch_tink(repo, a.dry_run)

    print()
    if changes:
        print(f"{GRN}{len(changes)} degisiklik:{RST}")
        for c in changes:
            print(f"    - {c}")
    else:
        print(f"{DIM}Degisiklik yok.{RST}")

    if notes:
        print(f"\n{YLW}Notlar:{RST}")
        for x in notes:
            print(f"    ! {x}")

    if changes and not a.dry_run:
        if a.disable_online:
            print(f"""
{CYN}Siradaki adim:{RST}
    git add -A
    git commit -m "build: temporarily disable Further Online"
    git push
""")
        else:
            print(f"""
{CYN}Siradaki adimlar:{RST}
    1. Yerelde kutuphaneleri kur (istege bagli, CI zaten kuracak):
         setup\\windows.bat        (Windows)
         sh ./setup/unix.sh       (Linux/macOS)

    2. Commit:
         git add -A
         git commit -m "build: add pinned Colyseus deps for Further Online"
         git push

    3. Actions -> Android ARM64 -> Run workflow

  Geri almak icin:
         python add-colyseus.py "{repo}" --revert
""")
    print()


if __name__ == "__main__":
    main()
