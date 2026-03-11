# Oracle Research Team

Last verified: 2026-03-11 UTC

## Purpose
This document describes the research team configured on `oracle.ylioo.com` for the Discord server workflow.

The team is designed for multi-step research and build work where the manager can keep the conversation coherent while specialist teammates handle focused execution.

## Current routing
- Gateway host: `oracle.ylioo.com`
- Discord guild id: `565501940742619145`
- Discord channel id: `565501941510045707`
- Guild mention policy: `requireMention=true`
- Discord default account: `manager`
- Live account to agent mapping:
  - `manager` -> `research-lead`
  - `engineer` -> `engineer`
  - `researcher` -> `researcher`
  - `reporter` -> `reporter`
  - `tracker` -> `tracker`

That means the team should stay silent in that guild unless one of the bot members is explicitly mentioned.

## Team members
- `OpenClaw Manager`
  - Internal agent: `research-lead`
  - Role: manager and orchestrator
- `OpenClaw Engineer`
  - Internal agent: `engineer`
  - Role: code execution, validation, scripts, graphs, and technical checks
- `OpenClaw Researcher`
  - Internal agent: `researcher`
  - Role: broad context gathering, source collection, and web-heavy analysis
- `OpenClaw Reporter`
  - Internal agent: `reporter`
  - Role: concise progress updates and user-facing status summaries
- `OpenClaw Tracker`
  - Internal agent: `tracker`
  - Role: follow-up tracking, issue recording, and status bookkeeping

## Message handling rules
The live team is configured to respond only to explicit real Discord member mentions.

Rules:
- Mention the actual bot member you want in Discord.
- Mentioning `OpenClaw Manager` wakes `research-lead`.
- Mentioning `OpenClaw Engineer`, `OpenClaw Researcher`, `OpenClaw Reporter`, or `OpenClaw Tracker` wakes that specialist directly.
- Plain text without an explicit bot mention should not trigger a reply in that guild.
- Operationally, mention one teammate bot per message on the shared channel.

## Manager delegation policy
`research-lead` is still the manager, but it is no longer the only Discord-facing entrypoint.

Rules:
- If the message mentions `OpenClaw Manager`, the manager answers directly.
- If the message mentions a specialist bot, that specialist receives the task through its own bound Discord account.
- The manager prompt still contains compatibility aliases such as `@manager` and `@engineer`, but the intended user-facing workflow is real Discord bot mentions.
- Specialist work should stay in dedicated bound subagent sessions or threads when possible.

## Examples
- `@OpenClaw Manager give me a short status of the current work`
  - Expected behavior: `research-lead` replies directly.
- `@OpenClaw Engineer validate this claim with code and give me the result`
  - Expected behavior: `engineer` responds through the engineer bot account.
- `@OpenClaw Researcher collect the latest public context on this topic`
  - Expected behavior: `researcher` responds through the researcher bot account.
- `hello team`
  - Expected behavior: no reply.

## Runtime implementation notes
- Native OpenClaw multi-account Discord routing is now live through `channels.discord.accounts`, `channels.discord.defaultAccount`, and binding-level `match.accountId`.
- All 5 Discord accounts are bound to the same guild channel, but each account wakes only on its own explicit bot mention because the guild requires mentions.
- `research-lead` still has managed alias logic in `~/.openclaw/workspace-research-lead/AGENTS.md`, but that is now a fallback path rather than the primary routing model.
- `TEAM.md` in workspace snapshots is operator documentation only and is not auto-injected into the runtime bootstrap prompt on this OpenClaw checkout.
- `openclaw health` reports only the default Discord account; use gateway logs to verify all 5 accounts after restart.

## Operational files
- Host context: `context/oracle.ylioo.com.md`
- Discord cutover helper: `scripts/oracle-discord-cutover.sh`
- Managed manager prompt: `managed/workspace-research-lead/AGENTS.md`
- Managed ACP note: `managed/workspace-research-lead/ACP.md`
- Live snapshot prompt: `snapshots/workspace-research-lead/AGENTS.md`
- Live snapshot config: `snapshots/openclaw.json`
- Oracle operation log: `operation-logs/2026-03-11-oracle.ylioo.com.md`

## How to maintain it
When changing team behavior:
1. Update the managed prompt files under `managed/workspace-research-lead/` only if manager behavior needs to change.
2. Rotate or capture bot tokens outside the repo if account credentials changed.
3. Run `./scripts/oracle-discord-cutover.sh` to merge the remote `.env` and patch Oracle `openclaw.json`.
4. Restart the gateway.
5. Run `./scripts/oracle-openclaw.sh health`.
6. Run `./scripts/oracle-openclaw.sh logs 120`.
7. Run `./scripts/oracle-openclaw.sh snapshot`.
8. Update this document and `context/oracle.ylioo.com.md` if behavior changed.
9. Commit the operator repo.

## Known limitations
- Mentioning multiple teammate bots in one message may wake more than one account on the shared channel; prefer one bot mention per message.
- The manager compatibility aliases in `workspace-research-lead/AGENTS.md` still exist, so prompt-level behavior and native Discord routing both matter for manager-only flows.
- This document reflects the Oracle deployment state, not generic upstream OpenClaw behavior.
