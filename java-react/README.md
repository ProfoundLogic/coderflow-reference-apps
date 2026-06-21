# java-react — Java + React

Minimal hello-world: a **Java** API serving `GET /api/hello`, and a
**React** front end that fetches and displays it. Two-process (live reload).

## Layout

- `api/` — Java backend. Serves `GET /api/hello` → `{"message":"Hello from the Java API!"}` on `0.0.0.0:3001`.
- `web/` — React front end. Dev server proxies `/api` → `http://localhost:3001`.
- `environment.json` — an importable CoderFlow environment (a starter — complete the runtime/app-server config in CoderFlow, or replace it via Export).

## Run it (two processes)

Runtime to install: **JDK 17 + Maven** and **Node.js** (for the front end).

```sh
# 1. install dependencies
cd api && mvn -q -DskipTests package
cd web && npm install

# 2. start the API (terminal 1)
cd api && mvn -q spring-boot:run

# 3. start the front end (terminal 2)
cd web && npm run dev
```

Open the front end at `http://localhost:5173`. It shows
"Hello from the Java API!", fetched through the dev-server proxy.

## In CoderFlow

Import this environment (**Import Environment → Git repository**, then pick
`java-react`), or create one that clones this repo. Set the runtime above as the
pre-clone step, the install lines as the post-clone action, and the two start
commands as application servers (the API on port 3001).
