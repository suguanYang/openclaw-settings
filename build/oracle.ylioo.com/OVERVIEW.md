# Oracle OpenClaw Overview

This document summarizes the tracked OpenClaw configuration for
`oracle.ylioo.com`.

It describes the desired build state in this repository, not a separately
verified live snapshot of the server. Secret values are intentionally omitted
from the tracked files and are merged from `.secrets/oracle.ylioo.com.env`
during render/apply.

## Runtime shape

- OpenClaw runs as a user-level gateway service for `suguan`.
- The browser layer is enabled, headless, and points to a pinned Chromium under
  `~/.openclaw/tools/playwright-browsers/...`.
- Logging is configured for high visibility: `trace` level overall, `debug`
  console level, and pretty console output.
- Host journald retention is capped at `1G` for both persistent and runtime
  journal storage through `/etc/systemd/journald.conf.d/50-openclaw-journal-size.conf`.
- The main shared workspace root is `/home/suguan/openclaw-workspace`.

Tracked sources:

- `rootfs/home/suguan/.openclaw/openclaw.json`
- `rootfs/home/suguan/.openclaw/.env`

## ACP and model setup

- ACP is enabled with the `acpx` backend.
- The default ACP agent is `codex`.
- The only allowed ACP agent is `codex`.
- The service loads `%h/.openclaw/acp-harness.env` through a systemd drop-in so
  ACP-side harnesses can reuse the managed OpenAI-compatible credentials.
- The tracked Codex-side setting pins `gpt-5.3-codex` with
  `openai_base_url = https://api.ikuncode.cc/v1` in `~/.codex/config.toml`, so
  Codex ACP uses the same ikuncode OpenAI-compatible endpoint as the main
  OpenClaw agents while reusing `OPENAI_API_KEY` from the ACP harness
  environment.
- The ACP harness env also exports `CODEX_API_KEY` from the same managed
  secret because the current Codex CLI build on Oracle authenticates correctly
  with that alias.
- `~/.acpx/config.json` routes the `codex` ACP harness through a local wrapper
  script at `~/.local/bin/openclaw-codex-acp`.
- Operator-facing Discord usage for this ACP setup is documented in `ACP.md`.
- That wrapper runs Codex ACP in a local Docker image because Oracle is still
  on Ubuntu 20.04 arm64, while the upstream `codex-acp` Linux arm64 binary
  currently requires newer glibc/OpenSSL runtime libraries than the host
  provides.
- The live host baseline behind that decision is:
  - Ubuntu 20.04.6 LTS (`focal`) on `arm64`
  - `glibc` 2.31 from the distro
  - OpenSSL 1.1 on the host library path
- The upstream `codex-acp` Linux arm64 binary was observed to require:
  - `GLIBC_2.32`
  - `GLIBC_2.33`
  - `GLIBC_2.34`
  - `libssl.so.3`
  - `libcrypto.so.3`
- This repository intentionally does not try to "fix" that mismatch by
  replacing host `glibc` or OpenSSL in place. On this server, that would be an
  operator-level OS/runtime upgrade risk rather than a safe app-level change.
  The tracked approach is to keep the host stable and run Codex ACP in a
  compatible container image instead.

Provider layout:

- `ikuncode-codex` uses the OpenAI-compatible endpoint at
  `${OPENAI_BASE_URL}` with `gpt-5.3-codex`, `gpt-5.2-codex`, and `gpt-5.2`.
- The default primary agent model is `ikuncode-codex/gpt-5.3-codex`.

## Agent topology

The host is configured as a small multi-agent team rather than a single
assistant.

Tracked agent IDs:

- `main`: default direct agent in `/home/suguan/openclaw-workspace`
- `research-lead`: manager/orchestrator
- `researcher`: web and source analyst
- `engineer`: validation and execution specialist
- `reporter`: progress summarizer
- `tracker`: issue and follow-up coordinator

Behavioral highlights:

- `research-lead` is configured as the Discord team manager with mention
  patterns for `@manager`, `@lead`, `@engineer`, `@researcher`, `@reporter`,
  and `@tracker`.
- `research-lead` may spawn `engineer`, `reporter`, `researcher`, and
  `tracker`.
