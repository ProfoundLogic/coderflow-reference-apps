<?php

// Router for PHP's built-in web server — the whole app is one process.
//
//   php -S 0.0.0.0:8000 router.php
//
// Single-origin: this one process serves both the page and the API on one
// port. There is no front-end dev server and no proxy, so the host:port is
// bound by the `php -S` command and this script doesn't read PORT itself.

$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

if ($path === '/api/hello') {
    header('Content-Type: application/json');
    echo json_encode(['message' => 'Hello from the PHP API!']);
    return true;
}

// Everything else renders the page.
require __DIR__ . '/index.php';
return true;
