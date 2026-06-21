<?php

// Router script for PHP's built-in web server.
// Run with: php -S 0.0.0.0:${PORT:-3001} router.php
// The host:port is bound by the `php -S` command, so this script
// does not need to read PORT itself.

$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

if ($path === '/api/hello') {
    header('Content-Type: application/json');
    echo json_encode(['message' => 'Hello from the PHP API!']);
    return true;
}

http_response_code(404);
header('Content-Type: application/json');
echo json_encode(['error' => 'Not Found']);
return true;
