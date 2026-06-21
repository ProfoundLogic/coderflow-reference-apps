# dotnet-vue — .NET + Vue

Minimal hello-world: a **.NET** API serving `GET /api/hello`, and a
**Vue** front end that fetches and displays it. Two-process (live reload).

## Layout

- `api/` — .NET backend. Serves `GET /api/hello` → `{"message":"Hello from the .NET API!"}` on `0.0.0.0:3001`.
- `web/` — Vue front end. Dev server proxies `/api` → `http://localhost:3001`.
- `environment.json` — an importable CoderFlow environment (a starter — complete the runtime/app-server config in CoderFlow, or replace it via Export).

## Run it (two processes)

Runtime to install: **.NET 8 SDK** and **Node.js** (for the front end).

```sh
# 1. install dependencies
cd api && dotnet restore
cd web && npm install

# 2. start the API (terminal 1)
cd api && dotnet run

# 3. start the front end (terminal 2)
cd web && npm run dev
```

Open the front end at `http://localhost:5173`. It shows
"Hello from the .NET API!", fetched through the dev-server proxy.

## In CoderFlow

Import this environment (**Import Environment → Git repository**, then pick
`dotnet-vue`), or create one that clones this repo. Set the runtime above as the
pre-clone step, the install lines as the post-clone action, and the two start
commands as application servers (the API on port 3001).
