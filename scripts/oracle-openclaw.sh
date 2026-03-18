#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_HOST="${OPENCLAW_HOST:-oracle.ylioo.com}" \
OPENCLAW_LOG_TITLE="${OPENCLAW_LOG_TITLE:-Oracle OpenClaw Operation Log}" \
OPENCLAW_LOG_RECORDER="${OPENCLAW_LOG_RECORDER:-scripts/oracle-openclaw.sh}" \
exec "$ROOT/scripts/openclaw-host.sh" "$@"
