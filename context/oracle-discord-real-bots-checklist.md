# Oracle Discord Real Bots Status

Last updated: 2026-03-11 UTC

## Goal
Replace the older single-bot + internal-agent Discord setup with real Discord bot members so `research-lead`, `engineer`, `researcher`, `reporter`, and `tracker` can be mentioned as actual Discord members.

## Current state
- Goal status: complete.
- Oracle no longer uses a single `channels.discord.token` entry for this team.
- Oracle now uses `channels.discord.accounts` with `defaultAccount = manager`.
- All 5 target bot applications exist and all 5 are invited into `sstar`.
- The live Discord UI on 2026-03-11 confirmed these member names in the server:
  - `OpenClaw Manager`
  - `OpenClaw Engineer`
  - `OpenClaw Researcher`
  - `OpenClaw Reporter`
  - `OpenClaw Tracker`
- Oracle routing is live for the shared channel `565501941510045707`:
  - `manager` -> `research-lead`
  - `engineer` -> `engineer`
  - `researcher` -> `researcher`
  - `reporter` -> `reporter`
  - `tracker` -> `tracker`
- Gateway restart and logs confirmed all 5 providers started and logged in successfully.

## Known application IDs
- `OpenClaw Manager`: `1481108454704943227`
- `OpenClaw Engineer`: `1481122055184187432`
- `OpenClaw Researcher`: `1481133991749750886`
- `OpenClaw Reporter`: `1481138115887501382`
- `OpenClaw Tracker`: `1481136653342081085`

## Secret handling
- Raw bot tokens are not stored in tracked repo files.
- Local operator secret staging lives in the gitignored file `.secrets/oracle-discord-bots.env`.
- Remote Oracle secret storage is `~/.openclaw/.env`.
- The tracked snapshot is redacted and does not include `.env`.
- `OPENAI_API_KEY` was preserved while merging the Discord token variables into the remote `.env`.

## Oracle-side implementation that is now live
- Remote helper script: `scripts/oracle-discord-cutover.sh`
- Live config shape:
  - `channels.discord.defaultAccount = manager`
  - `channels.discord.accounts.manager`
  - `channels.discord.accounts.engineer`
  - `channels.discord.accounts.researcher`
  - `channels.discord.accounts.reporter`
  - `channels.discord.accounts.tracker`
- Live bindings use `match.accountId` per bot account on the same Discord channel.
- Guild behavior still uses `requireMention=true`.

## Operational guidance
- Mention the actual bot member you want in Discord.
- Mention one teammate bot per message on the shared channel.
- Use `./scripts/oracle-openclaw.sh logs 120` after restart because `openclaw health` only shows the default Discord account.
- Use `./scripts/oracle-openclaw.sh snapshot` after any server-side Discord/account change.
- Commit `openclaw-settings` after each meaningful Oracle change.

## If a token or bot needs rotation later
1. Rotate the bot token in Discord Developer Portal.
2. Update the local gitignored `.secrets/oracle-discord-bots.env` file.
3. Run `./scripts/oracle-discord-cutover.sh`.
4. Run `./scripts/oracle-openclaw.sh restart`.
5. Run `./scripts/oracle-openclaw.sh health`.
6. Run `./scripts/oracle-openclaw.sh logs 120`.
7. Run `./scripts/oracle-openclaw.sh snapshot`.
8. Commit the operator repo.
