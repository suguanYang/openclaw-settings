#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${OPENCLAW_HOST:-}"
SERVICE_NAME="${OPENCLAW_SERVICE_NAME:-openclaw-gateway.service}"
SERVICE_MANAGER="${OPENCLAW_SERVICE_MANAGER:-auto}"
LAUNCHD_LABEL="${OPENCLAW_LAUNCHD_LABEL:-ai.openclaw.gateway}"
OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-}"
LOG_TITLE="${OPENCLAW_LOG_TITLE:-OpenClaw Host Operation Log}"
LOG_RECORDER="${OPENCLAW_LOG_RECORDER:-scripts/openclaw-host.sh}"
LOG_DIR="$ROOT/operation-logs"
SNAPSHOT_SCRIPT="$ROOT/scripts/snapshot.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/openclaw-host.sh --host <ssh-host> [options] <command> [args]

Options:
  --host <ssh-host>        SSH host or alias. Defaults to OPENCLAW_HOST if set
  --service <name>         systemd user service name (default: openclaw-gateway.service)
  --service-manager <kind> Remote service manager: auto, systemd, or launchd
                           (default: auto)
  --launchd-label <label>  launchd label (default: ai.openclaw.gateway)
  --openclaw-home <path>   Remote OpenClaw state dir (default: ~/.openclaw)
  -h, --help               Show this help

Commands:
  snapshot         Capture a redacted untracked live snapshot from the target host into .tmp/live/<host>/
  status           Show the current gateway service status
  restart          Restart the gateway service and print a short status block
  logs [n]         Show the latest gateway logs (default: 120 lines)
  logs-knowhere [n]
                   Show recent gateway logs filtered to Knowhere-related records
  watch-agent <agent> [--raw] [--tool-result <full|truncate>]
                   Stream the latest session transcript for one agent
                   Pretty mode prints all transcript record types; truncated mode uses
                   OPENCLAW_WATCH_TOOL_RESULT_MAX_CHARS (default: 100)
  watch-knowhere [n]
                   Follow gateway logs live, filtered to Knowhere-related records
  service-file     Print the live service definition
  runtime-exec <cmd>
                   Run a remote shell command with the gateway runtime PATH/env setup
  doctor           Run OpenClaw doctor using the service's current Node + entrypoint
  health           Run OpenClaw health using the service's current Node + entrypoint
  update           Update the global pnpm install, repair the service, then restart + health
  update-pnpm      Same as update
  update-npm       Backward-compatible alias for update-pnpm
  install-gateway-no-proxy <csv>
                   Reinstall the gateway service with a merged NO_PROXY list.
                   Launchd hosts reuse the current plist proxy env and regenerate
                   the LaunchAgent through OpenClaw instead of editing the plist directly.
  exec <cmd>       Run an arbitrary remote shell command
USAGE
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

ensure_host() {
  if [ -n "$HOST" ]; then
    return 0
  fi

  echo "missing --host or OPENCLAW_HOST" >&2
  usage >&2
  exit 1
}

log_file_path() {
  printf '%s/%s-%s.md' "$LOG_DIR" "$(date -u +%F)" "$HOST"
}

ensure_log_file() {
  local log_file

  mkdir -p "$LOG_DIR"
  log_file="$(log_file_path)"
  if [ ! -f "$log_file" ]; then
    printf '# %s\n\n- Host: `%s`\n- Date (UTC): `%s`\n- Recorder: `%s`\n\n' \
      "$LOG_TITLE" \
      "$HOST" \
      "$(date -u +%F)" \
      "$LOG_RECORDER" \
      >"$log_file"
  fi
}

