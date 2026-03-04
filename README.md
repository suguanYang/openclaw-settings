# openclaw-settings

Local-only Git repo for tracking OpenClaw settings changes over time.

## Scope
- Tracks sanitized snapshots from `~/.openclaw` (local) or a remote host over SSH.
- Intended for local change tracking only.
- No remote is configured by default.

## Usage
1. Run `./scripts/snapshot.sh`
2. Or snapshot from server: `OPENCLAW_SNAPSHOT_HOST=oracle.ylioo.com ./scripts/snapshot.sh`
3. Review: `git -C . status` and `git -C . diff`
4. Commit when needed.

## Redaction
- The snapshot script redacts common secrets (API keys, tokens, passwords, bearer/cookie values, emails).
- It also redacts sensitive JSON key paths by name (`token`, `secret`, `password`, etc.).
