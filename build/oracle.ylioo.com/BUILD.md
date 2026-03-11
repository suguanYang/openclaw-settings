# Build Oracle OpenClaw

This book explains how to rebuild the current Oracle host using the path-faithful build mirror in this directory.

## Before touching the host
1. Re-check the official OpenClaw docs at `https://docs.openclaw.ai` and the upstream source at `https://github.com/openclaw/openclaw`.
2. Review `rootfs/` in this folder so you understand the exact host paths that will exist on Oracle.
3. Read `manifest.json` to see where each mirrored file came from.

## What this folder gives you
- Exact host-style paths under `rootfs/`, such as:
  - `rootfs/home/suguan/.openclaw/openclaw.json`
  - `rootfs/home/suguan/.openclaw/.env`
  - `rootfs/home/suguan/.claude/settings.json`
  - `rootfs/home/suguan/.config/systemd/user/openclaw-gateway.service`
- A repo-safe mirror of the current tracked host configuration.
- A manual rebuild reference when you need to reason in host paths instead of repo layers.

## What this folder does not give you by default
- Live secret values.
- Untracked runtime caches, logs, or ephemeral host state that are intentionally excluded from the repo.

## Step 1: Prepare secrets locally
1. Copy `managed/secrets.example.env` to `.secrets/oracle.ylioo.com.env`.
2. Fill the real values locally.
3. Do not commit that file.

## Step 2: Refresh the build package
Refresh the tracked safe package:

```sh
./scripts/oracle-openclaw.sh snapshot
```

That updates `build/oracle.ylioo.com/rootfs/` directly from the live host and refreshes the tracked placeholder-safe `.env`.

## Step 3: Prepare the target host
1. Install Node 22+ on the target host.
2. Ensure the target account is `suguan` or adjust the profile first.
3. Create the required base directories:
   - `/home/suguan/.openclaw`
   - `/home/suguan/.claude`
   - `/home/suguan/.config/systemd/user/openclaw-gateway.service.d`

## Step 4: Copy the mirrored files
Copy the mirrored tree to the matching paths on the host.

For a manual path-faithful copy, use the generated `rootfs/` tree as the source of truth for destination paths.

Key destinations:
- `rootfs/home/suguan/.openclaw/*` -> `/home/suguan/.openclaw/`
- `rootfs/home/suguan/.claude/settings.json` -> `/home/suguan/.claude/settings.json`
- `rootfs/home/suguan/.config/systemd/user/openclaw-gateway.service` -> `/home/suguan/.config/systemd/user/openclaw-gateway.service`
- `rootfs/home/suguan/.config/systemd/user/openclaw-gateway.service.d/acp-harness.conf` -> `/home/suguan/.config/systemd/user/openclaw-gateway.service.d/acp-harness.conf`

## Step 5: Prefer the managed apply flow for real deployment
The recommended deployment path is still:

```sh
./scripts/apply-managed-host.sh \
  --host oracle.ylioo.com \
  --profile profiles/oracle.ylioo.com.env \
  --secrets-file .secrets/oracle.ylioo.com.env
```

Use the `build/` mirror to inspect and reason about the exact path layout.
Use the managed apply flow to perform the real rebuild safely and repeatably.

## Step 6: Repair and verify
1. Run `./scripts/oracle-openclaw.sh status`
2. Run `./scripts/oracle-openclaw.sh health`
3. Run `./scripts/oracle-openclaw.sh logs 120`
4. Run `./scripts/oracle-openclaw.sh snapshot`

## Step 7: Update the repo after rebuild
1. Refresh `build/` with `./scripts/oracle-openclaw.sh snapshot`.
2. Record the intervention in `operation-logs/`.
3. Update host docs if the behavior or layout changed.
