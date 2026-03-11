#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${OPENCLAW_HOST:-oracle.ylioo.com}"
SECRETS_FILE="${OPENCLAW_DISCORD_TOKENS_FILE:-$ROOT/.secrets/oracle-discord-bots.env}"
GUILD_ID="${OPENCLAW_DISCORD_GUILD_ID:-565501940742619145}"
CHANNEL_ID="${OPENCLAW_DISCORD_CHANNEL_ID:-565501941510045707}"
REMOTE_STATE_DIR='~/.openclaw'
REMOTE_ENV_TMP="$REMOTE_STATE_DIR/oracle-discord-bots.env.tmp"

require_file() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "missing required file: $path" >&2
    exit 1
  fi
}

require_file "$SECRETS_FILE"

echo "Copying gitignored Discord token env file to $HOST (temporary remote file only)..."
ssh "$HOST" "umask 077 && mkdir -p $REMOTE_STATE_DIR && cat > $REMOTE_ENV_TMP" < "$SECRETS_FILE"

echo "Merging Discord token vars into Oracle ~/.openclaw/.env..."
ssh "$HOST" "python3 - <<'PY'
from pathlib import Path
import os

home = Path.home()
state_dir = home / '.openclaw'
env_path = state_dir / '.env'
incoming_path = state_dir / 'oracle-discord-bots.env.tmp'

managed_prefixes = (
    'DISCORD_MANAGER_TOKEN=',
    'DISCORD_ENGINEER_TOKEN=',
    'DISCORD_RESEARCHER_TOKEN=',
    'DISCORD_REPORTER_TOKEN=',
    'DISCORD_TRACKER_TOKEN=',
)

existing_lines = []
if env_path.exists():
    existing_lines = env_path.read_text(encoding='utf-8').splitlines()

incoming_lines = [
    line for line in incoming_path.read_text(encoding='utf-8').splitlines()
    if line.strip()
]

merged = [
    line for line in existing_lines
    if not any(line.startswith(prefix) for prefix in managed_prefixes)
]
merged.extend(incoming_lines)

env_path.write_text('\\n'.join(merged) + '\\n', encoding='utf-8')
os.chmod(env_path, 0o600)
incoming_path.unlink(missing_ok=True)

print(f'wrote={env_path}')
print('managed_vars=5')
PY"

echo "Patching Oracle ~/.openclaw/openclaw.json for Discord multi-account routing..."
ssh "$HOST" "python3 - <<'PY'
from pathlib import Path
from datetime import datetime, timezone
import json
import shutil

guild_id = '$GUILD_ID'
channel_id = '$CHANNEL_ID'

path = Path.home() / '.openclaw' / 'openclaw.json'
config = json.loads(path.read_text(encoding='utf-8'))

timestamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
backup = path.with_name(f'openclaw.json.pre-discord-multi-account.{timestamp}.bak')
shutil.copy2(path, backup)

channels = config.setdefault('channels', {})
discord = channels.setdefault('discord', {})
discord.pop('token', None)
discord['defaultAccount'] = 'manager'
discord['accounts'] = {
    'manager': {
        'name': 'OpenClaw Manager',
        'token': '\${DISCORD_MANAGER_TOKEN}',
    },
    'engineer': {
        'name': 'OpenClaw Engineer',
        'token': '\${DISCORD_ENGINEER_TOKEN}',
    },
    'researcher': {
        'name': 'OpenClaw Researcher',
        'token': '\${DISCORD_RESEARCHER_TOKEN}',
    },
    'reporter': {
        'name': 'OpenClaw Reporter',
        'token': '\${DISCORD_REPORTER_TOKEN}',
    },
    'tracker': {
        'name': 'OpenClaw Tracker',
        'token': '\${DISCORD_TRACKER_TOKEN}',
    },
}

bindings = config.setdefault('bindings', [])
filtered = []
for binding in bindings:
    if binding.get('type') != 'route':
        filtered.append(binding)
        continue
    match = binding.get('match') or {}
    peer = match.get('peer') or {}
    if match.get('channel') == 'discord' and peer.get('kind') == 'channel' and peer.get('id') == channel_id:
        continue
    filtered.append(binding)

filtered.extend([
    {
        'agentId': 'research-lead',
        'match': {
            'channel': 'discord',
            'accountId': 'manager',
            'peer': {'kind': 'channel', 'id': channel_id},
        },
        'type': 'route',
    },
    {
        'agentId': 'engineer',
        'match': {
            'channel': 'discord',
            'accountId': 'engineer',
            'peer': {'kind': 'channel', 'id': channel_id},
        },
        'type': 'route',
    },
    {
        'agentId': 'researcher',
        'match': {
            'channel': 'discord',
            'accountId': 'researcher',
            'peer': {'kind': 'channel', 'id': channel_id},
        },
        'type': 'route',
    },
    {
        'agentId': 'reporter',
        'match': {
            'channel': 'discord',
            'accountId': 'reporter',
            'peer': {'kind': 'channel', 'id': channel_id},
        },
        'type': 'route',
    },
    {
        'agentId': 'tracker',
        'match': {
            'channel': 'discord',
            'accountId': 'tracker',
            'peer': {'kind': 'channel', 'id': channel_id},
        },
        'type': 'route',
    },
])

config['bindings'] = filtered
path.write_text(json.dumps(config, indent=2) + '\\n', encoding='utf-8')

print(f'backup={backup.name}')
print('accounts=manager,engineer,researcher,reporter,tracker')
print(f'guild={guild_id}')
print(f'channel={channel_id}')
PY"

echo "Cutover file updates complete on $HOST."