- `researcher` runs with sandbox mode `off` and executes against the gateway
  host instead of the sandbox.
- `engineer`, `reporter`, and `tracker` keep `sandbox.mode = all` with
  read-only workspace access.
- The `tracker` Discord account requires an explicit `@mention` in the main
  channel `565501941510045707`, matching the guild-level default.
- Default agent settings enable local memory search, safeguard compaction, and
  bounded subagent fan-out.

Tracked workspace prompts live under:

- `rootfs/home/suguan/.openclaw/workspace/`
- `rootfs/home/suguan/.openclaw/workspace-research-lead/`
- `rootfs/home/suguan/.openclaw/workspace-researcher/`
- `rootfs/home/suguan/.openclaw/workspace-engineer/`
- `rootfs/home/suguan/.openclaw/workspace-reporter/`
- `rootfs/home/suguan/.openclaw/workspace-tracker/`

## Tooling and sandbox policy

- Web search is disabled, but web fetch remains enabled.
- Elevated tools are disabled.
- Default `exec` runs in the sandbox with `security = full` and `ask = off`.
- Filesystem access is not limited to workspace-only mode.
- Sandbox browser host control is allowed.
- The sandbox Docker image is `openclaw-sandbox:ubuntu-24.04-full`.
- The Knowhere plugin checkout is bind-mounted read-only into the sandbox so
  sandboxed agents can inspect it.

Allowed sandbox tool families include:

- file edit/write/apply tools
- exec/process/session tools
- `cron` automation
- direct Discord connector access
- browser/canvas/image tools
- memory tools
- `knowhere_*` tools

Denied sandbox tool families still include `gateway` plus the remaining direct
chat/channel connectors such as Slack, Telegram, WhatsApp, Signal, and related
channel integrations.

## Discord routing model

Discord is enabled and configured as a controlled multi-account entrypoint.

Key points:

- Only the owner user ID `476950196589428738` is allowed to interact.
- Group policy is allowlist-based.
- Mention is required in the tracked guild.
- Thread bindings are enabled for both general session continuity and
  Discord-specific routing.
- The default Discord account is `manager`.

Tracked Discord accounts:

- `manager`
- `engineer`
- `researcher`
- `reporter`
- `tracker`

Tracked routes:

- The main channel `565501941510045707` routes each named account to its
  corresponding agent.
- Channel `1483122814025465937` routes `manager` to `research-lead` and
  `researcher` to `researcher`.

The tracked non-secret env also records the guild ID, primary channel ID,
channel name, and owner user ID.

## Gateway exposure

- Gateway port: `18789`
- Mode: `local`
- Bind: `loopback`
- Control UI: enabled from `~/.openclaw/control-ui`
- Allowed control UI origin:
  `https://oracle-phoneix.tail54f62.ts.net`
- Gateway auth mode: password
- Trusted proxies: loopback only
- Tailscale integration: `serve` mode

This means the tracked design keeps the OpenClaw gateway local on the host and
expects remote access to come through the Tailscale-served surface instead of a
public bind.

## Logfire exception polling

- Oracle also carries a user-level timer pair for Logfire exception polling:
  - `logfire-alert-poller.service`
  - `logfire-alert-poller.timer`
- The poller runs locally on the host every 5 minutes, queries Logfire through
  the official hosted MCP endpoint, deduplicates exception groups in local
  state, and hands any new or reopened groups to the `tracker` agent.
- The poller now shells out to a tiny local Node helper that uses the official
  `@modelcontextprotocol/sdk` package instead of a handwritten transport
  client. The pinned helper bundle lives under
  `rootfs/home/suguan/.local/share/logfire-alert-poller/` and is installed
  during apply.
- The current tracked query narrows to production records where either
  `is_exception = true` or `level = 'error'`, and it does not pin
  `service_name`.
- Delivery stays inside OpenClaw: the poller invokes `openclaw agent` with
  explicit Discord reply overrides so the final message is posted by the
  `tracker` Discord account into the tracked main channel.
- Runtime state for dedupe is stored under
  `~/.openclaw/integrations/logfire-alerts/state.json`.
