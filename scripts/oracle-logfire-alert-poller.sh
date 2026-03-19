#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_HOST="${OPENCLAW_HOST:-oracle.ylioo.com}" \
OPENCLAW_LOG_TITLE="${OPENCLAW_LOG_TITLE:-Oracle Logfire Alert Poller Operation Log}" \
OPENCLAW_LOG_RECORDER="${OPENCLAW_LOG_RECORDER:-scripts/oracle-logfire-alert-poller.sh}" \
exec "$ROOT/scripts/logfire-alert-poller-host.sh" "$@"
