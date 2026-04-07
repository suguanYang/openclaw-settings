#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${OPENCLAW_HOST:-}"
SERVICE_NAME="${OPENCLAW_LOGFIRE_POLLER_SERVICE_NAME:-logfire-alert-poller.service}"
TIMER_NAME="${OPENCLAW_LOGFIRE_POLLER_TIMER_NAME:-logfire-alert-poller.timer}"
STATE_PATH="${OPENCLAW_LOGFIRE_POLLER_STATE_PATH:-~/.openclaw/integrations/logfire-alerts/state.json}"
LOG_TITLE="${OPENCLAW_LOG_TITLE:-Logfire Alert Poller Operation Log}"
LOG_RECORDER="${OPENCLAW_LOG_RECORDER:-scripts/logfire-alert-poller-host.sh}"

usage() {
  cat <<'USAGE'
Usage: ./scripts/logfire-alert-poller-host.sh --host <ssh-host> [options] <command> [args]

Options:
  --host <ssh-host>        SSH host or alias. Defaults to OPENCLAW_HOST if set
  --service <name>         systemd user service name (default: logfire-alert-poller.service)
  --timer <name>           systemd user timer name (default: logfire-alert-poller.timer)
  --state-path <path>      Remote poller state file
                           (default: ~/.openclaw/integrations/logfire-alerts/state.json)
  -h, --help               Show this help

Commands:
  status           Show the current poller service status
  timer-status     Show the current timer status and next run
  restart-timer    Restart the timer and print a short timer status block
  run              Start one poll cycle immediately and print the service status
  logs [n]         Show recent poller logs (default: 120 lines)
  follow [n]       Follow poller logs live, starting with the last n lines (default: 20)
  service-file     Print the live poller service unit
  state            Print the current dedupe state file
  exec <cmd>       Run an arbitrary remote shell command
USAGE
}

ensure_host() {
  if [ -n "$HOST" ]; then
    return 0
  fi

  echo "missing --host or OPENCLAW_HOST" >&2
  usage >&2
  exit 1
}

run_openclaw_host() {
  OPENCLAW_HOST="$HOST" \
  OPENCLAW_SERVICE_NAME="$SERVICE_NAME" \
  OPENCLAW_LOG_TITLE="$LOG_TITLE" \
  OPENCLAW_LOG_RECORDER="$LOG_RECORDER" \
    "$ROOT/scripts/openclaw-host.sh" "$@"
}

run_remote_script() {
  local script="$1"
  ssh "$HOST" "bash -lc $(printf '%q' "$script")"
}

stream_remote_script() {
  local script="$1"
  ssh "$HOST" "bash -lc $(printf '%q' "$script")"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      HOST="$2"
      shift 2
      ;;
    --service|--service-name)
      SERVICE_NAME="$2"
      shift 2
      ;;
    --timer|--timer-name)
      TIMER_NAME="$2"
      shift 2
      ;;
    --state-path)
      STATE_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

ensure_host

cmd="${1:-}"
if [ -z "$cmd" ]; then
  usage
  exit 1
fi
shift || true

case "$cmd" in
  status|logs|service-file|exec)
    run_openclaw_host "$cmd" "$@"
    ;;
  timer-status)
    remote_script="$(cat <<EOF
set -euo pipefail
timer_name=$(printf '%q' "$TIMER_NAME")
systemctl --user status "\$timer_name" --no-pager | sed -n '1,40p'
EOF
)"
    run_remote_script "$remote_script"
    ;;
  restart-timer)
    remote_script="$(cat <<EOF
set -euo pipefail
timer_name=$(printf '%q' "$TIMER_NAME")
systemctl --user restart "\$timer_name"
systemctl --user status "\$timer_name" --no-pager | sed -n '1,40p'
EOF
)"
    run_remote_script "$remote_script"
    ;;
  run)
    remote_script="$(cat <<EOF
set -euo pipefail
service_name=$(printf '%q' "$SERVICE_NAME")
systemctl --user start "\$service_name"
systemctl --user status "\$service_name" --no-pager | sed -n '1,80p'
EOF
)"
    run_remote_script "$remote_script"
    ;;
  follow)
    lines="${1:-20}"
    remote_script="$(cat <<EOF
set -euo pipefail
service_name=$(printf '%q' "$SERVICE_NAME")
lines=$(printf '%q' "$lines")
journalctl --user -u "\$service_name" -n "\$lines" -f
EOF
)"
    stream_remote_script "$remote_script"
    ;;
  state)
    remote_script="$(cat <<EOF
set -euo pipefail
state_path=$(printf '%q' "$STATE_PATH")
case "\$state_path" in
  "~/"*)
    state_path="\$HOME/\${state_path#\~/}"
    ;;
esac
if [ ! -f "\$state_path" ]; then
  echo "state file not found: \$state_path" >&2
  exit 1
fi
cat "\$state_path"
EOF
)"
    run_remote_script "$remote_script"
    ;;
  *)
    usage
    exit 1
    ;;
esac
