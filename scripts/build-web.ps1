# Builds the Flutter web release bundle for the given environment.
# Usage: scripts/build-web.ps1 [stable|staging]   (defaults to stable)
param(
    [ValidateSet("stable", "staging")]
    [string]$Env = "stable"
)

if (-not (Test-Path ".env")) {
    Write-Warning ".env not found in repo root. It is required (pubspec.yaml assets) and holds SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, GOOGLE_CLIENT_ID."
}

Write-Host "Building web release for APP_ENV=$Env ..."
flutter build web --release --dart-define=APP_ENV=$Env

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

try {
    $Stamp = (git rev-parse --short HEAD 2>$null)
    if (-not $Stamp) { $Stamp = [string][DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
} catch {
    $Stamp = [string][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
}
Write-Host "Cache-busting with stamp: $Stamp"

$IndexPath = "build\web\index.html"
(Get-Content $IndexPath -Raw) -replace 'src="flutter_bootstrap\.js"', "src=`"flutter_bootstrap.js?v=$Stamp`"" | Set-Content $IndexPath -NoNewline

$BootstrapPath = "build\web\flutter_bootstrap.js"
(Get-Content $BootstrapPath -Raw) -replace 'main\.dart\.js', "main.dart.js?v=$Stamp" | Set-Content $BootstrapPath -NoNewline

$OutputPath = Join-Path (Get-Location) "build\web"
Write-Host "Build output: $OutputPath"
Write-Host "The bundle at build/web is deployed by the GitHub Actions workflow (.github/workflows/deploy.yml)."
