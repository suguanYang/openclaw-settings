---
name: github-repo-change
description: "Given a GitHub repository URL and change request, clone/update repo, implement changes on a branch, validate, and prepare commit/PR using open-source team workflow."
user-invocable: true
metadata:
  { "openclaw": { "emoji": "🐙" } }
---

# GitHub Repo Change Workflow

Use this when the user provides a GitHub repository link and asks for code changes.

## Inputs

- Required: repository URL (for example `https://github.com/owner/repo`)
- Required: concrete requested change
- Optional: target branch, test depth, whether to push/create PR

## Tool prerequisites

- Prefer `gh` if available; fallback path on this host: `~/.local/bin/gh`
- Use `git` for clone/edit/commit
- Use authenticated HTTPS remotes (no token in URL)

## Hard rule for repo URLs

If a valid GitHub repository URL is present and the repository is not already in the current workspace, you must clone it first.
Do not reply with “repo not available in workspace” before attempting clone/update.

## Core rules

1. Never expose or print GitHub tokens.
2. Never hardcode credentials into repo files or remotes.
3. Default to local edits first; push/PR only when user asks or confirms.
4. Follow existing project process before coding:
   - read `README`, `CONTRIBUTING`, CI config, and any `AGENTS.md` / `CLAUDE.md`
   - respect project lint/test/commit conventions

## Execution plan

1. Normalize repo URL and derive `owner/repo`.
2. Workspace path:
   - `<current-workspace>/repos/<owner>/<repo>`
3. Clone/update:
   - If missing: clone
   - If exists and clean: fetch + pull default branch
   - If exists and dirty: do **not** discard changes; either ask user or clone a fresh sibling path with suffix
4. Create working branch from default branch:
   - `openclaw/<yyyymmdd>-<short-task>`
5. Implement minimal change set to satisfy request.
6. Validate:
   - run project-recommended checks first
   - if unknown, run smallest reliable checks (targeted tests/lint for touched areas)
7. Summarize outcome:
   - files changed
   - checks run + results
   - remaining risks
8. If requested, finalize GitHub flow:
   - commit with clear, scoped message
   - push branch
   - create PR (draft by default) with problem/solution/test evidence

## OSS team process checklist (must apply)

- Confirm issue scope and non-goals before editing
- Prefer small, reviewable commits
- Keep behavior changes covered by tests where feasible
- Include migration/docs updates when behavior changes
- In PR body, include:
  - motivation
  - design choices and tradeoffs
  - test evidence
  - rollback/risk notes

## Response format

1. Plan
2. Progress (short step log)
3. Result (diff summary)
4. Validation results
5. Next action (`ready to push`, `ready to open PR`, etc.)
