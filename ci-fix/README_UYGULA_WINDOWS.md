# Further Engine — Keystore & CI İmzalama Kurulumu (Windows)

Bu paket iki sorunu birden çözer:

1. **Güvenlik:** Repo şu an public upstream anahtarıyla (`psychport` / şifre `psychengine`)
   imzalıyor. Bu anahtar herkeste var — birisi seninkiyle **aynı imzaya sahip** sahte bir
   APK üretip "Further Engine güncellemesi" diye dağıtabilir; Android bunu meşru bir
   güncelleme sanar.
2. **CI hang:** Kendi keystore'una geçmeyi denediğinde build
   `Daemon will be stopped at the end of the build` satırında sonsuza kadar takılıyordu.

**Gereksinimler:** Python 3 ✔ · JDK (keytool) ✔ · Git ✔ — hepsi sende var.

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
bloklanır. Gradle `--no-daemon` ile çalıştığı için "Daemon will be stopped at the end of
the build" mesajını **build'in en başında** basar, sonra prompt'ta donar. Dışarıdan
"derleme takıldı" görünür — aslında sana şifre soruyor, cevap verecek kimse yok.

**Secrets'a yazınca da olmamasının sebebi:** `Project.xml`, GitHub Actions'ın
`${{ secrets.X }}` sözdizimini bilmez, ortam değişkeni de genişletmez.
Attribute'u sildiysen → null → prompt. `${{ secrets.X }}` yazdıysan → Lime bunu düz metin
şifre sanar.

**Çözüm:** İmzalamayı Lime'dan tamamen çıkar. Gradle hiç `signingConfig` görmezse prompt
üretemez. İmzalamayı derlemeden **sonra**, `apksigner` ile, şifreyi ortam değişkeninden
okuyarak yaparız.

---

## Kurulum

Aşağıdaki komutları **PowerShell**'de çalıştır (cmd değil).
Repo yolunu kendi yoluna göre değiştir — örneklerde `C:\Projeler\Funky-Further-Engine`.

### Adım 1 — Keystore üret (bir kez)

```powershell
cd C:\Projeler\Funky-Further-Engine\ci-fix\scripts
powershell -ExecutionPolicy Bypass -File .\generate-keystore.ps1
```

Script şunları yapar:
- `keytool`'u otomatik bulur (PATH → `JAVA_HOME` → Android Studio'nun gömülü JDK'sı →
  Program Files altındaki Temurin/Oracle/Corretto kurulumları)
- 4096-bit RSA / PKCS12 keystore üretir (30 yıl geçerli)
- tek satır base64'e çevirir (GitHub Secret için şart)
- SHA-256 parmak izini kaydeder
- `gh` CLI varsa 4 secret'ı otomatik yüklemeyi teklif eder

Şifreyi sorarken ekranda **hiçbir şey görünmez** — bu normaldir, yazıp Enter'a bas.