append_log() {
  local action="$1"
  local cmd="$2"
  local status="$3"
  local output_file="$4"
  local log_file

  ensure_log_file
  log_file="$(log_file_path)"
  {
    printf '\n## %s | %s | exit=%s\n\n' "$(timestamp_utc)" "$action" "$status"
    printf 'Command:\n```sh\n%s\n```\n\n' "$cmd"
    printf 'Output:\n```text\n'
    cat "$output_file"
    printf '\n```\n'
  } >>"$log_file"
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
  local body

  body="$(cat <<'EOFBODY'
set -euo pipefail
normalize_remote_path() {
  local raw="$1"
  case "$raw" in
    "")
      printf '%s\n' "$HOME/.openclaw"
      ;;
    "~")
      printf '%s\n' "$HOME"
      ;;
    "~/"*)
      printf '%s\n' "$HOME/${raw#~/}"
      ;;
    '$HOME')
      printf '%s\n' "$HOME"
      ;;
    '$HOME/'*)
      printf '%s\n' "$HOME/${raw#\$HOME/}"
      ;;
    *)
      printf '%s\n' "$raw"
      ;;
  esac
}
service_name=__SERVICE_NAME__
service_manager_input=__SERVICE_MANAGER_INPUT__
launchd_label=__LAUNCHD_LABEL__
openclaw_home_input=__OPENCLAW_HOME_INPUT__
openclaw_home="$(normalize_remote_path "$openclaw_home_input")"
service_manager=""
service_file_path=""
launchd_domain="gui/$(id -u)/$launchd_label"
launchd_plist="$HOME/Library/LaunchAgents/$launchd_label.plist"
systemd_service_path="$HOME/.config/systemd/user/$service_name"
service_path=""
stdout_log_path=""
stderr_log_path=""
node_bin=""
openclaw_js=""
pnpm_home=""
pnpm_bin=""

is_systemd_available() {
  command -v systemctl >/dev/null 2>&1 && [ -f "$systemd_service_path" ]
}

is_launchd_available() {
  command -v launchctl >/dev/null 2>&1 && [ -f "$launchd_plist" ]
}

ensure_plist_buddy() {
  if [ ! -x /usr/libexec/PlistBuddy ]; then
    echo "launchd support requires /usr/libexec/PlistBuddy" >&2
    exit 1
  fi
}

read_launchd_value() {
  local key="$1"
  /usr/libexec/PlistBuddy -c "Print :$key" "$launchd_plist"
}

detect_service_manager() {
  case "$service_manager_input" in
    auto)
      if is_systemd_available; then
        service_manager="systemd"
        return 0
      fi
      if is_launchd_available; then
        service_manager="launchd"
        return 0
      fi
      ;;
    systemd)
      if is_systemd_available; then
        service_manager="systemd"
        return 0
      fi
      echo "systemd service file not found: $systemd_service_path" >&2
      exit 1
      ;;
    launchd)
      if is_launchd_available; then
        service_manager="launchd"
        return 0
      fi
      echo "launchd plist not found: $launchd_plist" >&2
      exit 1
      ;;
    *)
      echo "unsupported service manager: $service_manager_input" >&2
      exit 1
      ;;
  esac

  echo "unable to detect a supported service manager on this host" >&2
  echo "checked systemd unit: $systemd_service_path" >&2
  echo "checked launchd plist: $launchd_plist" >&2
  exit 1
}

configure_systemd_runtime() {
  local exec_start
  local rest

  service_file_path="$systemd_service_path"
  exec_start="$(sed -n 's/^ExecStart=//p' "$service_file_path")"
  if [ -z "$exec_start" ]; then
    echo "missing ExecStart in $service_file_path" >&2
    exit 1
  fi

  node_bin="${exec_start%% *}"
  rest="${exec_start#* }"
  openclaw_js="${rest%% *}"
}

configure_launchd_runtime() {
  ensure_plist_buddy

  service_file_path="$launchd_plist"
  node_bin="$(read_launchd_value 'ProgramArguments:0' 2>/dev/null || true)"
  openclaw_js="$(read_launchd_value 'ProgramArguments:1' 2>/dev/null || true)"
  stdout_log_path="$(read_launchd_value 'StandardOutPath' 2>/dev/null || true)"
  stderr_log_path="$(read_launchd_value 'StandardErrorPath' 2>/dev/null || true)"
  service_path="$(read_launchd_value 'EnvironmentVariables:PATH' 2>/dev/null || true)"

  if [ -z "$node_bin" ] || [ -z "$openclaw_js" ]; then
    echo "missing ProgramArguments in $service_file_path" >&2
    exit 1
  fi
}

