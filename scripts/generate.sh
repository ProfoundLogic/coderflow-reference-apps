#!/usr/bin/env bash
#
# CoderFlow reference-apps generator — MAINTAINER TOOLING, not a reference app.
#
# Assembles every backend × front-end combo from the hand-authored templates in
# templates/. Each combo is a self-contained, two-process "hello world":
#
#   <combo>/
#     api/               # backend serving GET /api/hello on 0.0.0.0:3001
#     web/               # front-end dev server, proxies /api -> :3001
#     environment.json   # importable CoderFlow environment, preconfigured to launch
#     AGENTS.md          # per-environment agent instructions (imported as CLAUDE.md)
#     README.md          # how to run it
#
# The committed combos are the source of truth that CoderFlow clones; this
# script reproduces them so adding/refreshing a combo is a one-command change.
#
# The generated environment.json is turnkey: it carries the pre-clone runtime
# install (docker_config.pre_clone_instructions), the post-clone dependency
# install (repo post_clone_action), and the application server(s) (ports,
# launch_urls, start_command). Importing a combo and launching it just works.
#
# Usage:
#   scripts/generate.sh            # regenerate all combos
#   scripts/generate.sh <combo>    # regenerate one (e.g. node-react)
#
# Env:
#   OUT_DIR    Output root (default: repo root). Set to a temp dir to test.
#   REPO_URL   Repo URL written into environment.json (default: the public repo).
#
# Requires: jq (used to emit valid JSON for the environment files).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT}"
TPL="$ROOT/templates"
REPO_URL="${REPO_URL:-https://github.com/ProfoundLogic/coderflow-reference-apps}"

# Where CoderFlow clones this repo inside the container. Start/install commands
# in environment.json use absolute paths under here so they run from anywhere.
REPO_ROOT="/workspace/coderflow-reference-apps"

command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }

# Backend metadata.
declare -A BE_DIR=( [node]=node [dotnet]=dotnet [java]=java [python]=python [php]=php )
declare -A BE_LABEL=( [node]="Node.js" [dotnet]=".NET" [java]="Java" [python]="Python" [php]="PHP" )
declare -A BE_RUNTIME=(
  [node]="Node.js 20 (npm)"
  [dotnet]=".NET 8 SDK"
  [java]="JDK 17 + Maven"
  [python]="Python 3.11 (pip)"
  [php]="PHP 8.2"
)
# Restore/build the backend's dependencies (bare command, run in api/).
# Empty = nothing to build (PHP runs from source).
declare -A BE_RESTORE=(
  [node]="npm install"
  [dotnet]="dotnet restore"
  [java]="mvn -q -DskipTests package"
  # --break-system-packages: the base image's Python is PEP 668 "externally
  # managed", which blocks a system-wide pip install. Safe in a disposable
  # container; locally you'd use a virtualenv instead.
  [python]="pip install --break-system-packages -r requirements.txt"
  [php]=""
)
# Start the backend API on 0.0.0.0:3001 in watch/reload mode (bare command, run
# in api/), so the managed app server reloads on code changes — the agent never
# has to kill and restart it. PHP's built-in server already re-reads per request.
declare -A BE_RUN=(
  [node]="node --watch index.js"
  [dotnet]="dotnet watch run"
  [java]="mvn -q spring-boot:run"
  [python]="uvicorn main:app --host 0.0.0.0 --port 3001 --reload"
  [php]="php -S 0.0.0.0:3001 router.php"
)

# How each backend picks up a code change (used in AGENTS.md). The phrasing is
# per-stack because Java needs an explicit recompile to trigger the restart.
declare -A BE_RELOAD_NOTE=(
  [node]="the API runs under \`node --watch\`, so saving a backend file restarts it automatically."
  [dotnet]="the API runs under \`dotnet watch\`, so saving a backend file rebuilds and restarts it automatically."
  [java]="the API runs with Spring DevTools. After editing a backend file, run \`mvn -q -o compile\` in \`api/\` and DevTools restarts the running API in place — don't kill and re-run it yourself."
  [python]="the API runs under \`uvicorn --reload\`, so saving a backend file restarts it automatically."
  [php]="the PHP built-in server re-reads files per request, so backend changes show on the next request — no restart needed."
)
# Pre-clone runtime install (raw Dockerfile). Empty = already in the base image
# (Node.js and Python are; .NET/Java/PHP are installed here).
declare -A BE_PRECLONE=(
  [node]=""
  [python]=""
  [dotnet]=$'RUN curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh && bash /tmp/dotnet-install.sh --channel 8.0 --install-dir /usr/local/dotnet && ln -sf /usr/local/dotnet/dotnet /usr/local/bin/dotnet && rm /tmp/dotnet-install.sh\nENV DOTNET_ROOT=/usr/local/dotnet'
  [java]="RUN apt-get update && apt-get install -y default-jdk maven && rm -rf /var/lib/apt/lists/*"
  [php]="RUN apt-get update && apt-get install -y php-cli && rm -rf /var/lib/apt/lists/*"
)

