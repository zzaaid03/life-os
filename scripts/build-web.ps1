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
# Keep in sync with build-web.sh (CI uses that one). --no-web-resources-cdn
# serves CanvasKit from our own domain instead of www.gstatic.com.
flutter build web --release --no-web-resources-cdn --dart-define=APP_ENV=$Env

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

# Version the local CanvasKit folder by engine revision (see build-web.sh).
$Bootstrap = Get-Content $BootstrapPath -Raw
if ($Bootstrap -notmatch '"engineRevision":"([0-9a-f]{10})') {
    Write-Error "engineRevision not found in flutter_bootstrap.js"
    exit 1
}
$Engine = $Matches[1]
Rename-Item "build\web\canvaskit" "canvaskit-$Engine"
$Bootstrap = $Bootstrap.Replace('_flutter.loader.load({', "_flutter.loader.load({ config: { canvasKitBaseUrl: `"canvaskit-$Engine/`" },")
if (-not $Bootstrap.Contains("canvasKitBaseUrl: `"canvaskit-$Engine/`"")) {
    Write-Error "could not point the loader at canvaskit-$Engine/"
    exit 1
}
$Bootstrap | Set-Content $BootstrapPath -NoNewline
Write-Host "CanvasKit served from canvaskit-$Engine/"

$OutputPath = Join-Path (Get-Location) "build\web"
Write-Host "Build output: $OutputPath"
Write-Host "The bundle at build/web is deployed by the GitHub Actions workflow (.github/workflows/deploy.yml)."
