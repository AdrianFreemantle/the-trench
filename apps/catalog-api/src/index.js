const express = require('express');

const app = express();
const PORT = process.env.PORT || 4101;

app.get('/healthz', (_req, res) => {
  res.json({ status: 'ok', service: 'catalog-api' });
});

app.get('/', (_req, res) => {
  res.json({ message: 'Catalog API is running' });
});

app.listen(PORT, () => {
  console.log(`catalog-api listening on port ${PORT}`);
});
