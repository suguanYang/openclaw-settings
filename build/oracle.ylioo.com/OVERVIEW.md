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
- The main shared workspace root is `/home/suguan/openclaw-workspace`.

Tracked sources:

- `rootfs/home/suguan/.openclaw/openclaw.json`
- `rootfs/home/suguan/.openclaw/.env`

## ACP and model setup

- ACP is enabled with the `acpx` backend.
- The default ACP agent is `claude`, and allowed ACP agents are restricted to
  `claude`.
- The service loads `%h/.openclaw/acp-harness.env` through a systemd drop-in so
  Claude ACP sessions can reuse the managed Anthropic credentials and headers.
- The tracked Claude-side setting pins `claude-sonnet-4-5-20250929` in
  `~/.claude/settings.json`.

Provider layout:

- `ikuncode-claude` uses the Anthropic-compatible endpoint at
  `${ANTHROPIC_BASE_URL}` with Claude Opus/Sonnet model entries.
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

## Plugins and custom extensions

Three plugin entries are enabled:

- `acpx`
- `knowhere-claw`
- `open-prose`

Important details:

- The only explicitly allowed external plugin is `knowhere-claw`.
- OpenClaw loads plugins from
  `/home/suguan/github.com/ontosAI/knowhere-openclaw-plugin`.
- `acpx` is configured with:
  - `cwd = /home/suguan/openclaw-workspace`
  - `permissionMode = approve-all`
  - `nonInteractivePermissions = fail`
- `knowhere-claw` stores data under
  `/home/suguan/.openclaw/plugin-state/knowhere`
  with `scopeMode = session`.

The build tree also carries a staged packaged copy under
`rootfs/home/suguan/.openclaw/plugins/knowhere/` and a source checkout under
`rootfs/home/suguan/github.com/ontosAI/knowhere-openclaw-plugin/`.

## File map

The main tracked files behind this overview are:

- `rootfs/home/suguan/.openclaw/openclaw.json`
- `rootfs/home/suguan/.openclaw/.env`
- `rootfs/home/suguan/.openclaw/acp-harness.env`
- `rootfs/home/suguan/.config/systemd/user/openclaw-gateway.service.d/acp-harness.conf`
- `rootfs/home/suguan/.claude/settings.json`
- `rootfs/home/suguan/.openclaw/workspace*/`
- `rootfs/home/suguan/.openclaw/plugins/knowhere/`
- `rootfs/home/suguan/github.com/ontosAI/knowhere-openclaw-plugin/`
