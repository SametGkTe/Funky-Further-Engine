# Android CI Keystore Hang — Teşhis ve Çözüm

## Sorun neydi?

Belirti: GitHub Actions'ta Android derlemesi
`Daemon will be stopped at the end of the build` satırından sonra sonsuza kadar takılıyor.
Secrets'a yazmak da çözmüyor.

**Sebep: Gradle bir şifre promptu açıp stdin'den cevap bekliyor.**

Lime'ın Android şablonundaki `build.gradle`, `<certificate>` etiketindeki
`password` / `alias-password` değerleri **boş veya null** olduğunda signingConfig'i
şu şekilde üretir:

```gradle
signingConfigs {
    release {
        storeFile file(...)
        storePassword System.console().readLine("\nKeystore password: ")
        keyAlias      System.console().readLine("\nAlias: ")
        keyPassword   System.console().readLine("\nAlias password: ")
    }
}
```

CI runner'da TTY yoktur. `System.console()` ya `null` döner ya da okuma sonsuza kadar
bloklanır. Gradle "Daemon will be stopped at the end of the build" mesajını **build'in
başında** (`--no-daemon` ile çalıştığı için) yazdırır, sonra prompt'ta donar. Dışarıdan
bakınca "derleme takıldı" gibi görünür; aslında sana şifre soruyor ve kimse cevap vermiyor.

**Neden Secrets'a yazınca da olmadı:** `Project.xml` GitHub Actions'ın `${{ secrets.X }}`
sözdizimini bilmez, ortam değişkenlerini de otomatik genişletmez. `password="${{ secrets.KS_PASS }}"`
yazdıysan Lime bunu düz metin bir şifre sanır (ya da sen attribute'u tamamen sildiysen null
kalır) → yine prompt → yine hang.

Şu anki `Project.xml:219` satırın çalışıyor olmasının tek sebebi şifrenin **düz metin gömülü**
olması:

```xml
<certificate path="key.keystore" password="psychengine" alias="psychport" alias-password="psychengine" if="android" unless="debug" />
```

---

## Çözüm A — Önerilen: İmzalamayı Lime'dan tamamen çıkar

Lime imzasız APK üretsin, imzalamayı ayrı bir adımda `apksigner` ile yap.
Gradle hiç signingConfig görmez → prompt ihtimali **sıfır**.

### 1. Project.xml

`<certificate .../>` satırını sil ya da sadece debug'a bırak:

```xml
<!-- İmzalama CI'da apksigner ile yapılıyor, bkz. .github/workflows/build.yml -->
<!-- <certificate path="key.keystore" password="..." alias="..." alias-password="..." if="android" unless="debug" /> -->
```

Artık release çıktısı: `app-release-unsigned.apk`

### 2. Workflow'a imzalama adımı ekle

`build.yml` içinde **Compile** ile **Upload Artifact** arasına:

```yaml
      - name: Sign Android APK
        if: inputs.name == 'Android' && env.KS_B64 != ''
        env:
          KS_B64:       ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          KS_PASS:      ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          KS_ALIAS:     ${{ secrets.ANDROID_KEY_ALIAS }}
          KS_ALIAS_PASS: ${{ secrets.ANDROID_KEY_PASSWORD }}
        shell: bash
        run: |
          set -euo pipefail

          APK_DIR="export/release/android/bin/app/build/outputs/apk/release"
          UNSIGNED=$(ls "$APK_DIR"/*-unsigned.apk 2>/dev/null | head -n1 || true)
          if [ -z "$UNSIGNED" ]; then
            echo "İmzasız APK bulunamadı, muhtemelen zaten imzalı. Atlanıyor."
            ls -la "$APK_DIR"
            exit 0
          fi

          echo "$KS_B64" | base64 --decode > /tmp/release.keystore

          BT=$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -n1)
          echo "build-tools: $BT"

          "$BT/zipalign" -p -f 4 "$UNSIGNED" /tmp/aligned.apk

          "$BT/apksigner" sign \
            --ks /tmp/release.keystore \
            --ks-pass "env:KS_PASS" \
            --ks-key-alias "$KS_ALIAS" \
            --key-pass "env:KS_ALIAS_PASS" \
            --out "$APK_DIR/${PROJECT_NAME}-release.apk" \
            /tmp/aligned.apk

          "$BT/apksigner" verify --print-certs "$APK_DIR/${PROJECT_NAME}-release.apk"

          rm -f /tmp/release.keystore /tmp/aligned.apk "$UNSIGNED"
```

`--ks-pass env:` kullanımı kritik: şifre komut satırında görünmez, prompt da açılmaz.
Keystore dosyası her zaman `/tmp` altına yazılır, workspace'e değil — yanlışlıkla
artifact'a sızmaz.

### 3. Secrets oluştur

Yerelde (bir kereye mahsus):

```bash
keytool -genkeypair -v \
  -keystore further-release.keystore \
  -alias furtherengine \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -storetype PKCS12

base64 -w0 further-release.keystore > ks.txt   # macOS: base64 -i ... -o ks.txt
```

GitHub → Settings → Secrets and variables → Actions:

