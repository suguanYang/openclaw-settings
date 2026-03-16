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
  snapshot         Capture a redacted untracked live snapshot from oracle.ylioo.com into .tmp/live/
  status           Show the current systemd user service status
  restart          Restart the gateway service and print a short status block
  logs [n]         Tail gateway logs with journalctl (default: 120 lines)
  watch-agent <agent> [--raw] [--tool-result <full|truncate>]
                   Stream the latest session transcript for one agent
                   Pretty mode defaults to full toolResult output; truncated mode uses
                   OPENCLAW_WATCH_TOOL_RESULT_MAX_CHARS (default: 100)
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

run_streamed_remote() {
  local remote_cmd="$1"
  ssh "$HOST" "$remote_cmd"
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

stream_remote_openclaw() {
  local body="$*"
  local remote_script

  remote_script="$(remote_openclaw_body)"
  remote_script+=$'\n'
  remote_script+="$body"
  run_streamed_remote "bash -lc $(printf '%q' "$remote_script")"
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
  watch-agent)
    if [ "$#" -eq 0 ]; then
      echo "watch-agent requires an agent name" >&2
      exit 1
    fi
    agent_name="$1"
    shift
    output_mode="pretty"
    tool_result_mode="full"
    tool_result_max_chars="${OPENCLAW_WATCH_TOOL_RESULT_MAX_CHARS:-100}"
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --raw)
          output_mode="raw"
          shift
          ;;
        --tool-result)
          if [ "$#" -lt 2 ]; then
            echo "--tool-result requires full or truncate" >&2
            exit 1
          fi
          case "$2" in
            full|truncate)
              tool_result_mode="$2"
              ;;
            *)
              echo "--tool-result only accepts full or truncate" >&2
              exit 1
              ;;
          esac
          shift 2
          ;;
        *)
          echo "watch-agent only accepts --raw and --tool-result <full|truncate>" >&2
          exit 1
          ;;
      esac
    done
    remote_watch_script="$(cat <<EOF
set -euo pipefail
agent_name=$(printf '%q' "$agent_name")
output_mode=$(printf '%q' "$output_mode")
tool_result_mode=$(printf '%q' "$tool_result_mode")
tool_result_max_chars=$(printf '%q' "$tool_result_max_chars")
sessions_dir="\$HOME/.openclaw/agents/\$agent_name/sessions"
history_lines="\${OPENCLAW_WATCH_LINES:-120}"

if [ ! -d "\$sessions_dir" ]; then
  echo "agent not found or has no sessions directory: \$agent_name" >&2
  exit 1
fi

latest_session="\$(find "\$sessions_dir" -maxdepth 1 -type f -name '*.jsonl' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"
if [ -z "\$latest_session" ]; then
  echo "no session transcripts found for agent: \$agent_name" >&2
  exit 1
fi

echo "Watching \$latest_session" >&2

tail_session() {
  if command -v stdbuf >/dev/null 2>&1; then
    stdbuf -oL tail -n "\$history_lines" -F "\$latest_session"
    return 0
  fi
  tail -n "\$history_lines" -F "\$latest_session"
}

if [ "\$output_mode" = "raw" ]; then
  tail_session
  exit 0
fi

if [ ! -x "\$node_bin" ]; then
  echo "pretty output unavailable because the OpenClaw runtime node binary is missing; falling back to raw JSONL" >&2
  tail_session
  exit 0
fi

tail_session | env \
  OPENCLAW_WATCH_TOOL_RESULT_MODE="\$tool_result_mode" \
  OPENCLAW_WATCH_TOOL_RESULT_MAX_CHARS="\$tool_result_max_chars" \
  "\$node_bin" -e '
const readline = require("node:readline");
const toolResultMode = process.env.OPENCLAW_WATCH_TOOL_RESULT_MODE || "full";
const parsedMaxChars = Number.parseInt(process.env.OPENCLAW_WATCH_TOOL_RESULT_MAX_CHARS || "100", 10);
const toolResultMaxChars = Number.isFinite(parsedMaxChars) && parsedMaxChars > 0 ? parsedMaxChars : 100;

function stringifyToolArguments(part) {
  if (typeof part.partialJson === "string" && part.partialJson.trim()) {
    return part.partialJson.trim();
  }
  if (part.arguments === undefined) {
    return "";
  }
  try {
    return JSON.stringify(part.arguments);
  } catch {
    return "[unserializable arguments]";
  }
}

function readEntries(message) {
  const content = message && Array.isArray(message.content) ? message.content : [];
  const fallbackRole = typeof message.role === "string" ? message.role : "unknown";
  const entries = [];

  for (const part of content) {
    if (!part || typeof part !== "object") {
      continue;
    }
    if (typeof part.text === "string" && part.text) {
      entries.push({ role: fallbackRole, content: part.text });
      continue;
    }
    if (typeof part.thinking === "string" && part.thinking) {
      entries.push({ role: fallbackRole, content: part.thinking });
      continue;
    }
    if (part.type === "toolCall") {
      const toolName = typeof part.name === "string" && part.name ? part.name : "unknown";
      const args = stringifyToolArguments(part);
      entries.push({
        role: "toolCall",
        content: args ? toolName + " " + args : toolName,
      });
    }
  }

  return entries;
}

function formatToolResultContent(content) {
  if (toolResultMode !== "truncate") {
    return content;
  }
  if (content.length <= toolResultMaxChars) {
    return content;
  }
  const truncated = content.slice(0, toolResultMaxChars);
  return truncated + "\\n[truncated]";
}

const reader = readline.createInterface({
  input: process.stdin,
  crlfDelay: Infinity,
});

reader.on("line", (line) => {
  if (!line.trim()) {
    return;
  }

  let record;
  try {
    record = JSON.parse(line);
  } catch {
    process.stdout.write(line + "\\n");
    return;
  }

  if (record.type !== "message" || !record.message) {
    return;
  }

  const timestamp = typeof record.timestamp === "string" ? record.timestamp : "";
  const entries = readEntries(record.message);
  if (entries.length === 0) {
    return;
  }

  for (const entry of entries) {
    const formattedContent =
      entry.role === "toolResult" ? formatToolResultContent(entry.content) : entry.content;
    process.stdout.write(timestamp + " [" + entry.role + "] " + formattedContent + "\\n");
  }
});
'
EOF
)"
    stream_remote_openclaw "$remote_watch_script"
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
