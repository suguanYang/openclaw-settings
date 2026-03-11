# openclaw-settings

Local Git repo for managing, auditing, and documenting host-specific OpenClaw deployments.

## Upstream-first rule
- **OpenClaw itself is an open-source upstream project.**
- **OpenClaw updates frequently, so local notes in this repo can drift.**
- **Before making claims about OpenClaw behavior, config shape, commands, or features, always check the official docs at `https://docs.openclaw.ai` and the upstream source at `https://github.com/openclaw/openclaw`.**
- This repo is the source of truth for our managed deployment state, not for generic upstream product behavior.

## Information hierarchy
Read the repo from broad to narrow:
1. `README.md`: repo purpose, top-level data layers, and common operator flows.
2. `context/README.md`: documentation hierarchy and storage rules.
3. `context/architecture/`: repo-wide state model and structural rules.
4. `context/hosts/<host>/`: host dossiers, runbooks, projects, and repair notes.
5. `context/design/`: future function proposals and accepted design decisions.
6. `operation-logs/` and `build/`: exact evidence and the current path-faithful live mirror.

## Repo layout
- `build/`: path-faithful host build mirrors plus step-by-step rebuild books.
- `managed/`: authoritative desired state for rebuilds.
- `profiles/`: tracked non-secret host values such as paths, ports, IDs, and origins.
- `.secrets/`: gitignored secret env files.
- `operation-logs/`: append-only server interaction logs.
- `context/architecture/`: repo-wide model and source-of-truth boundary.
- `context/hosts/`: per-host dossiers with small, focused docs.
- `context/design/`: future-facing proposals and decisions.

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
- `build/` and `operation-logs/` must contain only redacted or placeholder-safe values.

## State model
The rebuild boundary is documented in `context/architecture/source-of-truth.md`.

## Build mirrors
- `build/` is the host-path-oriented view.
- It mirrors files into exact host-style paths under `build/<host>/rootfs/`.
- It is refreshed from the live host capture plus the local profile and secret contract, so it is convenient for inspection and step-by-step rebuilds but is not the primary source of truth.
- Refresh it with `./scripts/oracle-openclaw.sh snapshot` or `OPENCLAW_SNAPSHOT_HOST=<ssh-host> ./scripts/snapshot.sh`.

## Documentation update rules
- Live host behavior changed: update `operation-logs/` plus the smallest relevant file under `context/hosts/<host>/`.
- Repo-wide policy or storage rules changed: update `context/architecture/`.
- A new function or workflow is being designed: add a record under `context/design/proposals/` and promote it to `context/design/decisions/` when accepted.

## Current coverage
- As of 2026-03-11 UTC, `managed/` + `profiles/oracle.ylioo.com.env` + local `.secrets/oracle.ylioo.com.env` are sufficient to recreate the current Oracle OpenClaw deployment without reading the live host config by hand.
- Build-mirror-only files under `build/oracle.ylioo.com/rootfs/` include runtime or generated state such as thread bindings, device state, exec approvals, backups, and the generated systemd service.
