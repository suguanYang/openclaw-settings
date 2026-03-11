# openclaw-settings

Local Git repo for managing, auditing, and documenting host-specific OpenClaw deployments.

## Upstream-first rule
- **OpenClaw itself is an open-source upstream project.**
- **OpenClaw updates frequently, so local notes in this repo can drift.**
- **Before making claims about OpenClaw behavior, config shape, commands, or features, always check the official docs at `https://docs.openclaw.ai` and the upstream source at `https://github.com/openclaw/openclaw`.**
- This repo is the source of truth for our intended deployment state, not for generic upstream product behavior.

## Information hierarchy
Read the repo from broad to narrow:
1. `README.md`: repo purpose, top-level data layers, and common operator flows.
2. `context/README.md`: documentation hierarchy and storage rules.
3. `context/architecture/`: repo-wide state model and structural rules.
4. `context/hosts/<host>/`: host dossiers, runbooks, projects, and repair notes.
5. `context/design/`: future function proposals and accepted design decisions.
6. `operation-logs/` and `build/`: exact intervention evidence and the path-faithful deploy source.

## Repo layout
- `build/`: path-faithful host build trees plus step-by-step rebuild books.
- `.secrets/`: gitignored secret env files.
- `operation-logs/`: append-only server interaction logs.
- `context/architecture/`: repo-wide model and source-of-truth boundary.
- `context/hosts/`: per-host dossiers with small, focused docs.
- `context/design/`: future-facing proposals and decisions.

## Fresh-host rebuild
1. Install Node 22+ on the target host.
2. Copy `build/<host>/secrets.example.env` to `.secrets/<host>.env` and fill the secrets locally.
3. Review and edit `build/<host>/rootfs/` until it matches the desired host state.
4. Apply the build tree to the server:
   `./scripts/apply-build-host.sh --host <ssh-host> --secrets-file .secrets/<host>.env`
5. Optionally capture the live host into `.tmp/live/<host>/` for comparison:
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
- `build/` is tracked; `.secrets/` is local only.
- `build/` and `operation-logs/` must contain only redacted or placeholder-safe values.

## State model
The rebuild boundary is documented in `context/architecture/source-of-truth.md`.

## Build trees
- `build/` is the host-path-oriented deploy source.
- It mirrors files into exact host-style paths under `build/<host>/rootfs/`.
- Edit `build/` directly when changing intended host state.
- Render and apply it with `./scripts/render-build-state.sh` and `./scripts/apply-build-host.sh`.
- `./scripts/oracle-openclaw.sh snapshot` now captures a redacted live tree into `.tmp/live/<host>/` for comparison only.

## Documentation update rules
- Live host behavior changed: update `operation-logs/` plus the smallest relevant file under `context/hosts/<host>/`.
- Repo-wide policy or storage rules changed: update `context/architecture/`.
- A new function or workflow is being designed: add a record under `context/design/proposals/` and promote it to `context/design/decisions/` when accepted.

## Current coverage
- As of 2026-03-11 UTC, `build/oracle.ylioo.com/rootfs/` + local `.secrets/oracle.ylioo.com.env` are sufficient to recreate the intended Oracle OpenClaw deployment without reading the live host config by hand.
- Runtime-only host state is no longer tracked in the deploy tree; use `.tmp/live/oracle.ylioo.com/` when you need a redacted live capture for comparison.