configure_package_runtime() {
  local candidate

  if [ -n "$service_path" ]; then
    export PATH="$service_path:$PATH"
  fi

  pnpm_bin="$(command -v pnpm || true)"
  if [ -n "$pnpm_bin" ]; then
    pnpm_home="$(cd "$(dirname "$pnpm_bin")" && pwd)"
  else
    for candidate in \
      "$HOME/.local/share/pnpm/pnpm" \
      "$HOME/Library/pnpm/pnpm" \
      "$(dirname "$node_bin")/pnpm"; do
      if [ -x "$candidate" ]; then
        pnpm_bin="$candidate"
        pnpm_home="$(cd "$(dirname "$candidate")" && pwd)"
        break
      fi
    done
  fi

  if [ -z "$pnpm_home" ]; then
    if [ -d "$HOME/.local/share/pnpm" ]; then
      pnpm_home="$HOME/.local/share/pnpm"
    elif [ -d "$HOME/Library/pnpm" ]; then
      pnpm_home="$HOME/Library/pnpm"
    fi
  fi

  if [ -n "$pnpm_home" ]; then
    export PNPM_HOME="$pnpm_home"
    export PATH="$pnpm_home:$(dirname "$node_bin"):$PATH"
  else
    export PATH="$(dirname "$node_bin"):$PATH"
  fi

  if [ -z "$pnpm_bin" ] && [ -n "$pnpm_home" ] && [ -x "$pnpm_home/pnpm" ]; then
    pnpm_bin="$pnpm_home/pnpm"
  fi
}

ensure_pnpm_available() {
  if [ -z "$pnpm_bin" ]; then
    echo "pnpm not found in PATH or known install directories" >&2
    exit 1
  fi
}

print_service_status() {
  case "$service_manager" in
    systemd)
      systemctl --user status "$service_name" --no-pager | sed -n '1,80p'
      ;;
    launchd)
      launchctl print "$launchd_domain" | sed -n '1,80p'
      ;;
  esac
}

restart_service() {
  case "$service_manager" in
    systemd)
      systemctl --user restart "$service_name"
      ;;
    launchd)
      launchctl kickstart -k "$launchd_domain"
      ;;
  esac
}

print_service_logs() {
  local lines="$1"
  local log_paths=()

  case "$service_manager" in
    systemd)
      journalctl --user -u "$service_name" -n "$lines" --no-pager
      ;;
    launchd)
      if [ -n "$stdout_log_path" ] && [ -f "$stdout_log_path" ]; then
        log_paths+=("$stdout_log_path")
      fi
      if [ -n "$stderr_log_path" ] && [ -f "$stderr_log_path" ]; then
        log_paths+=("$stderr_log_path")
      fi
      if [ "${#log_paths[@]}" -eq 0 ]; then
        echo "launchd log files not found for $launchd_label" >&2
        exit 1
      fi
      tail -n "$lines" "${log_paths[@]}"
      ;;
  esac
}

print_service_logs_filtered() {
  local lines="$1"
  local pattern="$2"
  local log_paths=()

  case "$service_manager" in
    systemd)
      journalctl --user -u "$service_name" -n "$lines" --no-pager \
        | awk -v pattern="$pattern" '$0 ~ pattern { print }'
      ;;
    launchd)
      if [ -n "$stdout_log_path" ] && [ -f "$stdout_log_path" ]; then
        log_paths+=("$stdout_log_path")
      fi
      if [ -n "$stderr_log_path" ] && [ -f "$stderr_log_path" ]; then
        log_paths+=("$stderr_log_path")
      fi
      if [ "${#log_paths[@]}" -eq 0 ]; then
        echo "launchd log files not found for $launchd_label" >&2
        exit 1
      fi
      tail -n "$lines" "${log_paths[@]}" \
        | awk -v pattern="$pattern" '$0 ~ pattern { print }'
      ;;
  esac
}

