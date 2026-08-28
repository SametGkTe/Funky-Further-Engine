<#
.SYNOPSIS
    Further Engine — APK Imza Dogrulayici (Windows / PowerShell)

.DESCRIPTION
    Indirdigin bir APK'nin gercekten senin keystore'unla imzalanip
    imzalanmadigini kontrol eder.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File verify-apk.ps1 FurtherEngine-release.apk

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File verify-apk.ps1 FurtherEngine-release.apk -Expected (Get-Content keystore-out\sha256-fingerprint.txt)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Apk,

    [Parameter(Position = 1)]
    [string]$Expected = ""
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

function Write-Ok   ($m) { Write-Host "  [OK] "   -ForegroundColor Green  -NoNewline; Write-Host $m }
function Write-Bad  ($m) { Write-Host "  [HATA] " -ForegroundColor Red    -NoNewline; Write-Host $m }
function Write-Warn ($m) { Write-Host "  [UYARI] "-ForegroundColor Yellow -NoNewline; Write-Host $m }

if (-not (Test-Path $Apk)) {
    Write-Bad "$Apk bulunamadi."
    exit 1
}
$Apk = (Resolve-Path $Apk).Path

# ─────────────────────────────────────────────────────────────
# apksigner'i bul  (Windows'ta apksigner.bat)
# ─────────────────────────────────────────────────────────────
function Find-ApkSigner {
    $cmd = Get-Command apksigner.bat -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $cmd = Get-Command apksigner -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $sdkRoots = @(
        $env:ANDROID_HOME,
        $env:ANDROID_SDK_ROOT,
        "$env:LOCALAPPDATA\Android\Sdk",
        "$env:ProgramFiles (x86)\Android\android-sdk",
        "$env:ProgramFiles\Android\android-sdk"
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($root in $sdkRoots) {
        $bt = Join-Path $root "build-tools"
        if (Test-Path $bt) {
            $newest = Get-ChildItem $bt -Directory -ErrorAction SilentlyContinue |
                      Sort-Object { [version]($_.Name -replace '[^0-9.].*$','0') } -Descending |
                      Select-Object -First 1
            if ($newest) {
                $p = Join-Path $newest.FullName "apksigner.bat"
                if (Test-Path $p) { return $p }
            }
        }
    }
    return $null
}

function Find-Keytool {
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    if ($env:JAVA_HOME) {
        $p = Join-Path $env:JAVA_HOME "bin\keytool.exe"
        if (Test-Path $p) { return $p }
    }
    foreach ($p in @("$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe",
                     "$env:ProgramFiles\Android\Android Studio\jre\bin\keytool.exe")) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

$apksigner = Find-ApkSigner

Write-Host ""
Write-Host "-> Imza dogrulaniyor: $(Split-Path -Leaf $Apk)" -ForegroundColor Cyan
Write-Host ""

# ─────────────────────────────────────────────────────────────
# apksigner yoksa keytool ile sinirli kontrol
# ─────────────────────────────────────────────────────────────
if (-not $apksigner) {
    Write-Warn "apksigner bulunamadi (Android SDK build-tools gerekli)."
    $keytool = Find-Keytool
    if (-not $keytool) {
        Write-Bad "keytool da yok. Dogrulama yapilamiyor."
        Write-Host "  Android Studio kur ya da: winget install EclipseAdoptium.Temurin.17.JDK"
        exit 1
    }
    Write-Host "  keytool ile sinirli kontrol yapiliyor..."
    Write-Host ""

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("apkverify_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Apk)
        $certEntry = $zip.Entries | Where-Object {
            $_.FullName -match '^META-INF/.*\.(RSA|DSA|EC)$'
        } | Select-Object -First 1

        if (-not $certEntry) {
            $zip.Dispose()
            Write-Bad "Imza bulunamadi - APK imzasiz olabilir."
            exit 2
        }
        $certFile = Join-Path $tmp "cert.rsa"
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($certEntry, $certFile, $true)
        $zip.Dispose()

        $certOut = & $keytool -printcert -file $certFile 2>&1
        $certOut | ForEach-Object { Write-Host "  $_" }

        # Parmak izini cek ve istenirse karsilastir
        $fbActual = ""
        $mm = $certOut | Select-String -Pattern "SHA256:\s*([0-9A-Fa-f:]+)" | Select-Object -First 1
        if ($mm) { $fbActual = $mm.Matches[0].Groups[1].Value.ToUpper() }

        if ($Expected -and $fbActual) {
            $ne = ($Expected  -replace '[: ]','').Trim().ToUpper()
            $na = ($fbActual  -replace '[: ]','').Trim().ToUpper()
            Write-Host ""
            if ($ne -eq $na) {
                Write-Host "  [OK] Parmak izi ESLESTI" -ForegroundColor Green -NoNewline
                Write-Host " - sertifika senin keystore'undan."
            } else {
                Write-Bad "Parmak izi ESLESMEDI!"
                Write-Host "    beklenen: $ne"
                Write-Host "    bulunan : $na"
                Write-Host "  Bu APK BASKA bir anahtarla imzalanmis. Dagitma." -ForegroundColor Red
                exit 3
            }
        }

        if ($certOut -match "psychport|psychengine") {
            Write-Host ""
            Write-Warn "Bu APK hala public upstream 'psychport' anahtariyla imzali gorunuyor."
            Write-Host "  Project.xml'deki <certificate> satiri kaldirilmamis olabilir."
        }

        Write-Host ""
        Write-Warn "Bu sadece sertifikayi gosterir; imzanin APK icerigiyle"
        Write-Warn "eslesip eslesmedigini dogrulamaz. Tam dogrulama icin apksigner gerekli."
        Write-Host "  Android SDK build-tools kurmak icin: Android Studio > SDK Manager"
    } finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
    exit 0
}

# ─────────────────────────────────────────────────────────────
# Tam dogrulama
# ─────────────────────────────────────────────────────────────
$verifyOut = & $apksigner verify --verbose --print-certs $Apk 2>&1
$verifyCode = $LASTEXITCODE

$verifyOut | ForEach-Object { Write-Host "  $_" }

if ($verifyCode -ne 0) {
    Write-Host ""
    Write-Bad "DOGRULAMA BASARISIZ - APK imzasiz veya imza bozuk."
    exit 2
}

Write-Host ""
Write-Ok "Imza gecerli"

# SHA-256 cek
$actual = ""
$m = $verifyOut | Select-String -Pattern "SHA-256 digest:\s*([0-9a-fA-F]+)" | Select-Object -First 1
if ($m) { $actual = $m.Matches[0].Groups[1].Value.ToUpper() }

if ($actual) {
    Write-Host "  SHA-256: $actual"
}

# ─────────────────────────────────────────────────────────────
# Parmak izi karsilastirmasi
# ─────────────────────────────────────────────────────────────
if ($Expected) {
    $normExp = ($Expected -replace '[: ]','').Trim().ToUpper()
    $normAct = ($actual   -replace '[: ]','').Trim().ToUpper()
    Write-Host ""
    if ($normExp -eq $normAct -and $normAct -ne "") {
        Write-Host "  [OK] Parmak izi ESLESTI" -ForegroundColor Green -NoNewline
        Write-Host " - bu APK senin keystore'unla imzalanmis."
    } else {
        Write-Bad "Parmak izi ESLESMEDI!"
        Write-Host "    beklenen: $normExp"
        Write-Host "    bulunan : $normAct"
        Write-Host "  Bu APK BASKA bir anahtarla imzalanmis. Dagitma." -ForegroundColor Red
        exit 3
    }
}

# ─────────────────────────────────────────────────────────────
# Public upstream key uyarisi
# ─────────────────────────────────────────────────────────────
if ($verifyOut -match "psychport|psychengine|PsychEngine") {
    Write-Host ""
    Write-Warn "Bu APK hala public upstream 'psychport' anahtariyla imzali gorunuyor."
    Write-Host "  Project.xml'deki <certificate> satiri kaldirilmamis olabilir."
    Write-Host "  Cozum: python apply-patch.py <repo>"
}

Write-Host ""
