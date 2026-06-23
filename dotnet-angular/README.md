# dotnet-angular — .NET + Angular

Minimal hello-world: a **.NET** API serving `GET /api/hello`, and a
**Angular** front end that fetches and displays it. Two-process (live reload).

## Layout

- `api/` — .NET backend. Serves `GET /api/hello` → `{"message":"Hello from the .NET API!"}` on `0.0.0.0:3001`.
- `web/` — Angular front end. Dev server proxies `/api` → `http://localhost:3001`.
- `environment.json` — an importable CoderFlow environment, **preconfigured to launch**: the pre-clone runtime install, post-clone dependency install, and both application servers are already set.

## In CoderFlow (import and launch)

This environment is preconfigured — there's nothing to wire up by hand:

1. **Import Environment → Git repository**, paste this repo's URL, **Load environments**, pick `dotnet-angular`, **Import**.
2. Build and launch it. The pre-clone script installs **.NET 8 SDK**, the post-clone action installs dependencies, and the application server starts the API (port 3001) and the Angular dev server (port 4200).

Open the launch URL — it shows "Hello from the .NET API!", fetched through the dev-server proxy.

## Run it locally (two processes)

To run outside CoderFlow, install **.NET 8 SDK** and **Node.js** (for the front end), then:

```sh
# 1. install dependencies
cd api && dotnet restore
cd web && npm install

# 2. start the API (terminal 1)
cd api && dotnet run

# 3. start the front end (terminal 2)
cd web && npm start
```

Open the front end at `http://localhost:4200`. It shows
"Hello from the .NET API!", fetched through the dev-server proxy.
