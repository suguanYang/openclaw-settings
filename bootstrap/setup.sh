#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_ROOT="$ROOT/bootstrap"
PROFILE="${BOOTSTRAP_PROFILE:-}"
HOST="${BOOTSTRAP_HOST:-}"
SECRETS_FILE=""
SKIP_VERIFY=0
RENDER_ONLY=0
YES=0
NON_INTERACTIVE=0

usage() {
  cat <<'USAGE'
Usage: ./bootstrap/setup.sh [options]

Single-command bootstrap entrypoint for cloning a tracked OpenClaw deployment to
another host. The script auto-discovers bootstrap profiles, prompts for missing
secret values, and then delegates to the selected profile's apply helpers.

Options:
  --profile <name>        Bootstrap profile under bootstrap/<name>/
  --host <ssh-host>       Target SSH host or alias. If you omit the user part,
                          the script prefixes the tracked OPENCLAW_HOST_USER.
  --secrets-file <path>   Local secrets env file to use. Defaults to
                          .secrets/<profile>.env
  --skip-verify           Skip post-apply status and health checks
  --render-only           Only render the staged build tree; do not SSH/apply
  --yes                   Skip the final confirmation prompt
  --non-interactive       Fail instead of prompting for missing input
  -h, --help              Show this help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    --secrets-file)
      SECRETS_FILE="$2"
      shift 2
      ;;
    --skip-verify)
      SKIP_VERIFY=1
      shift
      ;;
    --render-only)
      RENDER_ONLY=1
      shift
      ;;
    --yes)
      YES=1
      shift
      ;;
    --non-interactive)
      NON_INTERACTIVE=1
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

is_interactive() {
  [ -t 0 ] && [ "$NON_INTERACTIVE" -eq 0 ]
}

discover_profiles() {
  find "$BOOTSTRAP_ROOT" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
    if [ -f "$dir/apply-build-host.sh" ] && [ -f "$dir/render-build-state.sh" ]; then
      basename "$dir"
    fi
  done | sort
}

choose_profile() {
  local selected=""
  mapfile -t profiles < <(discover_profiles)

  if [ "${#profiles[@]}" -eq 0 ]; then
    echo "no bootstrap profiles found under $BOOTSTRAP_ROOT" >&2
    exit 1
  fi

  if [ -n "$PROFILE" ]; then
    for candidate in "${profiles[@]}"; do
      if [ "$candidate" = "$PROFILE" ]; then
        selected="$PROFILE"
        break
      fi
    done
    if [ -z "$selected" ]; then
      echo "unknown bootstrap profile: $PROFILE" >&2
      exit 1
    fi
    printf '%s\n' "$selected"
    return 0
  fi

  if [ "${#profiles[@]}" -eq 1 ]; then
    printf '%s\n' "${profiles[0]}"
    return 0
  fi

  if ! is_interactive; then
    echo "multiple bootstrap profiles found; pass --profile in non-interactive mode" >&2
    exit 1
  fi

  echo "Available bootstrap profiles:" >&2
  local idx=1
  for candidate in "${profiles[@]}"; do
    printf '  %d) %s\n' "$idx" "$candidate" >&2
    idx=$((idx + 1))
  done

  while true; do
    local reply=""
    read -r -p "Select profile [1]: " reply
    if [ -z "$reply" ]; then
      reply=1
    fi
    if [[ "$reply" =~ ^[0-9]+$ ]] && [ "$reply" -ge 1 ] && [ "$reply" -le "${#profiles[@]}" ]; then
      printf '%s\n' "${profiles[$((reply - 1))]}"
      return 0
    fi
    echo "invalid selection: $reply" >&2
  done
}

read_build_host_user() {
  local build_dir="$1"
  local build_env_template

  build_env_template="$(find "$build_dir/rootfs/home" -path '*/.openclaw/.env' -type f | head -n 1 || true)"
  if [ -z "$build_env_template" ]; then
    return 0
  fi

  awk -F= '/^OPENCLAW_HOST_USER=/{print $2}' "$build_env_template" | head -n 1
}

ensure_local_prereqs() {
  local missing=()
  local cmd
  for cmd in bash ssh tar python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "missing local prerequisites: ${missing[*]}" >&2
    exit 1
  fi
}

ensure_secrets_file_exists() {
  local example_file="$1"
  local target_file="$2"

  mkdir -p "$(dirname "$target_file")"
  if [ ! -f "$target_file" ]; then
    cp "$example_file" "$target_file"
    chmod 600 "$target_file"
    printf 'Created %s from %s\n' "$target_file" "$example_file" >&2
  fi
}

