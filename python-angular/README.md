# python-angular — Python + Angular

Minimal hello-world: a **Python** API serving `GET /api/hello`, and the
**Angular** front end fetches and displays it. Two-process (live reload).

## Layout

- `api/` — Python backend. Serves `GET /api/hello` → `{"message":"Hello from the Python API!"}` on `0.0.0.0:3001`.
- `web/` — Angular front end. Dev server proxies `/api` → `http://localhost:3001`.
- `environment.json` — an importable CoderFlow environment, **preconfigured to launch**: the pre-clone runtime install, post-clone dependency install, and both application servers are already set.

## In CoderFlow (import and launch)

This environment is preconfigured — there's nothing to wire up by hand:

1. **Import Environment → Git repository**, paste this repo's URL, **Load environments**, pick `python-angular`, **Import**.
2. Build and launch it. The pre-clone script installs **Python 3.11 (pip)**, the post-clone action installs dependencies, and the application server starts the API (port 3001) and the Angular dev server (port 4200).

Open the launch URL — it shows "Hello from the Python API!", fetched through the dev-server proxy.

## Run it locally (two processes)

To run outside CoderFlow, install **Python 3.11 (pip)** and **Node.js** (for the front end), then:

```sh
# 1. install dependencies
cd api && pip install -r requirements.txt
cd web && npm install

# 2. start the API (terminal 1)
cd api && uvicorn main:app --host 0.0.0.0 --port 3001

# 3. start the front end (terminal 2)
cd web && npm start
```

Open the front end at `http://localhost:4200`. It shows
"Hello from the Python API!", fetched through the dev-server proxy.
