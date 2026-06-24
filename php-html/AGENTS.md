# php-html — PHP single-origin reference app

A minimal **single-origin** "hello world": one PHP process serves both the page
and the API on **one port** (8000) — no front-end build, no proxy, no CORS.

## Layout (under `coderflow-reference-apps/php-html/`)

- `router.php` — built-in-server router. `/api/hello` returns `{"message":"Hello from the PHP API!"}`; every other path renders the page.
- `index.php` — the server-rendered page; fetches `/api/hello` from the same origin.

## Working here

- It's single-origin: the page and API share one port, so fetch relative `/api/...` paths — there's no proxy and no CORS to configure.
- Server-rendered PHP: there's no build step. Edit a `.php` file and refresh.

## Process lifecycle

The application server (`php -S`) is started and kept alive by CoderFlow and
re-reads your `.php` files on each request — edit and refresh, nothing to
restart. Don't start your own server process: anything you launch is torn down
when your session ends, and the preview would then go down.
