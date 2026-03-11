# oracle.ylioo.com Build Tree

This directory is the path-faithful desired build tree for the Oracle OpenClaw host.

## Layout
- `rootfs/`: host-style file tree rooted at `/`.
- `secrets.example.env`: secret contract for `.secrets/oracle.ylioo.com.env`.
- `BUILD.md`: step-by-step rebuild book for this host.

## Refresh
Edit `rootfs/` directly when you want to change intended Oracle state.

Render and apply it with:

```sh
./scripts/render-build-state.sh --build-dir build/oracle.ylioo.com --secrets-file .secrets/oracle.ylioo.com.env
./scripts/apply-build-host.sh --host oracle.ylioo.com --secrets-file .secrets/oracle.ylioo.com.env
```

## Important limits
- `rootfs/home/suguan/.openclaw/.env` contains only tracked non-secret values.
- Secret values come from `.secrets/oracle.ylioo.com.env` at render/apply time.
- Untracked live captures belong in `.tmp/live/oracle.ylioo.com/`, not in this directory.
