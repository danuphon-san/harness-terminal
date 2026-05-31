#!/usr/bin/env bash
set -euo pipefail
# Sign and notarize Harness.app for distribution.
#
# Required:
#   SIGNING_IDENTITY  — e.g. "Developer ID Application: Your Name (TEAMID)"
#
# Optional (omit to sign only, skip notarization):
#   APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD (app-specific password)
#
# Usage: make sign   or   ./Scripts/sign-and-notarize.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/Harness.app"
# Require an explicit identity so a release is never signed with the wrong or
# ambiguous one. Use SIGNING_IDENTITY=- for an ad-hoc (unsigned) local build.
IDENTITY="${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID (or '-' for an ad-hoc local build).}"

if [[ ! -d "$APP" ]]; then
  echo "Run Scripts/build-release.sh first." >&2
  exit 1
fi

echo "Signing $APP..."
# Sign inside-out (NOT --deep). Sparkle ships nested helpers — XPC services, Updater.app,
# and the Autoupdate tool — that each need their own hardened-runtime signature. `--deep`
# signs them with the app's identity but not correctly (Sparkle explicitly forbids it), so
# the updater is rejected at runtime. Sign the deepest components first, then the framework,
# then the embedded tools, then the app bundle.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE" ]]; then
  echo "  Signing Sparkle.framework components..."
  # XPC services and helper apps/tools live under Versions/<letter>; glob so a version
  # bump (B -> C ...) keeps working.
  for component in \
    "$SPARKLE"/Versions/*/XPCServices/*.xpc \
    "$SPARKLE"/Versions/*/Updater.app \
    "$SPARKLE"/Versions/*/Autoupdate; do
    [[ -e "$component" ]] || continue
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$component"
  done
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$SPARKLE"
fi

codesign --force --options runtime --timestamp --sign "$IDENTITY" \
  "$APP/Contents/MacOS/HarnessDaemon" \
  "$APP/Contents/MacOS/harness-cli" \
  "$APP/Contents/MacOS/Harness"
# Seal the app bundle last (no --deep — nested code is already signed above).
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"

if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_PASSWORD:-}" ]]; then
  echo "Set APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD to notarize."
  exit 0
fi

ZIP="$ROOT/Harness-notarize.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait
xcrun stapler staple "$APP"
echo "Notarized and stapled."
