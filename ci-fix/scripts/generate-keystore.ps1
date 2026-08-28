<#
.SYNOPSIS
    Further Engine — Release Keystore Olusturucu (Windows / PowerShell)

.DESCRIPTION
    Bu script'i YEREL makinende BIR KEZ calistir. Sunucuda/CI'da ASLA calistirma.
    Urettigi keystore dosyasi projenin omru boyunca kullanilacak tek imza kimligidir.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File generate-keystore.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File generate-keystore.ps1 -Repo "SametGkTe/Funky-Further-Engine"
#>

[CmdletBinding()]
param(
    [string]$KeystoreFile = "further-release.keystore",
    [string]$KeyAlias     = "furtherengine",
    [int]   $ValidityDays = 10950,   # ~30 yil
    [int]   $KeySize      = 4096,
    [string]$OutDir       = "keystore-out",
    [string]$Repo         = "",      # verilirse gh ile secret'lari otomatik yukler
    # Sertifika sahibi bilgileri
    [string]$CN = "Further Engine",
    [string]$OU = "Further Engine",
    [string]$O  = "SametGkTe",
    [string]$L  = "Ankara",
    [string]$ST = "Ankara",
    [string]$C  = "TR"
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

function Write-Ok   ($m) { Write-Host "  [OK] " -ForegroundColor Green  -NoNewline; Write-Host $m }
function Write-Err  ($m) { Write-Host "  HATA: " -ForegroundColor Red    -NoNewline; Write-Host $m }
function Write-Warn ($m) { Write-Host "  UYARI: " -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Write-Step ($m) { Write-Host "-> $m" -ForegroundColor Cyan }

Write-Host ""
Write-Host "+====================================================+" -ForegroundColor Cyan
Write-Host "|   Further Engine - Release Keystore Olusturucu     |" -ForegroundColor Cyan
Write-Host "+====================================================+" -ForegroundColor Cyan
Write-Host ""

# ─────────────────────────────────────────────────────────────
# keytool'u bul
# ─────────────────────────────────────────────────────────────
function Find-Keytool {
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @()
    if ($env:JAVA_HOME) { $candidates += Join-Path $env:JAVA_HOME "bin\keytool.exe" }

    # Android Studio gomulu JDK (jbr / jre)
    $candidates += "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe"
    $candidates += "$env:ProgramFiles\Android\Android Studio\jre\bin\keytool.exe"
    $candidates += "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe"

    # Yaygin JDK kurulumlari
    foreach ($base in @("$env:ProgramFiles\Eclipse Adoptium",
                        "$env:ProgramFiles\Java",
                        "$env:ProgramFiles\Microsoft\jdk",
                        "$env:ProgramFiles\Amazon Corretto")) {
        if (Test-Path $base) {
            Get-ChildItem $base -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | ForEach-Object {
                    $candidates += Join-Path $_.FullName "bin\keytool.exe"
                }
        }
    }

    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}

$keytool = Find-Keytool
if (-not $keytool) {
    Write-Err "'keytool' bulunamadi. JDK 17 kur:"
    Write-Host ""
    Write-Host "    winget install EclipseAdoptium.Temurin.17.JDK" -ForegroundColor White
    Write-Host ""
    Write-Host "  Kurduktan sonra YENI bir PowerShell penceresi ac ve tekrar dene."
    Write-Host "  (Android Studio kuruluysa onun JDK'sini da otomatik bulurum.)"
    exit 1
}
Write-Ok "keytool: $keytool"

# ─────────────────────────────────────────────────────────────
# Cikti klasoru
# ─────────────────────────────────────────────────────────────
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outPath = Join-Path $scriptDir $OutDir
New-Item -ItemType Directory -Force -Path $outPath | Out-Null
$ksPath = Join-Path $outPath $KeystoreFile

if (Test-Path $ksPath) {
    Write-Err "$ksPath zaten var."
    Write-Host "  Uzerine yazmak imza kimligini DEGISTIRIR ve mevcut kurulumlarin"
    Write-Host "  guncellenmesini imkansiz kilar. Once yedekle, sonra elle sil."
    exit 1
}

# ─────────────────────────────────────────────────────────────
# Sifre
# ─────────────────────────────────────────────────────────────
function ConvertFrom-SecureStringPlain([System.Security.SecureString]$s) {
    $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
    try   { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

if ($env:FE_KEYSTORE_PASSWORD) {
    # Otomasyon / test yolu. Normal kullanimda bunu KULLANMA -
    # sifre ortam degiskeninde ve process listesinde gorunur olur.
    $pass1 = $env:FE_KEYSTORE_PASSWORD
    Write-Warn "Sifre FE_KEYSTORE_PASSWORD ortam degiskeninden alindi (otomasyon modu)."
    if ($pass1.Length -lt 6) { Write-Err "keytool en az 6 karakter ister."; exit 1 }
}
else {
    Write-Host ""
    Write-Host "Keystore sifresi belirle (en az 12 karakter onerilir)."
    Write-Warn "Bu sifreyi kaybedersen keystore kullanilamaz hale gelir."
    Write-Host ""

    $sec1 = Read-Host -Prompt "Sifre" -AsSecureString
    $sec2 = Read-Host -Prompt "Sifre (tekrar)" -AsSecureString

    $pass1 = ConvertFrom-SecureStringPlain $sec1
    $pass2 = ConvertFrom-SecureStringPlain $sec2

    if ($pass1 -ne $pass2)    { Write-Err "Sifreler uyusmuyor."; exit 1 }
    if ($pass1.Length -lt 6)  { Write-Err "keytool en az 6 karakter ister."; exit 1 }
    if ($pass1.Length -lt 12) { Write-Warn "12 karakterden kisa. Yine de devam ediliyor." }
}

# PKCS12'de store ve key sifresi ayni olmak zorunda
$KS_PASS  = $pass1
$KEY_PASS = $pass1

# ─────────────────────────────────────────────────────────────
# Uret
# ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Keystore uretiliyor..."

$dname = "CN=$CN, OU=$OU, O=$O, L=$L, ST=$ST, C=$C"

# Sifreler argv'de gorunmesin diye stdin uzerinden verilir.
$ktArgs = @(
    "-genkeypair"
    "-keystore",  $ksPath
    "-storetype", "PKCS12"
    "-alias",     $KeyAlias
    "-keyalg",    "RSA"
    "-keysize",   $KeySize
    "-validity",  $ValidityDays
    "-dname",     $dname
    "-noprompt"
    "-storepass", $KS_PASS
    "-keypass",   $KEY_PASS
)

& $keytool @ktArgs
if ($LASTEXITCODE -ne 0) { Write-Err "keytool basarisiz oldu (kod $LASTEXITCODE)"; exit 1 }
Write-Ok "$ksPath uretildi"

# ─────────────────────────────────────────────────────────────
# base64  (tek satir - GitHub Secret icin sart)
# ─────────────────────────────────────────────────────────────
Write-Step "base64 kodlaniyor..."
$b64Path = Join-Path $outPath "keystore.base64.txt"
$bytes = [System.IO.File]::ReadAllBytes($ksPath)
$b64   = [System.Convert]::ToBase64String($bytes)
# Satir sonu / BOM olmadan yaz
[System.IO.File]::WriteAllText($b64Path, $b64, (New-Object System.Text.UTF8Encoding($false)))
Write-Ok "keystore.base64.txt uretildi ($($b64.Length) karakter)"

# ─────────────────────────────────────────────────────────────
# Parmak izi
# ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Sertifika parmak izi:"
$listOut = & $keytool -list -v -keystore $ksPath -storepass $KS_PASS -alias $KeyAlias 2>&1
$listOut | Select-String -Pattern "SHA256:|SHA1:|Valid from|Alias name|Gecerlilik" |
    ForEach-Object { Write-Host "    $_" }

$sha = ($listOut | Select-String -Pattern "SHA256:" | Select-Object -First 1) -replace '.*SHA256:\s*',''
$sha = $sha.Trim()
$shaPath = Join-Path $outPath "sha256-fingerprint.txt"
[System.IO.File]::WriteAllText($shaPath, $sha, (New-Object System.Text.UTF8Encoding($false)))
Write-Ok "sha256-fingerprint.txt kaydedildi"

# ─────────────────────────────────────────────────────────────
# SECRETS.txt
# ─────────────────────────────────────────────────────────────
$secretsPath = Join-Path $outPath "SECRETS.txt"
@"
GitHub -> Settings -> Secrets and variables -> Actions -> New repository secret

ANDROID_KEYSTORE_BASE64
  -> keystore.base64.txt dosyasinin TAM icerigi

ANDROID_KEYSTORE_PASSWORD
  -> $KS_PASS

ANDROID_KEY_ALIAS
  -> $KeyAlias

ANDROID_KEY_PASSWORD
  -> $KEY_PASS

SHA-256 parmak izi (dogrulama icin sakla):
  $sha
"@ | Set-Content -Path $secretsPath -Encoding UTF8

# Dosyayi sadece mevcut kullaniciya oku/yaz yap (yalnizca Windows)
$isWin = $PSVersionTable.PSVersion.Major -le 5 -or $IsWindows
if ($isWin) {
    try {
        $acl = Get-Acl $secretsPath
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "$env:USERDOMAIN\$env:USERNAME", "FullControl", "Allow")
        $acl.SetAccessRule($rule)
        Set-Acl -Path $secretsPath -AclObject $acl
        Write-Ok "SECRETS.txt yazildi (sadece sana okunabilir)"
    } catch {
        Write-Ok "SECRETS.txt yazildi"
        Write-Warn "Dosya izni sikilastirilamadi - dosyayi kullandiktan sonra sil."
    }
} else {
    try { & chmod 600 $secretsPath 2>$null } catch {}
    Write-Ok "SECRETS.txt yazildi"
}

# ─────────────────────────────────────────────────────────────
# gh CLI ile otomatik yukleme
# ─────────────────────────────────────────────────────────────
Write-Host ""
$gh = Get-Command gh -ErrorAction SilentlyContinue

function Test-RepoFormat([string]$r) {
    # OWNER/REPO  ya da  HOST/OWNER/REPO
    return $r -match '^([A-Za-z0-9._-]+/)?[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$'
}

if ($gh) {
    Write-Host "GitHub CLI bulundu." -ForegroundColor Cyan
    if (-not $Repo) {
        Write-Host "  Sadece repo adini yaz (komut degil), orn: SametGkTe/Funky-Further-Engine"
        $Repo = (Read-Host "  Repo (bos birak = atla)").Trim()
    }

    # Gecersiz format girildiyse tekrar sor - yanlis degerle gh'a gitme
    while ($Repo -and -not (Test-RepoFormat $Repo)) {
        Write-Warn "Gecersiz repo formati: '$Repo'"
        Write-Host "  Beklenen: OWNER/REPO   Buraya komut yapistirma."
        $Repo = (Read-Host "  Repo (bos birak = atla)").Trim()
    }

    if ($Repo) {
        # ONEMLI: PowerShell pipe'i native komuta gonderirken SONA SATIR SONU EKLER.
        #   "sifre" | gh secret set X   -> "sifre`n" yuklenir  (YANLIS SIFRE!)
        # Bu yuzden --body kullaniyoruz: deger bire bir gider.
        $toUpload = [ordered]@{
            "ANDROID_KEYSTORE_BASE64"   = $b64
            "ANDROID_KEYSTORE_PASSWORD" = $KS_PASS
            "ANDROID_KEY_ALIAS"         = $KeyAlias
            "ANDROID_KEY_PASSWORD"      = $KEY_PASS
        }

        $okCount = 0
        $failed  = @()
        foreach ($n in $toUpload.Keys) {
            & gh secret set $n --repo $Repo --body $toUpload[$n] 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Ok "$n yuklendi"; $okCount++ }
            else { Write-Err "$n YUKLENEMEDI (gh exit $LASTEXITCODE)"; $failed += $n }
        }

        Write-Host ""
        if ($failed.Count -eq 0) {
            Write-Host "  $okCount/4 secret yuklendi. Kontrol:" -ForegroundColor Green
            & gh secret list --repo $Repo
        } else {
            Write-Host "  $okCount/4 yuklendi, basarisiz: $($failed -join ', ')" -ForegroundColor Red
            Write-Host "  Tekrar denemek icin:  .\upload-secrets.ps1 -Repo $Repo"
        }
    } else {
        Write-Warn "Repo girilmedi - secret yukleme atlandi."
        Write-Host "  Sonra yuklemek icin:  .\upload-secrets.ps1"
    }
} else {
    Write-Warn "gh CLI yok - secret'lari elle gireceksin. Bkz. $secretsPath"
    Write-Host "  Kurmak istersen: winget install GitHub.cli"
    Write-Host "  Sonra:           .\upload-secrets.ps1"
}

# ─────────────────────────────────────────────────────────────
# Kapanis
# ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "+====================================================+" -ForegroundColor Red
Write-Host "|                     ONEMLI                         |" -ForegroundColor Red
Write-Host "+====================================================+" -ForegroundColor Red
Write-Host @"

  1. $OutDir\ klasorunu ASLA git'e commit etme.
     (.gitignore'a eklendiginden emin ol - apply-patch.py bunu yapiyor)

  2. $KeystoreFile dosyasini en az iki ayri yerde yedekle:
     - sifreli USB / harici disk
     - sifre yoneticisi (Bitwarden, 1Password) eki olarak

  3. Bu dosyayi kaybedersen com.sametgkte.furtherengine paket adiyla
     BIR DAHA guncelleme yayinlayamazsin. Kullanicilar uygulamayi
     silip yeniden kurmak zorunda kalir. Yedegi ciddiye al.

  4. Secret'lari yukledikten sonra SECRETS.txt'yi sil:
       Remove-Item "$secretsPath"

"@
Write-Host "Tamamdir. " -ForegroundColor Green -NoNewline
Write-Host "Siradaki adim: ci-fix\README_UYGULA_WINDOWS.md -> Adim 3"
Write-Host ""