set_env_var_in_file() {
  local file="$1"
  local key="$2"
  local value="$3"
  local escaped
  local tmp

  printf -v escaped '%q' "$value"
  tmp="$(mktemp)"
  awk -v key="$key" -v replacement="${key}=${escaped}" '
    $0 ~ "^" key "=" {
      print replacement
      seen=1
      next
    }
    {
      print
    }
    END {
      if (!seen) {
        print replacement
      }
    }
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

env_var_is_missing() {
  local file="$1"
  local key="$2"
  local line

  line="$(grep -E "^${key}=" "$file" | tail -n 1 || true)"
  [ -z "$line" ] || [ "$line" = "${key}=" ]
}

looks_sensitive() {
  case "$1" in
    *TOKEN*|*PASSWORD*|*SECRET*|*API_KEY*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

prompt_for_value() {
  local key="$1"
  local optional_flag="$2"
  local value=""
  local prompt="$key"

  if [ "$optional_flag" -eq 1 ]; then
    prompt="$prompt (optional)"
  fi

  while true; do
    if looks_sensitive "$key"; then
      read -r -s -p "Enter $prompt: " value
      printf '\n' >&2
    else
      read -r -p "Enter $prompt: " value
    fi

    if [ -n "$value" ] || [ "$optional_flag" -eq 1 ]; then
      printf '%s' "$value"
      return 0
    fi

    echo "$key is required" >&2
  done
}

fill_missing_secrets() {
  local example_file="$1"
  local target_file="$2"
  local missing_required=()
  local current_optional=0

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '')
        current_optional=0
        ;;
      \#*)
        case "$line" in
          *[Oo]ptional*)
            current_optional=1
            ;;
        esac
        ;;
      *=*)
        local key="${line%%=*}"
        local env_value="${!key-}"
        if ! env_var_is_missing "$target_file" "$key"; then
          continue
        fi
        if [ -n "$env_value" ]; then
          set_env_var_in_file "$target_file" "$key" "$env_value"
          continue
        fi
        if ! is_interactive; then
          if [ "$current_optional" -eq 0 ]; then
            missing_required+=("$key")
          fi
          continue
        fi
        local prompted
        prompted="$(prompt_for_value "$key" "$current_optional")"
        if [ -n "$prompted" ]; then
          set_env_var_in_file "$target_file" "$key" "$prompted"
        fi
        ;;
    esac
  done <"$example_file"

  if [ "${#missing_required[@]}" -gt 0 ]; then
    printf 'missing required secrets in %s: %s\n' "$target_file" "${missing_required[*]}" >&2
    printf 'Set them in the file or export matching env vars before retrying.\n' >&2
    exit 1
  fi
}

probe_ssh_connectivity() {
  local host="$1"
  local tmp
  tmp="$(mktemp)"
  if ssh "$host" 'printf connected' >"$tmp" 2>&1; then
    cat "$tmp" >&2
    rm -f "$tmp"
    return 0
  fi
  cat "$tmp" >&2
  rm -f "$tmp"
  echo "ssh connectivity check failed for $host" >&2
  exit 1
}

confirm_summary() {
  local profile="$1"
  local host="$2"
  local secrets_file="$3"
  local render_only="$4"

  echo "Bootstrap summary:" >&2
  printf '  profile: %s\n' "$profile" >&2
  printf '  secrets: %s\n' "$secrets_file" >&2
  if [ "$render_only" -eq 1 ]; then
    printf '  action: render only\n' >&2
  else
    printf '  host: %s\n' "$host" >&2
    printf '  action: render, upload, install, verify\n' >&2
  fi

  if [ "$YES" -eq 1 ] || ! is_interactive; then
    return 0
  fi

  local reply=""
  read -r -p "Continue? [Y/n] " reply
  case "$reply" in
    ''|y|Y|yes|YES)
      return 0
      ;;
    *)
      echo "aborted" >&2
      exit 1
      ;;
  esac
}

PROFILE="$(choose_profile)"
PROFILE_DIR="$BOOTSTRAP_ROOT/$PROFILE"
BUILD_DIR="$ROOT/build/$PROFILE"
EXAMPLE_SECRETS_FILE="$BUILD_DIR/secrets.example.env"
APPLY_SCRIPT="$PROFILE_DIR/apply-build-host.sh"
RENDER_SCRIPT="$PROFILE_DIR/render-build-state.sh"
HOST_HELPER="$PROFILE_DIR/host-openclaw.sh"
BUILD_HOST_USER="$(read_build_host_user "$BUILD_DIR")"

if [ ! -d "$BUILD_DIR/rootfs" ]; then
  echo "missing build tree for profile $PROFILE: $BUILD_DIR/rootfs" >&2
  exit 1
fi

if [ ! -f "$EXAMPLE_SECRETS_FILE" ]; then
  echo "missing secrets example for profile $PROFILE: $EXAMPLE_SECRETS_FILE" >&2
  exit 1
fi

if [ -z "$SECRETS_FILE" ]; then
  SECRETS_FILE="$ROOT/.secrets/$PROFILE.env"
fi

ensure_local_prereqs
ensure_secrets_file_exists "$EXAMPLE_SECRETS_FILE" "$SECRETS_FILE"
fill_missing_secrets "$EXAMPLE_SECRETS_FILE" "$SECRETS_FILE"

if [ "$RENDER_ONLY" -eq 0 ]; then
  if [ -z "$HOST" ]; then
    if ! is_interactive; then
      echo "missing target host; pass --host in non-interactive mode" >&2
      exit 1
    fi
    read -r -p "Target SSH host or alias: " HOST
    if [ -z "$HOST" ]; then
      echo "target host is required" >&2
      exit 1
    fi
  fi

  if [[ "$HOST" != *@* ]] && [ -n "$BUILD_HOST_USER" ]; then
    HOST="${BUILD_HOST_USER}@${HOST}"
  fi

  probe_ssh_connectivity "$HOST"
fi

confirm_summary "$PROFILE" "$HOST" "$SECRETS_FILE" "$RENDER_ONLY"

if [ "$RENDER_ONLY" -eq 1 ]; then
  exec "$RENDER_SCRIPT" --build-dir "$BUILD_DIR" --secrets-file "$SECRETS_FILE"
fi

"$APPLY_SCRIPT" --host "$HOST" --build-dir "$BUILD_DIR" --secrets-file "$SECRETS_FILE"

if [ "$SKIP_VERIFY" -eq 0 ] && [ -x "$HOST_HELPER" ]; then
  "$HOST_HELPER" --host "$HOST" status
  "$HOST_HELPER" --host "$HOST" health
fi
