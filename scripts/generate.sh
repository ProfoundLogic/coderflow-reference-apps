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
  [python]="pip install -r requirements.txt"
  [php]=""
)
# Start the backend API on 0.0.0.0:3001 (bare command, run in api/).
declare -A BE_RUN=(
  [node]="npm start"
  [dotnet]="dotnet run"
  [java]="mvn -q spring-boot:run"
  [python]="uvicorn main:app --host 0.0.0.0 --port 3001"
  [php]="php -S 0.0.0.0:3001 router.php"
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

# Front-end metadata.
declare -A FE_LABEL=( [angular]="Angular" [react]="React" [vue]="Vue" )
# Start the front-end dev server (bare command, run in web/). Each template's
# start script already binds 0.0.0.0 and proxies /api -> :3001.
declare -A FE_RUN=( [angular]="npm start" [react]="npm run dev" [vue]="npm run dev" )
declare -A FE_PORT=( [angular]="4200" [react]="5173" [vue]="5173" )

BACKENDS=(node dotnet java python php)
FRONTENDS=(angular react vue)

log() { printf '  %s\n' "$*"; }

# emit_env_json OUT IMAGE DESC PRECLONE POST_CLONE_ACTION SERVER_NAME START PORTS_JSON LAUNCH_JSON
# Writes a complete, importable environment.json. PRECLONE and POST_CLONE_ACTION
# may be empty (then their keys are omitted). PORTS_JSON/LAUNCH_JSON are JSON arrays.
emit_env_json() {
  local out="$1" image="$2" desc="$3" preclone="$4" pca="$5" sname="$6" start="$7" ports="$8" launch="$9"

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
    '{ image_name: $image, default_agent: "claude", description: $desc }
     + (if $preclone != "" then { docker_config: { pre_clone_instructions: $preclone, post_clone_instructions: "" } } else {} end)
     + { repos: [ $repo ],
         application_server: {
           enabled: true,
           name: $sname,
           ports: $ports,
           launch_urls: $launch,
           start_command: $start
         } }' \
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
    "${BE_PRECLONE[$be]}" "$pca" "${be_label} + ${fe_label}" "$start" "$ports_json" "$launch_json"

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

Minimal hello-world: a **${be_label}** API serving \`GET /api/hello\`, and a
**${fe_label}** front end that fetches and displays it. Two-process (live reload).

## Layout

- \`api/\` — ${be_label} backend. Serves \`GET /api/hello\` → \`{"message":"Hello from the ${be_label} API!"}\` on \`0.0.0.0:3001\`.
- \`web/\` — ${fe_label} front end. Dev server proxies \`/api\` → \`http://localhost:3001\`.
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

Open the front end at \`http://localhost:${fe_port}\`. It shows
"Hello from the ${be_label} API!", fetched through the dev-server proxy.
MD

  log "$combo"
}

render_static() {
  local dest="$OUT_DIR/static"
  [ -d "$dest" ] || { log "static (skipped — directory missing)"; return; }

  local start="cd $REPO_ROOT/static && python3 -m http.server 8000 --bind 0.0.0.0"
  local ports_json='[{"internal":8000,"name":"web"}]'
  local launch_json='[{"name":"Web","path":"/","port":8000,"primary":true,"description":"Static site"}]'
  local desc="Reference environment — plain HTML/CSS/JS, no backend, preconfigured to import and launch. Clones coderflow-reference-apps and serves the static/ folder on port 8000."

  # No runtime install (python3 is in the base image) and nothing to build.
  emit_env_json "$dest/environment.json" "coderflow-ref-static" "$desc" \
    "" "" "Static" "$start" "$ports_json" "$launch_json"
  log "static (environment.json)"
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
  emit_env_json "$dest/environment.json" "coderflow-ref-php-html" "$desc" \
    "$preclone" "" "PHP" "$start" "$ports_json" "$launch_json"

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
