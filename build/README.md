# Build Mirrors

This directory contains host-specific build packages.

## Purpose
- Keep the path-faithful desired host configuration under `rootfs/`.
- Give operators and LLMs one place to inspect and edit the exact files that will be pushed to the server.
- Keep reference notes next to the mirrored files and point operators at the repo-supported render/apply scripts.

## Rules
- `build/` is the primary tracked deploy source.
- `.secrets/` remains local-only and is merged during render/apply.
- Untracked live captures belong under `.tmp/live/`, not under `build/`.

## Safety
- The tracked `build/` tree must stay repo-safe.
- Secret values must not be committed here.
- If you need a redacted live comparison, capture it into `.tmp/live/`.
