#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="oracle.ylioo.com"
PLUGIN_DIR="/home/suguan/github.com/ontosAI/knowhere-openclaw-plugin"
BUILD_DIR="$ROOT/build/$HOST"
REMOTE_PLUGIN_DIR="/home/suguan/.openclaw/plugins/knowhere"
LOG_DIR="$ROOT/operation-logs"
STAGE_ONLY=0
SKIP_RESTART=0
SKIP_HEALTH=0

readonly PAYLOAD_ITEMS=(
  "README.md"
  "dist"
  "openclaw.plugin.json"
  "package.json"
  "skills"
)

usage() {
  cat <<'USAGE'
Usage: ./scripts/deploy-knowhere-plugin.sh [options]

Sync the local Knowhere plugin payload into the Oracle build tree, upload the
same payload to the live host, restart OpenClaw, and verify the deployed hash.

Options:
  --host <ssh-host>                 SSH host to deploy to (default: oracle.ylioo.com)
  --plugin-dir <path>               Local knowhere-openclaw-plugin checkout
  --build-dir <path>                Build tree to refresh before deploy
  --remote-plugin-dir <path>        Remote plugin install path
  --stage-only                      Refresh the local build payload only
  --skip-restart                    Upload without restarting the gateway
  --skip-health                     Skip post-restart health check
  -h, --help                        Show this help
USAGE
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

ensure_log_file() {
  LOG_FILE="$LOG_DIR/$(date -u +%F)-${HOST}.md"
  mkdir -p "$LOG_DIR"
  if [ ! -f "$LOG_FILE" ]; then
    {
      printf '# Oracle OpenClaw Operation Log\n\n'
      printf -- '- Host: `%s`\n' "$HOST"
      printf -- '- Date (UTC): `%s`\n' "$(date -u +%F)"
      printf -- '- Recorder: `scripts/deploy-knowhere-plugin.sh`\n'
    } >"$LOG_FILE"
  fi
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
  } >>"$LOG_FILE"
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

upload_payload_to_remote() {
  local source_dir="$1"
  local target_dir="$2"

  local tmp
  local status=0
  local remote_script
  local remote_cmd
  tmp="$(mktemp)"
  remote_script=$(cat <<REMOTE
set -euo pipefail
target_dir=$(printf '%q' "$target_dir")
parent_dir="\$(dirname "\$target_dir")"
mkdir -p "\$parent_dir"
tmp_dir="\$(mktemp -d "\$parent_dir/.knowhere-deploy.XXXXXX")"
trap 'rm -rf "\$tmp_dir"' EXIT
tar -xf - -C "\$tmp_dir"
# Keep the plugin root directory inode stable so existing bind mounts see updates.
if [ -e "\$target_dir" ] && [ ! -d "\$target_dir" ]; then
  rm -rf "\$target_dir"
fi
mkdir -p "\$target_dir"
shopt -s dotglob nullglob
existing_entries=("\$target_dir"/*)
if [ "\${#existing_entries[@]}" -gt 0 ]; then
  rm -rf -- "\${existing_entries[@]}"
fi
new_entries=("\$tmp_dir"/*)
if [ "\${#new_entries[@]}" -gt 0 ]; then
  mv -- "\${new_entries[@]}" "\$target_dir"/
fi
rmdir "\$tmp_dir"
trap - EXIT
REMOTE
)
  remote_cmd="bash -lc $(printf '%q' "$remote_script")"

  if tar -cf - -C "$source_dir" . | ssh "$HOST" "$remote_cmd" >"$tmp" 2>&1; then
    status=0
  else
    status=$?
  fi

  cat "$tmp"
  append_log \
    "upload-knowhere-plugin" \
    "tar -cf - -C $(printf '%q' "$source_dir") . | ssh $(printf '%q' "$HOST") $(printf '%q' "$remote_cmd")" \
    "$status" \
    "$tmp"
  rm -f "$tmp"
  return "$status"
}

tree_digest() {
  local target_dir="$1"

  (
    cd "$target_dir"
    find . -type f -print \
      | LC_ALL=C sort \
      | while IFS= read -r path; do
          sha256sum "$path"
        done
  ) | sha256sum | awk '{print $1}'
}

verify_payload_item_exists() {
  local item="$1"
  if [ ! -e "$PLUGIN_DIR/$item" ]; then
    echo "missing payload item: $PLUGIN_DIR/$item" >&2
    exit 1
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      HOST="$2"
      shift 2
      ;;
    --plugin-dir)
      PLUGIN_DIR="$2"
      shift 2
      ;;
    --build-dir)
      BUILD_DIR="$2"
      shift 2
      ;;
    --remote-plugin-dir)
      REMOTE_PLUGIN_DIR="$2"
      shift 2
      ;;
    --stage-only)
      STAGE_ONLY=1
      shift
      ;;
    --skip-restart)
      SKIP_RESTART=1
      shift
      ;;
    --skip-health)
      SKIP_HEALTH=1
      shift
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

ensure_log_file

if [ ! -d "$PLUGIN_DIR" ]; then
  echo "missing plugin directory: $PLUGIN_DIR" >&2
  exit 1
fi

if [ ! -d "$BUILD_DIR/rootfs" ]; then
  echo "missing build rootfs: $BUILD_DIR/rootfs" >&2
  exit 1
fi

if [ "$STAGE_ONLY" -eq 1 ]; then
  SKIP_RESTART=1
  SKIP_HEALTH=1
fi

for item in "${PAYLOAD_ITEMS[@]}"; do
  verify_payload_item_exists "$item"
done

BUILD_PLUGIN_DIR="$BUILD_DIR/rootfs/home/suguan/.openclaw/plugins/knowhere"
TEMP_DIR="$(mktemp -d)"
PAYLOAD_DIR="$TEMP_DIR/payload"
trap 'rm -rf "$TEMP_DIR"' EXIT
mkdir -p "$PAYLOAD_DIR"

for item in "${PAYLOAD_ITEMS[@]}"; do
  cp -R "$PLUGIN_DIR/$item" "$PAYLOAD_DIR/"
done

SOURCE_DIGEST="$(tree_digest "$PAYLOAD_DIR")"

rm -rf "$BUILD_PLUGIN_DIR"
mkdir -p "$(dirname "$BUILD_PLUGIN_DIR")"
cp -R "$PAYLOAD_DIR" "$BUILD_PLUGIN_DIR"
BUILD_DIGEST="$(tree_digest "$BUILD_PLUGIN_DIR")"

printf 'Source payload digest: %s\n' "$SOURCE_DIGEST"
printf 'Staged build digest:   %s\n' "$BUILD_DIGEST"

if [ "$SOURCE_DIGEST" != "$BUILD_DIGEST" ]; then
  echo "staged build payload digest mismatch" >&2
  exit 1
fi

run_logged_local \
  "stage-knowhere-plugin-build" \
  bash -lc \
  "$(printf "printf 'source=%%s\\nbuild=%%s\\n' %q %q" "$SOURCE_DIGEST" "$BUILD_DIGEST")"

if [ "$STAGE_ONLY" -eq 1 ]; then
  echo "Staged local build payload only. No remote deploy performed."
  exit 0
fi

upload_payload_to_remote "$PAYLOAD_DIR" "$REMOTE_PLUGIN_DIR"

REMOTE_DIGEST_SCRIPT=$(cat <<REMOTE
set -euo pipefail
cd $(printf '%q' "$REMOTE_PLUGIN_DIR")
find . -type f -print \
  | LC_ALL=C sort \
  | while IFS= read -r path; do
      sha256sum "\$path"
    done \
  | sha256sum \
  | awk '{print \$1}'
REMOTE
)

REMOTE_DIGEST="$(run_logged_remote_script "verify-live-knowhere-plugin" "$REMOTE_DIGEST_SCRIPT")"
printf 'Live host digest:      %s\n' "$REMOTE_DIGEST"

if [ "$SOURCE_DIGEST" != "$REMOTE_DIGEST" ]; then
  echo "live plugin payload digest mismatch" >&2
  exit 1
fi

LOCAL_TOOLS_HASH="$(sha256sum "$PAYLOAD_DIR/dist/tools.js" | awk '{print $1}')"
REMOTE_TOOLS_HASH_SCRIPT=$(cat <<REMOTE
set -euo pipefail
sha256sum $(printf '%q' "$REMOTE_PLUGIN_DIR/dist/tools.js") | awk '{print \$1}'
REMOTE
)
REMOTE_TOOLS_HASH="$(run_logged_remote_script "verify-live-knowhere-tools-hash" "$REMOTE_TOOLS_HASH_SCRIPT")"

printf 'dist/tools.js hash:    %s\n' "$LOCAL_TOOLS_HASH"

if [ "$LOCAL_TOOLS_HASH" != "$REMOTE_TOOLS_HASH" ]; then
  echo "live dist/tools.js hash mismatch" >&2
  exit 1
fi

if [ "$SKIP_RESTART" -eq 1 ]; then
  echo "Skipped gateway restart."
  exit 0
fi

"$ROOT/scripts/oracle-openclaw.sh" restart

if [ "$SKIP_HEALTH" -eq 1 ]; then
  echo "Skipped post-restart health check."
  exit 0
fi

"$ROOT/scripts/oracle-openclaw.sh" health
