# oracle.ylioo.com

Last verified: 2026-03-11 UTC

## Role
Primary managed OpenClaw deployment and current reference host for this repo.

## Quick facts
- SSH target: `oracle.ylioo.com`
- Host OS: Ubuntu 20.04.6 LTS (`focal`) on `aarch64`
- State dir: `~/.openclaw`
- Active service: `~/.config/systemd/user/openclaw-gateway.service`
- Observed running version: `v2026.3.8`
- Observed service port: `18789`
- Preferred helper script: `./scripts/oracle-openclaw.sh`

## Read this host in order
1. `runtime.md`: current live routing, ACP/plugin state, and Discord dispatch behavior.
2. `deployment.md`: rebuild kit, drift boundary, preferred commands, and snapshot coverage.
3. `repair-notes.md`: caveats discovered during earlier repairs that still matter.
4. `projects/discord-real-bots.md`: Oracle multi-account Discord workstream.
5. `runbooks/research-team.md`: operator guidance for the current research team.
6. `../../../operation-logs/2026-03-11-oracle.ylioo.com.md`: exact intervention history for the latest major Oracle changes.

## Update rules
- Keep this file as the host index plus stable quick facts.
- Update the smallest leaf doc when behavior changes.
- Record exact commands and outputs in `operation-logs/`.
