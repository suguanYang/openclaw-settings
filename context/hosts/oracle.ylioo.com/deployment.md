# oracle.ylioo.com Deployment

Last verified: 2026-03-11 UTC

## Current build mirror
- The redacted build mirror is synced as of 2026-03-11 UTC.
- Build files do not include Oracle plaintext secret values.
- Build coverage includes:
  - `acp-harness.env`
  - `claude/settings.json`
  - `systemd/openclaw-gateway.service.d/acp-harness.conf`
  - top-level Markdown files from `workspace/` and `workspace-*`
  - `skills/*/SKILL.md` from `workspace/` and `workspace-*`
- `scripts/snapshot.sh` prunes stale mirrored files so removed host-side files disappear on the next sync.
- The tracked build `.env` is regenerated from `profiles/oracle.ylioo.com.env` plus `managed/secrets.example.env`, so the file path exists but secret values stay blank in git.
- Redaction preserves non-secret numeric config fields such as `maxTokens`.
- `managed/workspace/skills/*` and the managed workspace prompt files define the rebuild baseline.
- Live manager task state such as `../../../build/oracle.ylioo.com/rootfs/home/suguan/.openclaw/workspace-research-lead/{ISSUES,STATUS}.md` is expected to drift as the team works.
- Declarative rebuild coverage is complete for the current Oracle deployment; remaining build-mirror-only files are runtime/generated state listed in `../../architecture/source-of-truth.md`.

## Managed rebuild kit
- Desired config template: `managed/openclaw.json.template`
- Oracle non-secret profile: `profiles/oracle.ylioo.com.env`
- Secrets contract: `managed/secrets.example.env`
- State-model doc: `../../architecture/source-of-truth.md`
- Build mirror: `../../../build/oracle.ylioo.com/`
- Render helper: `scripts/render-managed-state.sh`
- Apply helper: `scripts/apply-managed-host.sh`
- Build mirror helper: `scripts/snapshot.sh`

## Preferred commands from this repo
- Status: `./scripts/oracle-openclaw.sh status`
- Restart: `./scripts/oracle-openclaw.sh restart`
- Logs: `./scripts/oracle-openclaw.sh logs 120`
- Snapshot sync: `./scripts/oracle-openclaw.sh snapshot`
- Service file: `./scripts/oracle-openclaw.sh service-file`
- Runtime-aware exec: `./scripts/oracle-openclaw.sh runtime-exec '<cmd>'`
- Doctor: `./scripts/oracle-openclaw.sh doctor`
- Health: `./scripts/oracle-openclaw.sh health`
- Update: `./scripts/oracle-openclaw.sh update`
- Discord cutover helper: `./scripts/oracle-discord-cutover.sh`

## Update flow for this host
1. `./scripts/oracle-openclaw.sh snapshot`
2. `./scripts/oracle-openclaw.sh update`
3. `./scripts/oracle-openclaw.sh status`
4. `./scripts/oracle-openclaw.sh logs 120`

Docs prefer re-running `curl -fsSL https://openclaw.ai/install.sh | bash`; for this host, `update` is the closest non-interactive equivalent because the current service points at the PNPM global package tree while still using the NVM Node 22.18.0 runtime.

## Freshness notes
- Local reference repo `/home/suguan/github.com/openclaw` has uncommitted local files right now, so it was not auto-fast-forwarded during this sync pass.
- Live Oracle deployment was verified against the current installed OpenClaw `v2026.3.8` on 2026-03-11.

## Official docs checked
- Install: `https://docs.openclaw.ai/install`
- Updating: `https://docs.openclaw.ai/install/updating`
- Linux: `https://docs.openclaw.ai/platforms/linux`
- Doctor: `https://docs.openclaw.ai/gateway/doctor`
- Discord: `https://docs.openclaw.ai/channels/discord`
- ACP Agents: `https://docs.openclaw.ai/tools/acp-agents`
- Multi-Agent Routing: `https://docs.openclaw.ai/concepts/multi-agent`
- Upstream source: `https://github.com/openclaw/openclaw`

OpenClaw is upstream open source and moves quickly. Re-check the relevant official docs and upstream source before changing Oracle-managed behavior based on older local notes.
