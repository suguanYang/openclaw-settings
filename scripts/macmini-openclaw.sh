#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_SHORTCUT_HOST="${OPENCLAW_SHORTCUT_HOST:-macmini.openclaw}" \
OPENCLAW_SHORTCUT_LOG_TITLE="${OPENCLAW_SHORTCUT_LOG_TITLE:-Macmini OpenClaw Operation Log}" \
OPENCLAW_SHORTCUT_LOG_RECORDER="${OPENCLAW_SHORTCUT_LOG_RECORDER:-scripts/macmini-openclaw.sh}" \
OPENCLAW_SERVICE_MANAGER="${OPENCLAW_SERVICE_MANAGER:-launchd}" \
OPENCLAW_LAUNCHD_LABEL="${OPENCLAW_LAUNCHD_LABEL:-ai.openclaw.gateway}" \
exec "$ROOT/scripts/openclaw-host-shortcut.sh" "$@"
