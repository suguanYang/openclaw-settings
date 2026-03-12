# Bootstrap

This folder is the fresh-host bootstrap layer for this repo.

It exists to solve a different problem than `scripts/`:

- `scripts/` are the day-to-day maintenance helpers for the current live Oracle
  server.
- `bootstrap/` is the reproducible setup path for someone who copied this repo
  and wants to stand up a matching deployment on another host with as little
  manual work as possible.

## Quick Start

Run:

```sh
./bootstrap/setup.sh
```

That is the default entrypoint. When only one bootstrap profile exists, the
script selects it automatically and walks through the rest.

## How Bootstrap Works

`bootstrap/setup.sh` is a coordinator. It does not contain host-specific OpenClaw
settings itself. Instead, it discovers one or more bootstrap profiles under
`bootstrap/<profile>/` and then runs the selected profile's lower-level scripts.

The current flow is:

1. Discover bootstrap profiles.
2. Select a profile automatically if there is only one.
3. If multiple profiles exist, prompt for the profile unless `--profile` was
   provided.
4. Resolve the matching build tree from `build/<profile>/`.
5. Ensure local prerequisites exist: `bash`, `ssh`, `tar`, and `python3`.
6. Create `.secrets/<profile>.env` from `build/<profile>/secrets.example.env`
   if the file does not exist yet.
7. Fill missing secrets:
   required values must be provided;
   optional values may be left blank;
   matching exported environment variables are used automatically before any
   prompt.
8. Ask for the target SSH host if `--host` was not provided.
9. If the host is given without a user, prefix the tracked `OPENCLAW_HOST_USER`
   from the build env template.
10. Probe SSH connectivity before doing any real apply work.
11. Print a summary and ask for confirmation unless `--yes` was used.
12. Delegate to the profile-specific render/apply helper.
13. Run `status` and `health` verification unless `--skip-verify` was used.

## Directory Contract

Each bootstrap profile lives in `bootstrap/<profile>/`.

For `setup.sh` to treat a directory as a valid profile, it must contain:

- `render-build-state.sh`
- `apply-build-host.sh`

The matching build tree is expected at:

- `build/<profile>/rootfs/`
- `build/<profile>/secrets.example.env`

Current profile:

- `oracle.ylioo.com/`: bootstrap path for reproducing the current Oracle
  OpenClaw deployment shape on another host.

## Interactive Usage

The normal end-user path is:

```sh
./bootstrap/setup.sh
```

In interactive mode, the script will:

- auto-select the only available profile, or ask which profile to use
- create `.secrets/<profile>.env` if needed
- prompt for any missing required secrets
- prompt for the target SSH host
- show a final summary before applying

Sensitive values such as `*_TOKEN`, `*_PASSWORD`, `*_SECRET`, and `*_API_KEY`
are prompted with hidden input.

## Non-Interactive Usage

For automation, pass the required inputs explicitly:

```sh
./bootstrap/setup.sh \
  --profile oracle.ylioo.com \
  --host your-user@your-host \
  --yes \
  --non-interactive
```

In non-interactive mode:

- the script will not prompt
- required missing secrets cause a hard failure
- if multiple profiles exist, `--profile` is required
- if `--host` is omitted for a real apply, the script fails

You can preload secret values through environment variables with the same names
as the entries in `secrets.example.env`. Those values are written into the local
secrets file before apply.

Example:

```sh
export OPENCLAW_GATEWAY_PASSWORD='...'
export OPENAI_API_KEY='...'
export DISCORD_MANAGER_TOKEN='...'

./bootstrap/setup.sh \
  --profile oracle.ylioo.com \
  --host oracle-clone \
  --yes \
  --non-interactive
```

If `--host oracle-clone` is used and the tracked build says
`OPENCLAW_HOST_USER=suguan`, the script will actually connect to
`suguan@oracle-clone`.

## Common Modes

Render only:

```sh
./bootstrap/setup.sh --render-only
```

Render only with explicit profile and secrets file:

```sh
./bootstrap/setup.sh \
  --profile oracle.ylioo.com \
  --secrets-file .secrets/oracle.ylioo.com.env \
  --render-only
```

Apply but skip post-apply verification:

```sh
./bootstrap/setup.sh --host <ssh-host> --skip-verify
```

Use a non-default secrets file:

```sh
./bootstrap/setup.sh \
  --profile oracle.ylioo.com \
  --host <ssh-host> \
  --secrets-file /path/to/local.env
```

## Lower-Level Entry Points

`setup.sh` is the intended user-facing command, but the profile helpers are
still available when you want more control.

For the Oracle profile:

- `bootstrap/oracle.ylioo.com/render-build-state.sh`
- `bootstrap/oracle.ylioo.com/apply-build-host.sh`
- `bootstrap/oracle.ylioo.com/host-openclaw.sh`

Those scripts are useful when:

- you want to debug the staged render output separately from apply
- you want to rerun verification commands against a host that was already set up
- you want to call a profile helper directly from another wrapper

## What Bootstrap Does Not Replace

`bootstrap/` does not replace the current live-host maintenance workflow.

These remain separate on purpose:

- `scripts/oracle-openclaw.sh`
- `scripts/apply-build-host.sh`
- `scripts/render-build-state.sh`

That separation is intentional so we can improve first-time setup without
accidentally changing the daily operational path for the live Oracle server.

## Adding Another Bootstrap Profile

To add another bootstrap target, create:

- `bootstrap/<profile>/render-build-state.sh`
- `bootstrap/<profile>/apply-build-host.sh`
- optionally `bootstrap/<profile>/host-openclaw.sh`
- `build/<profile>/rootfs/`
- `build/<profile>/secrets.example.env`

Once those files exist, `./bootstrap/setup.sh` will discover the new profile
automatically.