follow_service_logs_filtered() {
  local lines="$1"
  local pattern="$2"
  local log_paths=()

  case "$service_manager" in
    systemd)
      journalctl --user -u "$service_name" -n "$lines" -f --no-pager \
        | awk -v pattern="$pattern" '$0 ~ pattern { print; fflush() }'
      ;;
    launchd)
      if [ -n "$stdout_log_path" ] && [ -f "$stdout_log_path" ]; then
        log_paths+=("$stdout_log_path")
      fi
      if [ -n "$stderr_log_path" ] && [ -f "$stderr_log_path" ]; then
        log_paths+=("$stderr_log_path")
      fi
      if [ "${#log_paths[@]}" -eq 0 ]; then
        echo "launchd log files not found for $launchd_label" >&2
        exit 1
      fi
      if command -v stdbuf >/dev/null 2>&1; then
        stdbuf -oL tail -n "$lines" -F "${log_paths[@]}" \
          | awk -v pattern="$pattern" '$0 ~ pattern { print; fflush() }'
        return 0
      fi
      tail -n "$lines" -F "${log_paths[@]}" \
        | awk -v pattern="$pattern" '$0 ~ pattern { print; fflush() }'
      ;;
  esac
}

print_service_file() {
  case "$service_manager" in
    systemd)
      sed -n '1,220p' "$service_file_path"
      ;;
    launchd)
      plutil -p "$service_file_path"
      ;;
  esac
}

reload_service_manager() {
  case "$service_manager" in
    systemd)
      systemctl --user daemon-reload
      ;;
    launchd)
      :
      ;;
  esac
}

find_latest_session_file() {
  local sessions_dir="$1"

  if find "$sessions_dir" -maxdepth 1 -type f -name '*.jsonl' -printf '' >/dev/null 2>&1; then
    find "$sessions_dir" -maxdepth 1 -type f -name '*.jsonl' -printf '%T@ %p\n' \
      | sort -nr \
      | head -n 1 \
      | cut -d' ' -f2-
    return 0
  fi

  find "$sessions_dir" -maxdepth 1 -type f -name '*.jsonl' -exec sh -c '
    for file do
      if stat -c "%Y %n" "$file" >/dev/null 2>&1; then
        stat -c "%Y %n" "$file"
        continue
      fi
      if stat -f "%m %N" "$file" >/dev/null 2>&1; then
        stat -f "%m %N" "$file"
        continue
      fi
      echo "unsupported stat implementation for $file" >&2
      exit 1
    done
  ' sh {} + \
    | sort -nr \
    | head -n 1 \
    | cut -d' ' -f2-
}

detect_service_manager
case "$service_manager" in
  systemd)
    configure_systemd_runtime
    ;;
  launchd)
    configure_launchd_runtime
    ;;
esac
configure_package_runtime
if [ -f "$openclaw_home/acp-harness.env" ]; then
  set -a
  . "$openclaw_home/acp-harness.env"
  set +a
fi
run_openclaw() {
  "$node_bin" "$openclaw_js" "$@"
}
EOFBODY
)"
  body="${body//__SERVICE_NAME__/$(printf '%q' "$SERVICE_NAME")}"
  body="${body//__SERVICE_MANAGER_INPUT__/$(printf '%q' "$SERVICE_MANAGER")}"
  body="${body//__LAUNCHD_LABEL__/$(printf '%q' "$LAUNCHD_LABEL")}"
  body="${body//__OPENCLAW_HOME_INPUT__/$(printf '%q' "$OPENCLAW_STATE_DIR")}"
  printf '%s' "$body"
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

