# ACP Harness Notes

Use ACP thread sessions for module-specific coding work.

Default mapping:
- Claude: implementation, debugging, architecture review, and long-context repo work on Oracle.
- Normal team turns already use Codex-first models, so reserve ACP for heavier coding-harness cases rather than ordinary chat turns.

Rules:
- Set an explicit `cwd` before repo work.
- Keep one ACP thread per module or repo.
- Ask for concise milestones, not chatty narration.
- Close or reset stale ACP sessions once the module is complete.
