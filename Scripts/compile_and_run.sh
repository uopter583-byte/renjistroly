#!/usr/bin/env bash
# Kill running instances, package, relaunch, verify.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$ROOT_DIR/version.env" ]]; then
  source "$ROOT_DIR/version.env"
fi
APP_NAME=${APP_NAME:-RenJistroly}
APP_BUNDLE="${ROOT_DIR}/${APP_NAME}.app"
INSTALLED_APP_BUNDLE="${HOME}/Applications/${APP_NAME}.app"
APP_PROCESS_PATTERN="${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
DEBUG_PROCESS_PATTERN="${ROOT_DIR}/.build/debug/${APP_NAME}"
RELEASE_PROCESS_PATTERN="${ROOT_DIR}/.build/release/${APP_NAME}"
RUN_TESTS=0
RELEASE_ARCHES=""

log() { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

for arg in "$@"; do
  case "${arg}" in
    --test|-t) RUN_TESTS=1 ;;
    --release-universal) RELEASE_ARCHES="arm64 x86_64" ;;
    --release-arches=*) RELEASE_ARCHES="${arg#*=}" ;;
    --help|-h)
      log "Usage: $(basename "$0") [--test] [--release-universal] [--release-arches=\"arm64 x86_64\"]"
      exit 0
      ;;
  esac
done

log "==> Killing existing ${APP_NAME} instances"
pkill -f "${APP_PROCESS_PATTERN}" 2>/dev/null || true
pkill -f "${DEBUG_PROCESS_PATTERN}" 2>/dev/null || true
pkill -f "${RELEASE_PROCESS_PATTERN}" 2>/dev/null || true
pkill -x "${APP_NAME}" 2>/dev/null || true

if [[ "${RUN_TESTS}" == "1" ]]; then
  SCRATCH_PATH="${SCRATCH_PATH:-/private/tmp/renjistroly-test}"
  log "==> swift test (scratch: $SCRATCH_PATH)"
  swift test --scratch-path "$SCRATCH_PATH" -q
fi

HOST_ARCH="$(uname -m)"
ARCHES_VALUE="${HOST_ARCH}"
if [[ -n "${RELEASE_ARCHES}" ]]; then
  ARCHES_VALUE="${RELEASE_ARCHES}"
fi

log "==> package app"
if security find-identity -v -p basic 2>/dev/null | grep -q "Apple Development"; then
  APP_IDENTITY=$(security find-identity -v -p basic 2>/dev/null | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)".*/\1/')
  SIGNING_MODE=development APP_IDENTITY="$APP_IDENTITY" ARCHES="${ARCHES_VALUE}" "${ROOT_DIR}/Scripts/package_app.sh" release
else
  SIGNING_MODE=adhoc ARCHES="${ARCHES_VALUE}" "${ROOT_DIR}/Scripts/package_app.sh" release
fi
# Also install to ~/Applications/ so the user always runs the right version
rm -rf "${INSTALLED_APP_BUNDLE}" 2>/dev/null
cp -R "${APP_BUNDLE}" "${INSTALLED_APP_BUNDLE}"

log "==> launch app"
if ! open "${INSTALLED_APP_BUNDLE}"; then
  log "WARN: open failed; launching binary directly."
  "${INSTALLED_APP_BUNDLE}/Contents/MacOS/${APP_NAME}" >/dev/null 2>&1 &
  disown
fi

for _ in {1..10}; do
  if pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1; then
    log "OK: ${APP_NAME} is running."
    exit 0
  fi
  sleep 0.4
done
fail "App exited immediately. Check crash logs in Console.app (User Reports)."
