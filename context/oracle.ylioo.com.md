# oracle.ylioo.com OpenClaw Context

Last verified: 2026-03-09 UTC

## Current host facts
- SSH target: `oracle.ylioo.com`
- Host OS: Ubuntu 20.04.6 LTS (`focal`) on `aarch64`
- State dir: `~/.openclaw`
- Active service: `~/.config/systemd/user/openclaw-gateway.service`
- Observed running version: `v2026.3.8`
- Observed service port: `18789`
- ExecStart node: `/home/suguan/.nvm/versions/node/v22.18.0/bin/node`
- ExecStart entrypoint: `/home/suguan/.local/share/pnpm/global/5/.pnpm/openclaw@2026.3.8_.../node_modules/openclaw/dist/index.js`
- Shell PATH caveat: non-interactive `zsh -lc` did not resolve `openclaw`, `node`, `npm`, or `pnpm`; use absolute paths or `scripts/oracle-openclaw.sh`.
- PNPM caveat: global writes require `PNPM_HOME=/home/suguan/.local/share/pnpm`.

## Research team routing
- Default gateway agent is preserved as `main`.
- Discord channel `565501941510045707` (`sstar/general`) is explicitly routed to `research-lead`.
- Specialized agents installed: `research-lead`, `researcher`, `engineer`, `reporter`, `tracker`.
- `research-lead` is unsandboxed with `exec` denied so it can orchestrate ACP while leaving code execution to specialists.
- `researcher`, `engineer`, `reporter`, and `tracker` use agent-scoped sandboxing.

## ACP and plugin state
- `acp.enabled=true` with backend `acpx`.
- `acp.defaultAgent=claude`.
- Allowed ACP harness ids: `claude`.
- `channels.discord.threadBindings` is enabled with both `spawnSubagentSessions=true` and `spawnAcpSessions=true`.
- Bundled plugins `acpx`, `discord`, and `open-prose` are enabled and observed loaded after restart.
- Host PATH does not contain standalone `acpx`, `codex`, `claude`, `claude-code`, `opencode`, or `gemini` binaries; OpenClaw currently relies on the bundled `acpx` runtime path.
- Gateway service now imports `%h/.openclaw/acp-harness.env` through `~/.config/systemd/user/openclaw-gateway.service.d/acp-harness.conf`.
- `~/.openclaw/acp-harness.env` is generated from `~/.openclaw/openclaw.json` and now reuses only the `ikuncode-claude` Anthropic-compatible settings.
- `~/.codex/config.toml` was removed from the host on 2026-03-09 when Codex ACP was disabled.
- `~/.claude/settings.json` is present and currently pins `claude-sonnet-4-5-20250929`.
- `scripts/oracle-openclaw.sh runtime-exec` now sources `~/.openclaw/acp-harness.env` so local smoke checks use the same extra env as the real gateway process.
- Current ACP smoke status:
  - Re-test at 2026-03-09T08:21Z showed the raw Anthropic-compatible endpoint is currently healthy again:
    - `GET https://api.ikuncode.cc/v1/models` returned `200`
    - `POST https://api.ikuncode.cc/v1/messages` returned `200` for:
      - `claude-opus-4-6`
      - `claude-sonnet-4-6`
      - `claude-haiku-4-5-20251001`
  - Earlier `model_not_found` responses observed around 2026-03-09T08:04Z appear to have been transient provider-side behavior rather than a persistent local config problem.
  - Claude-only ACP config remains live on Oracle, but `@zed-industries/claude-agent-acp` itself was not re-smoke-tested end-to-end after the provider recovered.
  - Codex ACP was intentionally removed from the live Oracle config for now instead of keeping a broken fallback.

## Current drift snapshot
- The redacted snapshot is synced as of 2026-03-09 UTC.
- Snapshot files do not include the base `systemd` unit, so service-entrypoint/version changes are tracked in `operation-logs/` and this context file.
- Snapshot coverage now includes:
  - `acp-harness.env`
  - `claude/settings.json`
  - `systemd/openclaw-gateway.service.d/acp-harness.conf`
