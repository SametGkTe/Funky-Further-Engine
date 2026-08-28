#!/usr/bin/env bash
#
# Further Engine — Release Keystore Oluşturucu
#
# Bu script'i YEREL makinende BİR KEZ çalıştır. Sunucuda/CI'da ASLA çalıştırma.
# Ürettiği keystore dosyası projenin ömrü boyunca kullanılacak tek imza kimliğidir.
#
# Kullanım:
#   chmod +x generate-keystore.sh
#   ./generate-keystore.sh
#
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Ayarlar — istersen değiştir
# ─────────────────────────────────────────────────────────────
KEYSTORE_FILE="further-release.keystore"
KEY_ALIAS="furtherengine"
VALIDITY_DAYS=10950          # 30 yıl
KEY_SIZE=4096
KEY_ALG="RSA"
STORE_TYPE="PKCS12"          # JKS değil — PKCS12 modern standart

# Sertifika sahibi bilgileri (istersen düzenle)
CN="Further Engine"
OU="Further Engine"
O="SametGkTe"
L="Ankara"
ST="Ankara"
C="TR"

OUT_DIR="keystore-out"

# ─────────────────────────────────────────────────────────────

RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YLW=$'\033[1;33m'; CYN=$'\033[0;36m'; RST=$'\033[0m'

echo
echo "${CYN}╔════════════════════════════════════════════════════╗${RST}"
echo "${CYN}║   Further Engine — Release Keystore Oluşturucu     ║${RST}"
echo "${CYN}╚════════════════════════════════════════════════════╝${RST}"
echo

# --- keytool var mı? ---
if ! command -v keytool >/dev/null 2>&1; then
  echo "${RED}HATA:${RST} 'keytool' bulunamadı. JDK 17 kur:"
  echo "  Windows : winget install EclipseAdoptium.Temurin.17.JDK"
  echo "  macOS   : brew install --cask temurin@17"
  echo "  Linux   : sudo apt install openjdk-17-jdk"
  exit 1
fi

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

if [ -f "$KEYSTORE_FILE" ]; then
  echo "${RED}HATA:${RST} $OUT_DIR/$KEYSTORE_FILE zaten var."
  echo "Üzerine yazmak imza kimliğini DEĞİŞTİRİR ve mevcut kurulumların"
  echo "güncellenmesini imkânsız kılar. Önce mevcut dosyayı yedekle ve elle sil."
  exit 1
fi

# --- Şifreyi al ---
echo "Keystore şifresi belirle (en az 12 karakter önerilir)."
echo "${YLW}Bu şifreyi kaybedersen keystore kullanılamaz hâle gelir.${RST}"
echo
read -r -s -p "Şifre: " KS_PASS; echo
read -r -s -p "Şifre (tekrar): " KS_PASS2; echo
echo

if [ "$KS_PASS" != "$KS_PASS2" ]; then
  echo "${RED}HATA:${RST} Şifreler uyuşmuyor."
  exit 1
