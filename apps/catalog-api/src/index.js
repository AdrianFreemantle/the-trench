const express = require('express');
const { DefaultAzureCredential } = require('@azure/identity');
const { Client } = require('pg');

const app = express();
const PORT = process.env.PORT || 4101;

const credential = new DefaultAzureCredential();
const PG_SCOPE = 'https://ossrdbms-aad.database.windows.net/.default';

const dbConfig = {
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME || 'catalog',
  user: process.env.DB_USER,
};

async function withClient(fn) {
  if (!dbConfig.host || !dbConfig.user) {
    throw new Error('Database configuration incomplete; DB_HOST and DB_USER are required');
  }

  const token = await credential.getToken(PG_SCOPE);
  const client = new Client({
    ...dbConfig,
    password: token.token,
    ssl: { rejectUnauthorized: false },
  });

  await client.connect();
  try {
    return await fn(client);
  } finally {
    await client.end();
  }
}

app.get('/healthz', async (_req, res) => {
  try {
    await withClient(async (client) => {
      await client.query('SELECT 1');
    });
    res.json({ status: 'ok', service: 'catalog-api', db: 'ok' });
  } catch (err) {
    console.error('healthz check failed:', err.message);
    res
      .status(500)
      .json({ status: 'degraded', service: 'catalog-api', error: 'database check failed' });
  }
});

app.get('/', (_req, res) => {
  res.json({ message: 'Catalog API is running' });
});

app.get('/products', async (_req, res) => {
  try {
    const rows = await withClient(async (client) => {
      const result = await client.query(
        'SELECT id, name, description, price FROM products ORDER BY name'
      );
      return result.rows;
    });
    res.json(rows);
  } catch (err) {
    console.error('GET /products failed:', err.message);
    res.status(500).json({ error: 'Failed to load products' });
  }
});

app.get('/products/:id', async (req, res) => {
  try {
    const row = await withClient(async (client) => {
      const result = await client.query(
        'SELECT id, name, description, price FROM products WHERE id = $1',
        [req.params.id]
      );
      return result.rows[0] || null;
    });

    if (!row) {
      res.status(404).json({ error: 'Product not found' });
      return;
    }

    res.json(row);
  } catch (err) {
    console.error('GET /products/:id failed:', err.message);
    res.status(500).json({ error: 'Failed to load product' });
  }
});

app.listen(PORT, () => {
  console.log(`catalog-api listening on port ${PORT}`);
});
