#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${OPENCLAW_HOST:-}"
LOCAL_CONFIG_PATH="${OPENCLAW_JOURNALD_CONFIG_PATH:-}"
REMOTE_CONFIG_PATH="${OPENCLAW_JOURNALD_REMOTE_CONFIG_PATH:-/etc/systemd/journald.conf.d/50-openclaw-journal-size.conf}"

usage() {
  cat <<'USAGE'
Usage: ./scripts/journald-host.sh --host <ssh-host> [options] <command>

Options:
  --host <ssh-host>        SSH host or alias. Defaults to OPENCLAW_HOST if set
  --config <path>          Local tracked journald config file to install
  --remote-path <path>     Remote journald drop-in path
                           (default: /etc/systemd/journald.conf.d/50-openclaw-journal-size.conf)
  -h, --help               Show this help

Commands:
  status           Show current journald size settings and disk usage
  install          Upload the tracked config and install it with interactive sudo
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

ensure_local_config() {
  if [ -n "$LOCAL_CONFIG_PATH" ]; then
    :
  elif [ -f "$ROOT/build/$HOST/rootfs$REMOTE_CONFIG_PATH" ]; then
    LOCAL_CONFIG_PATH="$ROOT/build/$HOST/rootfs$REMOTE_CONFIG_PATH"
  else
    echo "missing --config and no tracked config at build/$HOST/rootfs$REMOTE_CONFIG_PATH" >&2
    exit 1
  fi

  if [ ! -f "$LOCAL_CONFIG_PATH" ]; then
    echo "local config not found: $LOCAL_CONFIG_PATH" >&2
    exit 1
  fi
}

run_remote_script() {
  local script="$1"
  ssh "$HOST" "bash -lc $(printf '%q' "$script")"
}

run_remote_script_tty() {
  local script="$1"
  ssh -tt "$HOST" "bash -lc $(printf '%q' "$script")"
}

print_status() {
  local remote_script
  remote_script="$(cat <<'EOF'
set -euo pipefail
echo "--- journald config ---"
if [ -f /etc/systemd/journald.conf ]; then
  grep -nE '^(Storage|SystemMaxUse|RuntimeMaxUse)=' /etc/systemd/journald.conf || true
fi
echo "--- drop-ins ---"
if [ -d /etc/systemd/journald.conf.d ]; then
  find /etc/systemd/journald.conf.d -maxdepth 1 -type f -print 2>/dev/null | sort | while read -r file; do
    echo "FILE:$file"
    grep -nE '^(Storage|SystemMaxUse|RuntimeMaxUse)=' "$file" || true
  done
fi
echo "--- usage ---"
journalctl --disk-usage -q
EOF
)"
  run_remote_script "$remote_script"
}

install_config() {
  local remote_dir
  local remote_tmp
  local upload_script
  local install_script

  ensure_local_config

  remote_dir="$(dirname "$REMOTE_CONFIG_PATH")"
  remote_tmp="/tmp/$(basename "$REMOTE_CONFIG_PATH").$$"

  upload_script="$(cat <<EOF
set -euo pipefail
cat > $(printf '%q' "$remote_tmp")
EOF
)"
  ssh "$HOST" "bash -lc $(printf '%q' "$upload_script")" <"$LOCAL_CONFIG_PATH"

  install_script="$(cat <<EOF
set -euo pipefail
remote_dir=$(printf '%q' "$remote_dir")
remote_tmp=$(printf '%q' "$remote_tmp")
remote_path=$(printf '%q' "$REMOTE_CONFIG_PATH")
sudo mkdir -p "\$remote_dir"
sudo install -m 0644 "\$remote_tmp" "\$remote_path"
rm -f "\$remote_tmp"
sudo systemctl restart systemd-journald
echo "installed: \$remote_path"
journalctl --disk-usage -q
EOF
)"
  run_remote_script_tty "$install_script"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      HOST="$2"
      shift 2
      ;;
    --config)
      LOCAL_CONFIG_PATH="$2"
      shift 2
      ;;
    --remote-path)
      REMOTE_CONFIG_PATH="$2"
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

case "$cmd" in
  status)
    print_status
    ;;
  install)
    install_config
    ;;
  *)
    usage
    exit 1
    ;;
esac