fi
if [ ${#KS_PASS} -lt 6 ]; then
  echo "${RED}HATA:${RST} keytool en az 6 karakter ister."
  exit 1
fi
if [ ${#KS_PASS} -lt 12 ]; then
  echo "${YLW}UYARI:${RST} 12 karakterden kısa. Yine de devam ediliyor."
fi

# PKCS12'de store ve key şifresi aynı olmak zorunda.
KEY_PASS="$KS_PASS"

# --- Üret ---
echo "${CYN}→ Keystore üretiliyor...${RST}"
keytool -genkeypair \
  -keystore "$KEYSTORE_FILE" \
  -storetype "$STORE_TYPE" \
  -storepass "$KS_PASS" \
  -keypass "$KEY_PASS" \
  -alias "$KEY_ALIAS" \
  -keyalg "$KEY_ALG" \
  -keysize "$KEY_SIZE" \
  -validity "$VALIDITY_DAYS" \
  -dname "CN=$CN, OU=$OU, O=$O, L=$L, ST=$ST, C=$C" \
  -noprompt

echo "${GRN}✓${RST} $OUT_DIR/$KEYSTORE_FILE üretildi"

# --- base64 (platform farkı) ---
echo "${CYN}→ base64 kodlanıyor...${RST}"
if base64 --help 2>&1 | grep -q -- "-w"; then
  base64 -w0 "$KEYSTORE_FILE" > keystore.base64.txt      # GNU/Linux
else
  base64 -i "$KEYSTORE_FILE" | tr -d '\n' > keystore.base64.txt  # macOS/BSD
fi
echo "${GRN}✓${RST} $OUT_DIR/keystore.base64.txt üretildi ($(wc -c < keystore.base64.txt) karakter)"

# --- Parmak izi ---
echo
echo "${CYN}→ Sertifika parmak izi:${RST}"
keytool -list -v -keystore "$KEYSTORE_FILE" -storepass "$KS_PASS" -alias "$KEY_ALIAS" \
  | grep -E "SHA256:|SHA1:|Valid from|Alias name" || true

keytool -list -v -keystore "$KEYSTORE_FILE" -storepass "$KS_PASS" -alias "$KEY_ALIAS" \
  | grep -E "SHA256:" | head -1 | sed 's/.*SHA256: //' > sha256-fingerprint.txt
echo "${GRN}✓${RST} $OUT_DIR/sha256-fingerprint.txt kaydedildi"

# --- Secret değerlerini dosyaya yaz ---
cat > SECRETS.txt <<EOF
GitHub → Settings → Secrets and variables → Actions → New repository secret

ANDROID_KEYSTORE_BASE64
  → keystore.base64.txt dosyasının TAM içeriği

ANDROID_KEYSTORE_PASSWORD
  → $KS_PASS

ANDROID_KEY_ALIAS
  → $KEY_ALIAS

ANDROID_KEY_PASSWORD
  → $KEY_PASS

SHA-256 parmak izi (doğrulama için sakla):
  $(cat sha256-fingerprint.txt)
EOF
chmod 600 SECRETS.txt
echo "${GRN}✓${RST} $OUT_DIR/SECRETS.txt yazıldı (şifre içerir, chmod 600)"

# --- gh CLI ile otomatik yükleme teklifi ---
echo
if command -v gh >/dev/null 2>&1; then
  echo "${CYN}GitHub CLI bulundu.${RST} Secret'ları otomatik yükleyeyim mi?"
  read -r -p "Repo (örn: SametGkTe/Funky-Further-Engine), boş bırak = atla: " REPO
  if [ -n "$REPO" ]; then
    gh secret set ANDROID_KEYSTORE_BASE64   --repo "$REPO" < keystore.base64.txt
    printf '%s' "$KS_PASS"   | gh secret set ANDROID_KEYSTORE_PASSWORD --repo "$REPO"
    printf '%s' "$KEY_ALIAS" | gh secret set ANDROID_KEY_ALIAS         --repo "$REPO"
    printf '%s' "$KEY_PASS"  | gh secret set ANDROID_KEY_PASSWORD      --repo "$REPO"
    echo "${GRN}✓${RST} 4 secret yüklendi. Kontrol:"
    gh secret list --repo "$REPO"
  fi
else
  echo "${YLW}gh CLI yok${RST} — secret'ları elle gireceksin. Bkz. $OUT_DIR/SECRETS.txt"
  echo "Kurmak istersen: https://cli.github.com/"
fi

# --- Kapanış ---
echo
echo "${RED}╔════════════════════════════════════════════════════╗${RST}"
echo "${RED}║                     ÖNEMLİ                          ║${RST}"
echo "${RED}╚════════════════════════════════════════════════════╝${RST}"
cat <<EOF

  1. $OUT_DIR/ klasörünü ASLA git'e commit etme.
     (.gitignore'a eklendiğinden emin ol)

  2. $KEYSTORE_FILE dosyasını en az iki ayrı yerde yedekle:
     - şifreli USB / harici disk
     - şifre yöneticisi (Bitwarden, 1Password) eki olarak

  3. Bu dosyayı kaybedersen com.sametgkte.furtherengine paket adıyla
     BİR DAHA güncelleme yayınlayamazsın. Kullanıcılar uygulamayı
     silip yeniden kurmak zorunda kalır. Yedeği ciddiye al.

  4. Secret'ları yükledikten sonra SECRETS.txt'yi güvenli sil:
       shred -u $OUT_DIR/SECRETS.txt     # Linux
       rm -P  $OUT_DIR/SECRETS.txt       # macOS

EOF
echo "${GRN}Tamamdır.${RST} Sıradaki adım: ci-fix/README_UYGULA.md → Adım 3"
echo