# Deploy-profile build metadata (per backend), used by render_deploy_profile to
# build and package a real release artifact for the combo's API. Values are
# single-line and substituted into deploy.sh (so they avoid '&', '#', '\').
#   BUILD   bare command, run inside ( cd api ; ... ) — builds/restores the API.
#   PACKAGE copies the API's deployable bits into release/api/ (run from app dir).
#   ARTIFACT short human description of what that artifact is.
#   START   how the API would be started on the target (shown in the log).
declare -A BE_DEPLOY_BUILD=(
  [node]="npm ci --omit=dev --no-audit --no-fund"
  [dotnet]="DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_GENERATE_ASPNET_CERTIFICATE=false dotnet publish -c Release -o publish"
  [java]="mvn -q -DskipTests package"
  [python]="pip install --break-system-packages -r requirements.txt -t vendor"
  [php]="echo '    (PHP runs from source - nothing to build)'"
)
declare -A BE_DEPLOY_PACKAGE=(
  [node]="cp -R api/index.js api/package.json api/package-lock.json api/node_modules release/api/"
  [dotnet]="cp -R api/publish/. release/api/"
  [java]="cp api/target/*.jar release/api/app.jar"
  [python]="cp -R api/main.py api/requirements.txt api/vendor release/api/"
  [php]="cp -R api/. release/api/"
)
declare -A BE_DEPLOY_ARTIFACT=(
  [node]="index.js + production node_modules"
  [dotnet]="framework-dependent publish output"
  [java]="the Spring Boot executable jar"
  [python]="source + vendored dependencies"
  [php]="source files (runs as-is)"
)
declare -A BE_DEPLOY_START=(
  [node]="node index.js"
  [dotnet]="dotnet Api.dll"
  [java]="java -jar app.jar"
  [python]="PYTHONPATH=vendor uvicorn main:app --host 0.0.0.0 --port 3001"
  [php]="php -S 0.0.0.0:3001 router.php"
)

# Front-end metadata.
declare -A FE_LABEL=( [angular]="Angular" [react]="React" [vue]="Vue" )
# Start the front-end dev server (bare command, run in web/). Each template's
# start script already binds 0.0.0.0 and proxies /api -> :3001.
declare -A FE_RUN=( [angular]="npm start" [react]="npm run dev" [vue]="npm run dev" )
declare -A FE_PORT=( [angular]="4200" [react]="5173" [vue]="5173" )

BACKENDS=(node dotnet java python php)
FRONTENDS=(angular react vue)

log() { printf '  %s\n' "$*"; }

