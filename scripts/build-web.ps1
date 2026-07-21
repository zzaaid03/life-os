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

$OutputPath = Join-Path (Get-Location) "build\web"
Write-Host "Build output: $OutputPath"
Write-Host "The bundle at build/web is deployed by the GitHub Actions workflow (.github/workflows/deploy.yml)."
