# Build Oracle OpenClaw

This file documents the role of `build/oracle.ylioo.com/` as a path-faithful
deploy tree.

This directory is the tracked input for rendering and applying Oracle build
state with the repo-supported scripts.

## What This Directory Is For

- Keep the exact tracked host-style files under `rootfs/`.
- Show which Oracle files are declarative build state versus runtime state.
- Give operators one place to inspect or edit the files that the render/apply
  flow will stage and upload.

Typical tracked files here:

- `rootfs/home/suguan/.openclaw/openclaw.json`
- `rootfs/home/suguan/.openclaw/.env`
- `rootfs/home/suguan/.openclaw/acp-harness.env`
- `rootfs/home/suguan/.openclaw/workspace*/`
- `rootfs/home/suguan/.claude/settings.json`
- `rootfs/home/suguan/.config/systemd/user/openclaw-gateway.service.d/acp-harness.conf`

## What This Directory Does Not Contain

- Real secret values
- Tracked local plugin bundles under `rootfs/home/suguan/.openclaw/plugins/`
- Generated control UI assets
- Browser/runtime tool downloads
- Thread bindings, device state, backups, logs, or other runtime-only state
- The generated `openclaw-gateway.service`

Those boundaries are intentional. The tracked build tree is for desired config,
not live operational residue.

## Secrets Contract

- `secrets.example.env` is the contract for local-only secrets.
- The real file should live at `.secrets/oracle.ylioo.com.env`.
- Do not commit that file.

## How This Tree Is Used

`scripts/render-build-state.sh` reads this tree, merges in local secrets, and
renders the staged output. `scripts/apply-build-host.sh` calls the renderer,
uploads the result to the target host, and repairs the live installation.

If you want to inspect the rendered result without applying it:

```sh
./scripts/render-build-state.sh \
  --build-dir build/oracle.ylioo.com \
  --secrets-file .secrets/oracle.ylioo.com.env
```

If you want to apply the tracked Oracle state:

```sh
./scripts/apply-build-host.sh \
  --host oracle.ylioo.com \
  --secrets-file .secrets/oracle.ylioo.com.env
```

## When To Edit This Directory

Edit files under `rootfs/` when the intended Oracle deployment state changes.

Examples:

- OpenClaw config changes
- workspace prompt changes
- tracked environment defaults
- managed service drop-ins

After changing the intended state:

1. Keep `build/` aligned with what you intend to deploy.
2. Use the render/apply scripts to stage or deploy it.
3. Record real server interventions in `operation-logs/`.
4. Update the relevant host docs if behavior changed.
