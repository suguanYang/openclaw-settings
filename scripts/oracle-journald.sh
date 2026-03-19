#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_HOST="${OPENCLAW_HOST:-oracle.ylioo.com}" \
OPENCLAW_JOURNALD_CONFIG_PATH="${OPENCLAW_JOURNALD_CONFIG_PATH:-$ROOT/build/oracle.ylioo.com/rootfs/etc/systemd/journald.conf.d/50-openclaw-journal-size.conf}" \
exec "$ROOT/scripts/journald-host.sh" "$@"
