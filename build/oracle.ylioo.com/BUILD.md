# Build Oracle OpenClaw

This file documents the role of `build/oracle.ylioo.com/` as a path-faithful
deploy tree.

It is no longer the main setup guide for cloning Oracle onto another host.
Use `../../bootstrap/oracle.ylioo.com/README.md` or `./bootstrap/setup.sh` for
the actual bootstrap workflow.

## What This Directory Is For

- Keep the exact tracked host-style files under `rootfs/`.
- Show which Oracle files are declarative build state versus runtime state.
- Give operators one place to inspect or edit the files that bootstrap will
  render and upload.

Typical tracked files here:

- `rootfs/home/suguan/.openclaw/openclaw.json`
- `rootfs/home/suguan/.openclaw/.env`
- `rootfs/home/suguan/.openclaw/acp-harness.env`
- `rootfs/home/suguan/.openclaw/workspace*/`
- `rootfs/home/suguan/.claude/settings.json`
- `rootfs/home/suguan/.config/systemd/user/openclaw-gateway.service.d/acp-harness.conf`

## What This Directory Does Not Contain

- Real secret values
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

The bootstrap flow reads this tree, merges in local secrets, renders the staged
output, and then uploads it to the target host.

If you want to inspect the rendered result without applying it:

```sh
./bootstrap/setup.sh --profile oracle.ylioo.com --render-only
```

If you want the full guided setup flow:

```sh
./bootstrap/setup.sh
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
2. Use the bootstrap flow to render or apply it.
3. Record real server interventions in `operation-logs/`.
4. Update the relevant host docs if behavior changed.
