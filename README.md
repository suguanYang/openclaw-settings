# openclaw-settings

Local-only Git repo for tracking OpenClaw settings changes over time.

## Scope
- Tracks sanitized snapshots from `~/.openclaw`.
- Intended for local change tracking only.
- No remote is configured by default.

## Usage
1. Run `./scripts/snapshot.sh`
2. Review: `git -C . status` and `git -C . diff`
3. Commit when needed.