- The tracked env contract adds:
  - `LOGFIRE_READ_TOKEN` (secret)
  - `LOGFIRE_MCP_TRANSPORT`
  - `LOGFIRE_MCP_ENDPOINT`
  - `LOGFIRE_MCP_HTTP_TIMEOUT_SECONDS`
  - `LOGFIRE_MCP_COMMAND` as a stdio fallback
  - `LOGFIRE_ALERT_*` tuning variables for service/env/level filters,
    lookback, suppression, and delivery target

This design avoids any public webhook ingress for Logfire alerts.

## Plugins and custom extensions

Three plugin entries are enabled:

- `acpx`
- `knowhere-claw`
- `open-prose`

Important details:

- The explicitly allowed external plugins are `acpx` and `knowhere-claw`.
- `knowhere-claw` is treated as the external npm plugin
  `@ontos-ai/knowhere-claw`, not a local source checkout.
- Operators should install it with
  `openclaw plugins install @ontos-ai/knowhere-claw --pin` and update it with
  `openclaw plugins update knowhere-claw`.
- OpenClaw installs npm plugins under `~/.openclaw/extensions/<id>/`; this
  repo tracks the desired config entry for `knowhere-claw`, not a vendored
  plugin copy.
- `plugins.installs` is CLI-managed host runtime state used by
  `openclaw plugins update`, so it is not hand-edited or mirrored under
  `build/`.
- `acpx` is configured with:
  - `command = acpx`
  - `expectedVersion = 0.1.16`
  - `cwd = /home/suguan/openclaw-workspace`
  - `permissionMode = approve-all`
  - `nonInteractivePermissions = fail`
  - `mcpServers.logfire = bash -lc 'exec mcp-remote https://logfire-us.pydantic.dev/mcp --header "Authorization: Bearer $LOGFIRE_READ_TOKEN"'`
    with `LOGFIRE_READ_TOKEN`
- The apply flow also installs global ACP-side binaries needed by that config:
  - `acpx@0.1.16`
  - `@openai/codex@0.115.0`
  - `mcp-remote@0.1.38`
- The apply flow also builds `openclaw-codex-acp:ubuntu-24.04` from the
  tracked Dockerfile under `~/.local/share/openclaw-codex-acp/`. That image
  layers `uvx`, `@openai/codex@0.115.0`, `@zed-industries/codex-acp@0.10.0`,
  and `mcp-remote@0.1.38` onto the existing
  `openclaw-sandbox:ubuntu-24.04-full` base so Codex ACP can run on Oracle and
  bridge the hosted Logfire MCP endpoint from inside the container.
- The Logfire MCP path for ACP now uses the hosted endpoint through
  `mcp-remote`, not the local `uvx logfire-mcp` stdio server. The hosted route
  matched the working Oracle poller path and was the path verified live with
  Codex ACP.
- `knowhere-claw` stores data under
  `/home/suguan/.openclaw/plugin-state/knowhere`
  with `scopeMode = session`.

ACP sessions spawned through `acpx` now receive the Logfire MCP server during
session bootstrap, so channel or thread ACP runs can query production Logfire
data without the native OpenClaw agents carrying a separate handwritten client.

Installed Knowhere plugin files live on the host under
`~/.openclaw/extensions/knowhere-claw/` after the npm install. They are runtime
artifacts and are intentionally not mirrored under `build/`.

## File map

The main tracked files behind this overview are:

- `rootfs/home/suguan/.openclaw/openclaw.json`
- `rootfs/home/suguan/.openclaw/.env`
- `rootfs/home/suguan/.openclaw/acp-harness.env`
- `rootfs/home/suguan/.acpx/config.json`
- `rootfs/home/suguan/.codex/config.toml`
- `rootfs/home/suguan/.local/bin/openclaw-codex-acp`
- `rootfs/home/suguan/.local/share/openclaw-codex-acp/Dockerfile`
- `rootfs/home/suguan/.config/systemd/user/openclaw-gateway.service.d/acp-harness.conf`
- `rootfs/etc/systemd/journald.conf.d/50-openclaw-journal-size.conf`
- `rootfs/home/suguan/.openclaw/workspace*/`

Installed plugin payloads under `~/.openclaw/extensions/` and CLI-managed
`plugins.installs` are host runtime state, so they are intentionally excluded
from this tracked file map.
