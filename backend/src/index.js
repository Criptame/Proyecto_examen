require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { pool, withRetry } = require('./db');
const tasksRouter = require('./routes/tasks');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', db: 'up' });
  } catch (err) {
    res.status(503).json({ status: 'degraded', db: 'down' });
  }
});

app.use('/api/tasks', tasksRouter);

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'internal_server_error' });
});

async function start() {
  await withRetry(() => pool.query('SELECT 1'));
  app.listen(port, () => {
    console.log(`Backend escuchando en puerto ${port}`);
  });
}

start().catch((err) => {
  console.error('No se pudo conectar a la base de datos', err);
  process.exit(1);
});
