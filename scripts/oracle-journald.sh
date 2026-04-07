#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_HOST="${OPENCLAW_HOST:-oracle.ylioo.com}" \
exec "$ROOT/scripts/journald-host.sh" "$@"