Çıktılar: `ci-fix\scripts\keystore-out\`

> **"keytool bulunamadi" derse:**
> `winget install EclipseAdoptium.Temurin.17.JDK`
> Kurulumdan sonra **yeni bir PowerShell penceresi** aç (PATH güncellenmesi için).

> **"betik çalıştırma devre dışı" hatası alırsan:** yukarıdaki `-ExecutionPolicy Bypass`
> zaten bunu aşar. Yine de olmuyorsa bir kereliğine:
> `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`

### Adım 2 — GitHub Secrets

Keystore üretimi sırasında repo adını atladıysan ya da yükleme başarısız olduysa,
**keystore'u yeniden üretmeden** sadece secret'ları yüklemek için:

```powershell
cd C:\...\Funky-Further-Engine\ci-fix\scripts
powershell -ExecutionPolicy Bypass -File .\upload-secrets.ps1
```

Bu script:
- `git remote`'tan repo adını tahmin edip onaylatır
- format yanlışsa (komut yapıştırma gibi) **reddedip tekrar sorar**
- repoya gerçekten erişilebiliyor mu diye kontrol eder
- şifreyi **keystore'a karşı doğrular** — yanlış şifreyi yüklemeden önce durur
- 4 secret'ı yükler ve **her birinin gerçekten başarılı olduğunu** teyit eder

Elle girmek istersen: **Settings → Secrets and variables → Actions → New repository secret**

| Secret adı | Değer |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `keystore-out\keystore.base64.txt` içeriğinin tamamı |
| `ANDROID_KEYSTORE_PASSWORD` | belirlediğin şifre |
| `ANDROID_KEY_ALIAS` | `furtherengine` |
| `ANDROID_KEY_PASSWORD` | aynı şifre (PKCS12'de ikisi aynı olmak zorunda) |

base64'ü panoya kopyalamanın kolay yolu:

```powershell
Get-Content .\keystore-out\keystore.base64.txt -Raw | Set-Clipboard
```

> ⚠️ Not Defteri ile açıp kopyalama — dosya sonuna satır sonu ekleyip base64'ü bozabilir.
> ⚠️ Bu komutu script'in "Repo:" sorusuna **yapıştırma** — orası sadece `OWNER/REPO` bekler.

### Adım 3 — Yamayı uygula

```powershell
cd C:\Projeler\Funky-Further-Engine

# Önce ne değişeceğini gör (hiçbir şeye dokunmaz)
python ci-fix\scripts\apply-patch.py . --dry-run

# Uygula
python ci-fix\scripts\apply-patch.py .
```

Yaptıkları:

| # | Dosya | Değişiklik |
|---|---|---|
| 1 | `.github\workflows\build.yml` | stdin kapatma, apksigner imzalama, adım timeout'ları, hang teşhisi |
| 2 | Çağıran 5 workflow | `secrets: inherit` eklenir |
| 3 | `Project.xml` | `<certificate>` yorum satırına alınır (açıklamasıyla) |
| 4 | `.gitignore` | `!key.keystore` istisnası silinir, keystore kuralları eklenir |
| 5 | `key.keystore` | git takibinden çıkarılır (dosya diskte kalır) |

**Windows'a özel iki koruma var:**
- **Satır sonları korunur.** Repon CRLF ise CRLF kalır. (Python varsayılan davranışıyla
  yazsaydı LF→CRLF çevirir ve `git diff`'te dosyaların **tamamı** değişmiş görünürdü.)
- Konsol UTF-8'e alınır, ANSI renk desteklenmiyorsa `[OK]` / `[--]` düz metne düşer.

Geri almak için:

```powershell
python ci-fix\scripts\apply-patch.py . --revert
```

Script **idempotent** — iki kez çalıştırırsan ikincide hiçbir şeye dokunmaz.

### Adım 4 — Commit & çalıştır

```powershell
git diff
git add -A
git commit -m "ci: sign Android release with apksigner, fix Gradle prompt hang"
git push
```

GitHub → **Actions → Android ARM64 → Run workflow**

### Adım 5 — Doğrula

Artifact'i indirip aç, sonra:

```powershell
cd C:\Projeler\Funky-Further-Engine\ci-fix\scripts
$sha = Get-Content .\keystore-out\sha256-fingerprint.txt
powershell -ExecutionPolicy Bypass -File .\verify-apk.ps1 C:\indirilenler\FurtherEngine-release.apk $sha
```

Beklenen:
```
  [OK] Imza gecerli
  [OK] Parmak izi ESLESTI - bu APK senin keystore'unla imzalanmis.