# emit_env_json OUT IMAGE DESC PRECLONE POST_CLONE_ACTION SERVER_NAME START PORTS_JSON LAUNCH_JSON [FEEDBACK_WIDGET_JSON] [DEPLOYMENT_PROFILE_ORDER_JSON]
# Writes a complete, importable environment.json. PRECLONE and POST_CLONE_ACTION
# may be empty (then their keys are omitted). PORTS_JSON/LAUNCH_JSON are JSON arrays.
# FEEDBACK_WIDGET_JSON (optional) is a JSON object merged into application_server —
# used to enable auto-refresh-on-complete for environments with no live reload
# (static, php-html). Omit it (defaults to null) everywhere else.
# DEPLOYMENT_PROFILE_ORDER_JSON (optional) is a JSON array of deploy-profile names
# (e.g. ["deploy"]); when set it adds deployment_profile_order. Omit (null) when the
# environment carries no deploy profiles.
emit_env_json() {
  local out="$1" image="$2" desc="$3" preclone="$4" pca="$5" sname="$6" start="$7" ports="$8" launch="$9" fb="${10:-null}" dpo="${11:-null}"

  local repo
  repo=$(jq -n --arg url "$REPO_URL" --arg pca "$pca" \
    '{ name: "coderflow-reference-apps", url: $url, branch: "main", allow_branch_selection: true, clone_auto: true }
     | if $pca != "" then . + { post_clone_action: $pca } else . end')

  jq -n \
    --arg image "$image" \
    --arg desc "$desc" \
    --arg preclone "$preclone" \
    --arg sname "$sname" \
    --arg start "$start" \
    --argjson repo "$repo" \
    --argjson ports "$ports" \
    --argjson launch "$launch" \
    --argjson fb "$fb" \
    --argjson dpo "$dpo" \
    '{ image_name: $image, default_agent: "claude", description: $desc }
     + (if $preclone != "" then { docker_config: { pre_clone_instructions: $preclone, post_clone_instructions: "" } } else {} end)
     + { repos: [ $repo ],
         application_server: (
           {
             enabled: true,
             name: $sname,
             ports: $ports,
             launch_urls: $launch,
             start_command: $start
           }
           + (if $fb != null then { feedback_widget: $fb } else {} end)
         ),
         standardInstructions: { outputRequirements: true } }
     + (if $dpo != null then { deployment_profile_order: $dpo } else {} end)' \
    > "$out"
}

render_combo() {
  local be="$1" fe="$2"
  local combo="${be}-${fe}"
  local dest="$OUT_DIR/$combo"

  rm -rf "$dest"
  mkdir -p "$dest"
  cp -R "$TPL/backends/${BE_DIR[$be]}/." "$dest/api/"
  cp -R "$TPL/frontends/$fe/." "$dest/web/"

  local be_label="${BE_LABEL[$be]}" fe_label="${FE_LABEL[$fe]}"
  local fe_port="${FE_PORT[$fe]}"

  # Deploy-profile demo: every combo carries a reference Deploy Profile so the
  # imported environment shows the deploy flow end to end (see render_deploy_profile).
  local dpo_json='["deploy"]'

  # post-clone: install backend deps (if any), then front-end deps.
  local pca=""
  if [ -n "${BE_RESTORE[$be]}" ]; then
    pca="cd $REPO_ROOT/$combo/api && ${BE_RESTORE[$be]}"$'\n'
  fi
  pca+="cd $REPO_ROOT/$combo/web && npm install"

  # start: API in the background, then the front-end dev server in the foreground.
  local start="cd $REPO_ROOT/$combo/api && ${BE_RUN[$be]} &"$'\n'"cd $REPO_ROOT/$combo/web && ${FE_RUN[$fe]}"

  local ports_json="[{\"internal\":${fe_port},\"name\":\"web\"},{\"internal\":3001,\"name\":\"api\"}]"
  local launch_json="[{\"name\":\"Web\",\"path\":\"/\",\"port\":${fe_port},\"primary\":true,\"description\":\"${be_label} + ${fe_label} front end\"}]"
  local desc="Reference environment — ${be_label} API + ${fe_label} front end (two-process), preconfigured to import and launch. Clones coderflow-reference-apps and runs the ${combo} app."

  emit_env_json "$dest/environment.json" "coderflow-ref-${combo}" "$desc" \
    "${BE_PRECLONE[$be]}" "$pca" "${be_label} + ${fe_label}" "$start" "$ports_json" "$launch_json" \
    "null" "$dpo_json"

  # README install/run lines (for running the combo locally, outside CoderFlow).
  local be_install_line fe_install_line be_start_line fe_start_line
  if [ -n "${BE_RESTORE[$be]}" ]; then
    be_install_line="cd api && ${BE_RESTORE[$be]}"
  else
    be_install_line="# (the ${be_label} backend runs from source — nothing to install)"
  fi
  fe_install_line="cd web && npm install"
  be_start_line="cd api && ${BE_RUN[$be]}"
  fe_start_line="cd web && ${FE_RUN[$fe]}"

  cat > "$dest/README.md" <<MD
# ${combo} — ${be_label} + ${fe_label}

Minimal hello-world: a **${be_label}** API serving \`GET /api/hello\`, and the
**${fe_label}** front end fetches and displays it. Two-process (live reload).

## Layout

- \`api/\` — ${be_label} backend. Serves \`GET /api/hello\` → \`{"message":"Hello from the ${be_label} API!"}\` on \`0.0.0.0:3001\`.
- \`web/\` — ${fe_label} front end (source in \`web/src/\`). Renders a title, the API's message, and a **Reload from API** button. Dev server proxies \`/api\` → \`http://localhost:3001\`.
- \`environment.json\` — an importable CoderFlow environment, **preconfigured to launch**: the pre-clone runtime install, post-clone dependency install, and both application servers are already set.

## In CoderFlow (import and launch)

This environment is preconfigured — there's nothing to wire up by hand:

1. **Import Environment → Git repository**, paste this repo's URL, **Load environments**, pick \`${combo}\`, **Import**.
2. Build and launch it. The pre-clone script installs **${BE_RUNTIME[$be]}**, the post-clone action installs dependencies, and the application server starts the API (port 3001) and the ${fe_label} dev server (port ${fe_port}).

Open the launch URL — it shows "Hello from the ${be_label} API!", fetched through the dev-server proxy.

## Run it locally (two processes)

To run outside CoderFlow, install **${BE_RUNTIME[$be]}** and **Node.js** (for the front end), then:

\`\`\`sh
# 1. install dependencies
${be_install_line}
${fe_install_line}

# 2. start the API (terminal 1)
${be_start_line}

# 3. start the front end (terminal 2)
${fe_start_line}
\`\`\`

Open the front end at \`http://localhost:${fe_port}\`. The page renders a title
from ${fe_label}, the API's message ("Hello from the ${be_label} API!") fetched
through the dev-server proxy, and a **Reload from API** button. Edit the
front-end text in \`web/src/\` and save to see live reload.
MD

  # AGENTS.md — per-environment custom instructions, delivered to the agent as
  # CLAUDE.md. Imported with the environment and used as its project context.
  cat > "$dest/AGENTS.md" <<MD
# ${combo} — ${be_label} + ${fe_label} reference app

A minimal two-process "hello world" — **${be_label}** API + **${fe_label}** front
end — that fetches and displays \`GET /api/hello\`.

## Layout (under \`coderflow-reference-apps/${combo}/\`)

- \`api/\` — ${be_label} backend. Serves \`GET /api/hello\` → \`{"message":"Hello from the ${be_label} API!"}\` on \`0.0.0.0:3001\`.
- \`web/\` — ${fe_label} front end (source in \`web/src/\`). Renders a title, the API message, and a **Reload from API** button; dev server on port ${fe_port}, proxies \`/api\` to the API.

These run as **two processes** (already configured as the application server): the
API in the background, then the front-end dev server. The page shows
"Hello from the ${be_label} API!".

## Working here

- Keep the split: backend code in \`api/\`, UI in \`web/\`.
- The front end reaches the API through the \`/api\` proxy — fetch relative
  \`/api/...\` paths; don't hardcode the API origin or port.
- The API binds the port from the PORT env var (default 3001); the dev-server
  proxy targets \`http://localhost:3001\`.

## Applying changes

The application server (API + front-end dev server) is started and kept alive by
CoderFlow — it serves the live preview. **Don't kill it or start your own copy.**

- **Front-end** edits (in \`web/src/\`) hot-reload automatically — just save.
- **Back-end** edits: ${BE_RELOAD_NOTE[$be]}
- The front end re-fetches \`/api/hello\` on load, so after a back-end change the
  new value appears on the next browser refresh.

## Process lifecycle (important)

Any process you start runs only for the current session — it is **torn down when
the session ends**, and the preview will then show "Could not reach the API."
Never start a long-running server as a plain background job (\`… &\`); rely on the
managed app server's reload above instead. If you ever truly must run a durable
process yourself, fully detach it so it outlives your session:

\`\`\`sh
setsid nohup <command> > /tmp/server.log 2>&1 < /dev/null & disown
\`\`\`
MD

  render_deploy_profile "$dest" "$combo" "$be" "$fe"

  log "$combo"
}

# emit_deploy_json PDIR
# Writes the shared deploy.json (the same parameter surface for every combo) into
# a deployment-profiles dir. Flat parameter shape — each parameter is passed to
# deploy.sh as an environment variable of the same name. No secrets: the
# reference environments define none, so the profile must not require one (a
# missing required secret would block the run).
emit_deploy_json() {
  local pdir="$1"
  jq -n '{
    description: "Build a deployable release artifact from this app, then (placeholder) ship it to the chosen target. Reference profile: it genuinely builds the front end + the API into release.tgz, then prints the upload command instead of pushing — a hello-world has no real host or credentials.",
    parameters: {
      TARGET: {
        type: "select",
        label: "Target environment",
        description: "Which environment this release is for. In a real setup each target has its own host and credentials.",
        options: ["qa", "production"],
        default: "qa",
        required: true
      },
      DRY_RUN: {
        type: "boolean",
        label: "Dry run (build & package only)",
        description: "When on, build release.tgz but skip the upload step. The reference profile has no real host to ship to, so leave this on.",
        default: true
      },
      RELEASE_NOTES: {
        type: "textarea",
        label: "Release notes",
        description: "Optional notes recorded into the release bundle.",
        required: false
      }
    }
  }' > "$pdir/deploy.json"
}

# render_deploy_profile DEST COMBO BE FE
# Writes a reference Deploy Profile (deployment-profiles/deploy.{json,sh}) into a
# two-process combo so the imported CoderFlow environment demonstrates the deploy
# flow end to end. The script BUILDS a real release artifact (front-end static
# build + the API's per-stack artifact -> release.tgz) from the cloned source,
# then PRINTS the upload command instead of pushing — a hello-world has no real
# QA/Prod host or credentials, so the ship step is a clearly-labelled placeholder.
# The on-disk files ride along with the environment on git-import (the importer
# copies the whole combo dir); deployment_profile_order surfaces it in the UI.
render_deploy_profile() {
  local dest="$1" combo="$2" be="$3" fe="$4"
  local pdir="$dest/deployment-profiles"
  mkdir -p "$pdir"
  emit_deploy_json "$pdir"

  # deploy.sh — runs in a container from this environment's image, as the coder
  # user, with the repo cloned into /workspace. The @@TOKENS@@ are the only
  # generation-time substitutions (single-line, no '&'/'#'/'\'); everything else
  # is the script's own runtime.
  cat > "$pdir/deploy.sh" <<'SH'
#!/usr/bin/env bash
#
# Reference Deploy Profile — @@BE_LABEL@@ + @@FE_LABEL@@
# WHAT THIS SHOWS
#   How a CoderFlow Deploy Profile runs: in a container built from THIS
#   environment's image, with the repo cloned into /workspace, receiving each
#   profile parameter as an environment variable (TARGET, DRY_RUN, RELEASE_NOTES).
#
# WHAT IT REALLY DOES
#   Builds a genuine, deployable release artifact from the cloned source: the
#   @@FE_LABEL@@ front end (static build) plus the @@BE_LABEL@@ API
#   (@@BE_ARTIFACT@@), assembled into release.tgz.
#
# WHAT IT DELIBERATELY DOES NOT DO
#   It does not push anywhere. A hello-world has no real QA/Prod host or
#   credentials, so the upload is a clearly-labelled placeholder (see the end).
#   To make it a real deploy: add the target host + an SSH key as environment
#   Secrets (available_for: ["deploy"]) and fill in the marked block.
set -euo pipefail

APP_DIR="@@APP_DIR@@"
TARGET="${TARGET:-qa}"
DRY_RUN="${DRY_RUN:-true}"

echo "=================================================="
echo " CoderFlow reference deploy — @@BE_LABEL@@ + @@FE_LABEL@@"
echo "   Target:   ${TARGET}"
echo "   Dry run:  ${DRY_RUN}"
echo "=================================================="

cd "${APP_DIR}"

echo
echo "==> [1/3] Building the @@FE_LABEL@@ front end (static build)..."
( cd web && npm ci --no-audit --no-fund && npm run build )

echo
echo "==> [2/3] Preparing the @@BE_LABEL@@ API (@@BE_ARTIFACT@@)..."
(
  cd api
  @@BE_BUILD@@
)

echo
echo "==> [3/3] Assembling the release bundle..."
rm -rf release release.tgz
mkdir -p release/api
@@BE_PACKAGE@@
cp -R web/dist release/web
if [ -n "${RELEASE_NOTES:-}" ]; then
  printf '%s\n' "${RELEASE_NOTES}" > release/RELEASE_NOTES.txt
fi
tar -czf release.tgz -C release .
echo "    Built release.tgz:"
ls -lh release.tgz
echo "    Bundle layout:"
( cd release && find . -maxdepth 2 -type d | sort )
echo "    On the target, the API would start with: @@BE_START@@"

echo
echo "--------------------------------------------------"
if [ "${DRY_RUN}" = "true" ]; then
  echo " DRY RUN — release built, upload to '${TARGET}' skipped."
  echo " A real deploy would now run the command below."
else
  echo " DEPLOY to '${TARGET}' — placeholder: this reference environment has no"
  echo " host configured, so there is nothing to upload to. The command a real"
  echo " deploy would run:"
fi
cat <<'PLACEHOLDER'

    # Ship release.tgz to the target host over SSH. Provide DEPLOY_HOST, DEPLOY_USER,
    # and an SSH key as environment Secrets (available_for: ["deploy"]), then
    # replace this block with:
    #
    #   scp release.tgz "${DEPLOY_USER}@${DEPLOY_HOST}:/var/www/app/"
    #   ssh "${DEPLOY_USER}@${DEPLOY_HOST}" \
    #     'cd /var/www/app && tar -xzf release.tgz && systemctl restart app'

PLACEHOLDER
echo "--------------------------------------------------"
echo "Done."
SH

  sed -i \
    -e "s#@@APP_DIR@@#${REPO_ROOT}/${combo}#g" \
    -e "s#@@BE_LABEL@@#${BE_LABEL[$be]}#g" \
    -e "s#@@FE_LABEL@@#${FE_LABEL[$fe]}#g" \
    -e "s#@@BE_ARTIFACT@@#${BE_DEPLOY_ARTIFACT[$be]}#g" \
    -e "s#@@BE_BUILD@@#${BE_DEPLOY_BUILD[$be]}#g" \
    -e "s#@@BE_PACKAGE@@#${BE_DEPLOY_PACKAGE[$be]}#g" \
    -e "s#@@BE_START@@#${BE_DEPLOY_START[$be]}#g" \
    "$pdir/deploy.sh"
  chmod +x "$pdir/deploy.sh"
}

# render_single_dir_deploy_profile DEST COMBO ARTIFACT START
# Deploy profile for the single-directory combos (static, php-html): there is no
# api/web split, so the "release" is simply the app's own files (everything that
# isn't CoderFlow env metadata). No build step.
render_single_dir_deploy_profile() {
  local dest="$1" combo="$2" artifact="$3" start="$4"
  local pdir="$dest/deployment-profiles"
  mkdir -p "$pdir"
  emit_deploy_json "$pdir"

  cat > "$pdir/deploy.sh" <<'SH'
#!/usr/bin/env bash
#
# Reference Deploy Profile — @@ARTIFACT@@
# WHAT THIS SHOWS
#   How a CoderFlow Deploy Profile runs: in a container built from THIS
#   environment's image, with the repo cloned into /workspace, receiving each
#   profile parameter as an environment variable (TARGET, DRY_RUN, RELEASE_NOTES).
#
# WHAT IT REALLY DOES
#   Packages this app's deployable files into release.tgz.
#
# WHAT IT DELIBERATELY DOES NOT DO
#   It does not push anywhere. This reference environment has no real QA/Prod host
#   or credentials, so the upload is a clearly-labelled placeholder. To make it
#   real, add the host + an SSH key as environment Secrets (available_for:
#   ["deploy"]) and fill in the marked block.
set -euo pipefail

APP_DIR="@@APP_DIR@@"
TARGET="${TARGET:-qa}"
DRY_RUN="${DRY_RUN:-true}"

echo "=================================================="
echo " CoderFlow reference deploy — @@ARTIFACT@@"
echo "   Target:   ${TARGET}"
echo "   Dry run:  ${DRY_RUN}"
echo "=================================================="

cd "${APP_DIR}"

echo
echo "==> [1/2] Assembling the release bundle (@@ARTIFACT@@)..."
rm -rf release release.tgz
mkdir -p release
for f in *; do
  case "$f" in
    environment.json|AGENTS.md|README.md|deployment-profiles|release|release.tgz) continue ;;
  esac
  cp -R "$f" release/
done
if [ -n "${RELEASE_NOTES:-}" ]; then
  printf '%s\n' "${RELEASE_NOTES}" > release/RELEASE_NOTES.txt
fi
tar -czf release.tgz -C release .
echo "    Built release.tgz:"
ls -lh release.tgz
echo "    On the target, serve it with: @@START@@"

echo
echo "--------------------------------------------------"
if [ "${DRY_RUN}" = "true" ]; then
  echo " DRY RUN — release built, upload to '${TARGET}' skipped."
  echo " A real deploy would now run the command below."
else
  echo " DEPLOY to '${TARGET}' — placeholder: this reference environment has no"
  echo " host configured, so there is nothing to upload to. The command a real"
  echo " deploy would run:"
fi
cat <<'PLACEHOLDER'

    # Ship release.tgz to the target host over SSH. Provide DEPLOY_HOST, DEPLOY_USER,
    # and an SSH key as environment Secrets (available_for: ["deploy"]), then
    # replace this block with:
    #
    #   scp release.tgz "${DEPLOY_USER}@${DEPLOY_HOST}:/var/www/app/"
    #   ssh "${DEPLOY_USER}@${DEPLOY_HOST}" \
    #     'cd /var/www/app && tar -xzf release.tgz'

PLACEHOLDER
echo "--------------------------------------------------"
echo "Done."
SH

  sed -i \
    -e "s#@@APP_DIR@@#${REPO_ROOT}/${combo}#g" \
    -e "s#@@ARTIFACT@@#${artifact}#g" \
    -e "s#@@START@@#${start}#g" \
    "$pdir/deploy.sh"
  chmod +x "$pdir/deploy.sh"
}

render_static() {
  local dest="$OUT_DIR/static"
  [ -d "$dest" ] || { log "static (skipped — directory missing)"; return; }

  local start="cd $REPO_ROOT/static && python3 -m http.server 8000 --bind 0.0.0.0"
  local ports_json='[{"internal":8000,"name":"web"}]'
  local launch_json='[{"name":"Web","path":"/","port":8000,"primary":true,"description":"Static site"}]'
  local desc="Reference environment — plain HTML/CSS/JS, no backend, preconfigured to import and launch. Clones coderflow-reference-apps and serves the static/ folder on port 8000."

  # No runtime install (python3 is in the base image) and nothing to build.
  # Auto-refresh on task completion: static has no live reload (plain http.server),
  # so reload the preview when a task finishes instead of forcing a manual refresh.
  emit_env_json "$dest/environment.json" "coderflow-ref-static" "$desc" \
    "" "" "Static" "$start" "$ports_json" "$launch_json" \
    '{"auto_refresh_on_complete":true,"refresh_delay_ms":1000}' '["deploy"]'

  cat > "$dest/AGENTS.md" <<'MD'
# static — plain HTML/CSS/JS reference app

A minimal **static site** with no backend: plain HTML/CSS/JS served on port 8000.

## Layout (under `coderflow-reference-apps/static/`)

- `index.html`, `styles.css`, `app.js` — the whole site. No build step, no API.

## Working here

- There's no backend and no build step — edit the files and refresh to see changes.

## Process lifecycle

The static server is started and kept alive by CoderFlow and serves the current
files — edit and refresh, nothing to restart. Don't start your own server
process: anything you launch is torn down when your session ends.
MD

  render_single_dir_deploy_profile "$dest" "static" "static site (HTML/CSS/JS)" "python3 -m http.server 8000 --bind 0.0.0.0"

  log "static (environment.json + AGENTS.md + deploy profile)"
}

# php-html is the single-origin example: one PHP process serves the page and the
# API on one port (no front-end build, no proxy). Its code is hand-authored; this
# regenerates the importable environment.json and README so it stays reproducible.
render_php_html() {
  local dest="$OUT_DIR/php-html"
  [ -d "$dest" ] || { log "php-html (skipped — directory missing)"; return; }

  local start="cd $REPO_ROOT/php-html && php -S 0.0.0.0:8000 router.php"
  local preclone="RUN apt-get update && apt-get install -y php-cli && rm -rf /var/lib/apt/lists/*"
  local ports_json='[{"internal":8000,"name":"web"}]'
  local launch_json='[{"name":"Web","path":"/","port":8000,"primary":true,"description":"PHP single-origin app"}]'
  local desc="Reference environment — single-origin PHP (server-rendered, one port, no build, no proxy), preconfigured to import and launch. Clones coderflow-reference-apps and runs the php-html app on port 8000."

  # Single-origin: no front-end build, so no post-clone action.
  # Auto-refresh on task completion: php-html is server-rendered with no live
  # reload, so reload the preview when a task finishes instead of a manual refresh.
  emit_env_json "$dest/environment.json" "coderflow-ref-php-html" "$desc" \
    "$preclone" "" "PHP" "$start" "$ports_json" "$launch_json" \
    '{"auto_refresh_on_complete":true,"refresh_delay_ms":1000}' '["deploy"]'

  cat > "$dest/README.md" <<'MD'
# php-html — PHP (single-origin)

Minimal hello-world that demonstrates the **single-origin** model: one PHP
process serves both the page and the API on **one port** — no front-end build,
no dev-server proxy, no CORS. Edit a `.php` file and refresh; there's nothing to
rebuild.

## Layout

- `router.php` — routes requests for PHP's built-in server. `/api/hello` returns
  `{"message":"Hello from the PHP API!"}`; every other path renders the page.
- `index.php` — the server-rendered HTML page. It fetches `/api/hello` from the
  **same origin** it was served from, so there's no proxy and no CORS to set up.
- `environment.json` — an importable CoderFlow environment, **preconfigured to
  launch**: the pre-clone PHP install and the single application server (port
  8000) are already set.

## In CoderFlow (import and launch)

This environment is preconfigured — there's nothing to wire up by hand. **Import
Environment → Git repository**, paste this repo's URL, **Load environments**,
pick `php-html`, **Import**, then build and launch. The pre-clone script installs
PHP (the base image doesn't include it) and the application server runs
`php -S 0.0.0.0:8000 router.php` on port 8000.

Open the launch URL — the page shows "Hello from the PHP API!", fetched
same-origin from the one process that served it.

## Run it locally (one process)

Runtime to install: **PHP 8**. No front-end toolchain, no build step.

```sh
php -S 0.0.0.0:8000 router.php
```

Open `http://localhost:8000`. The page shows "Hello from the PHP API!", fetched
same-origin from the one process that served the page.

## Single-origin vs two-process

This is the counterpart to the two-process combos (for example `node-angular`).
There, a front-end dev server runs alongside the API and proxies `/api` to it —
you get live reload at the cost of a second process and a proxy. Here one process
serves everything on one port: simpler, and closer to how a single-host app
deploys. There's no hot reload — you refresh to see changes — but with
server-rendered PHP there's nothing to rebuild first.
MD

  cat > "$dest/AGENTS.md" <<'MD'
# php-html — PHP single-origin reference app

A minimal **single-origin** "hello world": one PHP process serves both the page
and the API on **one port** (8000) — no front-end build, no proxy, no CORS.

## Layout (under `coderflow-reference-apps/php-html/`)

- `router.php` — built-in-server router. `/api/hello` returns `{"message":"Hello from the PHP API!"}`; every other path renders the page.
- `index.php` — the server-rendered page; fetches `/api/hello` from the same origin.

## Working here

- It's single-origin: the page and API share one port, so fetch relative `/api/...` paths — there's no proxy and no CORS to configure.
- Server-rendered PHP: there's no build step. Edit a `.php` file and refresh.

## Process lifecycle

The application server (`php -S`) is started and kept alive by CoderFlow and
re-reads your `.php` files on each request — edit and refresh, nothing to
restart. Don't start your own server process: anything you launch is torn down
when your session ends, and the preview would then go down.
MD

  render_single_dir_deploy_profile "$dest" "php-html" "PHP single-origin app (source)" "php -S 0.0.0.0:8000 router.php"

  log "php-html (single-origin)"
}

main() {
  local target="${1:-all}"
  echo "Generating reference combos into: $OUT_DIR"
  if [ "$target" = "all" ]; then
    for be in "${BACKENDS[@]}"; do
      for fe in "${FRONTENDS[@]}"; do
        render_combo "$be" "$fe"
      done
    done
    render_static
    render_php_html
  elif [ "$target" = "static" ]; then
    render_static
  elif [ "$target" = "php-html" ]; then
    render_php_html
  else
    local be="${target%%-*}" fe="${target##*-}"
    [ -n "${BE_LABEL[$be]:-}" ] && [ -n "${FE_LABEL[$fe]:-}" ] || { echo "unknown combo: $target" >&2; exit 1; }
    render_combo "$be" "$fe"
  fi
  echo "Done."
}

main "$@"
