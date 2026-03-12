#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOST=""
LOG_DIR="$ROOT/operation-logs"

usage() {
  cat <<'USAGE'
Usage: ./bootstrap/oracle.ylioo.com/host-openclaw.sh --host <ssh-host> <command> [args]

Commands:
  status           Show the current systemd user service status
  restart          Restart the gateway service and print a short status block
  logs [n]         Tail gateway logs with journalctl (default: 120 lines)
  service-file     Print the live openclaw-gateway.service file
  runtime-exec <cmd>
                   Run a remote shell command with the gateway runtime PATH bootstrap
  doctor           Run OpenClaw doctor using the service's current Node + entrypoint
  health           Run OpenClaw health using the service's current Node + entrypoint
  update           Use host-installed pnpm/openclaw when present, otherwise install latest, then repair, restart, and health-check
  exec <cmd>       Run an arbitrary remote shell command
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      HOST="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

if [ -z "$HOST" ]; then
  usage >&2
  exit 1
fi

cmd="${1:-}"
if [ -z "$cmd" ]; then
  usage >&2
  exit 1
fi
shift || true

LOG_FILE="$LOG_DIR/$(date -u +%F)-${HOST}.md"

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

ensure_log_file() {
  mkdir -p "$LOG_DIR"
  if [ ! -f "$LOG_FILE" ]; then
    printf '# Host Operation Log\n\n- Host: `%s`\n- Date (UTC): `%s`\n- Recorder: `bootstrap/oracle.ylioo.com/host-openclaw.sh`\n\n' "$HOST" "$(date -u +%F)" >"$LOG_FILE"
  fi
}

append_log() {
  local action="$1"
  local cmd_string="$2"
  local status="$3"
  local output_file="$4"

  ensure_log_file
  {
    printf '\n## %s | %s | exit=%s\n\n' "$(timestamp_utc)" "$action" "$status"
    printf 'Command:\n```sh\n%s\n```\n\n' "$cmd_string"
    printf 'Output:\n```text\n'
    cat "$output_file"
    printf '\n```\n'
  } >>"$LOG_FILE"
}

run_logged_remote() {
  local action="$1"
  local remote_cmd="$2"
  local tmp
  local status=0

  tmp="$(mktemp)"
  if ssh "$HOST" "$remote_cmd" >"$tmp" 2>&1; then
    status=0
  else
    status=$?
  fi
  cat "$tmp"
  append_log "$action" "ssh $HOST $remote_cmd" "$status" "$tmp"
  rm -f "$tmp"
  return "$status"
}

remote_openclaw_body() {
  cat <<REMOTE
set -euo pipefail
service="\$HOME/.config/systemd/user/openclaw-gateway.service"
exec_start="\$(sed -n 's/^ExecStart=//p' "\$service")"
if [ -z "\$exec_start" ]; then
  echo "missing ExecStart in \$service" >&2
  exit 1
fi
node_bin="\${exec_start%% *}"
rest="\${exec_start#* }"
openclaw_js="\${rest%% *}"
pnpm_home="\$HOME/.local/share/pnpm"
export PNPM_HOME="\$pnpm_home"
export PATH="\$pnpm_home:\$(dirname "\$node_bin"):\$PATH"

ensure_pnpm() {
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
  if [ -z "\$pnpm_bin" ] && [ -x "\$pnpm_home/pnpm" ]; then
    pnpm_bin="\$pnpm_home/pnpm"
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

  if [ -x "\$pnpm_home/openclaw" ]; then
    printf '%s\n' "\$pnpm_home/openclaw"
    return 0
  fi

  echo "openclaw binary not found after installation" >&2
  exit 1
}

run_openclaw() {
  "\$node_bin" "\$openclaw_js" "\$@"
}
REMOTE
}

run_remote_openclaw() {
  local action="$1"
  shift
  local body="$*"
  local remote_script

  remote_script="$(remote_openclaw_body)"
  remote_script+=$'\n'
  remote_script+="$body"
  run_logged_remote "$action" "bash -lc $(printf '%q' "$remote_script")"
}

case "$cmd" in
  status)
    run_logged_remote "status" "systemctl --user status openclaw-gateway.service --no-pager | sed -n '1,80p'"
    ;;
  restart)
    run_logged_remote "restart" "systemctl --user restart openclaw-gateway.service && systemctl --user status openclaw-gateway.service --no-pager | sed -n '1,80p'"
    ;;
  logs)
    lines="${1:-120}"
    run_logged_remote "logs" "journalctl --user -u openclaw-gateway.service -n $lines --no-pager"
    ;;
  service-file)
    run_logged_remote "service-file" "sed -n '1,220p' ~/.config/systemd/user/openclaw-gateway.service"
    ;;
  runtime-exec)
    if [ "$#" -eq 0 ]; then
      echo "runtime-exec requires a remote command" >&2
      exit 1
    fi
    run_remote_openclaw "runtime-exec" "$*"
    ;;
  doctor)
    run_remote_openclaw "doctor" "run_openclaw doctor --non-interactive"
    ;;
  health)
    run_remote_openclaw "health" "run_openclaw health"
    ;;
  update)
    run_remote_openclaw "update" 'ensure_pnpm
openclaw_bin="$(ensure_openclaw)"
"$openclaw_bin" doctor --repair
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway.service
"$openclaw_bin" health
systemctl --user status openclaw-gateway.service --no-pager | sed -n "1,80p"'
    ;;
  exec)
    if [ "$#" -eq 0 ]; then
      echo "exec requires a remote command" >&2
      exit 1
    fi
    run_logged_remote "exec" "$*"
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
