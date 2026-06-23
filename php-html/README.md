# php-html — PHP (single-origin)

Minimal hello-world that demonstrates the **single-origin** model: one PHP
process serves both the page and the API on **one port** — no front-end build,
no dev-server proxy, no CORS. Edit a `.php` file and refresh; there's nothing to
rebuild.

## Layout

- `router.php` — routes requests for PHP's built-in server. `/api/hello` returns
  `{"message":"Hello from the PHP API!"}`; every other path renders the page.
- `index.php` — the server-rendered HTML page. It fetches `/api/hello` from the
  **same origin** it was served from, so there's no proxy and no CORS to set up.
- `environment.json` — an importable CoderFlow environment (a starter — complete
  the app-server config in CoderFlow, or replace it via Export).

## Run it (one process)

Runtime to install: **PHP 8**. No front-end toolchain, no build step.

```sh
php -S 0.0.0.0:8000 router.php
```

Open `http://localhost:8000`. The page shows "Hello from the PHP API!", fetched
same-origin from the one process that served the page.

## Single-origin vs two-process

This is the counterpart to the two-process combos (for example `node-angular`).
There, a front-end dev server runs alongside the API and proxies `/api` to it —
you get live reload at the cost of a second process and a proxy. Here one process
serves everything on one port: simpler, and closer to how a single-host app
deploys. There's no hot reload — you refresh to see changes — but with
server-rendered PHP there's nothing to rebuild first.

## In CoderFlow

Import this environment (**Import Environment → Git repository**, then pick
`php-html`), or create one that clones this repo. Install PHP as the pre-clone
step (the base image doesn't include it), and set the single start command above
as the application server on port 8000.
