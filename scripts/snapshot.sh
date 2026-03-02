#!/usr/bin/env bash
set -euo pipefail

SRC="${OPENCLAW_HOME:-$HOME/.openclaw}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/snapshots"

mkdir -p "$OUT/workspace" "$OUT/skills"

CONFIG="$SRC/openclaw.json"
if [ -f "$CONFIG" ]; then
  python3 - "$CONFIG" "$OUT/openclaw.json" <<'PY'
import json
import re
import sys
from pathlib import Path

src = Path(sys.argv[1])
out = Path(sys.argv[2])
obj = json.loads(src.read_text())

SENSITIVE_KEYS = {
    "apikey", "api_key", "token", "access", "refresh", "password", "secret",
    "clientsecret", "authorization", "bearer", "cookie",
}
SK_PATTERN = re.compile(r"\bsk-[A-Za-z0-9_-]{16,}\b")

def redact(val):
    if isinstance(val, dict):
        out = {}
        for k, v in val.items():
            lk = str(k).lower().replace("_", "")
            if lk in SENSITIVE_KEYS or lk.endswith("token") or lk.endswith("apikey"):
                out[k] = "<redacted>"
            else:
                out[k] = redact(v)
        return out
    if isinstance(val, list):
        return [redact(v) for v in val]
    if isinstance(val, str):
        s = SK_PATTERN.sub("<redacted>", val)
        if "authorization" in s.lower() and "bearer" in s.lower():
            return "<redacted>"
        return s
    return val

safe = redact(obj)
out.write_text(json.dumps(safe, indent=2, sort_keys=True) + "\n")
PY
else
  echo "warning: $CONFIG not found on this host; keeping existing snapshot files" >&2
fi

for f in AGENTS.md BOOTSTRAP.md SOUL.md USER.md IDENTITY.md TOOLS.md HEARTBEAT.md; do
  if [ -f "$SRC/workspace/$f" ]; then
    cp "$SRC/workspace/$f" "$OUT/workspace/$f"
  fi
done

if [ -d "$SRC/workspace/skills" ]; then
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$SRC/workspace/skills/" "$OUT/skills/"
  else
    rm -rf "$OUT/skills"
    mkdir -p "$OUT/skills"
    cp -R "$SRC/workspace/skills/." "$OUT/skills/"
  fi
fi

echo "snapshot updated in $OUT"
