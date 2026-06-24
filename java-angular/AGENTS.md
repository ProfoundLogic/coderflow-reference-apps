# java-angular — Java + Angular reference app

A minimal two-process "hello world" — **Java** API + **Angular** front
end — that fetches and displays `GET /api/hello`.

## Layout (under `coderflow-reference-apps/java-angular/`)

- `api/` — Java backend. Serves `GET /api/hello` → `{"message":"Hello from the Java API!"}` on `0.0.0.0:3001`.
- `web/` — Angular front end. Dev server on port 4200; proxies `/api` to the API.

These run as **two processes** (already configured as the application server): the
API in the background, then the front-end dev server. The page shows
"Hello from the Java API!".

## Working here

- Keep the split: backend code in `api/`, UI in `web/`.
- The front end reaches the API through the `/api` proxy — fetch relative
  `/api/...` paths; don't hardcode the API origin or port.
- The API binds the port from the PORT env var (default 3001); the dev-server
  proxy targets `http://localhost:3001`.