| Secret | Değer |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `ks.txt` içeriği |
| `ANDROID_KEYSTORE_PASSWORD` | keystore şifresi |
| `ANDROID_KEY_ALIAS` | `furtherengine` |
| `ANDROID_KEY_PASSWORD` | alias şifresi |

`further-release.keystore` ve `ks.txt` dosyalarını **repoya koyma**, yerelde yedekle.
Bu dosyayı kaybedersen aynı `packageName` ile bir daha güncelleme yayınlayamazsın.

---

## Çözüm B — Minimal değişiklik: Lime'da kalıp define ile besle

`<certificate>` etiketini bırakmak istersen, Lime `${...}` ile define genişletmesi yapar:

```xml
<set name="KS_PATH"       value="key.keystore" />
<set name="KS_PASS"       value="psychengine" />
<set name="KS_ALIAS"      value="psychport" />
<set name="KS_ALIAS_PASS" value="psychengine" />

<certificate path="${KS_PATH}" password="${KS_PASS}"
             alias="${KS_ALIAS}" alias-password="${KS_ALIAS_PASS}"
             if="android" unless="debug" />
```

Workflow'da:

```yaml
      - name: Compile
        run: |
          echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 --decode > /tmp/release.keystore
          haxelib run lime build ${{ inputs.buildArgs }} \
            -DKS_PATH=/tmp/release.keystore \
            -DKS_PASS='${{ secrets.ANDROID_KEYSTORE_PASSWORD }}' \
            -DKS_ALIAS='${{ secrets.ANDROID_KEY_ALIAS }}' \
            -DKS_ALIAS_PASS='${{ secrets.ANDROID_KEY_PASSWORD }}' \
            < /dev/null
```

Dezavantaj: şifrede `$`, `"`, boşluk gibi karakter varsa kaçış sorunu çıkar ve Lime
sürümüne bağımlısın. Bu yüzden A daha sağlam.

---

## Her Durumda Yap — "Sonsuza kadar takılma" bir daha olmasın

Bu üçü, imzalamadan bağımsız olarak, herhangi bir Gradle prompt'unun
**sonsuz hang yerine 1 saniyede anlaşılır hata** vermesini sağlar.

### 1. stdin'i kapat

Her `lime build` çağrısına `< /dev/null` ekle. Prompt açılırsa Gradle
`java.io.EOFException` / `NullPointerException` atıp **hemen** düşer.
Bu tek satır, teşhis edemediğin 3 saatlik hang'i 40 saniyelik net hataya çevirir.

```yaml
      - name: Compile
        run: haxelib run lime build ${{ inputs.buildArgs }} < /dev/null
```

### 2. Gradle'ı non-interaktif moda kilitle

`Configure Android` adımının sonuna:

```yaml
          mkdir -p ~/.gradle
          cat >> ~/.gradle/gradle.properties <<'EOF'
          org.gradle.daemon=false
          org.gradle.console=plain
          org.gradle.parallel=false
          org.gradle.jvmargs=-Xmx4g -Dfile.encoding=UTF-8
          EOF
```

Ayrıca job seviyesinde:

```yaml
    env:
      GRADLE_OPTS: "-Dorg.gradle.daemon=false -Dorg.gradle.internal.launcher.welcomeMessageEnabled=false"
      TERM: dumb
      CI: "true"
```

### 3. Adım bazlı timeout

Job'daki `timeout-minutes: 210` seni 3.5 saat bekletiyor. Asıl derdin
hangi adımın takıldığı — o yüzden adıma koy:

```yaml
      - name: Compile
        timeout-minutes: 75
        run: haxelib run lime build ${{ inputs.buildArgs }} < /dev/null
```

Ve job seviyesini 210 → 120'ye çek. Android derlemesi macos-15'te cache'siz
tipik olarak 45-70 dakika; 75 dakikayı geçiyorsa zaten bir terslik var.

### Bonus: takıldığında ne olduğunu gör

Hâlâ takılırsa sebebini görmek için Compile adımını şuna çevir:

```yaml
      - name: Compile
        timeout-minutes: 75
        run: |
          set -o pipefail
          ( haxelib run lime build ${{ inputs.buildArgs }} -verbose < /dev/null 2>&1 & echo $! > /tmp/pid ) | tee /tmp/build.log &
          BUILD_PID=$(cat /tmp/pid)
          # 60 dk sonra hâlâ yaşıyorsa thread dump al
          ( sleep 3600; for p in $(pgrep -f GradleDaemon || pgrep -f gradle); do jstack $p || true; done ) &
          wait $BUILD_PID
```

`jstack` çıktısı sana Gradle'ın tam olarak hangi satırda blokladığını söyler.
Prompt teorisi doğruysa stack'te `java.io.Console.readLine` göreceksin.

---

## Özet

| Adım | Etki |
|---|---|
| `< /dev/null` ekle | Hang → anlaşılır hata. **En küçük efor, en büyük kazanç.** |
| `<certificate>` kaldır + apksigner adımı | Sorunun kökünü siler |
| `gradle.properties` non-interaktif | Başka prompt kaynaklarını da kapatır |
| Adım bazlı `timeout-minutes` | 3.5 saat yerine 75 dk'da geri bildirim |
| Kendi release keystore'un | `psychengine`/`psychport` public key'inden kurtulursun |
