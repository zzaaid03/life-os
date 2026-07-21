#!/usr/bin/env bash
# Builds the Flutter web release bundle for the given environment.
# Usage: scripts/build-web.sh [stable|staging]   (defaults to stable)
set -euo pipefail

ENV="${1:-stable}"

if [[ "$ENV" != "stable" && "$ENV" != "staging" ]]; then
    echo "Usage: $0 [stable|staging]" >&2
    exit 1
fi

if [[ ! -f .env ]]; then
    echo "WARNING: .env not found in repo root. It is required (pubspec.yaml assets)" >&2
    echo "and holds SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, GOOGLE_CLIENT_ID." >&2
fi

echo "Building web release for APP_ENV=$ENV ..."
flutter build web --release --dart-define=APP_ENV="$ENV"

echo "Build output: $(pwd)/build/web"
echo "The bundle at build/web is deployed by the GitHub Actions workflow (.github/workflows/deploy.yml)."
