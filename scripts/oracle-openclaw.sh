#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_SHORTCUT_HOST="${OPENCLAW_SHORTCUT_HOST:-oracle.ylioo.com}" \
OPENCLAW_SHORTCUT_LOG_TITLE="${OPENCLAW_SHORTCUT_LOG_TITLE:-Oracle OpenClaw Operation Log}" \
OPENCLAW_SHORTCUT_LOG_RECORDER="${OPENCLAW_SHORTCUT_LOG_RECORDER:-scripts/oracle-openclaw.sh}" \
OPENCLAW_SERVICE_MANAGER="${OPENCLAW_SERVICE_MANAGER:-systemd}" \
exec "$ROOT/scripts/openclaw-host-shortcut.sh" "$@"
