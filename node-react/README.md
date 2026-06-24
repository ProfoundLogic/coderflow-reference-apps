# node-react — Node.js + React

Minimal hello-world: a **Node.js** API serving `GET /api/hello`, and the
**React** front end fetches and displays it. Two-process (live reload).

## Layout

- `api/` — Node.js backend. Serves `GET /api/hello` → `{"message":"Hello from the Node.js API!"}` on `0.0.0.0:3001`.
- `web/` — React front end. Dev server proxies `/api` → `http://localhost:3001`.
- `environment.json` — an importable CoderFlow environment, **preconfigured to launch**: the pre-clone runtime install, post-clone dependency install, and both application servers are already set.

## In CoderFlow (import and launch)

This environment is preconfigured — there's nothing to wire up by hand:

1. **Import Environment → Git repository**, paste this repo's URL, **Load environments**, pick `node-react`, **Import**.
2. Build and launch it. The pre-clone script installs **Node.js 20 (npm)**, the post-clone action installs dependencies, and the application server starts the API (port 3001) and the React dev server (port 5173).

Open the launch URL — it shows "Hello from the Node.js API!", fetched through the dev-server proxy.

## Run it locally (two processes)

To run outside CoderFlow, install **Node.js 20 (npm)** and **Node.js** (for the front end), then:

```sh
# 1. install dependencies
cd api && npm install
cd web && npm install

# 2. start the API (terminal 1)
cd api && npm start

# 3. start the front end (terminal 2)
cd web && npm run dev
```

Open the front end at `http://localhost:5173`. It shows
"Hello from the Node.js API!", fetched through the dev-server proxy.
