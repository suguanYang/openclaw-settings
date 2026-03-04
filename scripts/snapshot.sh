#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/snapshots"
TMP="$ROOT/.tmp/snapshot.$$"
SRC_STAGE="$TMP/src"

# Optional: set OPENCLAW_SNAPSHOT_HOST to capture from a remote host over SSH.
HOST="${OPENCLAW_SNAPSHOT_HOST:-}"

mkdir -p "$OUT" "$ROOT/.tmp" "$SRC_STAGE"
trap 'rm -rf "$TMP"' EXIT

collect_local() {
  local base="$1"
  [ -d "$base" ] || return 0

  copy_if_exists() {
    local rel="$1"
    if [ -f "$base/$rel" ]; then
      mkdir -p "$SRC_STAGE/$(dirname "$rel")"
      cp "$base/$rel" "$SRC_STAGE/$rel"
    fi
  }

  copy_if_exists "openclaw.json"
  copy_if_exists "exec-approvals.json"
  copy_if_exists "sandbox/containers.json"
  copy_if_exists "cron/jobs.json"
  copy_if_exists "cron/jobs.json.bak"
  copy_if_exists "discord/model-picker-preferences.json"
  copy_if_exists "devices/paired.json"
  copy_if_exists "devices/pending.json"

  for f in AGENTS.md BOOTSTRAP.md SOUL.md USER.md IDENTITY.md TOOLS.md HEARTBEAT.md; do
    copy_if_exists "workspace/$f"
  done

  for f in "$base"/openclaw.json.bak*; do
    [ -f "$f" ] || continue
    rel="${f#$base/}"
    mkdir -p "$SRC_STAGE/$(dirname "$rel")"
    cp "$f" "$SRC_STAGE/$rel"
  done

  for f in "$base"/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    rel="${f#$base/}"
    mkdir -p "$SRC_STAGE/$(dirname "$rel")"
    cp "$f" "$SRC_STAGE/$rel"
  done
}

collect_remote() {
  local host="$1"
  ssh "$host" 'bash -s' <<'REMOTE' | tar -xf - -C "$SRC_STAGE"
set -euo pipefail
shopt -s nullglob
base="${OPENCLAW_HOME:-$HOME/.openclaw}"
cd "$base"
paths=()

add_file() {
  local p="$1"
  [ -f "$p" ] && paths+=("$p")
}

add_file "openclaw.json"
add_file "exec-approvals.json"
add_file "sandbox/containers.json"
add_file "cron/jobs.json"
add_file "cron/jobs.json.bak"
add_file "discord/model-picker-preferences.json"
add_file "devices/paired.json"
add_file "devices/pending.json"

for f in workspace/AGENTS.md workspace/BOOTSTRAP.md workspace/SOUL.md workspace/USER.md workspace/IDENTITY.md workspace/TOOLS.md workspace/HEARTBEAT.md; do
  add_file "$f"
done

for f in openclaw.json.bak*; do
  [ -f "$f" ] && paths+=("$f")
done

for f in skills/*/SKILL.md; do
  [ -f "$f" ] && paths+=("$f")
done

if [ "${#paths[@]}" -eq 0 ]; then
  exit 0
fi

tar -cf - "${paths[@]}"
REMOTE
}

if [ -n "$HOST" ]; then
  collect_remote "$HOST"
  SOURCE_ID="$HOST"
else
  collect_local "${OPENCLAW_HOME:-$HOME/.openclaw}"
  SOURCE_ID="local"
fi

python3 - "$SRC_STAGE" "$OUT" "$SOURCE_ID" <<'PY'
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

src_root = Path(sys.argv[1])
out_root = Path(sys.argv[2])
source_id = sys.argv[3]

SENSITIVE_KEY_PARTS = (
    "api_key",
    "apikey",
    "token",
    "secret",
    "password",
    "authorization",
    "cookie",
    "bearer",
    "private",
    "client_secret",
    "clientsecret",
    "refresh",
)

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

def is_sensitive_key(key: str) -> bool:
    normalized = key.lower().replace("-", "_")
    return any(part in normalized for part in SENSITIVE_KEY_PARTS)

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

written = []
for src_file in sorted(src_root.rglob("*")):
    if not src_file.is_file():
        continue

    rel = src_file.relative_to(src_root)
    out_file = out_root / rel
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
    written.append(str(rel))

meta = {
    "capturedAtUtc": datetime.now(timezone.utc).isoformat(),
    "source": source_id,
    "fileCount": len(written),
    "files": written,
}
write_json(out_root / "_meta.json", meta)
PY

echo "snapshot updated in $OUT"
