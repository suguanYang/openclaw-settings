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

## External library rule
- npm-installed OpenClaw plugins are external libraries, not repo-owned code.
- Do not patch, vendor, mirror, or commit source changes for external plugins from this repository.
- Do not edit host-side external plugin files to fix behavior from work in `openclaw-settings`.
- If an external plugin is wrong, either update the pinned package version or fix it in the plugin's own upstream repository.

## Maintained hosts
- This repo may need to maintain more than one OpenClaw deployment at the same time.
- `oracle.ylioo.com` and `macmini.openclaw` are both in scope for operator docs, helper scripts, and host-specific deployment state kept here.
- Keep host-specific changes clearly scoped to the correct host instead of assuming Oracle-only behavior.

## Information hierarchy
Read the repo from broad to narrow:
1. `README.md`: repo purpose, top-level data layers, and common operator flows.
5. `operation-logs/` and `build/`: local intervention evidence plus the path-faithful deploy source.

## Repo layout
- `build/`: path-faithful host build trees plus reference notes for the tracked files.
- `.secrets/`: gitignored secret env files.
- `references/openclaw/`: gitignored local clone of the upstream OpenClaw source for code reference only.
- `operation-logs/`: local-only append-only server interaction logs; kept gitignored.

## Fresh-host rebuild
1. Install Node 22+ on the target host.
2. Copy `build/<host>/secrets.example.env` to `.secrets/<host>.env` and fill the secrets locally.
3. Review and edit `build/<host>/rootfs/` until it matches the desired host state.
4. Optionally render the staged build tree locally:
   `./scripts/render-build-state.sh --build-dir build/<host> --secrets-file .secrets/<host>.env`
5. Apply the build tree to the server:
   `./scripts/apply-build-host.sh --host <ssh-host> --secrets-file .secrets/<host>.env`
6. Install the external Knowhere plugin from npm on the host:
   `./scripts/openclaw-host.sh --host <ssh-host> runtime-exec 'openclaw plugins install @ontos-ai/knowhere-claw@0.2.1 --pin'`
7. Optionally capture the live host into `.tmp/live/<host>/` for comparison:
   `OPENCLAW_SNAPSHOT_HOST=<ssh-host> ./scripts/snapshot.sh`

For a reproducible clone of the current Oracle deployment on a different host,
start from `build/oracle.ylioo.com/`, copy it into a host-specific build
directory, and use the same render/apply flow above.

## Host helper flow
- Status: `./scripts/openclaw-host.sh --host <ssh-host> status`
- Restart: `./scripts/openclaw-host.sh --host <ssh-host> restart`
- Logs: `./scripts/openclaw-host.sh --host <ssh-host> logs 120`
- Knowhere logs: `./scripts/openclaw-host.sh --host <ssh-host> logs-knowhere 200`
- Watch Knowhere logs live: `./scripts/openclaw-host.sh --host <ssh-host> watch-knowhere 120`
- Watch the latest session for one agent with all transcript record types: `./scripts/openclaw-host.sh --host <ssh-host> watch-agent research-lead`
- Watch raw JSONL instead of pretty text: `./scripts/openclaw-host.sh --host <ssh-host> watch-agent research-lead --raw`
- Adjust the initial transcript history window: `OPENCLAW_WATCH_LINES=300 ./scripts/openclaw-host.sh --host <ssh-host> watch-agent research-lead`
- Override the default Knowhere log filter when needed: `OPENCLAW_KNOWHERE_LOG_PATTERN='knowhere|tracker progress|sendMessage failed' ./scripts/openclaw-host.sh --host <ssh-host> watch-knowhere 120`
- Health: `./scripts/openclaw-host.sh --host <ssh-host> health`
- Snapshot: `./scripts/openclaw-host.sh --host <ssh-host> snapshot`
- Update: `./scripts/openclaw-host.sh --host <ssh-host> update`
- Install Knowhere plugin from npm: `./scripts/openclaw-host.sh --host <ssh-host> runtime-exec 'openclaw plugins install @ontos-ai/knowhere-claw@0.2.1 --pin'`
- Update Knowhere plugin from npm: `./scripts/openclaw-host.sh --host <ssh-host> runtime-exec 'openclaw plugins update knowhere-claw'`
- Discord multi-account cutover helper: `./scripts/oracle-discord-cutover.sh`
- Oracle shortcut: `./scripts/oracle-openclaw.sh ...` still targets `oracle.ylioo.com` by default.
- Macmini shortcut: `./scripts/macmini-openclaw.sh ...` targets `macmini.openclaw` by default.
- Both shortcut scripts support the same commands as `./scripts/openclaw-host.sh`, including `status`, `logs`, `watch-agent`, `health`, `restart`, and `update`.
- `openclaw-host.sh` auto-detects `systemd` or `launchd`; use `--service-manager` and `--launchd-label` to override when needed.

## Redaction and secrets
- Never commit plaintext secrets.
- `build/` is tracked; `.secrets/` is local only.
- `build/` and `operation-logs/` must contain only redacted or placeholder-safe values.
- `operation-logs/` is local-only and must not be pushed.
- External plugin runtime files under `~/.openclaw/extensions/` and CLI-managed `plugins.installs` stay on the host; do not stage copied npm plugin payloads under `build/`.

## Build trees
- `build/` is the host-path-oriented deploy source.
- It mirrors files into exact host-style paths under `build/<host>/rootfs/`.
- Edit `build/` directly when changing intended host state.
- Render and apply it with `./scripts/render-build-state.sh` and `./scripts/apply-build-host.sh`.
- External npm plugins are installed on the host with the OpenClaw CLI, not mirrored into `build/`.
- `./scripts/openclaw-host.sh --host <ssh-host> snapshot` captures a redacted live tree into `.tmp/live/<host>/` for comparison only.

## Documentation update rules
- Fresh-host setup flow changed: update `README.md` plus the smallest relevant file under `build/` or `scripts/`.
