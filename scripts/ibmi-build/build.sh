#!/bin/bash
#
# Builds the ibmi reference app's demo library and packages it as a save file
# (cfdemo), optionally tagging coderflow-reference-apps and publishing a GitHub
# release with the save file attached.
#
# Runs on IBM i (builds locally) or on a Unix-like system (builds remotely over
# SSH). codermake handles its own connection; the other IBM i steps are routed
# through ibmi_bash, which runs locally on IBM i and over SSH elsewhere.

set -e
thisDir=$(cd -P "$(dirname "$0")" && pwd)     # scripts/ibmi-build
repoRoot=$(cd -P "$thisDir/../.." && pwd)      # coderflow-reference-apps
appDir="$repoRoot/ibmi"                        # the reference app built here
OWNER_REPO="ProfoundLogic/coderflow-reference-apps"
TAG_PREFIX="ibmi/"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [--publish] [--major|--minor|--patch] [--version X.Y.Z]

Builds the ibmi demo library and save file from ${appDir} in place (no clone).
By default this is a dry run: nothing is pushed to GitHub, so the library and
save file can be inspected. Pass --publish to create the tag/release on
${OWNER_REPO} and upload the save file.

  --publish          Create the GitHub tag + release and upload the save file

Version selection (only used with --publish; default: --patch):
  --major            Bump the major component of the latest tag (X.0.0)
  --minor            Bump the minor component of the latest tag (x.Y.0)
  --patch            Bump the patch component of the latest tag (x.y.Z)
  --version X.Y.Z    Use this exact version instead of bumping

Tags are prefixed: the release for version X.Y.Z is tagged ${TAG_PREFIX}vX.Y.Z.
If no ${TAG_PREFIX} version tags exist yet, the first release is ${TAG_PREFIX}v1.0.0.

Environment variables (may also be set in a .env file next to this script;
real environment variables take precedence over .env):
  IBMI_BUILD_LIBRARY  Work library to build into (required; rebuilt from scratch)
  GITHUB_TOKEN        Token with write access, required with --publish
                      (GH_TOKEN also accepted)

On a Unix-like system (remote build over SSH) these are also required so
codermake and the direct IBM i steps can reach the host:
  IBMI_HOST           IBM i host name
  IBMI_USER           IBM i user profile
  IBMI_KEY            Path to SSH private key (optional; else system SSH config)
EOF
}

# Parse command-line arguments.
BUMP=patch
VERSION=""
PUBLISH=false
while [ $# -gt 0 ]; do
  case "$1" in
    --publish) PUBLISH=true ;;
    --major) BUMP=major ;;
    --minor) BUMP=minor ;;
    --patch) BUMP=patch ;;
    --version) shift; VERSION="$1" ;;
    --version=*) VERSION="${1#--version=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

