# openclaw-settings

Local Git repo for managing and auditing host-specific OpenClaw deployments.

## Repo layout
- `managed/`: authoritative desired state for rebuilds.
- `profiles/`: tracked non-secret host values such as paths, ports, IDs, and origins.
- `.secrets/`: gitignored secret env files.
- `snapshots/`: redacted mirrors of the live host state.
- `operation-logs/`: append-only server interaction logs.
- `context/`: host notes, runbooks, and the state-model docs.

## Fresh-host rebuild
1. Install Node 22+ on the target host.
2. Copy `managed/secrets.example.env` to `.secrets/<host>.env` and fill the secrets locally.
3. Copy `profiles/oracle.ylioo.com.env` to `profiles/<host>.env` and adjust the non-secret values for the target host.
4. Render the concrete host state locally:
   `./scripts/render-managed-state.sh --profile profiles/<host>.env --secrets-file .secrets/<host>.env`
5. Apply the managed state to the server:
   `./scripts/apply-managed-host.sh --host <ssh-host> --profile profiles/<host>.env --secrets-file .secrets/<host>.env`
6. Refresh the redacted snapshot and commit the drift:
   `OPENCLAW_SNAPSHOT_HOST=<ssh-host> ./scripts/snapshot.sh`

## Oracle helper flow
- Status: `./scripts/oracle-openclaw.sh status`
- Restart: `./scripts/oracle-openclaw.sh restart`
- Logs: `./scripts/oracle-openclaw.sh logs 120`
- Health: `./scripts/oracle-openclaw.sh health`
- Snapshot: `./scripts/oracle-openclaw.sh snapshot`
- Update: `./scripts/oracle-openclaw.sh update`
- Discord multi-account cutover helper: `./scripts/oracle-discord-cutover.sh`

## Redaction and secrets
- Never commit plaintext secrets.
- `managed/` and `profiles/` are tracked; `.secrets/` is local only.
- `snapshots/` and `operation-logs/` must contain only redacted values.

## State model
The rebuild boundary is documented in `context/source-of-truth.md`.

## Current coverage
- As of 2026-03-11 UTC, `managed/` + `profiles/oracle.ylioo.com.env` + local `.secrets/oracle.ylioo.com.env` are sufficient to recreate the current Oracle OpenClaw deployment without reading the live host config by hand.
- Snapshot-only files under `snapshots/` are runtime or generated state such as thread bindings, device state, exec approvals, backups, and the generated systemd service.
