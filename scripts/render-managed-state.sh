#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE=""
BUILD_DIR=""
SECRETS_FILE=""
OUT_DIR=""

while [ "$#" -gt 0 ]; do
  case "$1" in
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
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

if [ -z "$BUILD_DIR" ]; then
  if [ -n "$PROFILE" ]; then
    BUILD_DIR="$ROOT/build/$(basename "$PROFILE" .env)"
  else
    echo "render-managed-state.sh is deprecated; use ./scripts/render-build-state.sh --build-dir <build/host> --secrets-file <.secrets/host.env>" >&2
    exit 1
  fi
fi

args=(
  --build-dir "$BUILD_DIR"
  --secrets-file "$SECRETS_FILE"
)

if [ -n "$OUT_DIR" ]; then
  args+=(--out-dir "$OUT_DIR")
fi

exec "$ROOT/scripts/render-build-state.sh" "${args[@]}"
