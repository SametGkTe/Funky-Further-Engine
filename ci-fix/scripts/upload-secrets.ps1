<#
.SYNOPSIS
    Further Engine — GitHub Secret Yukleyici (Windows / PowerShell)

.DESCRIPTION
    Daha once uretilmis keystore-out\ klasorundeki degerleri GitHub Secrets'a yukler.
    Keystore'u YENIDEN URETMEZ - mevcut olani kullanir.

    generate-keystore.ps1 sirasinda repo adini yanlis girdiysen ya da
    yukleme basarisiz olduysa bunu calistir.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\upload-secrets.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\upload-secrets.ps1 -Repo SametGkTe/Funky-Further-Engine
#>

[CmdletBinding()]
param(
    [string]$Repo     = "",
    [string]$OutDir   = "keystore-out",
    [string]$KeyAlias = "furtherengine"
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

function Write-Ok   ($m) { Write-Host "  [OK] "    -ForegroundColor Green  -NoNewline; Write-Host $m }
function Write-Err  ($m) { Write-Host "  HATA: "   -ForegroundColor Red    -NoNewline; Write-Host $m }
function Write-Warn ($m) { Write-Host "  UYARI: "  -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Write-Step ($m) { Write-Host "-> $m" -ForegroundColor Cyan }

Write-Host ""
Write-Host "+====================================================+" -ForegroundColor Cyan
Write-Host "|   Further Engine - GitHub Secret Yukleyici         |" -ForegroundColor Cyan
Write-Host "+====================================================+" -ForegroundColor Cyan
Write-Host ""

# ─────────────────────────────────────────────────────────────
# gh CLI
# ─────────────────────────────────────────────────────────────
$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Err "GitHub CLI (gh) bulunamadi."
    Write-Host "  Kur: winget install GitHub.cli"
    Write-Host "  Sonra: gh auth login"
    exit 1
}

# Giris yapilmis mi?
& gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Err "gh ile giris yapilmamis."
    Write-Host "  Once calistir: gh auth login"
    exit 1
}
Write-Ok "gh CLI hazir"

# ─────────────────────────────────────────────────────────────
# Dosyalar
# ─────────────────────────────────────────────────────────────
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outPath   = Join-Path $scriptDir $OutDir
$b64Path   = Join-Path $outPath "keystore.base64.txt"
$ksPath    = Join-Path $outPath "further-release.keystore"

if (-not (Test-Path $b64Path)) {
    Write-Err "$b64Path bulunamadi."
    Write-Host "  Once generate-keystore.ps1 calistir."
    exit 1
}

# base64'u satir sonu OLMADAN oku
$b64 = [System.IO.File]::ReadAllText($b64Path).Trim()
if ($b64.Length -lt 100) {
    Write-Err "base64 icerigi cok kisa ($($b64.Length) karakter) - dosya bozuk olabilir."
    exit 1
}
Write-Ok "keystore.base64.txt okundu ($($b64.Length) karakter)"

# ─────────────────────────────────────────────────────────────
# Repo adi - FORMAT DOGRULAMASI
# ─────────────────────────────────────────────────────────────
function Test-RepoFormat([string]$r) {
    # OWNER/REPO  ya da  HOST/OWNER/REPO
    return $r -match '^([A-Za-z0-9._-]+/)?[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$'
}

if (-not $Repo) {
    # git remote'tan tahmin etmeyi dene
    $guess = ""
    try {
        Push-Location $scriptDir
        $url = & git config --get remote.origin.url 2>$null
        Pop-Location
        if ($url -match '[:/]([^/]+/[^/]+?)(\.git)?$') { $guess = $Matches[1] }
    } catch { try { Pop-Location } catch {} }

    if ($guess) {
        Write-Host ""
        Write-Host "  Tespit edilen repo: " -NoNewline; Write-Host $guess -ForegroundColor Cyan
        $ans = Read-Host "  Bunu kullanayim mi? [E/h]"
        if ($ans -eq "" -or $ans -match '^[EeYy]') { $Repo = $guess }
    }
}

while (-not (Test-RepoFormat $Repo)) {
    if ($Repo) {
        Write-Warn "Gecersiz format: '$Repo'"
        Write-Host "  Beklenen: OWNER/REPO   (orn: SametGkTe/Funky-Further-Engine)"
        Write-Host "  Buraya komut degil, sadece repo adi yaz."
    }
    Write-Host ""
    $Repo = (Read-Host "  Repo (OWNER/REPO)").Trim()
    if (-not $Repo) { Write-Err "Repo girilmedi, cikiliyor."; exit 1 }
}
Write-Ok "Repo: $Repo"

# Repo gercekten erisilebilir mi?
& gh repo view $Repo --json name 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Err "Repo'ya erisilemiyor: $Repo"
    Write-Host "  Adi dogru mu? Bu hesapla yetkin var mi?"
    exit 1
}
Write-Ok "Repo erisilebilir"

