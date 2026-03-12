#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BOOTSTRAP_DIR="$ROOT/bootstrap/oracle.ylioo.com"
HOST=""
BUILD_DIR="$ROOT/build/oracle.ylioo.com"
SECRETS_FILE=""
LOG_DIR="$ROOT/operation-logs"

usage() {
  cat <<'USAGE'
Usage: ./bootstrap/oracle.ylioo.com/apply-build-host.sh --host <ssh-host> --secrets-file <.secrets/host.env> [--build-dir <build/host>]

Renders the tracked Oracle build tree locally, uploads it to another host,
uses the host-installed OpenClaw and pnpm when available, falls back to latest
install when missing, and performs host-specific preflight checks for the Oracle
deployment shape.
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

if [ ! -d "$BUILD_DIR/rootfs" ]; then
  echo "missing build rootfs: $BUILD_DIR/rootfs" >&2
  exit 1
fi

LOG_FILE="$LOG_DIR/$(date -u +%F)-${HOST}.md"

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

  if tar -cf - -C "$src_dir" . | ssh "$HOST" "tar --no-overwrite-dir -xf - -C /" >"$tmp" 2>&1; then
    status=0
  else
    status=$?
  fi

  cat "$tmp"
  append_log "$action" "tar -cf - -C $(printf '%q' "$src_dir") . | ssh $(printf '%q' "$HOST") tar --no-overwrite-dir -xf - -C /" "$status" "$tmp"
  rm -f "$tmp"
  return "$status"
}

mkdir -p "$LOG_DIR"
if [ ! -f "$LOG_FILE" ]; then
  {
    printf '# Host Operation Log\n\n'
    printf -- '- Host: `%s`\n' "$HOST"
    printf -- '- Date (UTC): `%s`\n' "$(date -u +%F)"
    printf -- '- Recorder: `bootstrap/oracle.ylioo.com/apply-build-host.sh`\n'
  } > "$LOG_FILE"
fi

render_dir="$ROOT/.tmp/bootstrap-rendered/$(basename "$BUILD_DIR")"

run_logged_local \
  "render-build-state" \
  "$BOOTSTRAP_DIR/render-build-state.sh" \
  --build-dir "$BUILD_DIR" \
  --secrets-file "$SECRETS_FILE" \
  --out-dir "$render_dir"

openclaw_json_path="$(find "$render_dir/home" -path '*/.openclaw/openclaw.json' -type f | head -n 1)"
if [ -z "$openclaw_json_path" ]; then
  echo "missing rendered openclaw.json under $render_dir/home/*/.openclaw/" >&2
  exit 1
fi

mapfile -t build_values < <(python3 - "$openclaw_json_path" <<'PY'
import json
import sys
from pathlib import Path

cfg = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(cfg.get("browser", {}).get("executablePath", ""))
print(cfg.get("agents", {}).get("defaults", {}).get("sandbox", {}).get("docker", {}).get("image", ""))
PY
)

BROWSER_COMPAT_PATH="${build_values[0]:-}"
SANDBOX_IMAGE="${build_values[1]:-}"

upload_rootfs_to_remote "upload-build-rootfs" "$render_dir"

browser_compat_path_q=$(printf '%q' "$BROWSER_COMPAT_PATH")
sandbox_image_q=$(printf '%q' "$SANDBOX_IMAGE")