snapshot_cmd() {
  local cmd=""

  if [ -n "$OPENCLAW_STATE_DIR" ]; then
    cmd+="OPENCLAW_SNAPSHOT_OPENCLAW_HOME=$(printf '%q' "$OPENCLAW_STATE_DIR") "
  fi
  cmd+="OPENCLAW_SNAPSHOT_HOST=$(printf '%q' "$HOST") $(printf '%q' "$SNAPSHOT_SCRIPT")"
  printf '%s' "$cmd"
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
    --service-manager)
      SERVICE_MANAGER="$2"
      shift 2
      ;;
    --launchd-label)
      LAUNCHD_LABEL="$2"
      shift 2
      ;;
    --openclaw-home|--state-dir)
      OPENCLAW_STATE_DIR="$2"
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
  snapshot)
    run_logged_local "snapshot" "$(snapshot_cmd)"
    ;;
  status)
    run_remote_openclaw "status" 'print_service_status'
    ;;
  restart)
    run_remote_openclaw "restart" 'restart_service
print_service_status'
    ;;
  logs)
    lines="${1:-120}"
    run_remote_openclaw "logs" 'print_service_logs '"$(printf '%q' "$lines")"
    ;;
  logs-knowhere)
    lines="${1:-120}"
    pattern="${OPENCLAW_KNOWHERE_LOG_PATTERN:-knowhere|tracker progress}"
    run_remote_openclaw "logs-knowhere" 'print_service_logs_filtered '"$(printf '%q' "$lines")"' '"$(printf '%q' "$pattern")"
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
sessions_dir="\$openclaw_home/agents/\$agent_name/sessions"
history_lines="\${OPENCLAW_WATCH_LINES:-120}"

if [ ! -d "\$sessions_dir" ]; then
  echo "agent not found or has no sessions directory: \$agent_name" >&2
  exit 1
fi

latest_session="\$(find_latest_session_file "\$sessions_dir")"
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
const emptyObjectJson = "{}";

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

function safeJson(value) {
  try {
    return JSON.stringify(value);
  } catch {
    return "[unserializable]";
  }
}

function omitKeys(value, keys) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return value;
  }

  const filtered = {};
  for (const [key, entryValue] of Object.entries(value)) {
    if (keys.has(key) || entryValue === undefined) {
      continue;
    }
    filtered[key] = entryValue;
  }
  return filtered;
}

function formatMetadata(value) {
  if (value === undefined) {
    return "";
  }
  if (typeof value === "string") {
    return value;
  }

  const json = safeJson(value);
  return json === emptyObjectJson ? "" : json;
}

function joinSegments(segments) {
  return segments.filter(Boolean).join(" ");
}

function formatRecordLabel(type, suffix) {
  if (!suffix) {
    return type;
  }
  return type + ":" + suffix;
}

function formatContentPart(part) {
  const type = typeof part.type === "string" && part.type ? part.type : "part";
  if (typeof part.data === "string" && part.data) {
    const binarySummary = joinSegments([
      typeof part.mimeType === "string" && part.mimeType ? "mimeType=" + part.mimeType : "",
      "dataChars=" + String(part.data.length),
      formatMetadata(omitKeys(part, new Set(["type", "data", "mimeType"]))),
    ]);
    return "[" + type + "] " + binarySummary;
  }

  const payload = formatMetadata(omitKeys(part, new Set(["type"])));
  if (!payload) {
    return "[" + type + "]";
  }
  return "[" + type + "] " + payload;
}

function readMessageEntries(message) {
  const fallbackRole = typeof message.role === "string" ? message.role : "unknown";
  if (typeof message.content === "string") {
    return message.content ? [{ role: fallbackRole, content: message.content }] : [];
  }

  const content = Array.isArray(message.content) ? message.content : [];
  const entries = [];

  for (const part of content) {
    if (typeof part === "string") {
      if (part) {
        entries.push({ role: fallbackRole, content: part });
      }
      continue;
    }
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
      continue;
    }

    entries.push({ role: fallbackRole, content: formatContentPart(part) });
  }

  return entries;
}

