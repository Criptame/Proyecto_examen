require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { pool, withRetry } = require('./db');
const tasksRouter = require('./routes/tasks');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

const healthHandler = async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', db: 'up' });
  } catch (err) {
    res.status(503).json({ status: 'degraded', db: 'down' });
  }
};

// /health: usado por el healthcheck del contenedor y el target group de ECS
// (pegan directo al puerto del backend, no pasan por el ALB).
// /api/health: usado por el frontend en el navegador, porque el ALB solo
// enruta el path /api/* hacia el backend (ver infra/03-network-alb-rds.sh).
app.get('/health', healthHandler);
app.get('/api/health', healthHandler);

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
