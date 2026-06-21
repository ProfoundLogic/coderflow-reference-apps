# scripts — maintainer tooling

**Not a reference app.** These scripts regenerate the reference apps in this repo.
You don't need them to *use* the apps — point a CoderFlow environment at a combo
directory and follow its README.

## generate.sh

Assembles every backend × front-end combo from the hand-authored templates in
[`../templates/`](../templates), so every combination stays consistent. Each
combo gets `api/` (backend), `web/` (front end), an importable `environment.json`,
and a `README.md`.

```bash
scripts/generate.sh            # regenerate all combos
scripts/generate.sh node-react # regenerate one
```

- **Templates are the source of truth.** Edit `templates/backends/<name>` or
  `templates/frontends/<name>` (each is a real, minimal app), then regenerate.
  Add a new stack by adding a template and listing it in the script's metadata.
- The shared contract: every backend serves `GET /api/hello` →
  `{"message":"Hello from the <Backend> API!"}` on `0.0.0.0:3001`; every front
  end fetches `/api/hello` and proxies `/api` to `:3001` (two-process).
- Set `OUT_DIR=/tmp/scratch` to generate into a throwaway location for testing.
- Set `REPO_URL=...` to change the repository URL written into `environment.json`.

No toolchain is required to *generate* (it's a file assembly). The committed
combos are the source of truth that CoderFlow clones; this script reproduces them.
