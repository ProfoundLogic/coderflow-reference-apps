# CoderFlow Reference Apps

Minimal "hello world" applications that demonstrate the [CoderFlow environment
setup](https://coderflow.ai/docs/environment-setup) patterns. Each subdirectory
is a self-contained reference app — a backend serving `GET /api/hello` and a
front end that fetches and displays it — that you point a CoderFlow environment
at. No local toolchain required.

Every combo follows the same shape, so only the per-stack values differ:

```
<backend>-<frontend>/
  api/               # backend, serves GET /api/hello on 0.0.0.0:3001
  web/               # front-end dev server, proxies /api -> :3001
  environment.json   # an importable CoderFlow environment (starter)
  README.md          # how to run this combo
```

## The matrix

Serving model is **two-process** (live reload) across the board: the API runs on
`:3001`, the front-end dev server proxies `/api` to it.

| Backend ↓ / Front end → | Angular | React | Vue |
|---|---|---|---|
| **Node.js** (Express) | [`node-angular`](./node-angular) | [`node-react`](./node-react) | [`node-vue`](./node-vue) |
| **.NET** (ASP.NET Core, .NET 8) | [`dotnet-angular`](./dotnet-angular) | [`dotnet-react`](./dotnet-react) | [`dotnet-vue`](./dotnet-vue) |
| **Java** (Spring Boot, JDK 17) | [`java-angular`](./java-angular) | [`java-react`](./java-react) | [`java-vue`](./java-vue) |
| **Python** (FastAPI) | [`python-angular`](./python-angular) | [`python-react`](./python-react) | [`python-vue`](./python-vue) |
| **PHP** (built-in server) | [`php-angular`](./php-angular) | [`php-react`](./php-react) | [`php-vue`](./php-vue) |

Plus [`static/`](./static) — plain HTML/CSS/JS, no backend.

## Use it in CoderFlow

**Import the ready-made environment** (easiest): in CoderFlow, **Import
Environment → Git repository**, paste this repo's URL, **Load environments**,
pick a combo (e.g. `node-react`), **Import**. Each combo ships an
`environment.json` that clones this repo; finish the runtime/app-server config in
the Web UI (or replace it via Export once you have a working one).

**Or wire it by hand:** create an environment that clones this repo, then set the
runtime, dependency install, and the two application servers per the combo's
`README.md`.

> The `environment.json` files are **starters** — they import cleanly and clone
> the repo, but the build/runtime/app-server details are best completed in the UI
> or captured by **Export** from a working environment, which keeps them
> schema-valid and credential-free.

## Run it locally

Each combo's `README.md` has the exact commands. The shape is always:

```sh
# install
cd api && <install>           # e.g. npm install / dotnet restore / pip install -r requirements.txt
cd ../web && npm install

# run (two terminals)
cd api && <start>             # API on 0.0.0.0:3001
cd web && <start>             # dev server, proxies /api -> :3001
```

The front end then shows "Hello from the &lt;Backend&gt; API!".

## Maintaining

The combos are assembled by [`scripts/generate.sh`](./scripts/generate.sh) from
the hand-authored templates in [`templates/`](./templates) (one per backend and
front end) — maintainer tooling, not part of any reference app. The committed
combos are the source of truth that CoderFlow clones; regenerate them all with
`scripts/generate.sh`, or one with `scripts/generate.sh node-react`.

## Versions

- **.NET** — targets **.NET 8 (LTS)**.
- **Java** — Spring Boot 3 on **JDK 17**, built with Maven.
- **Python** — FastAPI on **Python 3.11+**, served with uvicorn.
- **PHP** — **PHP 8**, built-in web server.
- **Angular** — Angular 21 (standalone, no SSR/routing); **React/Vue** on Vite 5.

Match these to the runtime installed in each environment's pre-clone step.
