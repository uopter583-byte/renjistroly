#!/usr/bin/env bash
# Build, test, sign, install, and smoke-check a local RenJistroly release candidate.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f "$ROOT/version.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/version.env"
fi

APP_NAME="${APP_NAME:-RenJistroly}"
BUNDLE_ID="${BUNDLE_ID:-com.renjistroly.app}"
MARKETING_VERSION="${MARKETING_VERSION:-${APP_VERSION:-0.2.0}}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
APP_BUNDLE="${ROOT}/${APP_NAME}.app"
INSTALLED_APP_BUNDLE="${HOME}/Applications/${APP_NAME}.app"
ARCHES_VALUE="${ARCHES:-$(uname -m)}"
RUN_TESTS=1
RUN_MANUAL_TESTS_GATE=1
INSTALL_APP=1
LAUNCH_APP=1
FORCE_ADHOC=0

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --skip-tests          Skip normal swift test.
  --skip-manual-tests   Skip RUN_MANUAL_TESTS=1 swift test.
  --no-install          Do not replace ~/Applications/${APP_NAME}.app.
  --no-launch           Do not launch the installed app.
  --adhoc               Force ad-hoc signing even if a local identity exists.
  --universal           Build arm64 x86_64.
  --arches="..."        Build the given architectures.
  -h, --help            Show this help.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --skip-tests) RUN_TESTS=0 ;;
    --skip-manual-tests) RUN_MANUAL_TESTS_GATE=0 ;;
    --no-install) INSTALL_APP=0 ;;
    --no-launch) LAUNCH_APP=0 ;;
    --adhoc) FORCE_ADHOC=1 ;;
    --universal) ARCHES_VALUE="arm64 x86_64" ;;
    --arches=*) ARCHES_VALUE="${arg#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $arg" ;;
  esac
done

select_identity() {
  [[ "$FORCE_ADHOC" == "1" ]] && return 1
  [[ -n "${APP_IDENTITY:-}" ]] && { printf '%s\n' "$APP_IDENTITY"; return 0; }

  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  local pattern
  for pattern in "Developer ID Application" "Apple Distribution" "Apple Development"; do
    if grep -q "$pattern" <<<"$identities"; then
      grep "$pattern" <<<"$identities" | head -1 | sed 's/.*"\(.*\)".*/\1/'
      return 0
    fi
  done
  return 1
}

verify_bundle() {
  local app="$1"
  [[ -d "$app" ]] || fail "Missing app bundle: $app"

  codesign --verify --deep --strict --verbose=2 "$app"

  local signature identifier plist_id
  signature="$(codesign -dv --entitlements :- "$app" 2>&1)"
  identifier="$(sed -n 's/^Identifier=//p' <<<"$signature" | head -1)"
  plist_id="$(plutil -extract CFBundleIdentifier raw "$app/Contents/Info.plist")"

  [[ "$identifier" == "$BUNDLE_ID" ]] || fail "codesign identifier mismatch: $identifier"
  [[ "$plist_id" == "$BUNDLE_ID" ]] || fail "Info.plist bundle id mismatch: $plist_id"
  grep -q "com.apple.security.accessibility" <<<"$signature" || fail "Missing accessibility entitlement"
  grep -q "com.apple.security.device.audio-input" <<<"$signature" || fail "Missing microphone entitlement"

  if ! spctl --assess --type execute --verbose "$app" >/tmp/renjistroly-spctl.log 2>&1; then
    warn "spctl assessment did not accept this local build:"
    sed -n '1,8p' /tmp/renjistroly-spctl.log >&2
  fi
}

install_and_launch() {
  mkdir -p "$(dirname "$INSTALLED_APP_BUNDLE")"
  if pgrep -f "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" >/dev/null 2>&1; then
    log "==> Quit running ${APP_NAME}"
    osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
    sleep 1
    pkill -f "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
  fi

  log "==> Install ${APP_NAME}.app to ~/Applications"
  rm -rf "$INSTALLED_APP_BUNDLE"
  ditto "$APP_BUNDLE" "$INSTALLED_APP_BUNDLE"
  verify_bundle "$INSTALLED_APP_BUNDLE"

  [[ "$LAUNCH_APP" == "1" ]] || return 0
  log "==> Launch installed app"
  open "$INSTALLED_APP_BUNDLE"
  for _ in {1..20}; do
    if pgrep -f "${INSTALLED_APP_BUNDLE}/Contents/MacOS/${APP_NAME}" >/dev/null 2>&1; then
      log "OK: ${APP_NAME} is running from ${INSTALLED_APP_BUNDLE}"
      return 0
    fi
    sleep 0.5
  done
  fail "App did not stay running after launch"
}

if [[ "$RUN_TESTS" == "1" ]]; then
  log "==> swift test"
  swift test --scratch-path /private/tmp/renjistroly-rc-test
fi

if [[ "$RUN_MANUAL_TESTS_GATE" == "1" ]]; then
  log "==> RUN_MANUAL_TESTS=1 swift test"
  RUN_MANUAL_TESTS=1 swift test --scratch-path /private/tmp/renjistroly-rc-manual-test
fi

if identity="$(select_identity)"; then
  log "==> Package signed with identity: ${identity}"
  SIGNING_MODE=development \
    APP_IDENTITY="$identity" \
    ARCHES="$ARCHES_VALUE" \
    MARKETING_VERSION="$MARKETING_VERSION" \
    BUILD_NUMBER="$BUILD_NUMBER" \
    CONF=release \
    "$ROOT/Scripts/package_app.sh"
else
  warn "No code signing identity found; falling back to ad-hoc signing."
  SIGNING_MODE=adhoc \
    ARCHES="$ARCHES_VALUE" \
    MARKETING_VERSION="$MARKETING_VERSION" \
    BUILD_NUMBER="$BUILD_NUMBER" \
    CONF=release \
    "$ROOT/Scripts/package_app.sh"
fi

log "==> Verify packaged app"
verify_bundle "$APP_BUNDLE"

if [[ "$INSTALL_APP" == "1" ]]; then
  install_and_launch
fi

log "Done: local release candidate is ready."
