#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$ROOT/.tmp/snapshot.$$"
SRC_STAGE="$TMP/src"
SNAPSHOT_OPENCLAW_HOME="${OPENCLAW_SNAPSHOT_OPENCLAW_HOME:-}"

# Optional: set OPENCLAW_SNAPSHOT_HOST to capture from a remote host over SSH.
HOST="${OPENCLAW_SNAPSHOT_HOST:-}"
CAPTURE_ID="${HOST:-local}"
OUT_BASE="$ROOT/.tmp/live/$CAPTURE_ID"
ROOTFS_OUT="$OUT_BASE/rootfs"

mkdir -p "$OUT_BASE" "$ROOT/.tmp" "$SRC_STAGE"
trap 'rm -rf "$TMP"' EXIT

copy_local_file() {
  local abs="$1"
  local rel
  [ -f "$abs" ] || return 0
  rel="${abs#/}"
  mkdir -p "$SRC_STAGE/$(dirname "$rel")"
  cp "$abs" "$SRC_STAGE/$rel"
}

collect_openclaw_tree_local() {
  local base="$1"
  [ -d "$base" ] || return 0

  copy_local_file "$base/openclaw.json"
  copy_local_file "$base/exec-approvals.json"
  copy_local_file "$base/sandbox/containers.json"
  copy_local_file "$base/cron/jobs.json"
  copy_local_file "$base/cron/jobs.json.bak"
  copy_local_file "$base/acp-harness.env"
  copy_local_file "$base/discord/model-picker-preferences.json"
  copy_local_file "$base/discord/thread-bindings.json"
  copy_local_file "$base/devices/paired.json"
  copy_local_file "$base/devices/pending.json"

  local workspace_dir
  local f
  for workspace_dir in "$base"/workspace "$base"/workspace-*; do
    [ -d "$workspace_dir" ] || continue
    for f in "$workspace_dir"/*.md; do
      [ -f "$f" ] || continue
      copy_local_file "$f"
    done
    for f in "$workspace_dir"/skills/*/SKILL.md; do
      [ -f "$f" ] || continue
      copy_local_file "$f"
    done
  done

  for f in "$base"/openclaw.json.bak*; do
    [ -f "$f" ] || continue
    copy_local_file "$f"
  done

  for f in "$base"/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    copy_local_file "$f"
  done
}

collect_local() {
  local base="${SNAPSHOT_OPENCLAW_HOME:-${OPENCLAW_HOME:-$HOME/.openclaw}}"

  collect_openclaw_tree_local "$base"
  copy_local_file "$HOME/.acpx/config.json"
  copy_local_file "$HOME/.codex/config.toml"
  copy_local_file "$HOME/.config/systemd/user/openclaw-gateway.service"
  copy_local_file "$HOME/.config/systemd/user/openclaw-gateway.service.d/acp-harness.conf"
}

