# Build Mirrors

This directory contains host-specific build packages.

## Purpose
- Mirror the current host configuration with path-faithful file names under `rootfs/`.
- Give operators and LLMs one place to inspect the current build shape without translating from a flatter repo-specific layout.
- Keep a step-by-step rebuild book next to the mirrored files.

## Rules
- `build/` is a derived layer, not the primary source of truth.
- `managed/` + `profiles/` remain the authoritative rebuild inputs.
- `build/` is the redacted path-faithful evidence layer for the live host.
- `build/` turns the live capture plus managed context into a host-path-oriented package for inspection and rebuild walkthroughs.

## Safety
- The tracked `build/` tree must stay repo-safe.
- Secret values must not be committed here.
- If you need a fully local package with real secrets, render it into a non-git path such as `.tmp/`.