```

Android SDK build-tools kurulu değilse script `keytool`'a düşer ve yine parmak izini
karşılaştırır (sadece imzanın içerikle eşleşmesini doğrulayamaz).

---

## Bu paket gerçekten test edildi

Uydurma değil, çalıştırıldı:

| Test | Sonuç |
|---|---|
| Her iki `.ps1` PowerShell 7.4.6 parser'ından geçti | ✔ |
| `generate-keystore.ps1` uçtan uca çalıştı, gerçek keystore üretti | ✔ 4096-bit RSA, SHA384withRSA |
| base64 → decode → keystore **byte byte aynı** | ✔ roundtrip doğrulandı |
| Üretilen base64 **tek satır, satır sonu yok** | ✔ 5736 karakter |
| `verify-apk.ps1` gerçek imzalı pakette | ✔ parmak izi eşleşti |
| `verify-apk.ps1` imzasız pakette | ✔ hata verdi |
| `verify-apk.ps1` yanlış parmak iziyle | ✔ reddetti (exit 3) |
| `apply-patch.py` CRLF repoda | ✔ CRLF korundu, LF sızıntısı 0 |
| `apply-patch.py` idempotency | ✔ 2. çalıştırma "değişiklik yok" |
| `apply-patch.py --revert` | ✔ 8 dosya + git index geri geldi |
| Yamalı 7 workflow'un YAML'i | ✔ hepsi geçerli |
| Secret'lar `--body` ile yükleniyor | ✔ 8 karakter şifre = **8 bayt**, satır sonu yok |
| Eski pipe yöntemi karşılaştırması | ✔ 9 bayt çıkıyordu — bug doğrulandı |
| Geçersiz repo formatı (komut yapıştırma) | ✔ reddedip tekrar soruyor |
| Yanlış şifre | ✔ yüklemeden önce keystore'a karşı doğrulayıp duruyor |
| Erişilemeyen repo | ✔ tespit edip duruyor |
| `gh` başarısız olursa | ✔ dürüstçe "0/4 BAŞARISIZ" diyor |

Test sırasında yakalanıp düzeltilen 6 bug: `.bak` dosyaları git'e sızıyordu ·
`.gitignore`'a kural tekrarı ekleniyordu · `$env:TEMP` boşken `verify-apk.ps1` çöküyordu ·
CRLF repoda `build.yml` LF olarak yazılıyordu · **PowerShell pipe'ı şifreye satır sonu
ekliyordu** · **`gh` başarısız olsa bile "4 secret yüklendi" deniyordu**.

---

## build.yml'de ne değişti

### 1. `< /dev/null` — en kritik tek satır

```yaml
- name: Compile
  timeout-minutes: 75
  run: haxelib run lime build ${{ inputs.buildArgs }} < /dev/null 2>&1 | tee /tmp/build.log
```

Runner Linux/macOS olduğu için bu Windows'ta çalışsan bile geçerli — workflow macos-15
üzerinde koşuyor. stdin kapalı olduğundan herhangi bir prompt **anında EOF hatası** verir:
sonsuz hang → 40 saniyede okunabilir hata.

### 2. Gradle non-interaktif
`~/.gradle/gradle.properties`: `org.gradle.daemon=false`, `console=plain`,
`parallel=false`, `jvmargs=-Xmx4g`. Job seviyesinde `GRADLE_OPTS`, `TERM: dumb`, `CI: true`.

### 3. Timeout'lar
Job `210 → 120` dk, `Compile` `75`, `Install Libraries` `30`.
Android derlemesi macos-15'te tipik 45-70 dk.

### 4. Hang teşhisi
Compile düşerse otomatik: son 200 satır log, java process listesi, `jstack` thread dump.
Stack'te `java.io.Console.readLine` görürsen sebep kesin olarak şifre promptudur.

### 5. apksigner imzalama
- `--ks-pass env:` → şifre argv'de görünmez, prompt açılmaz
- keystore `/tmp`'ye yazılır (workspace'e değil) → artifact'a sızamaz, sonra silinir
- `zipalign -p 4` → apksigner'dan önce
- `apksigner verify --print-certs` → log'da doğrulanır
- Secret yoksa adım **hata vermeden atlanır** → fork PR'ları kırılmaz

---

## Keystore'u Yeniden Üretmek İstersen

Henüz hiçbir APK yayınlamadıysan keystore'u değiştirmenin **hiçbir maliyeti yok**.
Daha güçlü bir şifre kullanmak istersen:

```powershell
cd C:\...\Funky-Further-Engine\ci-fix\scripts

# Eskisini yedekle (silmek yerine)
Rename-Item .\keystore-out .\keystore-out-eski

