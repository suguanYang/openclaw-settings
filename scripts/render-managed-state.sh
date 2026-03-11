#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE=""
SECRETS_FILE=""
OUT_DIR=""

usage() {
  cat <<'USAGE'
Usage: ./scripts/render-managed-state.sh --profile <profiles/host.env> --secrets-file <.secrets/host.env> [--out-dir <dir>]

Renders managed OpenClaw state into a local temp directory without writing secrets into git.
Outputs:
  openclaw.json
  .env
  acp-harness.env
  manifest.json
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --secrets-file)
      SECRETS_FILE="$2"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="$2"
      shift 2
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

if [ -z "$PROFILE" ] || [ -z "$SECRETS_FILE" ]; then
  usage >&2
  exit 1
fi

if [ ! -f "$PROFILE" ]; then
  echo "missing profile file: $PROFILE" >&2
  exit 1
fi

if [ ! -f "$SECRETS_FILE" ]; then
  echo "missing secrets file: $SECRETS_FILE" >&2
  exit 1
fi

if [ -z "$OUT_DIR" ]; then
  profile_name="$(basename "$PROFILE" .env)"
  OUT_DIR="$ROOT/.tmp/rendered/$profile_name"
fi

mkdir -p "$OUT_DIR"

set -a
# shellcheck disable=SC1090
. "$PROFILE"
# shellcheck disable=SC1090
. "$SECRETS_FILE"
set +a

export ROOT PROFILE SECRETS_FILE OUT_DIR
python3 - <<'PY'
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

root = Path(os.environ["ROOT"])
profile_path = Path(os.environ["PROFILE"])
secrets_path = Path(os.environ["SECRETS_FILE"])
out_dir = Path(os.environ["OUT_DIR"])

optional_blank = {"ANTHROPIC_AUTH_TOKEN"}
profile_token_re = re.compile(r"__([A-Z0-9_]+)__")
secret_var_re = re.compile(r"\$\{([A-Z_][A-Z0-9_]*)\}")


def render_profile_tokens(text: str) -> str:
    missing: set[str] = set()

    def replace(match: re.Match[str]) -> str:
        key = match.group(1)
        value = os.environ.get(key)
        if value is None or (value == "" and key not in optional_blank):
            missing.add(key)
            return match.group(0)
        return value

    rendered = profile_token_re.sub(replace, text)
    if missing:
        missing_names = ", ".join(sorted(missing))
        raise SystemExit(f"missing render variables: {missing_names}")
    if profile_token_re.search(rendered):
        raise SystemExit("unresolved __VAR__ placeholders remain after render")
    return rendered


def ensure_config_secret_vars(text: str) -> list[str]:
    missing = []
    for key in sorted(set(secret_var_re.findall(text))):
        if os.environ.get(key, "") == "":
            missing.append(key)
    return missing


openclaw_template = (root / "managed" / "openclaw.json.template").read_text(encoding="utf-8")
rendered_openclaw = render_profile_tokens(openclaw_template)
json.loads(rendered_openclaw)

missing_secret_vars = ensure_config_secret_vars(rendered_openclaw)
if missing_secret_vars:
    missing_names = ", ".join(missing_secret_vars)
    raise SystemExit(f"missing config env vars for ${{VAR}} placeholders: {missing_names}")

(out_dir / "openclaw.json").write_text(rendered_openclaw.rstrip() + "\n", encoding="utf-8")

acp_template = (root / "managed" / "acp-harness.env.template").read_text(encoding="utf-8")
rendered_acp = render_profile_tokens(acp_template)
(out_dir / "acp-harness.env").write_text(rendered_acp.rstrip() + "\n", encoding="utf-8")

combined_env = "\n".join(
    [
        "# Rendered by scripts/render-managed-state.sh",
        f"# Profile: {profile_path}",
        profile_path.read_text(encoding="utf-8").rstrip(),
        "",
        f"# Secrets: {secrets_path}",
        secrets_path.read_text(encoding="utf-8").rstrip(),
        "",
    ]
)
(out_dir / ".env").write_text(combined_env, encoding="utf-8")

manifest = {
    "renderedAtUtc": datetime.now(timezone.utc).isoformat(),
    "profile": str(profile_path),
    "secretsFile": str(secrets_path),
    "outputs": ["openclaw.json", ".env", "acp-harness.env"],
    "configEnvVars": sorted(set(secret_var_re.findall(rendered_openclaw))),
}
(out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

print(out_dir)
PY
