# ibmi-build — maintainer tooling

**Not a reference app.** This builds the [`ibmi`](../../ibmi) reference app's demo
library on IBM i, packages it as a save file (`cfdemo`), and optionally tags
`coderflow-reference-apps` and publishes a GitHub release with the save file
attached. It lives under `scripts/` (alongside `generate.sh`) so it stays out of
the `ibmi/` app directory — which CoderFlow imports and syncs to IBM i verbatim —
and out of the environment-import and generation paths.

## What the build does

Running `build.sh` (from this directory):

1. Recreates the work library named by `$IBMI_BUILD_LIBRARY` and builds `../../ibmi` into it
   with `codermake` (in place — no clone).
2. Loads the demo data by running the SQL scripts in `data/`.
3. Deletes the source physical files from the library.
4. Compiles `utils/resave.cpp` and saves all objects into a save file,
   `$IBMI_BUILD_LIBRARY/cfdemo`, targeting the release from `../../ibmi/.codermake/config.json`
   (`targetRelease`).

With `--publish`, it then copies the save file off IBM i, creates the tag and
GitHub release, and uploads `cfdemo.savf` as an asset. Tags are **prefixed**:
version `X.Y.Z` is tagged `ibmi/vX.Y.Z`, so the `ibmi` app versions independently
of anything else in this repo.

## Where it runs: IBM i or Linux/macOS

`codermake` builds on IBM i directly or from a Unix-like system over SSH, and this
script does the same for its other IBM i work (recreating the library, loading
data, compiling `resave`, saving). The platform is detected with `uname -s`
(`OS400` = IBM i):

- **On IBM i** — every IBM i command runs in a local shell. Set `BUILD_LIBRARY`
  is handled for you from `IBMI_BUILD_LIBRARY`.
- **On Linux/macOS** — IBM i commands run over SSH via `/QOpenSys/pkgs/bin/bash`
  (Bash is required and is not always a user's default shell). codermake connects
  using `IBMI_HOST` / `IBMI_USER` / `IBMI_KEY`; the direct steps reuse the same
  host/user/key. Authentication is SSH-key based (key from `IBMI_KEY`, else the
  system SSH configuration) — no password. To avoid a burst of connections that
  IBM i's sshd would reset during key exchange, the script opens a single shared
  SSH master connection up front and routes all its `ssh`/`scp` through it
  (control socket `./.ssh-cm.<pid>`, git-ignored, closed on exit). codermake does
  its own multiplexing independently.

The demo-data SQL and `resave.cpp` are staged to a unique per-run working
directory on the IBM i IFS (`/tmp/cfdemo-build-<uuid>`) so the remote commands
can reach them; the finished `cfdemo.savf` is copied back before upload. The
staging directory is always removed on exit, whether the build succeeds or
fails.

## Requirements

- `codermake` (`npm i -g @profoundlogic/codermake`), `git`, `curl`, `jq` on
  `PATH` of the machine you run this from.
- On Linux/macOS: `ssh`/`scp`, and key-based SSH access to the IBM i host.
- A work library name (`IBMI_BUILD_LIBRARY`). **Its contents are destroyed and rebuilt.**
- To publish: a GitHub token with write access to `ProfoundLogic/coderflow-reference-apps`.

## Configuration

Settings come from environment variables, which may also be placed in a `.env`
file next to `build.sh`. Real environment variables take precedence over `.env`.

| Variable             | Required             | Description                                         |
| -------------------- | -------------------- | --------------------------------------------------- |
| `IBMI_BUILD_LIBRARY` | always               | Work library to build into (rebuilt from scratch).  |
| `GITHUB_TOKEN`       | with `--publish`     | Token with write access (`GH_TOKEN` also accepted). |
| `IBMI_HOST`          | off IBM i            | IBM i host name (SSH).                               |
| `IBMI_USER`          | off IBM i            | IBM i user profile (SSH).                            |
| `IBMI_KEY`           | optional (off IBM i) | SSH private key; else system SSH config.            |

Copy `.env.example` to `.env` and fill it in. `.env` is git-ignored so your token
is never committed.

## Usage

```
./build.sh [--publish] [--major|--minor|--patch] [--version X.Y.Z]
```

By default the script is a **dry run**: it builds the library and save file but
does not touch GitHub. No token is needed for a dry run.

### Version selection (only with `--publish`)

The version is derived from the latest `ibmi/`-prefixed semver tag in this repo:

- `--patch` *(default)* — `ibmi/v1.2.3` → `ibmi/v1.2.4`
- `--minor` — `ibmi/v1.2.3` → `ibmi/v1.3.0`
- `--major` — `ibmi/v1.2.3` → `ibmi/v2.0.0`
- `--version X.Y.Z` — use an exact version instead of bumping

If no `ibmi/` version tags exist yet, the first release is `ibmi/v1.0.0`. The tag
points at the currently checked-out commit of this repo.

### Examples

```sh
# Dry run — build and inspect only
./build.sh

# First release (no ibmi/ tags exist yet)
./build.sh --publish --version 1.0.0

# Publish a patch release (e.g. ibmi/v1.0.0 -> ibmi/v1.0.1)
./build.sh --publish
```

## Output

- `$IBMI_BUILD_LIBRARY/cfdemo` — the save file object on IBM i.
- `cfdemo.savf` — the save file copied here (only when publishing; git-ignored).
- A GitHub release with the `cfdemo.savf` asset (only when publishing).
