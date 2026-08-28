# Further Engine — Keystore & CI İmzalama Kurulumu

Bu paket iki sorunu birden çözer:

1. **Güvenlik:** Repo şu an public upstream anahtarıyla (`psychport` / şifre `psychengine`)
   imzalıyor. Bu anahtar herkeste var — yani birisi senin uygulamanla **aynı imzaya sahip**
   sahte bir APK üretip "Further Engine güncellemesi" diye dağıtabilir. Android bunu meşru
   bir güncelleme olarak kabul eder.
2. **CI hang:** Kendi keystore'una geçmeyi denediğinde build
   `Daemon will be stopped at the end of the build` satırında sonsuza kadar takılıyordu.

---

## Neden takılıyordu?

Lime'ın Android şablonu, `Project.xml`'deki `<certificate>` etiketinde
`password` / `alias-password` **boş veya null** olduğunda `build.gradle`'a şunu üretir:

```gradle
signingConfigs {
    release {
        storeFile     file(...)
        storePassword System.console().readLine("\nKeystore password: ")
        keyAlias      System.console().readLine("\nAlias: ")
        keyPassword   System.console().readLine("\nAlias password: ")
    }
}
```

CI runner'da TTY yoktur. `System.console()` ya `null` döner ya da okuma sonsuza kadar
bloklanır. Gradle `--no-daemon` ile çalıştığı için
"Daemon will be stopped at the end of the build" mesajını **build'in en başında** basar,
sonra prompt'ta donar. Dışarıdan "derleme takıldı" gibi görünür — aslında sana şifre
soruyor ve cevap verecek kimse yok.

**Secrets'a yazınca da çalışmamasının sebebi:** `Project.xml`, GitHub Actions'ın
`${{ secrets.X }}` sözdizimini bilmez ve ortam değişkeni genişletmez.
Attribute'u sildiysen → null → prompt. `${{ secrets.X }}` yazdıysan → Lime bunu düz metin
şifre sanar → yanlış şifre hatası.

**Çözüm:** İmzalamayı Lime'dan tamamen çıkar. Gradle hiç `signingConfig` görmezse
prompt üretemez. İmzalamayı derlemeden **sonra** `apksigner` ile, şifreyi ortam
değişkeninden okuyarak yaparız.

---

## Kurulum

### Adım 1 — Keystore üret (yerelde, bir kez)

```bash
cd ci-fix/scripts
chmod +x generate-keystore.sh verify-apk.sh
./generate-keystore.sh
```

Script şunları yapar:
- 4096-bit RSA / PKCS12 keystore üretir (30 yıl geçerli)
- base64'e çevirir (GitHub Secret için)
- SHA-256 parmak izini kaydeder
- `gh` CLI varsa secret'ları otomatik yüklemeyi teklif eder

Çıktılar `ci-fix/scripts/keystore-out/` altına düşer.

> **JDK 17 gerekiyor.** Yoksa:
> Windows `winget install EclipseAdoptium.Temurin.17.JDK` ·
> macOS `brew install --cask temurin@17` ·
> Linux `sudo apt install openjdk-17-jdk`

### Adım 2 — GitHub Secrets

`gh` CLI ile otomatik yüklemediysen, elle:
**Settings → Secrets and variables → Actions → New repository secret**

