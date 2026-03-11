# OpenClaw Upstream Reference Policy

## Rule
- **OpenClaw is an open-source upstream project.**
- **OpenClaw updates frequently.**
- **For anything about generic OpenClaw behavior, always verify against the official docs and the upstream GitHub source before trusting local repo notes.**

## Primary upstream sources
- Official docs: `https://docs.openclaw.ai`
- Upstream source: `https://github.com/openclaw/openclaw`

## What this means in practice
- Use this repo as the source of truth for our managed deployment state, local profiles, snapshots, and operator history.
- Do not treat local notes here as the final authority on upstream command behavior, config schema, plugin support, or feature availability.
- Before changing managed config, repair flows, or design docs, re-check the related upstream docs and source code.
- If local notes conflict with upstream, treat upstream as authoritative, then update the local docs to record the verified behavior for our host.

## When to refresh upstream context
- Before implementing a new OpenClaw function or workflow.
- Before editing `managed/openclaw.json.template` or deployment scripts.
- Before relying on CLI or gateway behavior that may have changed in recent OpenClaw releases.
- Before writing conclusions into host runtime notes or repair notes.
