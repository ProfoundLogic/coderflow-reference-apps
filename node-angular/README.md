# node-angular — Node.js + Angular

Minimal hello-world: a **Node.js** API serving `GET /api/hello`, and a
**Angular** front end that fetches and displays it. Two-process (live reload).

## Layout

- `api/` — Node.js backend. Serves `GET /api/hello` → `{"message":"Hello from the Node.js API!"}` on `0.0.0.0:3001`.
- `web/` — Angular front end. Dev server proxies `/api` → `http://localhost:3001`.
- `environment.json` — an importable CoderFlow environment (a starter — complete the runtime/app-server config in CoderFlow, or replace it via Export).

## Run it (two processes)

Runtime to install: **Node.js 20 (npm)** and **Node.js** (for the front end).

```sh
# 1. install dependencies
cd api && npm install
cd web && npm install

# 2. start the API (terminal 1)
cd api && npm start

# 3. start the front end (terminal 2)
cd web && npm start
```

Open the front end at `http://localhost:4200`. It shows
"Hello from the Node.js API!", fetched through the dev-server proxy.

## In CoderFlow

Import this environment (**Import Environment → Git repository**, then pick
`node-angular`), or create one that clones this repo. Set the runtime above as the
pre-clone step, the install lines as the post-clone action, and the two start
commands as application servers (the API on port 3001).
