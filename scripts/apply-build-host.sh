#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST=""
BUILD_DIR=""
SECRETS_FILE=""
LOG_DIR="$ROOT/operation-logs"

usage() {
  cat <<'USAGE'
Usage: ./scripts/apply-build-host.sh --host <ssh-host> [--build-dir <build/host>] --secrets-file <.secrets/host.env>

Renders the tracked build rootfs locally, uploads it to the target host,
reinstalls/repairs the gateway with pnpm + Node, and records all host interactions
in operation-logs/<date>-<host>.md.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      HOST="$2"
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
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$HOST" ] || [ -z "$SECRETS_FILE" ]; then
  usage >&2
  exit 1
fi

if [ -z "$BUILD_DIR" ]; then
  BUILD_DIR="$ROOT/build/$HOST"
fi

if [ ! -d "$BUILD_DIR/rootfs" ]; then
  echo "missing build rootfs: $BUILD_DIR/rootfs" >&2
  exit 1
fi

LOG_FILE="$LOG_DIR/$(date -u +%F)-${HOST}.md"
mkdir -p "$LOG_DIR"
if [ ! -f "$LOG_FILE" ]; then
  {
    printf '# Host Operation Log\n\n'
    printf -- '- Host: `%s`\n' "$HOST"
    printf -- '- Date (UTC): `%s`\n' "$(date -u +%F)"
    printf -- '- Recorder: `scripts/apply-build-host.sh`\n'
  } > "$LOG_FILE"
fi

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

append_log() {
  local action="$1"
  local cmd="$2"
  local status="$3"
  local output_file="$4"

  {
    printf '\n## %s | %s | exit=%s\n\n' "$(timestamp_utc)" "$action" "$status"
    printf 'Command:\n```sh\n%s\n```\n\n' "$cmd"
    printf 'Output:\n```text\n'
    cat "$output_file"
    printf '\n```\n'
  } >> "$LOG_FILE"
}

quote_cmd() {
  local quoted=""
  local part
  for part in "$@"; do
    quoted+=" $(printf '%q' "$part")"
  done
  printf '%s' "${quoted# }"
}

run_logged_local() {
  local action="$1"
  shift

  local tmp
  local status=0
  local cmd_string
  tmp="$(mktemp)"
  cmd_string="$(quote_cmd "$@")"

  if "$@" >"$tmp" 2>&1; then
    status=0
  else
    status=$?
  fi

  cat "$tmp"
  append_log "$action" "$cmd_string" "$status" "$tmp"
  rm -f "$tmp"
  return "$status"
}

run_logged_remote_script() {
  local action="$1"
  local script="$2"

  local tmp
  local status=0
  local cmd_string
  tmp="$(mktemp)"
  cmd_string=$(printf "ssh %q 'bash -s' <<'REMOTE'\n%s\nREMOTE" "$HOST" "$script")

  if ssh "$HOST" 'bash -s' >"$tmp" 2>&1 <<<"$script"; then
    status=0
  else
    status=$?
  fi

  cat "$tmp"
  append_log "$action" "$cmd_string" "$status" "$tmp"
  rm -f "$tmp"
  return "$status"
}

upload_rootfs_to_remote() {
  local action="$1"
  local src_dir="$2"

  local tmp
  local status=0
  tmp="$(mktemp)"

  if tar -cf - -C "$src_dir" . | ssh "$HOST" "tar -xf - -C /" >"$tmp" 2>&1; then
    status=0
  else
    status=$?
  fi

  cat "$tmp"
  append_log "$action" "tar -cf - -C $(printf '%q' "$src_dir") . | ssh $(printf '%q' "$HOST") tar -xf - -C /" "$status" "$tmp"
  rm -f "$tmp"
  return "$status"
}

build_name="$(basename "$BUILD_DIR")"
render_dir="$ROOT/.tmp/rendered-build/$build_name"

run_logged_local \
  "render-build-state" \
  "$ROOT/scripts/render-build-state.sh" \
  --build-dir "$BUILD_DIR" \
  --secrets-file "$SECRETS_FILE" \
  --out-dir "$render_dir"

upload_rootfs_to_remote "upload-build-rootfs" "$render_dir"

remote_install_script=$(cat <<'REMOTE'
set -euo pipefail

ensure_node_on_path() {
  if command -v node >/dev/null 2>&1; then
    return 0
  fi

  service="$HOME/.config/systemd/user/openclaw-gateway.service"
  if [ -f "$service" ]; then
    exec_start="$(sed -n 's/^ExecStart=//p' "$service" | head -n 1)"
    if [ -n "$exec_start" ]; then
      node_bin="${exec_start%% *}"
      if [ -x "$node_bin" ]; then
        export PATH="$(dirname "$node_bin"):$PATH"
      fi
    fi
  fi

  if command -v node >/dev/null 2>&1; then
    return 0
  fi

  if [ -s "$HOME/.nvm/nvm.sh" ]; then
    # shellcheck disable=SC1090
    . "$HOME/.nvm/nvm.sh"
    nvm use >/dev/null 2>&1 || true
  fi
}

ensure_node_on_path
if ! command -v node >/dev/null 2>&1; then
  echo "missing node; install Node 22+ before applying tracked OpenClaw build state" >&2
  exit 1
fi

export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
mkdir -p "$PNPM_HOME"
export PATH="$PNPM_HOME:$PATH"

if ! command -v pnpm >/dev/null 2>&1; then
  if command -v corepack >/dev/null 2>&1; then
    corepack enable >/dev/null 2>&1 || true
    corepack prepare pnpm@latest --activate
  elif command -v npm >/dev/null 2>&1; then
    npm install -g pnpm
  else
    echo "missing pnpm and no corepack/npm fallback available" >&2
    exit 1
  fi
fi

hash -r
pnpm add -g openclaw@latest
hash -r

openclaw_bin="$(command -v openclaw || true)"
if [ -z "$openclaw_bin" ] && [ -x "$PNPM_HOME/openclaw" ]; then
  openclaw_bin="$PNPM_HOME/openclaw"
fi

if [ -z "$openclaw_bin" ]; then
  echo "openclaw binary not found after pnpm install" >&2
  exit 1
fi

"$openclaw_bin" gateway install --runtime node --force
"$openclaw_bin" doctor --repair
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway.service
sleep 5
"$openclaw_bin" health
systemctl --user status openclaw-gateway.service --no-pager | sed -n '1,120p'
REMOTE
)

run_logged_remote_script "install-build-openclaw" "$remote_install_script"