# Load variables (e.g. GITHUB_TOKEN, IBMI_BUILD_LIBRARY, IBMI_*) from a .env file if
# present. Values already set in the environment take precedence over the file.
envFile="$thisDir/.env"
if [ -f "$envFile" ]; then
  while IFS='=' read -r key value || [ -n "$key" ]; do
    case "$key" in ''|\#*) continue ;; esac
    key=${key// /}
    [ -z "$key" ] && continue
    # Strip one layer of surrounding single or double quotes from the value.
    value=${value%\"}; value=${value#\"}
    value=${value%\'}; value=${value#\'}
    if [ -z "${!key:-}" ]; then
      export "$key=$value"
    fi
  done < "$envFile"
fi

if [ -z "${IBMI_BUILD_LIBRARY:-}" ]; then
  echo "Required environment variable IBMI_BUILD_LIBRARY is not set" >&2
  exit 1
fi
# Export it so codermake (which reads IBMI_BUILD_LIBRARY off IBM i) inherits it.
export IBMI_BUILD_LIBRARY

# --- Platform abstraction -------------------------------------------------
# On IBM i (uname -s = OS400) the IBM i commands run in a local shell; on any
# other platform they run over SSH. codermake follows the same split via its
# own environment variables (BUILD_LIBRARY vs IBMI_BUILD_LIBRARY + IBMI_HOST...).
PLATFORM=$(uname -s)
is_ibmi() { [ "$PLATFORM" = "OS400" ]; }

sshArgs=()
CONTROL_PATH=""
if ! is_ibmi; then
  if [ -z "${IBMI_HOST:-}" ] || [ -z "${IBMI_USER:-}" ]; then
    echo "On $PLATFORM, IBMI_HOST and IBMI_USER are required (SSH target for" >&2
    echo "codermake and the IBM i build steps)." >&2
    exit 1
  fi
  # Mirror codermake: use IBMI_KEY if given, else the system SSH configuration.
  [ -n "${IBMI_KEY:-}" ] && sshArgs+=(-i "$IBMI_KEY")
  # Multiplex every ssh/scp this script runs through ONE shared master
  # connection. IBM i's sshd resets a burst of simultaneous connections during
  # key exchange ("kex_exchange_identification: Connection reset by peer"); a
  # single reused connection avoids that. codermake does its own multiplexing
  # separately, so this only governs this script's connections. The control
  # socket is per-process and git-ignored.
  CONTROL_PATH="$thisDir/.ssh-cm.$$"
  sshArgs+=(-o "ControlPath=$CONTROL_PATH")
fi

# Open the shared SSH master up front so every later ssh/scp reuses it; close it
# on exit. Both are no-ops on IBM i (where nothing goes over SSH).
start_ssh_master() {
  is_ibmi && return 0
  ssh "${sshArgs[@]}" -o ControlMaster=yes -o ControlPersist=600 -fN "$IBMI_USER@$IBMI_HOST"
}
stop_ssh_master() {
  { [ -n "$CONTROL_PATH" ] && [ -S "$CONTROL_PATH" ]; } || return 0
  ssh "${sshArgs[@]}" -O exit "$IBMI_USER@$IBMI_HOST" >/dev/null 2>&1 || true
}

# Run a bash script (read from stdin) on IBM i. Any arguments are passed to the
# remote script as $1, $2, ...  This is ONE shell per call, so state set early
# in the script — notably `liblist` — is inherited by everything after it.
ibmi_bash() { # ibmi_bash [arg ...]  <<'EOF' ... EOF
  if is_ibmi; then
    /QOpenSys/pkgs/bin/bash -s -- "$@"
  else
    ssh "${sshArgs[@]}" "$IBMI_USER@$IBMI_HOST" /QOpenSys/pkgs/bin/bash -s -- "$@"
  fi
}

# Copy a local file onto the IBM i IFS (cp locally, scp over SSH).
ibmi_put() { # ibmi_put <local-src> <ibmi-abs-dest>
  if is_ibmi; then
    mkdir -p "$(dirname "$2")"
    cp "$1" "$2"
  else
    ssh "${sshArgs[@]}" "$IBMI_USER@$IBMI_HOST" "mkdir -p '$(dirname "$2")'"
    scp -q "${sshArgs[@]}" "$1" "$IBMI_USER@$IBMI_HOST:$2"
  fi
}

# Copy a file from the IBM i IFS back to the local machine.
ibmi_get() { # ibmi_get <ibmi-abs-src> <local-dest>
  if is_ibmi; then
    cp "$1" "$2"
  else
    scp -q "${sshArgs[@]}" "$IBMI_USER@$IBMI_HOST:$1" "$2"
  fi
}

# Staging area on the IBM i IFS for files this script must hand to IBM i (the
# demo-data SQL, the resave source, and the outgoing save file). On IBM i this
# is a local IFS path; on Linux it lives on the remote host. A unique per-run
# directory keeps concurrent builds from colliding and leaves no shared name
# behind; it is always removed on exit (success or failure) by cleanup.
if command -v uuidgen >/dev/null 2>&1; then
  runId=$(uuidgen)
elif [ -r /proc/sys/kernel/random/uuid ]; then
  runId=$(cat /proc/sys/kernel/random/uuid)
else
  runId="$$-$RANDOM-$RANDOM"
fi
STAGE="/tmp/cfdemo-build-$runId"
STAGED=false   # set true once anything is written to STAGE, so cleanup only
               # reaches out to IBM i when there is actually something to remove.
cleanup() {
  if $STAGED; then
    ibmi_bash "$STAGE" >/dev/null 2>&1 <<'EOF' || true
rm -rf "$1"
EOF
  fi
  stop_ssh_master
}
trap 'exit 130' INT TERM   # turn a signal into a normal exit so the EXIT trap runs
trap cleanup EXIT

# Establish the shared SSH master before any other connection (no-op on IBM i).
start_ssh_master

# --- Publishing details (validated up front so a bad token/version fails fast
# --- rather than after the long build). --------------------------------------
if $PUBLISH; then
  : "${GITHUB_TOKEN:=${GH_TOKEN:-}}"
  if [ -z "$GITHUB_TOKEN" ]; then
    echo "Required environment variable GITHUB_TOKEN (or GH_TOKEN) is not set" >&2
    exit 1
  fi

  # Verify the token actually authenticates (not just that it's non-empty), so a
  # bad or expired token fails here with a clear message instead of surfacing a
  # bare "curl: ... 401" from the first API call partway through publishing.
  authStatus=$(curl -sS -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${OWNER_REPO}") \
    || { echo "Could not reach the GitHub API to verify credentials." >&2; exit 1; }
  case "$authStatus" in
    200) ;;
    401) echo "GitHub rejected GITHUB_TOKEN (HTTP 401): the token is set but invalid or expired." >&2; exit 1 ;;
    403) echo "GitHub returned HTTP 403 for ${OWNER_REPO}: the token lacks access, or you are rate-limited." >&2; exit 1 ;;
    404) echo "GitHub returned HTTP 404 for ${OWNER_REPO}: repo not found, or the token cannot see it." >&2; exit 1 ;;
    *)   echo "Unexpected GitHub API status $authStatus while verifying credentials for ${OWNER_REPO}." >&2; exit 1 ;;
  esac

  # Determine the version to release.
  if [ -n "$VERSION" ]; then
    newVersion="v${VERSION#v}"
    if ! echo "${newVersion#v}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
      echo "Invalid --version '$VERSION' (expected X.Y.Z)" >&2
      exit 1
    fi
  else
    # Find the highest existing ibmi/-prefixed semver tag and bump it. Only tags
    # under the ibmi/ prefix are considered, so releases of other apps in this
    # repo never affect the ibmi version.
    tagsJson=$(curl -fsS \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${OWNER_REPO}/tags?per_page=100")
    latest=$(printf '%s' "$tagsJson" \
      | grep -o '"name": *"[^"]*"' \
      | sed 's/.*"name": *"//; s/"$//' \
      | grep -E "^${TAG_PREFIX}v?[0-9]+\.[0-9]+\.[0-9]+$" \
      | sed "s#^${TAG_PREFIX}##; s/^v//" \
      | sort -V \
      | tail -1)
    if [ -z "$latest" ]; then
      newVersion="v1.0.0"
    else
      IFS=. read -r major minor patch <<< "$latest"
      case "$BUMP" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
      esac
      newVersion="v${major}.${minor}.${patch}"
    fi
  fi
  newTag="${TAG_PREFIX}${newVersion}"
  echo "Publishing $newTag"
else
  echo "Dry run: building only (pass --publish to create a GitHub release)"
fi

# Read the target release from the app's codermake config.
configFile="$appDir/.codermake/config.json"
targetRelease=$(jq -r '.targetRelease // empty' "$configFile")
if [ -z "$targetRelease" ]; then
  echo "Could not read targetRelease from $configFile" >&2
  exit 1
fi

# Stage the demo-data SQL and the resave source onto the IBM i IFS.
STAGED=true
for f in "$thisDir/data/"*; do
  ibmi_put "$f" "$STAGE/data/$(basename "$f")"
done
ibmi_put "$thisDir/utils/resave.cpp" "$STAGE/resave.cpp"

# Recreate the work library from scratch. Also clear codermake's local build
# state (build/, tmp/): it tracks built targets with local marker files, so an
# in-place rebuild would otherwise treat the just-deleted library's objects as
# up to date and do nothing ("make: Nothing to be done for 'all'").
echo "==> Recreating library $IBMI_BUILD_LIBRARY..."
rm -rf "$appDir/build" "$appDir/tmp"
ibmi_bash "$IBMI_BUILD_LIBRARY" <<'EOF'
export PATH=/QOpenSys/pkgs/bin:/usr/bin:/QOpenSys/usr/bin:$PATH
system "dltlib $1" </dev/null >/dev/null 2>&1 || true
EOF

echo "==> Building $appDir with codermake..."
cd "$appDir"
if is_ibmi; then
  # On IBM i codermake reads BUILD_LIBRARY; elsewhere it reads IBMI_BUILD_LIBRARY
  # (already exported below), so a plain invocation suffices off-platform.
  BUILD_LIBRARY="$IBMI_BUILD_LIBRARY" codermake
else
  codermake
fi
cd "$thisDir"

# Populate the demo data. liblist and the runsqlstm calls MUST share one shell:
# liblist sets the library list for this shell, which the runsqlstm children
# inherit so the unqualified table names in the SQL resolve to $IBMI_BUILD_LIBRARY.
# runsqlstm output is squelched on success and shown only if a load fails.
echo "==> Loading demo data..."
ibmi_bash "$IBMI_BUILD_LIBRARY" "$STAGE" <<'EOF'
export PATH=/QOpenSys/pkgs/bin:/usr/bin:/QOpenSys/usr/bin:$PATH
set -e
liblist -af "$1"
for f in "$2"/data/*; do
  out=$(system "runsqlstm srcstmf('$f') commit(*none) naming(*sys)" </dev/null 2>&1) || {
    echo "runsqlstm failed for $(basename "$f"):" >&2
    printf '%s\n' "$out" >&2
    exit 1
  }
done
EOF

# Remove source physical files from the library before saving.
echo "==> Removing source physical files..."
ibmi_bash "$IBMI_BUILD_LIBRARY" <<'EOF'
export PATH=/QOpenSys/pkgs/bin:/usr/bin:/QOpenSys/usr/bin:$PATH
set -e
LIB="$1"
sql="select table_name from qsys2.systables where table_schema = ucase('$LIB') and file_type = 'S'"
qsh -c "db2 \"$sql\"" </dev/null \
  | awk '/^-+$/ {start=1; next} start { if (!NF) exit; sub(/ +$/,""); print }' \
  | while IFS= read -r tbl; do
      system "dltf $LIB/$tbl" </dev/null
    done
EOF

# Compile the resave helper, create the save file, save the library objects
# targeting the configured release, then downgrade-resave via QTEMP.
echo "==> Saving objects to $IBMI_BUILD_LIBRARY/cfdemo (target release $targetRelease)..."
ibmi_bash "$IBMI_BUILD_LIBRARY" "$STAGE" "$targetRelease" <<'EOF'
export PATH=/QOpenSys/pkgs/bin:/usr/bin:/QOpenSys/usr/bin:$PATH
set -e
LIB="$1"; STAGE="$2"; TGT="$3"
# Every command reads from /dev/null: this script is fed to `bash -s` on stdin,
# and some IBM i commands (notably the crtbndcpp compiler) read stdin and would
# otherwise drain the rest of this script, silently skipping the later steps.
system "crtbndcpp pgm($LIB/resave) srcstmf('$STAGE/resave.cpp') dbgview(*all)" </dev/null
system "crtsavf $LIB/cfdemo" </dev/null
system "savobj obj(*all) objtype(*all) lib($LIB) dev(*savf) savf($LIB/cfdemo) dtacpr(*high) tgtrls($TGT) omitobj((resave *pgm) (cfdemo *file))" </dev/null
qsh -c "/qsys.lib/$LIB.lib/resave.pgm $LIB $LIB cfdemo $TGT qpgmr" </dev/null || { system "dltf $LIB/cfdemo" </dev/null; exit 1; }
EOF

if ! $PUBLISH; then
  echo "Dry run complete: library $IBMI_BUILD_LIBRARY built and save file $IBMI_BUILD_LIBRARY/cfdemo created."
  echo "Re-run with --publish to create the GitHub release."
  exit 0
fi

# Copy the save file out to a stream file on the IBM i IFS, then fetch it here.
ibmi_bash "$IBMI_BUILD_LIBRARY" "$STAGE" <<'EOF'
export PATH=/QOpenSys/pkgs/bin:/usr/bin:/QOpenSys/usr/bin:$PATH
set -e
system "cpytostmf frommbr('/qsys.lib/$1.lib/cfdemo.file') tostmf('$2/cfdemo.savf') stmfopt(*replace) cvtdta(*none)" </dev/null
EOF
savfLocal="$thisDir/cfdemo.savf"
rm -f "$savfLocal"
ibmi_get "$STAGE/cfdemo.savf" "$savfLocal"

# Create the tag + GitHub release, pointing the tag at the commit being built.
commit=$(git -C "$repoRoot" rev-parse HEAD)
body="Automated build of $newTag ($commit)."
payload=$(printf '{"tag_name":"%s","target_commitish":"%s","name":"%s","body":"%s"}' \
  "$newTag" "$commit" "$newTag" "$body")
# No -f here: on an HTTP error we want GitHub's JSON (which explains why, e.g.
# a tag that already exists) rather than curl's terse status line.
releaseJson=$(curl -sS -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${OWNER_REPO}/releases" \
  -d "$payload")
releaseId=$(printf '%s' "$releaseJson" | grep -o '"id": *[0-9]*' | head -1 | sed 's/[^0-9]//g')
if [ -z "$releaseId" ]; then
  echo "Failed to create release $newTag on ${OWNER_REPO}. GitHub responded:" >&2
  echo "$releaseJson" >&2
  exit 1
fi

# Upload the save file as a release asset.
if ! curl -fsS -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"$savfLocal" \
  "https://uploads.github.com/repos/${OWNER_REPO}/releases/${releaseId}/assets?name=cfdemo.savf" > /dev/null; then
  echo "Release $newTag was created but uploading cfdemo.savf failed." >&2
  exit 1
fi

echo "Released $newTag with asset cfdemo.savf"

# The tag was created server-side via the API, so nothing was tagged locally.
# Fetch just this tag so it shows up in the local repository.
if git -C "$repoRoot" fetch --quiet origin "refs/tags/${newTag}:refs/tags/${newTag}" 2>/dev/null; then
  echo "Fetched tag $newTag into the local repository."
else
  echo "Note: tag $newTag exists on the remote; run 'git fetch --tags' to pull it locally." >&2
fi
