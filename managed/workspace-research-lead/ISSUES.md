# Research Team Issue Board

Format:
- `RT-xxx | status | owner | title`
- `deps: ...`
- `next: ...`

Statuses: `todo | in-progress | blocked | done`

## Current items

- `RT-001 | in-progress | manager | Define GitHub governance model`
  - deps: none
  - next: finalize labels, templates, branch protections, PR checklist

- `RT-002 | todo | manager | Create GitHub Project schema`
  - deps: RT-001
  - next: define fields (Owner/Priority/Area/Milestone/ETA), views, automation

- `RT-003 | todo | manager | Draft CI pipeline spec`
  - deps: RT-001
  - next: PR checks for lint/typecheck/test/build

- `RT-004 | todo | manager | Draft CD strategy`
  - deps: RT-003
  - next: Vercel preview deploy + backend staging/prod promotion flow

- `RT-005 | todo | manager | Design code-search data model`
  - deps: RT-001
  - next: index schema, query API contract, ranking/filter strategy

- `RT-006 | todo | manager | Design MCP HTTP server contract`
  - deps: RT-005
  - next: tools list, auth strategy, error model, request tracing

- `RT-007 | todo | manager | Backend free-tier provider comparison`
  - deps: none
  - next: compare Fly/Railway/Cloudflare/HF on runtime fit, limits, ops overhead

- `RT-008 | todo | manager | Produce implementation milestone plan`
  - deps: RT-002, RT-003, RT-004, RT-005, RT-006, RT-007
  - next: sequence work into 30/60/90-day roadmap with risk controls