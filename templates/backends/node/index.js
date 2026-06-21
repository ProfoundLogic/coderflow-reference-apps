const express = require("express");

const app = express();
const port = process.env.PORT || 3001;

app.get("/api/hello", (_req, res) => {
  res.json({ message: "Hello from the Node.js API!" });
});

app.listen(port, "0.0.0.0", () => console.log(`API listening on http://localhost:${port}`));