| Secret adı | Değer |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `keystore-out/keystore.base64.txt` içeriğinin tamamı |
| `ANDROID_KEYSTORE_PASSWORD` | belirlediğin şifre |
| `ANDROID_KEY_ALIAS` | `furtherengine` |
| `ANDROID_KEY_PASSWORD` | aynı şifre (PKCS12'de ikisi aynı olmalı) |

### Adım 3 — Yamayı uygula

```bash
# Önce ne değişeceğini gör
python3 ci-fix/scripts/apply-patch.py /yol/Funky-Further-Engine --dry-run

# Uygula
python3 ci-fix/scripts/apply-patch.py /yol/Funky-Further-Engine
```

Yaptıkları:

| # | Dosya | Değişiklik |
|---|---|---|
| 1 | `.github/workflows/build.yml` | stdin kapatma, apksigner imzalama, adım timeout'ları, hang teşhisi |
| 2 | Çağıran 5 workflow | `secrets: inherit` eklenir (yoksa secret'lar alt workflow'a geçmez) |
| 3 | `Project.xml` | `<certificate>` yorum satırına alınır (açıklamasıyla) |
| 4 | `.gitignore` | `!key.keystore` istisnası silinir, keystore kuralları sıkılaştırılır |
| 5 | `key.keystore` | git takibinden çıkarılır (dosya diskte kalır) |

Her dosyanın `.bak` yedeği alınır. Geri almak için:

```bash
python3 ci-fix/scripts/apply-patch.py /yol/Funky-Further-Engine --revert
```

Script **idempotent**: iki kez çalıştırırsan ikincide hiçbir şey değiştirmez.

### Adım 4 — Commit & çalıştır

```bash
cd /yol/Funky-Further-Engine
git diff                     # gözden geçir
git add -A
git commit -m "ci: sign Android release with apksigner, fix Gradle prompt hang"
git push
```

GitHub → **Actions → Android ARM64 → Run workflow**

### Adım 5 — Doğrula

```bash
ci-fix/scripts/verify-apk.sh FurtherEngine-release.apk \
  "$(cat ci-fix/scripts/keystore-out/sha256-fingerprint.txt)"
```

Beklenen çıktı:
```
✓ İmza geçerli
✓ Parmak izi EŞLEŞTİ — bu APK senin keystore'unla imzalanmış.
```

---

## build.yml'de tam olarak ne değişti

### 1. `< /dev/null` — en kritik tek satır

```yaml
- name: Compile
  timeout-minutes: 75
  run: haxelib run lime build ${{ inputs.buildArgs }} < /dev/null 2>&1 | tee /tmp/build.log
```

stdin kapalı olduğu için herhangi bir prompt **anında EOF hatası** verir.
Sonsuz hang → 40 saniyede okunabilir hata. Başka hiçbir şey yapmasan bunu yap.

### 2. Gradle non-interaktif

`Configure Android` adımının sonunda `~/.gradle/gradle.properties`:
```properties
org.gradle.daemon=false
org.gradle.console=plain
org.gradle.parallel=false
org.gradle.caching=false
org.gradle.jvmargs=-Xmx4g -Dfile.encoding=UTF-8
```
Job seviyesinde ayrıca `GRADLE_OPTS`, `TERM: dumb`, `CI: "true"`.

### 3. Timeout'lar

Job `210 → 120` dakika, `Compile` adımı `75`, `Install Libraries` `30`.
Android derlemesi macos-15'te tipik olarak 45-70 dk; 75'i geçiyorsa zaten bir terslik var.

### 4. Hang teşhis adımı

Compile başarısız olursa otomatik çalışır: son 200 satır log, çalışan java process'leri,
Gradle thread dump (`jstack`). Stack'te `java.io.Console.readLine` görürsen sebep
kesinlikle şifre promptudur.

### 5. apksigner imzalama

```yaml
- name: Sign Android APK
  if: inputs.name == 'Android'
  env:
    KS_B64:        ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
    KS_PASS:       ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
    KS_ALIAS:      ${{ secrets.ANDROID_KEY_ALIAS }}
    KS_ALIAS_PASS: ${{ secrets.ANDROID_KEY_PASSWORD }}
```

Güvenlik detayları:
- `--ks-pass env:KS_PASS` → şifre komut satırında görünmez (`ps` ile okunamaz), prompt açılmaz
- Keystore `/tmp/release.keystore`'a yazılır, **workspace'e değil** → artifact'a sızamaz
- İşlem sonunda `rm -f` ile silinir
- `zipalign -p 4` → apksigner'dan önce, Android'in istediği hizalama
- `apksigner verify --print-certs` → imza log'da doğrulanır
- Secret yoksa adım **hata vermeden atlanır** → fork'lardan gelen PR'lar kırılmaz

---

## Sorun Giderme

**"Imzasiz APK bulunamadi"**
`Project.xml`'de `<certificate>` hâlâ aktif. Adım 3'ü çalıştırdığından emin ol.

**"ANDROID_KEYSTORE_BASE64 secret'i tanimli degil"**
Secret yüklenmemiş ya da çağıran workflow'da `secrets: inherit` yok.
`gh secret list --repo SametGkTe/Funky-Further-Engine` ile kontrol et.

**apksigner "Failed to load signer"**
base64 bozuk. `-w0` (Linux) veya `| tr -d '\n'` (macOS) ile satır sonu olmadan
kodlandığından emin ol. Kontrol:
```bash
gh secret list   # boyut ~3800 karakter olmalı
```

**Build hâlâ takılıyor**
Artık 75 dakikada düşer ve "Diagnose hang" adımı çalışır. Thread dump'ta:
- `java.io.Console.readLine` → hâlâ bir yerde prompt var
- `SocketInputStream.read` → ağ/bağımlılık indirme takılması
- `NativeProcess` → hxcpp derleme takılması (farklı sorun)

---

## Keystore Güvenliği — Unutma

1. `keystore-out/` klasörünü **asla** commit etme (`.gitignore`'a eklendi).
2. `further-release.keystore`'u **en az iki yerde** yedekle: şifreli USB + şifre yöneticisi.
3. **Kaybedersen** `com.sametgkte.furtherengine` paket adıyla bir daha güncelleme
   yayınlayamazsın. Kullanıcılar uygulamayı silip yeniden kurmak zorunda kalır.
4. Secret'ları yükledikten sonra `SECRETS.txt`'yi güvenli sil:
   `shred -u SECRETS.txt` (Linux) / `rm -P SECRETS.txt` (macOS)
5. SHA-256 parmak izini bir yere not et — ileride "bu APK gerçekten benden mi çıktı?"
   sorusunu cevaplamanı sağlar.

---

## Eski `key.keystore` ne olacak?

Yama onu git takibinden çıkarır ama **geçmişten silmez**. Bu sorun değil:
o zaten upstream'in herkese açık anahtarı, sızdırılacak bir sırrı yok.
Geçmişi yeniden yazmak (29 tag'ini ve release'lerini kırmak) buna değmez.

Önemli olan **bundan sonra** yeni keystore'unun asla repoya girmemesi — `.gitignore`
artık bunu garantiliyor.

---

## Dosya Listesi

```
ci-fix/
├── README_UYGULA.md              ← bu dosya
├── KEYSTORE_CI_TR.md             ← teşhisin uzun teknik anlatımı
├── build.yml                     ← yamalı workflow
├── build.yml.orig                ← senin mevcut hâlin (referans)
├── workflows-orig/               ← 7 workflow'un orijinal yedeği
└── scripts/
    ├── generate-keystore.sh      ← Adım 1
    ├── apply-patch.py            ← Adım 3
    └── verify-apk.sh             ← Adım 5
```