# Yeniden üret
powershell -ExecutionPolicy Bypass -File .\generate-keystore.ps1
```

Script mevcut keystore'un üzerine **bilerek yazmaz** — "zaten var" deyip durur.
Bu bir hata değil, koruma: yanlışlıkla imza kimliğini değiştirmeni engeller.

Yeni keystore ürettikten sonra secret'ları da güncellemeyi unutma
(`upload-secrets.ps1` eski değerlerin üzerine yazar).

**Bir APK yayınladıktan sonra** bu artık mümkün değil — o noktadan sonra keystore
kalıcıdır.

---

## Sorun Giderme

**"Imzasiz APK bulunamadi"**
`Project.xml`'de `<certificate>` hâlâ aktif. Adım 3'ü çalıştırdın mı?

**"ANDROID_KEYSTORE_BASE64 secret'i tanimli degil"**
Secret yok ya da çağıran workflow'da `secrets: inherit` yok.
`gh secret list --repo SametGkTe/Funky-Further-Engine`

**apksigner "Failed to load signer"**
base64 bozuk — muhtemelen araya satır sonu girdi. `Set-Clipboard` ile kopyala,
Not Defteri kullanma. Secret uzunluğu ~5700 karakter olmalı.

**Build hâlâ takılıyor**
Artık 75 dakikada düşer ve "Diagnose hang" adımı çalışır. Thread dump'ta:
- `java.io.Console.readLine` → hâlâ bir prompt var
- `SocketInputStream.read` → ağ / bağımlılık indirme takılması
- `NativeProcess` → hxcpp derleme takılması (bambaşka sorun)

**Python "python bulunamadı" diyor**
`py ci-fix\scripts\apply-patch.py . --dry-run` diye dene (Windows py launcher).

---

## Keystore Güvenliği

1. `keystore-out\` klasörünü **asla** commit etme — `.gitignore`'a eklendi.
2. `further-release.keystore`'u **en az iki yere** yedekle: şifreli USB + şifre yöneticisi.
3. **Kaybedersen** `com.sametgkte.furtherengine` paket adıyla bir daha güncelleme
   yayınlayamazsın; kullanıcılar uygulamayı silip yeniden kurmak zorunda kalır.
4. Secret'ları yükledikten sonra:
   `Remove-Item .\keystore-out\SECRETS.txt`
5. SHA-256 parmak izini not et — ileride "bu APK gerçekten benden mi çıktı?" sorusunu
   cevaplar.

---

## Eski `key.keystore` ne olacak?

Yama onu git takibinden çıkarır ama **geçmişten silmez**. Sorun değil: o zaten upstream'in
herkese açık anahtarı, sızdırılacak bir sırrı yok. Geçmişi yeniden yazmak (29 tag'ini ve
release'lerini kırmak) buna değmez. Önemli olan **yeni** keystore'unun asla repoya
girmemesi — `.gitignore` artık bunu garantiliyor.

---

## Dosya Listesi

```
ci-fix\
├── README_UYGULA_WINDOWS.md      <- bu dosya
├── README_UYGULA.md              <- Linux/macOS sürümü
├── KEYSTORE_CI_TR.md             <- teşhisin uzun teknik anlatımı
├── build.yml                     <- yamalı workflow
├── build.yml.orig                <- senin mevcut hâlin (referans)
├── workflows-orig\               <- 7 workflow'un orijinal yedeği
└── scripts\
    ├── generate-keystore.ps1     <- Adım 1  (Windows)
    ├── apply-patch.py            <- Adım 3  (Windows uyumlu)
    ├── verify-apk.ps1            <- Adım 5  (Windows)
    ├── generate-keystore.sh      <- Linux/macOS karşılıkları
    └── verify-apk.sh
```

### Otomasyon notu

`generate-keystore.ps1` normalde şifreyi interaktif sorar. Otomatik akışta
`FE_KEYSTORE_PASSWORD` ortam değişkeninden de okuyabilir — ama şifre ortam
değişkeninde görünür olacağı için **normal kullanımda tercih etme**.
