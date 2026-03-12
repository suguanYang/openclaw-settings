# Context Hierarchy

This directory is the operator-note layer for the repo. It holds repo-wide rules and host-specific context that sit beside the tracked build state in `../build/`.

## Read order
1. `../README.md`
2. `architecture/`
3. `hosts/README.md`
4. `hosts/<host>/`
5. `../operation-logs/`
6. `../build/`

## Storage rules
- `architecture/`: repo-wide rules, boundaries, and source-of-truth policy.
- `hosts/`: host-specific facts, runtime notes, repair history, projects, and runbooks.
- `../build/`: tracked target state and path-faithful files used to rebuild hosts.
- `../operation-logs/`: exact intervention records and timestamped command evidence.

## Writing rules
- Keep one concern per file.
- Keep host `README.md` files thin; use them as indexes, not dump files.
- Put durable rebuild intent in `../build/`, not in host runtime notes.
- Put exact incident evidence in `../operation-logs/`, not in summary docs.
- When live behavior changes, update the log plus the smallest affected leaf doc.
- For anything about generic OpenClaw behavior, verify against the official docs and upstream GitHub source before trusting local notes.
