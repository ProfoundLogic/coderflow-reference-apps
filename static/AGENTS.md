# static — plain HTML/CSS/JS reference app

A minimal **static site** with no backend: plain HTML/CSS/JS served on port 8000.

## Layout (under `coderflow-reference-apps/static/`)

- `index.html`, `styles.css`, `app.js` — the whole site. No build step, no API.

## Working here

- There's no backend and no build step — edit the files and refresh to see changes.

## Process lifecycle

The static server is started and kept alive by CoderFlow and serves the current
files — edit and refresh, nothing to restart. Don't start your own server
process: anything you launch is torn down when your session ends.
