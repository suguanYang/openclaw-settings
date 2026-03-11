#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST=""
PROFILE=""
BUILD_DIR=""
SECRETS_FILE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      HOST="$2"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --build-dir)
      BUILD_DIR="$2"
      shift 2
      ;;
    --secrets-file)
      SECRETS_FILE="$2"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

if [ -z "$BUILD_DIR" ]; then
  if [ -n "$HOST" ]; then
    BUILD_DIR="$ROOT/build/$HOST"
  elif [ -n "$PROFILE" ]; then
    BUILD_DIR="$ROOT/build/$(basename "$PROFILE" .env)"
  else
    echo "apply-managed-host.sh is deprecated; use ./scripts/apply-build-host.sh --host <ssh-host> --secrets-file <.secrets/host.env>" >&2
    exit 1
  fi
fi

args=(
  --build-dir "$BUILD_DIR"
  --secrets-file "$SECRETS_FILE"
)

if [ -n "$HOST" ]; then
  args=(--host "$HOST" "${args[@]}")
fi

exec "$ROOT/scripts/apply-build-host.sh" "${args[@]}"