function readRecordEntries(record) {
  if (record.message && typeof record.message === "object") {
    const messageEntries = readMessageEntries(record.message);
    if (messageEntries.length > 0) {
      return messageEntries;
    }

    const messageRole =
      record.message && typeof record.message.role === "string" ? record.message.role : "message";
    const messageMetadata = formatMetadata(
      omitKeys(record.message, new Set(["role", "content"])),
    );
    if (messageMetadata) {
      return [{ role: messageRole, content: messageMetadata }];
    }
  }

  const recordType = typeof record.type === "string" && record.type ? record.type : "record";

  if (recordType === "session") {
    const sessionSummary = joinSegments([
      typeof record.id === "string" && record.id ? "id=" + record.id : "",
      typeof record.cwd === "string" && record.cwd ? "cwd=" + record.cwd : "",
      typeof record.parentSession === "string" && record.parentSession
        ? "parentSession=" + record.parentSession
        : "",
      formatMetadata(omitKeys(record, new Set(["type", "id", "cwd", "parentSession", "timestamp"]))),
    ]);
    return [{ role: "session", content: sessionSummary || safeJson(record) }];
  }

  if (recordType === "custom_message") {
    const customMessageContent =
      typeof record.content === "string" && record.content
        ? record.content
        : formatMetadata(record.content);
    const customMessageSummary = joinSegments([
      customMessageContent,
      formatMetadata(omitKeys(record, new Set(["type", "customType", "content", "timestamp"]))),
    ]);
    return [
      {
        role: formatRecordLabel(
          "custom_message",
          typeof record.customType === "string" && record.customType ? record.customType : "",
        ),
        content: customMessageSummary || safeJson(record),
      },
    ];
  }

  if (recordType === "custom") {
    const customSummary = joinSegments([
      formatMetadata(record.data),
      formatMetadata(omitKeys(record, new Set(["type", "customType", "data", "timestamp"]))),
    ]);
    return [
      {
        role: formatRecordLabel(
          "custom",
          typeof record.customType === "string" && record.customType ? record.customType : "",
        ),
        content: customSummary || safeJson(record),
      },
    ];
  }

  if (recordType === "compaction") {
    const compactionSummary = joinSegments([
      typeof record.summary === "string" && record.summary ? record.summary : "",
      typeof record.tokensBefore === "number" ? "tokensBefore=" + String(record.tokensBefore) : "",
      typeof record.firstKeptEntryId === "string" && record.firstKeptEntryId
        ? "firstKeptEntryId=" + record.firstKeptEntryId
        : "",
      formatMetadata(
        omitKeys(record, new Set(["type", "summary", "tokensBefore", "firstKeptEntryId", "timestamp"])),
      ),
    ]);
    return [{ role: "compaction", content: compactionSummary || safeJson(record) }];
  }

  if (recordType === "branch_summary") {
    const branchSummary = joinSegments([
      typeof record.summary === "string" && record.summary ? record.summary : "",
      formatMetadata(omitKeys(record, new Set(["type", "summary", "timestamp"]))),
    ]);
    return [{ role: "branch_summary", content: branchSummary || safeJson(record) }];
  }

  const recordSummary = formatMetadata(omitKeys(record, new Set(["type", "timestamp"])));
  return [{ role: recordType, content: recordSummary || safeJson(record) }];
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

  const timestamp =
    typeof record.timestamp === "string"
      ? record.timestamp
      : Number.isFinite(record.timestamp)
        ? new Date(record.timestamp).toISOString()
        : "";
  const entries = readRecordEntries(record);
  if (entries.length === 0) {
    return;
  }

  for (const entry of entries) {
    const formattedContent =
      entry.role === "toolResult" ? formatToolResultContent(entry.content) : entry.content;
    const prefix = timestamp ? timestamp + " " : "";
    process.stdout.write(prefix + "[" + entry.role + "] " + formattedContent + "\\n");
  }
});
'
EOF
)"
    stream_remote_openclaw "$remote_watch_script"
    ;;
  watch-knowhere)
    lines="${1:-120}"
    if [ "$#" -gt 1 ]; then
      echo "watch-knowhere accepts at most one optional line-count argument" >&2
      exit 1
    fi
    pattern="${OPENCLAW_KNOWHERE_LOG_PATTERN:-knowhere|tracker progress}"
    remote_watch_script="$(cat <<EOF
