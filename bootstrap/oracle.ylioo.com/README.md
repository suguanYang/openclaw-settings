# Oracle Clone Bootstrap

This folder is the reproducible fresh-host path for cloning the current
`oracle.ylioo.com` OpenClaw deployment onto another host.

It intentionally stays separate from `scripts/`, which remain the day-to-day
maintenance helpers for the live Oracle server.

## Quickstart

```sh
./bootstrap/setup.sh
```

When only one bootstrap profile exists, the script selects it automatically,
creates `.secrets/oracle.ylioo.com.env` if needed, prompts for missing secret
values, asks for the target SSH host, and then runs the bootstrap flow.

## What this bootstrap path adds

- A host-aware apply script that does not default to Oracle
- Use host-installed `pnpm` and `openclaw` when present, otherwise install the
  latest available versions
- Docker preflight checks for the tracked sandboxed-agent setup
- A browser compatibility symlink derived from the tracked build tree, so the
  hardcoded Oracle browser path can still work on a fresh host

## Preconditions

1. Install Node 22+ on the target host.
2. Install Docker and ensure the target user can run `docker info` without
   manual intervention.
3. Use the same target account as the tracked build tree (`suguan`) or adjust
   `build/oracle.ylioo.com/rootfs/` before applying.
4. Copy `build/oracle.ylioo.com/secrets.example.env` to
   `.secrets/oracle.ylioo.com.env` and fill the real values locally.
5. If the target host is arm64 and you want the tracked local `memorySearch`
   path to warm up successfully, make sure `cmake` is available for the first
   local `node-llama-cpp` build.

## Render

```sh
./bootstrap/oracle.ylioo.com/render-build-state.sh \
  --secrets-file .secrets/oracle.ylioo.com.env
```

## Apply To Another Host

```sh
./bootstrap/setup.sh --host <ssh-host>
```

The profile-specific apply helper still exists when you want a lower-level
entrypoint:

```sh
./bootstrap/oracle.ylioo.com/apply-build-host.sh \
  --host <ssh-host> \
  --secrets-file .secrets/oracle.ylioo.com.env
```

## Verify

```sh
./bootstrap/oracle.ylioo.com/host-openclaw.sh --host <ssh-host> status
./bootstrap/oracle.ylioo.com/host-openclaw.sh --host <ssh-host> health
./bootstrap/oracle.ylioo.com/host-openclaw.sh --host <ssh-host> logs 120
```

## Notes

- The apply script reads the tracked browser path and sandbox image from the
  rendered `openclaw.json`, so it follows the build tree instead of hardcoding
  another copy of those values.
- The browser compatibility symlink is only a bootstrap aid. Runtime browser
  assets still live under `~/.openclaw/tools/`.
- The live Oracle maintenance helpers remain unchanged under `scripts/`.
