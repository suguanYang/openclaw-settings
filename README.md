# openclaw-settings

Local Git repo for managing, auditing, and documenting host-specific OpenClaw deployments.

## Upstream-first rule
- **OpenClaw itself is an open-source upstream project.**
- **OpenClaw updates frequently, so local notes in this repo can drift.**
- **Before making claims about OpenClaw behavior, config shape, commands, or features, always check the official docs at `https://docs.openclaw.ai` and the upstream source at `https://github.com/openclaw/openclaw`.**
- This repo is the source of truth for our intended deployment state, not for generic upstream product behavior.

## Local source reference
- A gitignored local upstream checkout is available at `references/openclaw/`.
- LLMs and operators may inspect `references/openclaw/` for faster code-level lookup when diagnosing OpenClaw behavior or matching current implementation details.
- Keep that checkout up to date before relying on it. At minimum, refresh from upstream and verify the local reference is on the expected branch/commit.
- The local reference is an aid, not the source of truth. If there is any mismatch between `references/openclaw/`, the official docs, and upstream GitHub, re-check upstream first.

## Information hierarchy
Read the repo from broad to narrow:
1. `README.md`: repo purpose, top-level data layers, and common operator flows.
5. `operation-logs/` and `build/`: local intervention evidence plus the path-faithful deploy source.

## Repo layout
- `build/`: path-faithful host build trees plus reference notes for the tracked files.
- `bootstrap/`: fresh-host rebuild flows kept separate from the current Oracle maintenance scripts.
- `.secrets/`: gitignored secret env files.
- `references/openclaw/`: gitignored local clone of the upstream OpenClaw source for code reference only.
- `operation-logs/`: local-only append-only server interaction logs; kept gitignored.

## Fresh-host rebuild
1. Install Node 22+ on the target host.
2. Copy `build/<host>/secrets.example.env` to `.secrets/<host>.env` and fill the secrets locally.
3. Review and edit `build/<host>/rootfs/` until it matches the desired host state.
4. Apply the build tree to the server:
   `./scripts/apply-build-host.sh --host <ssh-host> --secrets-file .secrets/<host>.env`
5. Optionally capture the live host into `.tmp/live/<host>/` for comparison:
   `OPENCLAW_SNAPSHOT_HOST=<ssh-host> ./scripts/snapshot.sh`

For a reproducible clone of the current Oracle deployment on a different host,
use the bootstrap flow in `bootstrap/oracle.ylioo.com/`, or just run
`./bootstrap/setup.sh`.

## Oracle helper flow
- Status: `./scripts/oracle-openclaw.sh status`
- Restart: `./scripts/oracle-openclaw.sh restart`
- Logs: `./scripts/oracle-openclaw.sh logs 120`
- Watch the latest session for one agent with all transcript record types: `./scripts/oracle-openclaw.sh watch-agent research-lead`
- Watch raw JSONL instead of pretty text: `./scripts/oracle-openclaw.sh watch-agent research-lead --raw`
- Adjust the initial transcript history window: `OPENCLAW_WATCH_LINES=300 ./scripts/oracle-openclaw.sh watch-agent research-lead`
- Health: `./scripts/oracle-openclaw.sh health`
- Snapshot: `./scripts/oracle-openclaw.sh snapshot`
- Update: `./scripts/oracle-openclaw.sh update`
- Knowhere plugin deploy: `./scripts/deploy-knowhere-plugin.sh`
- Discord multi-account cutover helper: `./scripts/oracle-discord-cutover.sh`

## Redaction and secrets
- Never commit plaintext secrets.
- `build/` is tracked; `.secrets/` is local only.
- `build/` and `operation-logs/` must contain only redacted or placeholder-safe values.
- `operation-logs/` is local-only and must not be pushed.
- Local Knowhere plugin payloads staged under `build/**/rootfs/home/suguan/github.com/ontosAI/knowhere-openclaw-plugin/` must stay gitignored.

## Build trees
- `build/` is the host-path-oriented deploy source.
- It mirrors files into exact host-style paths under `build/<host>/rootfs/`.
- Edit `build/` directly when changing intended host state.
- Render and apply it with `./scripts/render-build-state.sh` and `./scripts/apply-build-host.sh`.
- `./scripts/oracle-openclaw.sh snapshot` now captures a redacted live tree into `.tmp/live/<host>/` for comparison only.

## Documentation update rules
- Fresh-host setup flow changed: update `bootstrap/README.md` plus the smallest relevant file under `bootstrap/`.
