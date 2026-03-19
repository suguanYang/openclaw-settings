# Oracle ACP Usage

This document explains how to use ACP on `oracle.ylioo.com` with the current
tracked configuration in this repository.

It is an operator guide for this host, not a generic OpenClaw ACP reference.

## Current shape

- The only tracked ACP harness is `codex`.
- Discord is the main operator surface for ACP on this host.
- The safest account for ACP spawn is `OpenClaw Researcher`.
- The `researcher` OpenClaw agent is not sandboxed, so it can start ACP
  sessions on the host.
- The `engineer`, `reporter`, and `tracker` agents are sandboxed and cannot
  start ACP sessions.

## Which bot to use

Use `@OpenClaw Researcher` when you want Codex ACP.

Why:

- ACP sessions run on the host runtime.
- Sandboxed agents cannot spawn ACP sessions.
- `researcher` is the tracked non-sandboxed Discord account intended for this
  flow.

Do not use `@OpenClaw Engineer` for ACP spawn unless the sandbox policy is
changed first.

## Mention requirement

The tracked guild config still requires mentions in Discord channels and
threads.

In practice, this means:

- Mention `@OpenClaw Researcher` when you start ACP.
- Keep mentioning `@OpenClaw Researcher` for follow-up messages if you want the
  most reliable routing.

## Start a Codex ACP session

From an allowed Discord channel:

```text
@OpenClaw Researcher /acp spawn codex
```

Useful variants:

```text
@OpenClaw Researcher /acp spawn codex --label logfire
@OpenClaw Researcher /acp spawn codex --cwd /home/suguan/openclaw-workspace
@OpenClaw Researcher /acp spawn codex --thread here
```

Notes:

- `/acp spawn` takes a harness id such as `codex`, not an OpenClaw agent id.
- `--thread here` only works when you run it inside an existing Discord thread.
- When you run `/acp spawn codex` in a normal channel, OpenClaw usually creates
  a new `🤖 codex` thread and binds that thread to the ACP session.

## How to talk to Codex after spawn

Once the `🤖 codex` thread exists, use that thread as the working surface.

The practical pattern is:

```text
@OpenClaw Researcher find recent production exceptions in Logfire
@OpenClaw Researcher summarize the top three exception groups
@OpenClaw Researcher propose a prioritized fix plan
```

Thread-bound follow-up messages route to the same ACP session. You usually do
not need to run `/acp steer` for normal conversation once you are already in
the spawned thread.

## Useful ACP control commands

```text
@OpenClaw Researcher /acp sessions
@OpenClaw Researcher /acp status
@OpenClaw Researcher /acp cwd /home/suguan/openclaw-workspace
@OpenClaw Researcher /acp model gpt-5.3-codex
@OpenClaw Researcher /acp close
```

Use `/acp status` and `/acp sessions` when you need to confirm which ACP
session is currently bound.

## What to expect with steering

Parent-channel steering is intentionally limited by the current session
visibility policy.

Current behavior:

- If you try to steer an older Codex ACP session from a different parent
  context, OpenClaw may refuse cross-session steering.
- In that case, OpenClaw may create a fresh ACP session and bind a new thread.

This is expected with the current default session visibility model.

## Known limitations

- `engineer`, `reporter`, and `tracker` cannot spawn ACP because they run in
  the sandbox.
- Cross-session steering from the parent channel is restricted by default.
- Discord channel visibility is separate from OpenClaw routing. If a bot is not
  visible in a channel, fix the Discord channel permissions first.

## Troubleshooting

If `/acp spawn` replies with a sandbox warning:

- switch to `@OpenClaw Researcher`

If the bot ignores a message:

- include `@OpenClaw Researcher`

If the bot is not visible in a channel:

- confirm the bot's Discord role has channel access
- Oracle config alone is not enough if Discord denies the channel

If you are unsure which ACP session you are talking to:

- run `@OpenClaw Researcher /acp status` inside the thread

