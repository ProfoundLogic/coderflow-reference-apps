# php-angular — PHP + Angular

Minimal hello-world: a **PHP** API serving `GET /api/hello`, and the
**Angular** front end fetches and displays it. Two-process (live reload).

## Layout

- `api/` — PHP backend. Serves `GET /api/hello` → `{"message":"Hello from the PHP API!"}` on `0.0.0.0:3001`.
- `web/` — Angular front end (source in `web/src/`). Renders a title, the API's message, and a **Reload from API** button. Dev server proxies `/api` → `http://localhost:3001`.
- `environment.json` — an importable CoderFlow environment, **preconfigured to launch**: the pre-clone runtime install, post-clone dependency install, and both application servers are already set.

## In CoderFlow (import and launch)

This environment is preconfigured — there's nothing to wire up by hand:

1. **Import Environment → Git repository**, paste this repo's URL, **Load environments**, pick `php-angular`, **Import**.
2. Build and launch it. The pre-clone script installs **PHP 8.2**, the post-clone action installs dependencies, and the application server starts the API (port 3001) and the Angular dev server (port 4200).

Open the launch URL — it shows "Hello from the PHP API!", fetched through the dev-server proxy.

## Run it locally (two processes)

To run outside CoderFlow, install **PHP 8.2** and **Node.js** (for the front end), then:

```sh
# 1. install dependencies
# (the PHP backend runs from source — nothing to install)
cd web && npm install

# 2. start the API (terminal 1)
cd api && php -S 0.0.0.0:3001 router.php

# 3. start the front end (terminal 2)
cd web && npm start
```

Open the front end at `http://localhost:4200`. The page renders a title
from Angular, the API's message ("Hello from the PHP API!") fetched
through the dev-server proxy, and a **Reload from API** button. Edit the
front-end text in `web/src/` and save to see live reload.
