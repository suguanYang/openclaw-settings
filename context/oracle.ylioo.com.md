# oracle.ylioo.com OpenClaw Context

Last verified: 2026-03-11 UTC

## Current host facts
- SSH target: `oracle.ylioo.com`
- Host OS: Ubuntu 20.04.6 LTS (`focal`) on `aarch64`
- State dir: `~/.openclaw`
- Active service: `~/.config/systemd/user/openclaw-gateway.service`
- Observed running version: `v2026.3.8`
- Observed service port: `18789`
- ExecStart node: `/home/suguan/.nvm/versions/node/v22.18.0/bin/node`
- ExecStart entrypoint: `/home/suguan/.local/share/pnpm/global/5/.pnpm/openclaw@2026.3.8_.../node_modules/openclaw/dist/index.js`
- Shell PATH caveat: non-interactive `zsh -lc` does not resolve `openclaw`, `node`, `npm`, or `pnpm`; use absolute paths or `scripts/oracle-openclaw.sh`.
- PNPM caveat: global writes require `PNPM_HOME=/home/suguan/.local/share/pnpm`.

## Research team docs
- Real Discord bot status: `context/oracle-discord-real-bots-checklist.md`
- Team runbook: `context/oracle-research-team.md`

## Research team routing
- Routed Discord guild: `565501940742619145` (`sstar`)
- Routed Discord channel: `565501941510045707` (`#general`)
- Discord is now configured with `channels.discord.accounts` and `channels.discord.defaultAccount = manager`.
- Live Discord account to agent bindings are:
  - `manager` -> `research-lead`
  - `engineer` -> `engineer`
  - `researcher` -> `researcher`
  - `reporter` -> `reporter`
  - `tracker` -> `tracker`
- `requireMention=true` is enabled for the guild, so the team should stay silent unless one of the bot members is explicitly mentioned.
- Confirmed in the live Discord UI on 2026-03-11 that all 5 real bot members are present in `sstar`:
  - `OpenClaw Manager`
  - `OpenClaw Engineer`
  - `OpenClaw Researcher`
  - `OpenClaw Reporter`
  - `OpenClaw Tracker`
- The legacy placeholder Discord member `bot1469239070508191847` was removed from `sstar` after the real manager cutover was verified.

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
  - Claude-only ACP config remains live on Oracle.
  - Codex ACP was intentionally removed from the live Oracle config for now instead of keeping a broken fallback.

## Discord multi-account cutover state
- Remote `~/.openclaw/.env` now contains the managed Discord token variables:
  - `DISCORD_MANAGER_TOKEN`
  - `DISCORD_ENGINEER_TOKEN`
  - `DISCORD_RESEARCHER_TOKEN`
  - `DISCORD_REPORTER_TOKEN`
  - `DISCORD_TRACKER_TOKEN`
- `OPENAI_API_KEY` was preserved in the same remote env file during the merge.
- Remote config backup created during cutover:
  - `~/.openclaw/openclaw.json.pre-discord-multi-account.20260311T052148Z.bak`
- Gateway restart and log verification confirmed all 5 Discord providers started and logged in successfully.
- `openclaw health` currently reports only the default Discord account, so full multi-account verification should use gateway logs in addition to health.

## Current drift snapshot
- The redacted snapshot is synced as of 2026-03-11 UTC.
- Snapshot files do not include Oracle plaintext secret files.
- Snapshot coverage now includes:
  - `acp-harness.env`
  - `claude/settings.json`
  - `systemd/openclaw-gateway.service.d/acp-harness.conf`
  - top-level Markdown files from `workspace/` and `workspace-*`
  - `skills/*/SKILL.md` from `workspace/` and `workspace-*`
- `scripts/snapshot.sh` prunes stale snapshot files so removed host-side files disappear on the next sync.
- A temporary local `snapshots/.env` capture was removed on 2026-03-11 and the snapshot was refreshed; current `_meta.json` confirms no `.env` file is tracked.
- Snapshot redaction now preserves non-secret numeric config fields such as `maxTokens`.
- `managed/workspace/skills/*` and `managed/workspace-research-lead/{ISSUES,STATUS}.md` now mirror the live Oracle workspace baseline.
- Declarative rebuild coverage is now complete for the current Oracle deployment; remaining snapshot-only files are runtime/generated state listed in `context/source-of-truth.md`.

## Managed rebuild kit
- Desired config template: `managed/openclaw.json.template`
- Oracle non-secret profile: `profiles/oracle.ylioo.com.env`
- Secrets contract: `managed/secrets.example.env`
- State-model doc: `context/source-of-truth.md`
- Render helper: `scripts/render-managed-state.sh`
- Apply helper: `scripts/apply-managed-host.sh`

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

## Freshness notes
- Local reference repo `/home/suguan/github.com/openclaw` has uncommitted local files right now, so it was not auto-fast-forwarded during this sync pass.
- Live Oracle deployment verified against the current installed OpenClaw `v2026.3.8` on 2026-03-11.

## Official docs checked
- Install: `https://docs.openclaw.ai/install`
- Updating: `https://docs.openclaw.ai/install/updating`
- Linux: `https://docs.openclaw.ai/platforms/linux`
- Doctor: `https://docs.openclaw.ai/gateway/doctor`
- Discord: `https://docs.openclaw.ai/channels/discord`
- ACP Agents: `https://docs.openclaw.ai/tools/acp-agents`
- Multi-Agent Routing: `https://docs.openclaw.ai/concepts/multi-agent`

## Direct member mention workflow
- Real Discord member mentions are now the primary dispatch path on Oracle.
- Mentioning `OpenClaw Manager` in `#general` routes the message to `research-lead` through Discord account `manager`.
- Mentioning `OpenClaw Engineer`, `OpenClaw Researcher`, `OpenClaw Reporter`, or `OpenClaw Tracker` routes directly to the matching specialized agent through its own Discord account binding.
- Plain text without an explicit bot mention should stay silent because `requireMention=true` is enabled.
- The earlier `@manager` / `@engineer` alias-based manager prompt still exists in `workspace-research-lead/AGENTS.md`, but it is now a fallback compatibility layer rather than the primary user UX.
- Operational guidance: mention one teammate bot per message to avoid ambiguous multi-bot wakeups on the shared channel.

## Discord real-bot portal status from 2026-03-11
- Confirmed directly in Discord web that Oracle guild `565501940742619145` is `sstar` and routed channel `565501941510045707` is `#general`.
- Discord application ids:
  - `OpenClaw Manager`: `1481108454704943227`
  - `OpenClaw Engineer`: `1481122055184187432`
  - `OpenClaw Researcher`: `1481133991749750886`
  - `OpenClaw Reporter`: `1481138115887501382`
  - `OpenClaw Tracker`: `1481136653342081085`
- All 5 apps are invited into `sstar` and visible in the live member/join events.
- Oracle is now switched from single-account Discord config to multi-account Discord config.