set -euo pipefail
lines=$(printf '%q' "$lines")
pattern=$(printf '%q' "$pattern")
follow_service_logs_filtered "\$lines" "\$pattern"
EOF
)"
    stream_remote_openclaw "$remote_watch_script"
    ;;
  service-file)
    run_remote_openclaw "service-file" 'print_service_file'
    ;;
  runtime-exec)
    if [ "$#" -eq 0 ]; then
      echo "runtime-exec requires a remote command" >&2
      exit 1
    fi
    run_remote_openclaw "runtime-exec" "$*"
    ;;
  doctor)
    run_remote_openclaw "doctor" 'run_openclaw doctor --non-interactive'
    ;;
  health)
    run_remote_openclaw "health" 'run_openclaw health'
    ;;
  update|update-pnpm|update-npm)
    run_remote_openclaw "update-pnpm" 'ensure_pnpm_available
"$pnpm_bin" add -g openclaw@latest
run_openclaw doctor --yes --fix
reload_service_manager
restart_service
run_openclaw health
print_service_status'
    ;;
  install-gateway-no-proxy)
    if [ "$#" -ne 1 ]; then
      echo "install-gateway-no-proxy requires one comma-separated NO_PROXY value" >&2
      exit 1
    fi
    no_proxy_value="$1"
    remote_install_script="$(cat <<EOF
set -euo pipefail
target_no_proxy=$(printf '%q' "$no_proxy_value")

merge_no_proxy_csv() {
  local current="\$1"
  local additions="\$2"
  local merged=""
  local list=""
  local entry=""
  local trimmed=""
  local old_ifs="\$IFS"

  for list in "\$current" "\$additions"; do
    [ -z "\$list" ] && continue
    IFS=','
    read -r -a entries <<<"\$list"
    IFS="\$old_ifs"
    for entry in "\${entries[@]}"; do
      trimmed="\$(printf '%s' "\$entry" | sed 's/^[[:space:]]*//; s/[[:space:]]*\$//')"
      [ -z "\$trimmed" ] && continue
      case ",\$merged," in
        *",\$trimmed,"*) ;;
        *)
          if [ -z "\$merged" ]; then
            merged="\$trimmed"
          else
            merged="\$merged,\$trimmed"
          fi
          ;;
      esac
    done
  done

  printf '%s\n' "\$merged"
}

set_or_unset_env_var() {
  local key="\$1"
  local value="\$2"

  if [ -n "\$value" ]; then
    export "\$key=\$value"
    return 0
  fi

  unset "\$key" || true
}

if [ "\$service_manager" != "launchd" ]; then
  echo "install-gateway-no-proxy currently supports launchd-managed hosts only" >&2
  exit 1
fi

current_http_proxy="\$(read_launchd_value 'EnvironmentVariables:HTTP_PROXY' 2>/dev/null || true)"
current_https_proxy="\$(read_launchd_value 'EnvironmentVariables:HTTPS_PROXY' 2>/dev/null || true)"
current_all_proxy="\$(read_launchd_value 'EnvironmentVariables:ALL_PROXY' 2>/dev/null || true)"
current_no_proxy="\$(read_launchd_value 'EnvironmentVariables:NO_PROXY' 2>/dev/null || true)"
merged_no_proxy="\$(merge_no_proxy_csv "\$current_no_proxy" "\$target_no_proxy")"

set_or_unset_env_var HTTP_PROXY "\$current_http_proxy"
set_or_unset_env_var HTTPS_PROXY "\$current_https_proxy"
set_or_unset_env_var ALL_PROXY "\$current_all_proxy"
set_or_unset_env_var NO_PROXY "\$merged_no_proxy"
set_or_unset_env_var no_proxy "\$merged_no_proxy"

echo "Reinstalling gateway with NO_PROXY=\$merged_no_proxy"
run_openclaw gateway install --runtime node --force
sleep 2
print_service_status
echo "LaunchAgent NO_PROXY:"
read_launchd_value 'EnvironmentVariables:NO_PROXY' 2>/dev/null || true
EOF
)"
    run_remote_openclaw "install-gateway-no-proxy" "$remote_install_script"
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
