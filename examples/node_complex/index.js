const express = require("express");

const app = express();
const port = 8080;

app.get("/", (_req, res) => {
  res.json({ message: "hello from express" });
});

app.listen(port, () => {
  console.log(`Example app listening on port ${port}`);
});