collect_remote() {
  local host="$1"
  local remote_cmd="bash -s"

  if [ -n "$SNAPSHOT_OPENCLAW_HOME" ]; then
    remote_cmd="OPENCLAW_HOME=$(printf '%q' "$SNAPSHOT_OPENCLAW_HOME") bash -s"
  fi

  ssh "$host" "$remote_cmd" <<'REMOTE' | tar -xf - -C "$SRC_STAGE"
set -euo pipefail
shopt -s nullglob

base="${OPENCLAW_HOME:-$HOME/.openclaw}"
paths=()

add_file() {
  local p="$1"
  [ -f "$p" ] && paths+=("${p#/}")
}

add_file "$base/openclaw.json"
add_file "$base/exec-approvals.json"
add_file "$base/sandbox/containers.json"
add_file "$base/cron/jobs.json"
add_file "$base/cron/jobs.json.bak"
add_file "$base/acp-harness.env"
add_file "$base/discord/model-picker-preferences.json"
add_file "$base/discord/thread-bindings.json"
add_file "$base/devices/paired.json"
add_file "$base/devices/pending.json"

for workspace_dir in "$base"/workspace "$base"/workspace-*; do
  [ -d "$workspace_dir" ] || continue
  for f in "$workspace_dir"/*.md; do
    [ -f "$f" ] && paths+=("${f#/}")
  done
  for f in "$workspace_dir"/skills/*/SKILL.md; do
    [ -f "$f" ] && paths+=("${f#/}")
  done
done

for f in "$base"/openclaw.json.bak*; do
  [ -f "$f" ] && paths+=("${f#/}")
done

for f in "$base"/skills/*/SKILL.md; do
  [ -f "$f" ] && paths+=("${f#/}")
done

add_file "$HOME/.acpx/config.json"
add_file "$HOME/.codex/config.toml"
add_file "$HOME/.config/systemd/user/openclaw-gateway.service"
add_file "$HOME/.config/systemd/user/openclaw-gateway.service.d/acp-harness.conf"

if [ "${#paths[@]}" -eq 0 ]; then
  exit 0
fi

tar -C / -cf - "${paths[@]}"
REMOTE
}

if [ -n "$HOST" ]; then
  collect_remote "$HOST"
  SOURCE_ID="$HOST"
else
  collect_local
  SOURCE_ID="local"
fi

python3 - "$SRC_STAGE" "$OUT_BASE" "$SOURCE_ID" <<'PY'
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

src_root = Path(sys.argv[1])
out_base = Path(sys.argv[2])
source_id = sys.argv[3]
rootfs_out = out_base / "rootfs"

SENSITIVE_KEY_NAMES = (
    "api_key",
    "apikey",
    "client_secret",
    "clientsecret",
)

SENSITIVE_KEY_PARTS = (
    "token",
    "secret",
    "password",
    "authorization",
    "cookie",
    "bearer",
    "private",
    "refresh",
)

NON_SENSITIVE_KEY_NAMES = {
    "max_tokens",
}

STRING_PATTERNS = [
    re.compile(r"\bsk-[A-Za-z0-9_-]{16,}\b"),
    re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b"),
    re.compile(r"\bBearer\s+[A-Za-z0-9%._\-]{20,}\b", re.IGNORECASE),
    re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"),
]

LINE_SECRET_PATTERN = re.compile(
    r"(?i)\b(api[_-]?key|token|secret|password|authorization|cookie)\b\s*[:=]\s*([^\s]+)"
)


def redact_string(value: str) -> str:
    redacted = value
    for pattern in STRING_PATTERNS:
        redacted = pattern.sub("<redacted>", redacted)
    redacted = LINE_SECRET_PATTERN.sub(lambda m: f"{m.group(1)}=<redacted>", redacted)
    return redacted


def normalize_key(key: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", key).lower().replace("-", "_")


def is_sensitive_key(key: str) -> bool:
    normalized = normalize_key(key)
    if normalized in NON_SENSITIVE_KEY_NAMES:
        return False
    if normalized in SENSITIVE_KEY_NAMES:
        return True
    return any(part in SENSITIVE_KEY_PARTS for part in normalized.split("_") if part)


def redact_json(value):
    if isinstance(value, dict):
        out = {}
        for key, item in value.items():
            if is_sensitive_key(str(key)):
                out[key] = "<redacted>"
            else:
                out[key] = redact_json(item)
        return out
    if isinstance(value, list):
        return [redact_json(v) for v in value]
    if isinstance(value, str):
        return redact_string(value)
    return value


def write_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


if rootfs_out.exists():
    shutil.rmtree(rootfs_out)
rootfs_out.mkdir(parents=True, exist_ok=True)

written = []
for src_file in sorted(src_root.rglob("*")):
    if not src_file.is_file():
        continue

    rel = src_file.relative_to(src_root)
    out_file = rootfs_out / rel
    out_file.parent.mkdir(parents=True, exist_ok=True)

    text = src_file.read_text(encoding="utf-8", errors="replace")
    if src_file.suffix.lower() == ".json":
        try:
            obj = json.loads(text)
            write_json(out_file, redact_json(obj))
        except json.JSONDecodeError:
            out_file.write_text(redact_string(text), encoding="utf-8")
    else:
        out_file.write_text(redact_string(text), encoding="utf-8")

    written.append(
        {
            "hostPath": "/" + rel.as_posix(),
            "buildPath": str(out_file.relative_to(out_base)),
            "sourcePath": "/" + rel.as_posix(),
            "mode": "live-capture",
        }
    )


manifest = {
    "capturedAtUtc": datetime.now(timezone.utc).isoformat(),
    "source": source_id,
    "fileCount": len(written),
    "files": written,
}
write_json(out_base / "manifest.json", manifest)
PY

echo "live capture updated in $OUT_BASE"
