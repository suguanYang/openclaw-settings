# oracle.ylioo.com Build Mirror

This directory is the path-faithful build package for the current Oracle OpenClaw host.

## Layout
- `rootfs/`: host-style file tree rooted at `/`.
- `BUILD.md`: step-by-step rebuild book for this host.
- `manifest.json`: machine-readable file map with source provenance.

## Refresh
Regenerate this package from the current repo state with:

```sh
./scripts/oracle-openclaw.sh snapshot
```

## Important limits
- Captured files stay redacted in the tracked build mirror.
- `rootfs/home/suguan/.openclaw/.env` is generated from the tracked profile plus the chosen secrets source.
- The tracked version uses `managed/secrets.example.env`, so path and variable names are exact, but secret values are blank.
