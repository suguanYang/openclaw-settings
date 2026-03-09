# Oracle Research Team

Last verified: 2026-03-09 UTC

## Purpose
This document describes the research team configured on `oracle.ylioo.com` for the Discord server workflow.

The team is designed for multi-step research and build work where the manager can keep the conversation coherent while specialist teammates handle focused execution.

## Current routing
- Gateway host: `oracle.ylioo.com`
- Discord guild id: `565501940742619145`
- Discord channel id: `565501941510045707`
- Routed agent for that channel: `research-lead`
- Guild mention policy: `requireMention=true`

That means the bot should stay silent in the guild unless the message explicitly mentions the bot or matches one of the configured member aliases below.

## Team members
- `research-lead`
  - Role: manager and orchestrator
  - Mention aliases: `@manager`, `@lead`
  - Default behavior: responds directly when explicitly called as manager
- `engineer`
  - Role: code execution, validation, scripts, graphs, technical checks
  - Mention alias: `@engineer`
- `researcher`
  - Role: broad context gathering, source collection, web-heavy analysis
  - Mention alias: `@researcher`
- `reporter`
  - Role: concise progress updates and user-facing status summaries
  - Mention alias: `@reporter`
- `tracker`
  - Role: follow-up tracking, issue recording, status bookkeeping
  - Mention alias: `@tracker`

## Message handling rules
The live team is configured to respond only to explicit member mentions.

Rules:
- The first token in the message is the routing token.
- `@manager` or `@lead` keeps the task with `research-lead`.
- `@engineer`, `@researcher`, `@reporter`, or `@tracker` explicitly selects that teammate.
- Mentions later in the sentence are advisory only. They do not change dispatch.
- If no valid leading member mention is present, the team should not respond in that guild channel.

## Manager delegation policy
`research-lead` is intentionally conservative.

Rules:
- It should not spawn specialist teammates unless the user explicitly starts the message with that teammate mention.
- If the user starts with `@manager` or `@lead`, the manager answers directly.
- If the user selects a specialist, the manager may coordinate the result, but should not invent extra teammate work that the user did not ask for.
- Specialist work should stay in dedicated bound subagent sessions or threads when possible.

## Examples
- `@manager give me a short status of the current work`
  - Expected behavior: `research-lead` replies directly.
- `@engineer validate this claim with code and give me the result`
  - Expected behavior: manager dispatches to `engineer`.
- `@researcher collect the latest public context on this topic`
  - Expected behavior: manager dispatches to `researcher`.
- `hello team`
  - Expected behavior: no reply.
- `please help @engineer with this`
  - Expected behavior: no teammate dispatch, because the member mention is not the first token.

## Runtime implementation notes
- Discord routing is still bound to `research-lead` at the channel level.
- Direct teammate mentions are implemented as managed prompt behavior in `~/.openclaw/workspace-research-lead/AGENTS.md`, not as native Discord route retargeting.
- `research-lead` accepts member aliases through `agents.list[1].groupChat.mentionPatterns` in the live Oracle config.
- Workspace bootstrap files such as `AGENTS.md` are cached per session key, so prompt changes are safest after a gateway restart or session reset.
- `TEAM.md` in workspace snapshots is operator documentation only and is not auto-injected into the runtime bootstrap prompt on this OpenClaw checkout.

## Operational files
- Host context: `context/oracle.ylioo.com.md`
- Managed manager prompt: `managed/workspace-research-lead/AGENTS.md`
- Managed ACP note: `managed/workspace-research-lead/ACP.md`
- Live snapshot prompt: `snapshots/workspace-research-lead/AGENTS.md`
- Live snapshot config: `snapshots/openclaw.json`
- Oracle operation log: `operation-logs/2026-03-09-oracle.ylioo.com.md`

## How to maintain it
When changing team behavior:
1. Update the managed prompt files under `managed/workspace-research-lead/`.
2. Push the changed files to Oracle.
3. Restart the gateway.
4. Run `./scripts/oracle-openclaw.sh health`.
5. Run `./scripts/oracle-openclaw.sh snapshot`.
6. Update this document and `context/oracle.ylioo.com.md` if behavior changed.
7. Commit the operator repo.

## Known limitations
- A real explicit Discord bot mention can still wake the routed agent, because Discord explicit bot mentions are part of OpenClaw mention detection.
- Native OpenClaw routing in this checkout does not retarget the channel directly to `engineer` or `researcher`; the manager prompt performs that dispatch.
- This document reflects the Oracle deployment state, not generic upstream OpenClaw behavior.
