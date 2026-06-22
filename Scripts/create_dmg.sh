#!/usr/bin/env bash
# Compatibility wrapper. Prefer Scripts/create-dmg.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT/Scripts/create-dmg.sh" "$@"
