# python-angular — Python + Angular reference app

A minimal two-process "hello world" — **Python** API + **Angular** front
end — that fetches and displays `GET /api/hello`.

## Layout (under `coderflow-reference-apps/python-angular/`)

- `api/` — Python backend. Serves `GET /api/hello` → `{"message":"Hello from the Python API!"}` on `0.0.0.0:3001`.
- `web/` — Angular front end (source in `web/src/`). Renders a title, the API message, and a **Reload from API** button; dev server on port 4200, proxies `/api` to the API.

These run as **two processes** (already configured as the application server): the
API in the background, then the front-end dev server. The page shows
"Hello from the Python API!".

## Working here

- Keep the split: backend code in `api/`, UI in `web/`.
- The front end reaches the API through the `/api` proxy — fetch relative
  `/api/...` paths; don't hardcode the API origin or port.
- The API binds the port from the PORT env var (default 3001); the dev-server
  proxy targets `http://localhost:3001`.
