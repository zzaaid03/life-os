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
# --no-web-resources-cdn: serve CanvasKit from our own domain instead of
# www.gstatic.com. Privacy browsers (DuckDuckGo, Brave) and content blockers
# refuse Google domains, and without CanvasKit the app is a blank page.
flutter build web --release --no-web-resources-cdn --dart-define=APP_ENV="$ENV"

STAMP="$(git rev-parse --short HEAD 2>/dev/null || date +%s)"
echo "Cache-busting with stamp: $STAMP"
sed -i "s/src=\"flutter_bootstrap.js\"/src=\"flutter_bootstrap.js?v=$STAMP\"/" build/web/index.html
sed -i "s/main\.dart\.js/main.dart.js?v=$STAMP/g" build/web/flutter_bootstrap.js

# The local CanvasKit lives at an unversioned /canvaskit/ path, so a browser
# could pair a cached old engine with new app code after a Flutter upgrade.
# Move it under the engine revision (the CDN does the same) so it stays
# cached across normal deploys and changes URL only when Flutter does.
ENGINE="$(grep -o '"engineRevision":"[0-9a-f]*"' build/web/flutter_bootstrap.js | grep -o '[0-9a-f]\{10,\}' | cut -c1-10)"
if [[ -z "$ENGINE" ]]; then
    echo "ERROR: engineRevision not found in flutter_bootstrap.js" >&2
    exit 1
fi
mv build/web/canvaskit "build/web/canvaskit-$ENGINE"
sed -i "s|_flutter.loader.load({|_flutter.loader.load({ config: { canvasKitBaseUrl: \"canvaskit-$ENGINE/\" },|" build/web/flutter_bootstrap.js
# sed exits 0 on zero matches; fail loudly instead of shipping a bundle
# that looks for an engine folder that no longer exists.
if ! grep -q "canvasKitBaseUrl: \"canvaskit-$ENGINE/\"" build/web/flutter_bootstrap.js; then
    echo "ERROR: could not point the loader at canvaskit-$ENGINE/" >&2
    exit 1
fi
echo "CanvasKit served from canvaskit-$ENGINE/"

echo "Build output: $(pwd)/build/web"
echo "The bundle at build/web is deployed by the GitHub Actions workflow (.github/workflows/deploy.yml)."
