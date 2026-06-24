# java-react — Java + React

Minimal hello-world: a **Java** API serving `GET /api/hello`, and the
**React** front end fetches and displays it. Two-process (live reload).

## Layout

- `api/` — Java backend. Serves `GET /api/hello` → `{"message":"Hello from the Java API!"}` on `0.0.0.0:3001`.
- `web/` — React front end (source in `web/src/`). Renders a title, the API's message, and a **Reload from API** button. Dev server proxies `/api` → `http://localhost:3001`.
- `environment.json` — an importable CoderFlow environment, **preconfigured to launch**: the pre-clone runtime install, post-clone dependency install, and both application servers are already set.

## In CoderFlow (import and launch)

This environment is preconfigured — there's nothing to wire up by hand:

1. **Import Environment → Git repository**, paste this repo's URL, **Load environments**, pick `java-react`, **Import**.
2. Build and launch it. The pre-clone script installs **JDK 17 + Maven**, the post-clone action installs dependencies, and the application server starts the API (port 3001) and the React dev server (port 5173).

Open the launch URL — it shows "Hello from the Java API!", fetched through the dev-server proxy.

## Run it locally (two processes)

To run outside CoderFlow, install **JDK 17 + Maven** and **Node.js** (for the front end), then:

```sh
# 1. install dependencies
cd api && mvn -q -DskipTests package
cd web && npm install

# 2. start the API (terminal 1)
cd api && mvn -q spring-boot:run

# 3. start the front end (terminal 2)
cd web && npm run dev
```

Open the front end at `http://localhost:5173`. The page renders a title
from React, the API's message ("Hello from the Java API!") fetched
through the dev-server proxy, and a **Reload from API** button. Edit the
front-end text in `web/src/` and save to see live reload.
