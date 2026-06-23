<?php
// The page, rendered by the same PHP process that serves /api/hello.
// Single-origin: the fetch below hits the SAME origin this page was served
// from, so there is no proxy and no CORS to configure — and no build step,
// so editing this file and refreshing is all it takes to see a change.
?>
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>CoderFlow PHP reference app</title>
    <style>
      body { font-family: system-ui, sans-serif; margin: 4rem auto; max-width: 40rem; line-height: 1.5; }
      #message { font-size: 1.5rem; }
    </style>
  </head>
  <body>
    <h1>CoderFlow PHP reference app</h1>
    <p id="message">Loading…</p>
    <script>
      // Same-origin: one port serves both this page and /api/hello.
      fetch("/api/hello")
        .then((r) => r.json())
        .then((d) => { document.getElementById("message").textContent = d.message; })
        .catch(() => { document.getElementById("message").textContent = "Could not reach /api/hello"; });
    </script>
  </body>
</html>
