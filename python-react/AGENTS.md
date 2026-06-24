# python-react — Python + React reference app

A minimal two-process "hello world" — **Python** API + **React** front
end — that fetches and displays `GET /api/hello`.

## Layout (under `coderflow-reference-apps/python-react/`)

- `api/` — Python backend. Serves `GET /api/hello` → `{"message":"Hello from the Python API!"}` on `0.0.0.0:3001`.
- `web/` — React front end (source in `web/src/`). Renders a title, the API message, and a **Reload from API** button; dev server on port 5173, proxies `/api` to the API.

These run as **two processes** (already configured as the application server): the
API in the background, then the front-end dev server. The page shows
"Hello from the Python API!".

## Working here

- Keep the split: backend code in `api/`, UI in `web/`.
- The front end reaches the API through the `/api` proxy — fetch relative
  `/api/...` paths; don't hardcode the API origin or port.
- The API binds the port from the PORT env var (default 3001); the dev-server
  proxy targets `http://localhost:3001`.

## Applying changes

The application server (API + front-end dev server) is started and kept alive by
CoderFlow — it serves the live preview. **Don't kill it or start your own copy.**

- **Front-end** edits (in `web/src/`) hot-reload automatically — just save.
- **Back-end** edits: the API runs under `uvicorn --reload`, so saving a backend file restarts it automatically.
- The front end re-fetches `/api/hello` on load, so after a back-end change the
  new value appears on the next browser refresh.

## Process lifecycle (important)

Any process you start runs only for the current session — it is **torn down when
the session ends**, and the preview will then show "Could not reach the API."
Never start a long-running server as a plain background job (`… &`); rely on the
managed app server's reload above instead. If you ever truly must run a durable
process yourself, fully detach it so it outlives your session:

```sh
setsid nohup <command> > /tmp/server.log 2>&1 < /dev/null & disown
```
