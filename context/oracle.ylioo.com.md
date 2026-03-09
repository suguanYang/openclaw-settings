# oracle.ylioo.com OpenClaw Context

Last verified: 2026-03-09 UTC

## Current host facts
- SSH target: `oracle.ylioo.com`
- State dir: `~/.openclaw`
- Active service: `~/.config/systemd/user/openclaw-gateway.service`
- Observed running version: `v2026.2.26`
- Observed service port: `18789`
- ExecStart node: `/home/suguan/.nvm/versions/node/v22.18.0/bin/node`
- ExecStart entrypoint: `/home/suguan/.nvm/versions/node/v22.18.0/lib/node_modules/openclaw/dist/index.js`
- Shell PATH caveat: non-interactive `zsh -lc` did not resolve `openclaw`, `node`, or `npm`; use absolute paths or `scripts/oracle-openclaw.sh`.

## Current drift snapshot
- Redacted snapshot drift on 2026-03-09 only changed:
  - `snapshots/_meta.json`
  - `snapshots/sandbox/containers.json` (`lastUsedAtMs` advanced)

## Preferred commands from this repo
- Status: `./scripts/oracle-openclaw.sh status`
- Restart: `./scripts/oracle-openclaw.sh restart`
- Logs: `./scripts/oracle-openclaw.sh logs 120`
- Snapshot sync: `./scripts/oracle-openclaw.sh snapshot`
- Service file: `./scripts/oracle-openclaw.sh service-file`
- Doctor: `./scripts/oracle-openclaw.sh doctor`
- Health: `./scripts/oracle-openclaw.sh health`

## Update flow for this host
1. `./scripts/oracle-openclaw.sh snapshot`
2. `./scripts/oracle-openclaw.sh update-npm`
3. `./scripts/oracle-openclaw.sh status`
4. `./scripts/oracle-openclaw.sh logs 120`

Docs prefer re-running `curl -fsSL https://openclaw.ai/install.sh | bash`; for this host, `update-npm` is the closest non-interactive equivalent because the current service points at a global npm-installed `dist/index.js` under the NVM Node 22.18.0 tree.

## Freshness notes from 2026-03-09
- Local repo `/home/suguan/github.com/openclaw` is at `f6243916b51ca4b4131674fa2f6fa9d863314c01`.
- Upstream `origin/main` was `a438ff4397b3500fec0f263b81cdbebbaa55f79d`.
- Latest GitHub release observed: `v2026.3.7` published 2026-03-08.

## Official docs checked
- Install: `https://docs.openclaw.ai/install`
- Updating: `https://docs.openclaw.ai/install/updating`
- Linux: `https://docs.openclaw.ai/platforms/linux`
- Doctor: `https://docs.openclaw.ai/gateway/doctor`