remote_install_script=$(cat <<REMOTE
set -euo pipefail

BROWSER_COMPAT_PATH=$browser_compat_path_q
SANDBOX_IMAGE=$sandbox_image_q

ensure_node_on_path() {
  if command -v node >/dev/null 2>&1; then
    return 0
  fi

  service="\$HOME/.config/systemd/user/openclaw-gateway.service"
  if [ -f "\$service" ]; then
    exec_start="\$(sed -n 's/^ExecStart=//p' "\$service" | head -n 1)"
    if [ -n "\$exec_start" ]; then
      node_bin="\${exec_start%% *}"
      if [ -x "\$node_bin" ]; then
        export PATH="\$(dirname "\$node_bin"):\$PATH"
      fi
    fi
  fi

  if command -v node >/dev/null 2>&1; then
    return 0
  fi

  if [ -s "\$HOME/.nvm/nvm.sh" ]; then
    . "\$HOME/.nvm/nvm.sh"
    nvm use >/dev/null 2>&1 || true
  fi
}

ensure_pnpm() {
  export PNPM_HOME="\${PNPM_HOME:-\$HOME/.local/share/pnpm}"
  mkdir -p "\$PNPM_HOME"
  export PATH="\$PNPM_HOME:\$PATH"

  if command -v pnpm >/dev/null 2>&1; then
    hash -r
    return 0
  fi

  if command -v corepack >/dev/null 2>&1; then
    corepack enable >/dev/null 2>&1 || true
    corepack prepare pnpm@latest --activate
  elif command -v npm >/dev/null 2>&1; then
    npm install -g pnpm@latest
  else
    echo "missing pnpm and no corepack/npm fallback available" >&2
    exit 1
  fi

  hash -r
}

ensure_openclaw() {
  local pnpm_bin
  pnpm_bin="\$(command -v pnpm || true)"
  if [ -z "\$pnpm_bin" ] && [ -x "\$PNPM_HOME/pnpm" ]; then
    pnpm_bin="\$PNPM_HOME/pnpm"
  fi

  if [ -z "\$pnpm_bin" ]; then
    echo "pnpm binary not found after installation" >&2
    exit 1
  fi

  if command -v openclaw >/dev/null 2>&1; then
    command -v openclaw
    return 0
  fi

  "\$pnpm_bin" add -g openclaw@latest
  hash -r

  if command -v openclaw >/dev/null 2>&1; then
    command -v openclaw
    return 0
  fi

  if [ -x "\$PNPM_HOME/openclaw" ]; then
    printf '%s\n' "\$PNPM_HOME/openclaw"
    return 0
  fi

  echo "openclaw binary not found after installation" >&2
  exit 1
}

refresh_browser_compat_path() {
  local compat_path="\$BROWSER_COMPAT_PATH"
  local browser_root="\$HOME/.openclaw/tools/playwright-browsers"
  local resolved=""

  if [ -z "\$compat_path" ]; then
    return 0
  fi

  if [ -d "\$browser_root" ]; then
    resolved="\$(find "\$browser_root" -path '*/chrome-linux/chrome' -type f | sort | tail -n 1)"
  fi

  if [ -z "\$resolved" ]; then
    echo "warning: no Chromium binary found under \$browser_root after doctor --repair" >&2
    return 0
  fi

  if [ "\$resolved" = "\$compat_path" ]; then
    return 0
  fi

  mkdir -p "\$(dirname "\$compat_path")"
  ln -sfn "\$resolved" "\$compat_path"
}

ensure_docker_ready() {
  if [ -z "\$SANDBOX_IMAGE" ]; then
    return 0
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo "missing docker; install Docker or change the tracked sandbox image before applying this build" >&2
    exit 1
  fi

  if ! docker info >/dev/null 2>&1; then
    echo "docker is installed but not usable for \$USER; fix Docker access before relying on sandboxed agents" >&2
    exit 1
  fi

  if ! docker image inspect "\$SANDBOX_IMAGE" >/dev/null 2>&1; then
    echo "warning: sandbox image \$SANDBOX_IMAGE is not present locally yet; first sandboxed run may still need to pull/build it" >&2
  fi
}

ensure_node_on_path
if ! command -v node >/dev/null 2>&1; then
  echo "missing node; install Node 22+ before applying tracked OpenClaw build state" >&2
  exit 1
fi

ensure_pnpm
openclaw_bin="\$(ensure_openclaw)"

"\$openclaw_bin" gateway install --runtime node --force
"\$openclaw_bin" doctor --repair
refresh_browser_compat_path
ensure_docker_ready
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway.service
sleep 5
"\$openclaw_bin" health
systemctl --user status openclaw-gateway.service --no-pager | sed -n '1,120p'
REMOTE
)

run_logged_remote_script "install-bootstrap-openclaw" "$remote_install_script"
