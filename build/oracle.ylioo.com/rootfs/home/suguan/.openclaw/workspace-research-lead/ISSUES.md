# Research Team Issue Board

Format:
- `RT-xxx | status | owner | title`
- `deps: ...`
- `next: ...`

Statuses: `todo | in-progress | blocked | done`

## Current items

- `RT-301 | in-progress | researcher | Gather current source context for SQLite fit`
  - deps: none
  - next: summarize strengths/limits for tiny single-node analytics; include citations.

- `RT-302 | in-progress | manager | Validate one SQLite technical point reproducibly`
  - deps: none
  - next: run local reproducible check and capture commands/output.

- `RT-303 | in-progress | tracker | Maintain issue board and dependency snapshot`
  - deps: RT-301, RT-302
  - next: provide status transitions + blocker report.

- `RT-304 | todo | manager | Final synthesis and recommendation`
  - deps: RT-301, RT-302, RT-303
  - next: produce decision, confidence, risks, mitigations, next actions.
