#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${OPENCLAW_HOST:-oracle.ylioo.com}"
LOG_DIR="$ROOT/operation-logs"
LOG_FILE="$LOG_DIR/$(date -u +%F)-${HOST}.md"
SNAPSHOT_SCRIPT="$ROOT/scripts/snapshot.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/oracle-openclaw.sh <command> [args]

Commands:
  snapshot         Refresh the redacted local snapshot from oracle.ylioo.com
  status           Show the current systemd user service status
  restart          Restart the gateway service and print a short status block
  logs [n]         Tail gateway logs with journalctl (default: 120 lines)
  service-file     Print the live openclaw-gateway.service file
  runtime-exec <cmd>
                   Run a remote shell command with the gateway runtime PATH/env bootstrap
  doctor           Run OpenClaw doctor using the service's current Node + entrypoint
  health           Run OpenClaw health using the service's current Node + entrypoint
  update           Update the global pnpm install, repair the service, then restart + health
  update-pnpm      Same as update
  update-npm       Backward-compatible alias for update-pnpm
  exec <cmd>       Run an arbitrary remote shell command
USAGE
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

ensure_log_file() {
  mkdir -p "$LOG_DIR"
  if [ ! -f "$LOG_FILE" ]; then
    printf '# Oracle OpenClaw Operation Log\n\n- Host: `%s`\n- Date (UTC): `%s`\n- Recorder: `scripts/oracle-openclaw.sh`\n\n' "$HOST" "$(date -u +%F)" >"$LOG_FILE"
  fi
}

append_log() {
  local action="$1"
  local cmd="$2"
  local status="$3"
  local output_file="$4"

  ensure_log_file
  {
    printf '\n## %s | %s | exit=%s\n\n' "$(timestamp_utc)" "$action" "$status"
    printf 'Command:\n```sh\n%s\n```\n\n' "$cmd"
    printf 'Output:\n```text\n'
    cat "$output_file"
    printf '\n```\n'
  } >>"$LOG_FILE"
}

run_logged_local() {
  local action="$1"
  shift
  local cmd="$*"
  local tmp
  local status=0

  tmp="$(mktemp)"
  if bash -lc "$cmd" >"$tmp" 2>&1; then
    status=0
  else
    status=$?
  fi
  cat "$tmp"
  append_log "$action" "$cmd" "$status" "$tmp"
  rm -f "$tmp"
  return "$status"
}

run_logged_remote() {
  local action="$1"
  shift
  local remote_cmd="$1"
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
  cat <<'EOFBODY'
set -euo pipefail
service="$HOME/.config/systemd/user/openclaw-gateway.service"
exec_start="$(sed -n 's/^ExecStart=//p' "$service")"
if [ -z "$exec_start" ]; then
  echo "missing ExecStart in $service" >&2
  exit 1
fi
node_bin="${exec_start%% *}"
rest="${exec_start#* }"
openclaw_js="${rest%% *}"
pnpm_home="$HOME/.local/share/pnpm"
npm_bin="${node_bin%/node}/npm"
export PNPM_HOME="$pnpm_home"
export PATH="$pnpm_home:$(dirname "$node_bin"):$PATH"
pnpm_bin="$(command -v pnpm || true)"
if [ -z "$pnpm_bin" ]; then
  pnpm_bin="$pnpm_home/pnpm"
fi
if [ -f "$HOME/.openclaw/acp-harness.env" ]; then
  set -a
  . "$HOME/.openclaw/acp-harness.env"
  set +a
fi
run_openclaw() {
  "$node_bin" "$openclaw_js" "$@"
}
EOFBODY
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

cmd="${1:-}"
if [ -z "$cmd" ]; then
  usage
  exit 1
fi
shift || true

case "$cmd" in
  snapshot)
    run_logged_local "snapshot" "OPENCLAW_SNAPSHOT_HOST=$HOST $(printf '%q' "$SNAPSHOT_SCRIPT")"
    ;;
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
  update|update-pnpm|update-npm)
    run_remote_openclaw "update-pnpm" '"$pnpm_bin" add -g openclaw@latest
"$pnpm_home/openclaw" doctor --yes --fix
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway.service
"$pnpm_home/openclaw" health
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
    usage
    exit 1
    ;;
esac
