# Context Hierarchy

This directory is the structured knowledge layer for the repo. It exists so operators and LLMs can find the right level of context without reading one giant note.

## Read order
1. `../README.md`
2. `architecture/`
3. `hosts/README.md`
4. `hosts/<host>/runbooks/` or `hosts/<host>/projects/`
5. `operation-logs/`
6. `../build/`

## Storage rules
- `architecture/`: repo-wide rules, boundaries, and state model.
- `hosts/`: host-specific facts, live behavior, rebuild notes, and repair history.
- `design/`: future-facing function design and accepted decisions.
- `operation-logs/`: append-only evidence of exact interventions.
- `build/`: redacted path-faithful live mirror when exact current files matter.

## Writing rules
- Keep one concern per file.
- Keep host `README.md` files thin; use them as indexes, not dump files.
- Put planned changes in `design/`, not in host runtime notes.
- When live behavior changes, update the log plus the smallest affected leaf doc.
- For anything about generic OpenClaw behavior, verify against the official docs and upstream GitHub source before trusting local notes.
