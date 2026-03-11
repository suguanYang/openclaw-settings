# Build Oracle OpenClaw

This book explains how to rebuild the current Oracle host using the path-faithful build tree in this directory.

## Before touching the host
1. Re-check the official OpenClaw docs at `https://docs.openclaw.ai` and the upstream source at `https://github.com/openclaw/openclaw`.
2. Review `rootfs/` in this folder so you understand the exact host paths that will exist on Oracle.
3. Review `secrets.example.env` so you know which secret values must be provided locally.

## What this folder gives you
- Exact host-style paths under `rootfs/`, such as:
  - `rootfs/home/suguan/.openclaw/openclaw.json`
  - `rootfs/home/suguan/.openclaw/.env`
  - `rootfs/home/suguan/.claude/settings.json`
  - `rootfs/home/suguan/.config/systemd/user/openclaw-gateway.service.d/acp-harness.conf`
- A repo-safe mirror of the current tracked host configuration.
- A manual rebuild reference when you need to reason in host paths instead of repo layers.

## What this folder does not give you by default
- Live secret values.
- Runtime-only state such as device pairings, thread bindings, backups, and the generated service file.

## Step 1: Prepare secrets locally
1. Copy `secrets.example.env` to `.secrets/oracle.ylioo.com.env`.
2. Fill the real values locally.
3. Do not commit that file.

## Step 2: Edit the build tree
Edit the tracked files under `rootfs/` until they match the intended Oracle state.

Typical files:
- `rootfs/home/suguan/.openclaw/openclaw.json`
- `rootfs/home/suguan/.openclaw/.env`
- `rootfs/home/suguan/.openclaw/acp-harness.env`
- `rootfs/home/suguan/.openclaw/workspace*/`
- `rootfs/home/suguan/.claude/settings.json`
- `rootfs/home/suguan/.config/systemd/user/openclaw-gateway.service.d/acp-harness.conf`

## Step 3: Render locally

```sh
./scripts/render-build-state.sh \
  --build-dir build/oracle.ylioo.com \
  --secrets-file .secrets/oracle.ylioo.com.env
```

## Step 4: Prepare the target host
1. Install Node 22+ on the target host.
2. Ensure the target account is `suguan` or adjust the build tree first.
3. Create the required base directories:
   - `/home/suguan/.openclaw`
   - `/home/suguan/.claude`
   - `/home/suguan/.config/systemd/user/openclaw-gateway.service.d`

## Step 5: Apply the build tree
The recommended deployment path is:

```sh
./scripts/apply-build-host.sh \
  --host oracle.ylioo.com \
  --secrets-file .secrets/oracle.ylioo.com.env
```

## Step 6: Repair and verify
1. Run `./scripts/oracle-openclaw.sh status`
2. Run `./scripts/oracle-openclaw.sh health`
3. Run `./scripts/oracle-openclaw.sh logs 120`
4. If you need a redacted live comparison, run `./scripts/oracle-openclaw.sh snapshot`.

## Step 7: Update the repo after rebuild
1. Keep `build/` aligned with the intended deployed state.
2. Record the intervention in `operation-logs/`.
3. Update host docs if the behavior or layout changed.
