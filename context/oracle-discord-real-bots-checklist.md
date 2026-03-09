# Oracle Discord Real Bots Checklist

Last updated: 2026-03-10 UTC

## Goal
Replace the current single-bot + internal-agent Discord setup with real Discord bot members so `research-lead`, `engineer`, `researcher`, `reporter`, and `tracker` can be mentioned as actual Discord members.

## Current state
- Oracle currently has one Discord bot account configured in `channels.discord.token`.
- Internal OpenClaw agents exist for `research-lead`, `engineer`, `researcher`, `reporter`, and `tracker`.
- Real Discord member mentions are not possible until each teammate has its own Discord bot account.

## Fastest migration path
Reuse the current existing Discord bot as the manager account, then create 4 new Discord bots.

Recommended target mapping:
- Existing bot -> `research-lead` / manager
- New bot -> `engineer`
- New bot -> `researcher`
- New bot -> `reporter`
- New bot -> `tracker`

## Discord-side creation checklist
For each bot app in Discord Developer Portal:
1. Create or rename the application.
2. Ensure a bot user exists.
3. Enable privileged intents:
   - Message Content Intent
   - Server Members Intent
4. On Installation / OAuth setup, use scopes:
   - `bot`
   - `applications.commands`
5. Grant baseline permissions:
   - View Channels
   - Send Messages
   - Read Message History
   - Embed Links
   - Attach Files
   - Add Reactions
6. Invite the bot to the target Discord server.
7. Confirm the bot appears in the member list.
8. Copy and keep these values:
   - Application ID
   - Bot User ID
   - Bot token

## Recommended bot names
- `OpenClaw Manager`
- `OpenClaw Engineer`
- `OpenClaw Researcher`
- `OpenClaw Reporter`
- `OpenClaw Tracker`

## What to give back for Oracle wiring
For each bot, provide:
- role name: manager / engineer / researcher / reporter / tracker
- application id
- bot user id
- bot token

## Oracle-side work after Discord creation
Once the bot credentials exist, Oracle will need:
1. Migrate from single-account Discord config to `channels.discord.accounts`.
2. Bind each `accountId` to the matching agent via `bindings[].match.accountId`.
3. Keep guild allowlist and channel allowlist aligned for each account.
4. Keep `requireMention=true` for guild behavior.
5. Remove temporary alias-based member emulation if real member UX makes it unnecessary.
6. Restart the gateway.
7. Run `./scripts/oracle-openclaw.sh health`.
8. Run `./scripts/oracle-openclaw.sh snapshot`.
9. Commit the synced operator repo.

## Secret handling
- Do not store raw bot tokens in this repo.
- Tokens may be written directly to Oracle config or Oracle-local secret storage, then verified through redacted snapshots only.
