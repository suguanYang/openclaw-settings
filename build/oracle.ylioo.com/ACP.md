# Oracle ACP Status

This document records the tracked ACP state for `oracle.ylioo.com`.

ACP is disabled in the current Oracle build tree.

## Current tracked state

- `rootfs/home/suguan/.openclaw/openclaw.json` sets `acp.enabled = false`.
- Discord thread-bound ACP spawns are disabled for this host.
- The Oracle build no longer manages `.acpx`, `.codex`, the
  `openclaw-codex-acp` wrapper, or the ACP harness environment/drop-in files.

## Operational effect

- Re-applying `build/oracle.ylioo.com/` removes the previously managed Oracle
  Codex ACP wrapper/env files from the host.
- Existing OpenClaw agents still use the tracked `ikuncode-codex` provider for
  normal agent turns. This change only removes the Oracle-side ACP/Codex
  integration layer.

## If ACP returns later

Re-introduce ACP only as explicit tracked build state and update this document
at the same time.
