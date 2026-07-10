const express = require('express');
const { pool } = require('../db');

const router = express.Router();

router.get('/', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, title, done, created_at FROM tasks ORDER BY id DESC'
    );
    res.json(rows);
  } catch (err) {
    next(err);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const { title } = req.body;
    if (!title || !title.trim()) {
      return res.status(400).json({ error: 'title es requerido' });
    }
    const { rows } = await pool.query(
      'INSERT INTO tasks (title) VALUES ($1) RETURNING id, title, done, created_at',
      [title.trim()]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    next(err);
  }
});

router.put('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const { title, done } = req.body;
    const { rows } = await pool.query(
      `UPDATE tasks SET title = COALESCE($1, title), done = COALESCE($2, done)
       WHERE id = $3 RETURNING id, title, done, created_at`,
      [title ?? null, done ?? null, id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'task no encontrada' });
    }
    res.json(rows[0]);
  } catch (err) {
    next(err);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const { rowCount } = await pool.query('DELETE FROM tasks WHERE id = $1', [id]);
    if (rowCount === 0) {
      return res.status(404).json({ error: 'task no encontrada' });
    }
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

module.exports = router;