- `scripts/snapshot.sh` now captures top-level Markdown files and `skills/*/SKILL.md` from both `workspace/` and `workspace-*` directories so multi-agent runbooks stay synced locally.
- `scripts/snapshot.sh` now also prunes stale snapshot files, so removed host-side files (for example `codex/config.toml`) disappear from the local snapshot on the next sync.

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

## Update flow for this host
1. `./scripts/oracle-openclaw.sh snapshot`
2. `./scripts/oracle-openclaw.sh update`
3. `./scripts/oracle-openclaw.sh status`
4. `./scripts/oracle-openclaw.sh logs 120`

Docs prefer re-running `curl -fsSL https://openclaw.ai/install.sh | bash`; for this host, `update` is the closest non-interactive equivalent because the current service now points at the PNPM global package tree while still using the NVM Node 22.18.0 runtime.

## Repair notes discovered on 2026-03-09
- `pnpm add -g openclaw@2026.3.8` succeeds only when `PNPM_HOME=/home/suguan/.local/share/pnpm` is exported.
- `scripts/oracle-openclaw.sh update` now resolves `pnpm` from `PATH` first and falls back to `$PNPM_HOME/pnpm`, which matches the current Oracle host layout.
- `openclaw doctor --non-interactive --fix` does not apply service-file repairs.
- `openclaw doctor --yes --fix` does apply the `systemd` service rewrite in a non-TTY session.
- `openclaw health` can return a transient loopback `1006` if probed immediately after restart; wait a few seconds before treating that as a real failure.
- `@zed-industries/codex-acp` currently fails on Oracle Linux ARM64 with `libssl.so.3` missing, so Codex ACP is not yet usable end-to-end on this host without a host-library fix or adapter override.
- The reused Claude proxy on this host has shown transient behavior on 2026-03-09: early probes returned `model_not_found`, while a later re-test returned `200` for `/models` and current Claude `/messages` calls.
- Local build attempts for `codex-acp` on this host hit a cascading toolchain gap:
  - Ubuntu 20.04 only ships GCC 9.4, which `aws-lc-sys` rejects because of the known memcmp bug.
  - User-local `zig` got past the GCC guard, but the build still failed later in the dependency graph with `libsqlx_macros... undefined symbol: __ubsan_handle_type_mismatch_v1`.
- Practical recommendation for Codex ACP on this host:
  - best fix: move the host to Ubuntu 22.04 or 24.04, or another newer ARM64 Linux baseline;
  - fallback fix: install a full newer LLVM/clang + compiler-rt stack user-locally and keep a custom `~/.acpx/config.json` codex override.

## Freshness notes from 2026-03-09
- Local repo `/home/suguan/github.com/openclaw` is at `f6243916b51ca4b4131674fa2f6fa9d863314c01`.
- Upstream `main` was `3caab9260cb0a0064e6a37b2de3bedc8a547e599` when checked via GitHub on 2026-03-09.
- Latest GitHub release observed: `v2026.3.8` published 2026-03-09.

## Official docs checked
- Install: `https://docs.openclaw.ai/install`
- Updating: `https://docs.openclaw.ai/install/updating`
- Linux: `https://docs.openclaw.ai/platforms/linux`
- Doctor: `https://docs.openclaw.ai/gateway/doctor`
- Discord: `https://docs.openclaw.ai/channels/discord`
- ACP Agents: `https://docs.openclaw.ai/tools/acp-agents`
- Multi-Agent Routing: `https://docs.openclaw.ai/concepts/multi-agent`

## Direct member mention workflow
- Oracle still routes Discord channel `565501941510045707` to `research-lead`; direct Discord `@engineer` or `@researcher` text does not natively retarget routing on this OpenClaw checkout.
- The managed workaround lives in `managed/workspace-research-lead/AGENTS.md` and is deployed to `~/.openclaw/workspace-research-lead/AGENTS.md`.
- Supported leading dispatch tokens: `@engineer`, `@researcher`, `@reporter`, `@tracker`.
- Because `AGENTS.md` bootstrap files are cached per session key, restarting the gateway or resetting the active session is the safest way to force the current Discord channel to pick up prompt changes.
- `TEAM.md` remains human/operator documentation only; it is not auto-injected into the runtime bootstrap prompt on this OpenClaw checkout.
