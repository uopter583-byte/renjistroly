#!/usr/bin/env bash
# Build, sign, notarize, staple, and verify a Developer ID release.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f "$ROOT/version.env" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT/version.env"
fi

APP_NAME="${APP_NAME:-RenJistroly}"
APP_VERSION="${APP_VERSION:-0.2.0}"
APP_PATH="$ROOT/${APP_NAME}.app"
DMG_PATH="$ROOT/${APP_NAME}-${APP_VERSION}.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-RenJistrolyNotary}"
INSTALL_PATH="${INSTALL_PATH:-$HOME/Applications/${APP_NAME}.app}"

find_identity() {
  security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application: .* (.*)\)".*/\1/p' \
    | head -n 1
}

APP_IDENTITY="${APP_IDENTITY:-$(find_identity)}"
if [[ -z "$APP_IDENTITY" ]]; then
  echo "ERROR: No Developer ID Application identity found. Import the certificate first." >&2
  exit 1
fi

echo "==> Using identity: $APP_IDENTITY"
echo "==> Using notary profile: $NOTARY_PROFILE"

echo "==> Building and signing app..."
SIGNING_MODE=devid APP_IDENTITY="$APP_IDENTITY" CONF="${CONF:-release}" "$ROOT/Scripts/package_app.sh"

echo "==> Notarizing app..."
ZIP_PATH="$ROOT/${APP_NAME}_notarize.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
rm -f "$ZIP_PATH"

echo "==> Creating signed DMG..."
APP_IDENTITY="$APP_IDENTITY" "$ROOT/Scripts/create-dmg.sh"

echo "==> Notarizing DMG..."
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "==> Verifying release artifacts..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign --verify --verbose=2 "$DMG_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
hdiutil verify "$DMG_PATH"

echo "==> Installing notarized app copy..."
rm -rf "$INSTALL_PATH"
mkdir -p "$(dirname "$INSTALL_PATH")"
ditto "$APP_PATH" "$INSTALL_PATH"
codesign --verify --deep --strict --verbose=2 "$INSTALL_PATH"
spctl --assess --type execute --verbose=4 "$INSTALL_PATH"

echo "==> SHA-256"
shasum -a 256 "$DMG_PATH"

echo "Done: $DMG_PATH"
