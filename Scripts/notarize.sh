#!/usr/bin/env bash
# Notarize RenJistroly.app with Apple and staple the ticket.
# Requires: APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD env vars or keychain profile.
#
# Setup (one-time):
#   xcrun notarytool store-credentials "RenJistrolyNotary"
#     --apple-id "your@email.com"
#     --team-id "ABCDE12345"
#     --password "@keychain:AC_PASSWORD"
#
# Usage:
#   ./Scripts/notarize.sh                    # use keychain profile
#   APPLE_ID=you@me.com APPLE_TEAM_ID=X APPLE_APP_PASSWORD=xxxx ./Scripts/notarize.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f "$ROOT/version.env" ]]; then
  source "$ROOT/version.env"
fi
APP_NAME="${APP_NAME:-RenJistroly}"
APP_PATH="${ROOT}/${APP_NAME}.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: ${APP_NAME}.app not found. Run Scripts/package_app.sh first with SIGNING_MODE=devid." >&2
  exit 1
fi

NOTARY_PROFILE="${NOTARY_PROFILE:-RenJistrolyNotary}"

# Check if we should use env vars or keychain profile
USE_KEYCHAIN=true
if [[ -n "${APPLE_ID:-}" ]] && [[ -n "${APPLE_TEAM_ID:-}" ]] && [[ -n "${APPLE_APP_PASSWORD:-}" ]]; then
  USE_KEYCHAIN=false
fi

echo "==> Creating zip for notarization..."
ZIP_PATH="${ROOT}/${APP_NAME}_notarize.zip"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Submitting to Apple notary service..."

if [[ "$USE_KEYCHAIN" == "true" ]]; then
  xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
else
  xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait
fi

echo "==> Staple notarization ticket to app..."
xcrun stapler staple "$APP_PATH"

echo "==> Verify stapling..."
xcrun stapler validate "$APP_PATH"

rm -f "$ZIP_PATH"
echo "Done: ${APP_PATH} is notarized and stapled."
