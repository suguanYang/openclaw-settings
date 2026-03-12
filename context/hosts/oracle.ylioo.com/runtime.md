# oracle.ylioo.com Runtime

Last verified: 2026-03-12 UTC

## Current host facts
- SSH target: `oracle.ylioo.com`
- Host OS: Ubuntu 20.04.6 LTS (`focal`) on `aarch64`
- State dir: `~/.openclaw`
- Active service: `~/.config/systemd/user/openclaw-gateway.service`
- Observed running version: `v2026.3.8`
- Observed service port: `18789`
- ExecStart node: `/home/suguan/.nvm/versions/node/v22.18.0/bin/node`
- ExecStart entrypoint: `/home/suguan/.local/share/pnpm/global/5/.pnpm/openclaw@2026.3.8_.../node_modules/openclaw/dist/index.js`
- Shell PATH caveat: non-interactive `zsh -lc` does not resolve `openclaw`, `node`, `npm`, `pnpm`, or `gh`; use absolute paths or `scripts/oracle-openclaw.sh`.
- PNPM caveat: global writes require `PNPM_HOME=/home/suguan/.local/share/pnpm`.

## Related docs
- Host index: `README.md`
- Discord project: `projects/discord-real-bots.md`
- Team runbook: `runbooks/research-team.md`

## Research team routing
- Routed Discord guild: `565501940742619145` (`sstar`)
- Routed Discord channel: `565501941510045707` (`#general`)
- Discord is configured with `channels.discord.accounts` and `channels.discord.defaultAccount = manager`.
- Live Discord account to agent bindings are:
  - `manager` -> `research-lead`
  - `engineer` -> `engineer`
  - `researcher` -> `researcher`
  - `reporter` -> `reporter`
  - `tracker` -> `tracker`
- `requireMention=true` and `ignoreOtherMentions=true` are enabled for the guild, so the team should stay silent unless one of the bot members is explicitly mentioned.
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
- Normal team-agent turns are now Codex-first:
  - `main`, `research-lead`, `researcher`, `engineer`, `reporter`, and `tracker` all run `ikuncode-codex/gpt-5.3-codex` by default.
  - Claude API models were removed from the normal team allowlist in `agents.defaults.models`.
  - Claude remains reserved for explicit ACP / Claude Code usage rather than the normal member message path.
- `channels.discord.threadBindings` is enabled with both `spawnSubagentSessions=true` and `spawnAcpSessions=true`.
- Bundled plugins `acpx`, `discord`, and `open-prose` are enabled and observed loaded after restart.
- Host PATH does not contain standalone `acpx`, `codex`, `claude`, `claude-code`, `opencode`, or `gemini` binaries; OpenClaw currently relies on the bundled `acpx` runtime path.
- Gateway service imports `%h/.openclaw/acp-harness.env` through `~/.config/systemd/user/openclaw-gateway.service.d/acp-harness.conf`.
- `~/.openclaw/acp-harness.env` is generated from `~/.openclaw/openclaw.json` and now reuses only the `ikuncode-claude` Anthropic-compatible settings.
- `~/.codex/config.toml` was removed from the host on 2026-03-09 when Codex ACP was disabled.
- `~/.claude/settings.json` is present and currently pins `claude-sonnet-4-5-20250929`.
- `scripts/oracle-openclaw.sh runtime-exec` now sources `~/.openclaw/acp-harness.env` so local smoke checks use the same extra env as the real gateway process.
- Global sandbox defaults keep `docker.binds=[]`.
- The earlier engineer-only GitHub CLI bind-mount workaround was removed from the normal engineer agent path on 2026-03-11 because it blocked manager-spawned engineer subagents.
- All 5 normal team agents now share the same basic tool baseline:
  - `tools.exec.host = sandbox` with `ask = off`
  - `tools.exec.pathPrepend = ["/workspace/.openclaw/bin"]`
  - `tools.fs.workspaceOnly = true`
  - no per-agent `exec` deny blocks remain
