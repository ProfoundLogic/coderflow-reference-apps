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
#     environment.json   # importable CoderFlow environment (starter)
#     README.md          # how to run it
#
# The committed combos are the source of truth that CoderFlow clones; this
# script reproduces them so adding/refreshing a combo is a one-command change.
#
# Usage:
#   scripts/generate.sh            # regenerate all combos
#   scripts/generate.sh <combo>    # regenerate one (e.g. node-react)
#
# Env:
#   OUT_DIR    Output root (default: repo root). Set to a temp dir to test.
#   REPO_URL   Repo URL written into environment.json (default: the public repo).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT}"
TPL="$ROOT/templates"
REPO_URL="${REPO_URL:-https://github.com/ProfoundLogic/coderflow-reference-apps}"

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
declare -A BE_INSTALL=(
  [node]="cd api && npm install"
  [dotnet]="cd api && dotnet restore"
  [java]="cd api && mvn -q -DskipTests package"
  [python]="cd api && pip install -r requirements.txt"
  [php]="# no build step"
)
declare -A BE_START=(
  [node]="cd api && npm start"
  [dotnet]="cd api && dotnet run"
  [java]="cd api && mvn -q spring-boot:run"
  [python]="cd api && uvicorn main:app --host 0.0.0.0 --port 3001"
  [php]="cd api && php -S 0.0.0.0:3001 router.php"
)

# Front-end metadata.
declare -A FE_LABEL=( [angular]="Angular" [react]="React" [vue]="Vue" )
declare -A FE_INSTALL=(
  [angular]="cd web && npm install"
  [react]="cd web && npm install"
  [vue]="cd web && npm install"
)
declare -A FE_START=(
  [angular]="cd web && npm start"
  [react]="cd web && npm run dev"
  [vue]="cd web && npm run dev"
)
declare -A FE_PORT=( [angular]="4200" [react]="5173" [vue]="5173" )

BACKENDS=(node dotnet java python php)
FRONTENDS=(angular react vue)

log() { printf '  %s\n' "$*"; }

render_combo() {
  local be="$1" fe="$2"
  local combo="${be}-${fe}"
  local dest="$OUT_DIR/$combo"

  rm -rf "$dest"
  mkdir -p "$dest"
  cp -R "$TPL/backends/${BE_DIR[$be]}/." "$dest/api/"
  cp -R "$TPL/frontends/$fe/." "$dest/web/"

  local be_label="${BE_LABEL[$be]}" fe_label="${FE_LABEL[$fe]}"

  cat > "$dest/environment.json" <<JSON
{
  "image_name": "coderflow-ref-${combo}",
  "default_agent": "claude",
  "description": "Reference environment — ${be_label} API + ${fe_label} front end (two-process). Clones coderflow-reference-apps; run the ${combo} app per its README.",
  "repos": [
    {
      "name": "coderflow-reference-apps",
      "url": "${REPO_URL}",
      "branch": "main",
      "allow_branch_selection": true
    }
  ]
}
JSON

  cat > "$dest/README.md" <<MD
# ${combo} — ${be_label} + ${fe_label}

Minimal hello-world: a **${be_label}** API serving \`GET /api/hello\`, and a
**${fe_label}** front end that fetches and displays it. Two-process (live reload).

## Layout

- \`api/\` — ${be_label} backend. Serves \`GET /api/hello\` → \`{"message":"Hello from the ${be_label} API!"}\` on \`0.0.0.0:3001\`.
- \`web/\` — ${fe_label} front end. Dev server proxies \`/api\` → \`http://localhost:3001\`.
- \`environment.json\` — an importable CoderFlow environment (a starter — complete the runtime/app-server config in CoderFlow, or replace it via Export).

## Run it (two processes)

Runtime to install: **${BE_RUNTIME[$be]}** and **Node.js** (for the front end).

\`\`\`sh
# 1. install dependencies
${BE_INSTALL[$be]}
${FE_INSTALL[$fe]}

# 2. start the API (terminal 1)
${BE_START[$be]}

# 3. start the front end (terminal 2)
${FE_START[$fe]}
\`\`\`

Open the front end at \`http://localhost:${FE_PORT[$fe]}\`. It shows
"Hello from the ${be_label} API!", fetched through the dev-server proxy.

## In CoderFlow

Import this environment (**Import Environment → Git repository**, then pick
\`${combo}\`), or create one that clones this repo. Set the runtime above as the
pre-clone step, the install lines as the post-clone action, and the two start
commands as application servers (the API on port 3001).
MD

  log "$combo"
}

render_static() {
  local dest="$OUT_DIR/static"
  [ -d "$dest" ] || { log "static (skipped — directory missing)"; return; }
  cat > "$dest/environment.json" <<JSON
{
  "image_name": "coderflow-ref-static",
  "default_agent": "claude",
  "description": "Reference environment — plain HTML/CSS/JS, no backend. Clones coderflow-reference-apps; serve the static/ folder per its README.",
  "repos": [
    {
      "name": "coderflow-reference-apps",
      "url": "${REPO_URL}",
      "branch": "main",
      "allow_branch_selection": true
    }
  ]
}
JSON
  log "static (environment.json)"
}

# php-html is the single-origin example: one PHP process serves the page and the
# API on one port (no front-end build, no proxy). Its code is hand-authored; this
# regenerates the importable environment.json and README so it stays reproducible.
render_php_html() {
  local dest="$OUT_DIR/php-html"
  [ -d "$dest" ] || { log "php-html (skipped — directory missing)"; return; }

  cat > "$dest/environment.json" <<JSON
{
  "image_name": "coderflow-ref-php-html",
  "default_agent": "claude",
  "description": "Reference environment — single-origin PHP (server-rendered, one port, no build, no proxy). Clones coderflow-reference-apps; run the php-html app per its README.",
  "repos": [
    {
      "name": "coderflow-reference-apps",
      "url": "${REPO_URL}",
      "branch": "main",
      "allow_branch_selection": true
    }
  ]
}
JSON

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
- `environment.json` — an importable CoderFlow environment (a starter — complete
  the app-server config in CoderFlow, or replace it via Export).

## Run it (one process)

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

## In CoderFlow

Import this environment (**Import Environment → Git repository**, then pick
`php-html`), or create one that clones this repo. Install PHP as the pre-clone
step (the base image doesn't include it), and set the single start command above
as the application server on port 8000.
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
