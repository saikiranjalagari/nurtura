# Build Nurtura Android release for production (mobile-only).
#
# Usage:
#   .\deploy-mobile.ps1 -ApiBaseUrl "https://nurtura-api.onrender.com/api"
#   .\deploy-mobile.ps1 -ApiBaseUrl "https://nurtura-api.onrender.com/api" -BuildType appbundle

param(
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl,

    [ValidateSet("apk", "appbundle")]
    [string]$BuildType = "apk"
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$keyProps = Join-Path $root "android\key.properties"
$keystore = Join-Path $root "android\app\nurtura-release.jks"

if (-not (Test-Path $keystore)) {
    Write-Host "Creating release keystore (first run only)..." -ForegroundColor Yellow
    $dname = "CN=Nurtura, OU=Mobile, O=Nurtura, L=Unknown, ST=Unknown, C=US"
    keytool -genkeypair -v `
        -keystore $keystore `
        -alias nurtura `
        -keyalg RSA -keysize 2048 -validity 10000 `
        -storepass nurtura2026 -keypass nurtura2026 `
        -dname $dname
}

if (-not (Test-Path $keyProps)) {
    @"
storePassword=nurtura2026
keyPassword=nurtura2026
keyAlias=nurtura
storeFile=nurtura-release.jks
"@ | Set-Content -Path $keyProps -Encoding UTF8
    Write-Host "Created android/key.properties" -ForegroundColor Green
}

Write-Host ""
Write-Host "Building Nurtura for Android ($BuildType)..." -ForegroundColor Cyan
Write-Host "API: $ApiBaseUrl"
Write-Host ""

Push-Location $root
try {
    flutter pub get
    if ($BuildType -eq "appbundle") {
        flutter build appbundle --release --dart-define=API_BASE_URL=$ApiBaseUrl
        $out = "build\app\outputs\bundle\release\app-release.aab"
    } else {
        flutter build apk --release --dart-define=API_BASE_URL=$ApiBaseUrl
        $out = "build\app\outputs\flutter-apk\app-release.apk"
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "Build complete!" -ForegroundColor Green
Write-Host "Output: $out"
Write-Host ""
Write-Host "Install APK on phone:" -ForegroundColor Cyan
Write-Host "  adb install $out"
Write-Host ""
Write-Host "Play Store upload:" -ForegroundColor Cyan
Write-Host "  Upload the .aab to https://play.google.com/console"
Write-Host "  Application ID: com.nurtura.app"
