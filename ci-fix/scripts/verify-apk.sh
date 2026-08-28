#!/usr/bin/env bash
#
# Further Engine — APK İmza Doğrulayıcı
#
# İndirdiğin bir APK'nın gerçekten senin keystore'unla imzalanıp
# imzalanmadığını kontrol eder.
#
# Kullanım:
#   ./verify-apk.sh FurtherEngine-release.apk
#   ./verify-apk.sh FurtherEngine-release.apk <beklenen-sha256-parmak-izi>
#
set -euo pipefail

RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YLW=$'\033[1;33m'; CYN=$'\033[0;36m'; RST=$'\033[0m'

APK="${1:-}"
EXPECTED="${2:-}"

if [ -z "$APK" ]; then
  echo "Kullanım: $0 <apk-dosyasi> [beklenen-sha256]"
  exit 1
fi
if [ ! -f "$APK" ]; then
  echo "${RED}HATA:${RST} $APK bulunamadı."
  exit 1
fi

# apksigner'ı bul
APKSIGNER=""
if command -v apksigner >/dev/null 2>&1; then
  APKSIGNER="apksigner"
elif [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/build-tools" ]; then
  APKSIGNER=$(ls -d "$ANDROID_HOME"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -n1 || true)
fi

if [ -z "$APKSIGNER" ]; then
  echo "${YLW}apksigner bulunamadı${RST} — keytool ile sınırlı kontrol yapılıyor."
  echo
  unzip -p "$APK" META-INF/*.RSA 2>/dev/null | keytool -printcert || {
    echo "${RED}İmza bulunamadı — APK imzasız olabilir.${RST}"; exit 2;
  }
  exit 0
fi

echo "${CYN}→ İmza doğrulanıyor: $APK${RST}"
echo

if ! "$APKSIGNER" verify --verbose --print-certs "$APK"; then
  echo
  echo "${RED}✗ DOĞRULAMA BAŞARISIZ${RST} — APK imzasız veya imza bozuk."
  exit 2
fi

ACTUAL=$("$APKSIGNER" verify --print-certs "$APK" 2>/dev/null \
  | grep -i "SHA-256 digest" | head -1 | awk '{print $NF}' | tr 'a-f' 'A-F')

echo
echo "${GRN}✓ İmza geçerli${RST}"
echo "  SHA-256: $ACTUAL"

if [ -n "$EXPECTED" ]; then
  NORM_EXP=$(echo "$EXPECTED" | tr -d ': ' | tr 'a-f' 'A-F')
  NORM_ACT=$(echo "$ACTUAL"   | tr -d ': ' | tr 'a-f' 'A-F')
  echo
  if [ "$NORM_EXP" = "$NORM_ACT" ]; then
    echo "${GRN}✓ Parmak izi EŞLEŞTİ${RST} — bu APK senin keystore'unla imzalanmış."
  else
    echo "${RED}✗ Parmak izi EŞLEŞMEDİ!${RST}"
    echo "  beklenen: $NORM_EXP"
    echo "  bulunan : $NORM_ACT"
    echo "${RED}Bu APK BAŞKA bir anahtarla imzalanmış. Dağıtma.${RST}"
    exit 3
  fi
fi

# Public upstream key kontrolü
if "$APKSIGNER" verify --print-certs "$APK" 2>/dev/null | grep -qi "psychport\|psychengine"; then
  echo
  echo "${RED}⚠ UYARI:${RST} Bu APK hâlâ public upstream 'psychport' anahtarıyla imzalı görünüyor."
  echo "Project.xml'deki <certificate> satırı kaldırılmamış olabilir."
fi
