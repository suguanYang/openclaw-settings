# openclaw-settings

Local-only Git repo for tracking redacted OpenClaw server state, operator logs, and host-specific runbooks.

## Scope
- Tracks sanitized snapshots from `~/.openclaw` locally or over SSH.
- Stores Oracle host operation logs under `operation-logs/`.
- Stores host-specific helper context under `context/`.
- No remote is configured by default.

## Usage
1. Refresh the redacted server snapshot:
   `OPENCLAW_SNAPSHOT_HOST=oracle.ylioo.com ./scripts/snapshot.sh`
2. Use the Oracle helper shell for common operations:
   `./scripts/oracle-openclaw.sh status`
   `./scripts/oracle-openclaw.sh logs 120`
   `./scripts/oracle-openclaw.sh snapshot`
   `./scripts/oracle-openclaw.sh update`
3. Review drift:
   `git -C . status`
   `git -C . diff`
4. Commit after each meaningful server/config change.

## Redaction
- The snapshot script redacts common secrets (API keys, tokens, passwords, bearer/cookie values, emails).
- It also redacts sensitive JSON key paths by name (`token`, `secret`, `password`, etc.).
- Operation logs and context files must never contain plaintext secrets.
