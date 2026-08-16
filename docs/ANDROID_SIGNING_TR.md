# Android imzalama — GitHub Actions Secrets

Further Engine'in Android release anahtarı artık depoda tutulmaz. Workflow, derleme sırasında anahtarı GitHub Secrets'tan geçici olarak oluşturur ve derlemeden sonra siler.

## Gerekli secrets

Depoda **Settings → Secrets and variables → Actions → New repository secret** yolunu açıp şunları ekleyin:

| Secret | İçerik |
| :-- | :-- |
| `ANDROID_KEYSTORE_BASE64` | `key.keystore` dosyasının Base64 çıktısı |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore parolası |

`Project.xml` içindeki alias şu anda `psychport` olarak ayarlıdır. Farklı alias kullanılıyorsa bu değeri değiştirin; alias gizli bilgi değildir.

## Base64 üretme

### Linux

```bash
base64 -w 0 key.keystore > key.keystore.base64.txt
```

### macOS

```bash
base64 < key.keystore | tr -d '\n' > key.keystore.base64.txt
```

### PowerShell

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("key.keystore")) |
  Set-Content -NoNewline key.keystore.base64.txt
```

Oluşan metnin tamamını `ANDROID_KEYSTORE_BASE64` secret'ına yapıştırın.

> [!CAUTION]
> Bu depoda daha önce bir keystore ve parolası commit edildiği için anahtarın açığa çıkmış olduğu kabul edilmelidir. Üretim dağıtımında mümkünse yeni bir keystore oluşturun. Eski dosyayı yalnızca son commit'ten silmek Git geçmişinden kaldırmaz.

## Yerel release derlemesi

Anahtar dosyasını yalnızca yerel çalışma dizininize koyun; `.gitignore` artık `*.keystore` ve `*.jks` dosyalarını engeller.

```bash
lime build android -final --certificate-password="PAROLANIZ"
```

Parolayı kabuk geçmişine yazmamak için Lime'ın parola istemini kullanmak daha güvenlidir:

```bash
lime build android -final
```
