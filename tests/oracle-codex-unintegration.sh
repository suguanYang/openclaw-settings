#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORACLE_ROOT="$ROOT/build/oracle.ylioo.com/rootfs/home/suguan"
OPENCLAW_CONFIG="$ORACLE_ROOT/.openclaw/openclaw.json"
APPLY_SCRIPT="$ROOT/scripts/apply-build-host.sh"

require_missing() {
  local path="$1"
  if [ -e "$path" ]; then
    echo "expected managed path to be removed: $path" >&2
    exit 1
  fi
}

require_missing "$ORACLE_ROOT/.openclaw/acp-harness.env"
require_missing "$ORACLE_ROOT/.acpx/config.json"
require_missing "$ORACLE_ROOT/.codex/config.toml"
require_missing "$ORACLE_ROOT/.local/bin/openclaw-codex-acp"
require_missing "$ORACLE_ROOT/.local/share/openclaw-codex-acp/Dockerfile"
require_missing "$ORACLE_ROOT/.config/systemd/user/openclaw-gateway.service.d/acp-harness.conf"

python3 - "$OPENCLAW_CONFIG" <<'PY'
import json
import sys
from pathlib import Path

config = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))

acp = config.get("acp")
if acp != {"enabled": False}:
    raise SystemExit(f"expected acp to be disabled only, got: {acp!r}")

agent_to_agent_allow = config["tools"]["agentToAgent"]["allow"]
if "codex" in agent_to_agent_allow:
    raise SystemExit("unexpected Codex ACP route in tools.agentToAgent.allow")

discord_thread_bindings = config["channels"]["discord"]["threadBindings"]
if discord_thread_bindings.get("spawnAcpSessions") is not False:
    raise SystemExit("expected Discord ACP thread spawning to be disabled")

plugins = config["plugins"]
if "acpx" in plugins["allow"]:
    raise SystemExit("unexpected acpx plugin allow entry")
if "acpx" in plugins["entries"]:
    raise SystemExit("unexpected acpx plugin entry")
PY

if grep -Eq '@openai/codex|acpx@0\.1\.16|mcp-remote@0\.1\.38|docker build -t openclaw-codex-acp' "$APPLY_SCRIPT"; then
  echo "apply-build-host.sh still contains Codex ACP install/build steps" >&2
  exit 1
fi

grep -Fq 'remove_stale_codex_integration_paths' "$APPLY_SCRIPT"