# ─────────────────────────────────────────────────────────────
# Sifre
# ─────────────────────────────────────────────────────────────
function ConvertFrom-SecureStringPlain([System.Security.SecureString]$s) {
    $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
    try   { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

Write-Host ""
if ($env:FE_KEYSTORE_PASSWORD) {
    $KS_PASS = $env:FE_KEYSTORE_PASSWORD
    Write-Warn "Sifre FE_KEYSTORE_PASSWORD ortam degiskeninden alindi (otomasyon modu)."
} else {
    Write-Host "Keystore sifreni gir (generate-keystore.ps1'de belirledigin)."
    $sec = Read-Host -Prompt "  Sifre" -AsSecureString
    $KS_PASS = ConvertFrom-SecureStringPlain $sec
}

if (-not $KS_PASS) { Write-Err "Sifre bos."; exit 1 }

# Sifreyi keystore'a karsi DOGRULA - yanlis sifreyi yuklemektense simdi yakala
function Find-Keytool {
    $c = Get-Command keytool -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    if ($env:JAVA_HOME) {
        $p = Join-Path $env:JAVA_HOME "bin\keytool.exe"
        if (Test-Path $p) { return $p }
    }
    foreach ($base in @("$env:ProgramFiles\Eclipse Adoptium","$env:ProgramFiles\Java",
                        "$env:ProgramFiles\Microsoft\jdk","$env:ProgramFiles\Amazon Corretto")) {
        if (Test-Path $base) {
            $d = Get-ChildItem $base -Directory -EA SilentlyContinue | Sort-Object Name -Descending
            foreach ($x in $d) {
                $p = Join-Path $x.FullName "bin\keytool.exe"
                if (Test-Path $p) { return $p }
            }
        }
    }
    foreach ($p in @("$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe",
                     "$env:ProgramFiles\Android\Android Studio\jre\bin\keytool.exe")) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

$keytool = Find-Keytool
if ($keytool -and (Test-Path $ksPath)) {
    Write-Step "Sifre keystore'a karsi dogrulaniyor..."
    & $keytool -list -keystore $ksPath -storepass $KS_PASS -alias $KeyAlias 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Sifre yanlis - keystore acilamadi."
        Write-Host "  Yanlis sifreyi secret olarak yuklemektense simdi durduruyorum."
        exit 1
    }
    Write-Ok "Sifre dogru"
} else {
    Write-Warn "keytool yok - sifre dogrulanamadi, oldugu gibi yuklenecek."
}

# ─────────────────────────────────────────────────────────────
# Yukle
#
# ONEMLI: PowerShell pipe'i native komuta gonderirken SONA SATIR SONU EKLER.
#   "sifre" | gh secret set X     -> "sifre`n" olarak yuklenir  (YANLIS!)
# Bu yuzden --body kullaniyoruz: deger bire bir gider.
# ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Secret'lar yukleniyor..."

$secrets = [ordered]@{
    "ANDROID_KEYSTORE_BASE64"   = $b64
    "ANDROID_KEYSTORE_PASSWORD" = $KS_PASS
    "ANDROID_KEY_ALIAS"         = $KeyAlias
    "ANDROID_KEY_PASSWORD"      = $KS_PASS
}

$okCount = 0
$failed  = @()

foreach ($name in $secrets.Keys) {
    $value = $secrets[$name]
    & gh secret set $name --repo $Repo --body $value 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "$name  ($($value.Length) karakter)"
        $okCount++
    } else {
        Write-Err "$name yuklenemedi (gh exit $LASTEXITCODE)"
        $failed += $name
    }
}

Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "  $okCount/4 secret basariyla yuklendi." -ForegroundColor Green
} else {
    Write-Host "  $okCount/4 yuklendi, $($failed.Count) BASARISIZ:" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    exit 1
}

# ─────────────────────────────────────────────────────────────
# Dogrula
# ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Repodaki secret listesi:"
& gh secret list --repo $Repo

$listed = (& gh secret list --repo $Repo 2>&1) -join "`n"
$missing = @()
foreach ($name in $secrets.Keys) {
    if ($listed -notmatch [regex]::Escape($name)) { $missing += $name }
}

Write-Host ""
if ($missing.Count -eq 0) {
    Write-Host "  [OK] 4 secret'in hepsi repoda gorunuyor." -ForegroundColor Green
    Write-Host ""
    Write-Host "Siradaki adim:" -ForegroundColor Cyan
    Write-Host "    cd <repo koku>"
    Write-Host "    python ci-fix\scripts\apply-patch.py . --dry-run"
} else {
    Write-Warn "Listede gorunmeyenler: $($missing -join ', ')"
}
Write-Host ""
