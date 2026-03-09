# oracle.ylioo.com OpenClaw Context

Last verified: 2026-03-09 UTC

## Current host facts
- SSH target: `oracle.ylioo.com`
- State dir: `~/.openclaw`
- Active service: `~/.config/systemd/user/openclaw-gateway.service`
- Observed running version: `v2026.3.7`
- Observed service port: `18789`
- ExecStart node: `/home/suguan/.nvm/versions/node/v22.18.0/bin/node`
- ExecStart entrypoint: `/home/suguan/.local/share/pnpm/global/5/.pnpm/openclaw@2026.3.7_.../node_modules/openclaw/dist/index.js`
- Shell PATH caveat: non-interactive `zsh -lc` did not resolve `openclaw`, `node`, `npm`, or `pnpm`; use absolute paths or `scripts/oracle-openclaw.sh`.
- PNPM caveat: global writes require `PNPM_HOME=/home/suguan/.local/share/pnpm`.

## Current drift snapshot
- The redacted snapshot is synced as of 2026-03-09 UTC.
- Snapshot files do not include the `systemd` unit, so service-entrypoint/version changes are tracked in `operation-logs/` and this context file.

## Preferred commands from this repo
- Status: `./scripts/oracle-openclaw.sh status`
- Restart: `./scripts/oracle-openclaw.sh restart`
- Logs: `./scripts/oracle-openclaw.sh logs 120`
- Snapshot sync: `./scripts/oracle-openclaw.sh snapshot`
- Service file: `./scripts/oracle-openclaw.sh service-file`
- Doctor: `./scripts/oracle-openclaw.sh doctor`
- Health: `./scripts/oracle-openclaw.sh health`
- Update: `./scripts/oracle-openclaw.sh update`

## Update flow for this host
1. `./scripts/oracle-openclaw.sh snapshot`
2. `./scripts/oracle-openclaw.sh update`
3. `./scripts/oracle-openclaw.sh status`
4. `./scripts/oracle-openclaw.sh logs 120`

Docs prefer re-running `curl -fsSL https://openclaw.ai/install.sh | bash`; for this host, `update` is the closest non-interactive equivalent because the current service now points at the PNPM global package tree while still using the NVM Node 22.18.0 runtime.

## Repair notes discovered on 2026-03-09
- `pnpm add -g openclaw@2026.3.7` succeeds only when `PNPM_HOME=/home/suguan/.local/share/pnpm` is exported.
- `openclaw doctor --non-interactive --fix` does not apply service-file repairs.
- `openclaw doctor --yes --fix` does apply the `systemd` service rewrite in a non-TTY session.

## Freshness notes from 2026-03-09
- Local repo `/home/suguan/github.com/openclaw` is at `f6243916b51ca4b4131674fa2f6fa9d863314c01`.
- Upstream `origin/main` was `a438ff4397b3500fec0f263b81cdbebbaa55f79d`.
- Latest GitHub release observed: `v2026.3.7` published 2026-03-08.

## Official docs checked
- Install: `https://docs.openclaw.ai/install`
- Updating: `https://docs.openclaw.ai/install/updating`
- Linux: `https://docs.openclaw.ai/platforms/linux`
- Doctor: `https://docs.openclaw.ai/gateway/doctor`
