#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="$ROOT/build/oracle.ylioo.com"
SECRETS_FILE=""
OUT_DIR="$ROOT/.tmp/bootstrap-rendered/oracle.ylioo.com"

usage() {
  cat <<'USAGE'
Usage: ./bootstrap/oracle.ylioo.com/render-build-state.sh [--build-dir <build/host>] --secrets-file <.secrets/host.env> [--out-dir <dir>]

Renders a tracked OpenClaw build rootfs into a temp directory without writing
secrets into git.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --build-dir)
      BUILD_DIR="$2"
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

if [ -z "$SECRETS_FILE" ]; then
  usage >&2
  exit 1
fi

if [ ! -d "$BUILD_DIR/rootfs" ]; then
  echo "missing build rootfs: $BUILD_DIR/rootfs" >&2
  exit 1
fi

if [ ! -f "$SECRETS_FILE" ]; then
  echo "missing secrets file: $SECRETS_FILE" >&2
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
cp -R "$BUILD_DIR/rootfs/." "$OUT_DIR/"

env_template="$(find "$BUILD_DIR/rootfs/home" -path '*/.openclaw/.env' -type f | head -n 1)"
if [ -z "$env_template" ]; then
  echo "missing build env template under $BUILD_DIR/rootfs/home/*/.openclaw/.env" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$env_template"
# shellcheck disable=SC1090
. "$SECRETS_FILE"
set +a

export ROOT BUILD_DIR SECRETS_FILE OUT_DIR
python3 - <<'PY'
import os
import re
from pathlib import Path

root = Path(os.environ["ROOT"]).resolve()
build_dir = Path(os.environ["BUILD_DIR"]).resolve()
secrets_file = Path(os.environ["SECRETS_FILE"]).resolve()
out_dir = Path(os.environ["OUT_DIR"]).resolve()

rootfs_dir = build_dir / "rootfs"
env_templates = list(rootfs_dir.glob("home/*/.openclaw/.env"))
if not env_templates:
    raise SystemExit("missing .env template in build rootfs")
env_template = env_templates[0]
rendered_env = out_dir / env_template.relative_to(rootfs_dir)

optional_blank = {"ANTHROPIC_AUTH_TOKEN"}
token_re = re.compile(r"__([A-Z0-9_]+)__")


def render_tokens(text: str) -> str:
    missing: set[str] = set()

    def replace(match: re.Match[str]) -> str:
        key = match.group(1)
        if key not in os.environ:
            return match.group(0)
        value = os.environ.get(key)
        if value == "" and key not in optional_blank:
            missing.add(key)
            return match.group(0)
        return value

    rendered = token_re.sub(replace, text)
    if missing:
        missing_names = ", ".join(sorted(missing))
        raise SystemExit(f"missing render variables: {missing_names}")
    return rendered


env_text = "\n".join(
    [
        env_template.read_text(encoding="utf-8").rstrip(),
        "",
        secrets_file.read_text(encoding="utf-8").rstrip(),
        "",
    ]
)
rendered_env.write_text(env_text, encoding="utf-8")

for file_path in sorted(out_dir.rglob("*")):
    if not file_path.is_file():
        continue
    text = file_path.read_text(encoding="utf-8", errors="replace")
    if "__" not in text:
        continue
    file_path.write_text(render_tokens(text).rstrip() + "\n", encoding="utf-8")

print(out_dir)
PY