- The gateway host browser subsystem is enabled globally and uses the managed Chromium path `/home/suguan/.openclaw/tools/playwright-browsers/chromium-1208/chrome-linux/chrome`.
- Sandbox tool policy now explicitly allows `browser`, `canvas`, and `group:memory`, while still denying `nodes` and channel-control tools for normal team-agent sessions.
- `agents.defaults.sandbox.browser.allowHostControl = true`, so sandboxed agents can target the host Chromium profile when needed.
- Verified on 2026-03-11 UTC: sandboxed `researcher` used the browser tool successfully against `https://example.com` and returned `Example Domain`.
- Verified on 2026-03-12 UTC: Oracle gateway has `0` paired and `0` connected nodes, so `canvas` is exposed to team agents but remains unusable until a node is paired.
- Oracle now ships a managed local plugin payload at `~/.openclaw/plugins/knowhere`, trusts it via `plugins.allow = ["knowhere"]`, and loads it through `plugins.load.paths`.
- Sandbox policy now also allows `knowhere_ingest_document`, `knowhere_search_documents`, `knowhere_list_documents`, `knowhere_remove_document`, and `knowhere_clear_scope`.
- `plugins.entries.knowhere` is enabled with `scopeMode=session`, `autoGrounding=false`, and `storageDir=/home/suguan/.openclaw/plugin-state/knowhere`.
- The tracked Knowhere config stays session-scoped, but usage is now manual: agents decide whether to call `knowhere_*` tools, and the plugin does not auto-ingest attachments or auto-ground prompts.
- The local plugin repo `~/github.com/ontosAI/knowhere-openclaw-plugin` now defers attachment format acceptance to the Knowhere API instead of pre-validating file types inside the plugin.
- `.secrets/oracle.ylioo.com.env` does not currently define `KNOWHERE_API_KEY`, so the plugin can load plus list/search/remove locally stored docs, but new Knowhere ingestion calls will fail until credentials are added.
- Sandboxed Codex sessions now expose `memory_search` and `memory_get` without reopening host writes.
- `agents.defaults.memorySearch` is now enabled with the local provider model `hf:sentence-transformers/all-MiniLM-L6-v2`.
- Oracle needed a user-space `cmake` install at `~/.local/bin/cmake` so the first local `node-llama-cpp` build could complete on arm64.
- Global sandbox env now points `GH_CONFIG_DIR` at `/workspace/.openclaw/gh`, so each sandboxed agent uses GitHub CLI state copied into its own workspace rather than the host home directory.
- `research-lead` no longer overrides sandboxing off; it now inherits the same per-agent sandbox defaults as the other team members.
- The live `~/.openclaw/exec-approvals.json` currently has empty `defaults` and `agents` maps, so no extra gateway-host exec approvals are in play for the team baseline.
- With the current sandboxed setup, `~/...` writes from normal agent `exec` land inside the sandbox container rather than the Oracle host home directory; only files written under `/workspace` persist back to the host agent workspace.
- For heavier repo work, multi-step coding, or GitHub-auth-sensitive flows, prefer Claude ACP threads over ad hoc normal-agent shell usage.
- Preferred engineer smoke test:
  - `./scripts/oracle-openclaw.sh runtime-exec 'run_openclaw agent --agent engineer --message "Reply with exactly: engineer ok" --json'`
- 2026-03-11 engineer re-test result:
  - before the Codex-first switch, the earlier bind-mount sandbox rejection was gone;
  - the remaining Claude-path failure was upstream model-provider availability: `HTTP 503 new_api_error: No available channel for model claude-sonnet-4-6 under group cc逆向 (distributor)`.
  - after the Codex-first switch, the same smoke test succeeded with provider `ikuncode-codex` and model `gpt-5.3-codex`.
- Current ACP smoke status:
  - Re-test at `2026-03-09T08:21Z` showed the raw Anthropic-compatible endpoint is currently healthy again:
    - `GET https://api.ikuncode.cc/v1/models` returned `200`
    - `POST https://api.ikuncode.cc/v1/messages` returned `200` for:
      - `claude-opus-4-6`
      - `claude-sonnet-4-6`
      - `claude-haiku-4-5-20251001`
  - Earlier `model_not_found` responses observed around `2026-03-09T08:04Z` appear to have been transient provider-side behavior rather than a persistent local config problem.
  - Claude-only ACP config remains live on Oracle.
  - Codex ACP was intentionally removed from the live Oracle config for now instead of keeping a broken fallback.

## Direct member mention workflow
- Real Discord member mentions are now the primary dispatch path on Oracle.
- Mentioning `OpenClaw Manager` in `#general` routes the message to `research-lead` through Discord account `manager`.
- `research-lead` is configured to auto-delegate substantial tasks to `researcher`, `engineer`, `reporter`, and `tracker` instead of waiting for explicit teammate mentions.
- Mentioning `OpenClaw Engineer`, `OpenClaw Researcher`, `OpenClaw Reporter`, or `OpenClaw Tracker` routes directly to the matching specialized agent through its own Discord account binding.
- Plain text without an explicit bot mention should stay silent because `requireMention=true` is enabled.
- A role mention such as `<@&...>` is not a bot-member mention. On 2026-03-11 the text `@OpenClaw Researcher` resolved to Discord role id `1481135755001724991`, not the researcher bot user id `1481133991749750886`.
- Oracle build config now sets `ignoreOtherMentions=true` so role mentions and unrelated mentions are ignored instead of being treated as a manager wake-up.
- The earlier `@manager` / `@engineer` alias-based manager prompt still exists in `workspace-research-lead/AGENTS.md`, but manager-only flows now also allow autonomous internal delegation.
- Operational guidance: mention one teammate bot per message to avoid ambiguous multi-bot wakeups on the shared channel.
