# oracle.ylioo.com Repair Notes

Last verified: 2026-03-11 UTC

These are historical repair findings that still matter when touching the Oracle host.

## Notes discovered on 2026-03-09
- `pnpm add -g openclaw@2026.3.8` succeeds only when `PNPM_HOME=/home/suguan/.local/share/pnpm` is exported.
- `scripts/oracle-openclaw.sh update` resolves `pnpm` from `PATH` first and falls back to `$PNPM_HOME/pnpm`, which matches the current Oracle host layout.
- `scripts/apply-build-host.sh` bootstraps `node` from the live systemd service `ExecStart` (and then NVM as fallback), so non-interactive Oracle applies no longer fail just because `node` is missing from SSH PATH.
- `openclaw doctor --non-interactive --fix` does not apply service-file repairs.
- `openclaw doctor --yes --fix` does apply the `systemd` service rewrite in a non-TTY session.
- `openclaw health` can return a transient loopback `1006` if probed immediately after restart; wait a few seconds before treating that as a real failure.
- `@zed-industries/codex-acp` currently fails on Oracle Linux ARM64 with `libssl.so.3` missing, so Codex ACP is not yet usable end-to-end on this host without a host-library fix or adapter override.
- The reused Claude proxy on this host showed transient behavior on 2026-03-09: early probes returned `model_not_found`, while a later re-test returned `200` for `/models` and current Claude `/messages` calls.
- Local build attempts for `codex-acp` on this host hit a cascading toolchain gap:
  - Ubuntu 20.04 only ships GCC 9.4, which `aws-lc-sys` rejects because of the known `memcmp` bug.
  - User-local `zig` got past the GCC guard, but the build still failed later in the dependency graph with `libsqlx_macros... undefined symbol: __ubsan_handle_type_mismatch_v1`.

## Practical recommendation for Codex ACP on this host
- Best fix: move the host to Ubuntu 22.04 or 24.04, or another newer ARM64 Linux baseline.
- Fallback fix: install a full newer LLVM/clang + compiler-rt stack user-locally and keep a custom `~/.acpx/config.json` codex override.
