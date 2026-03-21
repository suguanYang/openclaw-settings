#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_HOST="${OPENCLAW_SHORTCUT_HOST:-}"
DEFAULT_LOG_TITLE="${OPENCLAW_SHORTCUT_LOG_TITLE:-}"
DEFAULT_LOG_RECORDER="${OPENCLAW_SHORTCUT_LOG_RECORDER:-}"

ensure_shortcut_defaults() {
  if [ -z "$DEFAULT_HOST" ]; then
    echo "missing OPENCLAW_SHORTCUT_HOST" >&2
    exit 1
  fi

  if [ -z "$DEFAULT_LOG_TITLE" ]; then
    echo "missing OPENCLAW_SHORTCUT_LOG_TITLE" >&2
    exit 1
  fi

  if [ -z "$DEFAULT_LOG_RECORDER" ]; then
    echo "missing OPENCLAW_SHORTCUT_LOG_RECORDER" >&2
    exit 1
  fi
}

ensure_shortcut_defaults

OPENCLAW_HOST="${OPENCLAW_HOST:-$DEFAULT_HOST}" \
OPENCLAW_LOG_TITLE="${OPENCLAW_LOG_TITLE:-$DEFAULT_LOG_TITLE}" \
OPENCLAW_LOG_RECORDER="${OPENCLAW_LOG_RECORDER:-$DEFAULT_LOG_RECORDER}" \
exec "$ROOT/scripts/openclaw-host.sh" "$@"
