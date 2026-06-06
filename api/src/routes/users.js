const express = require('express');
const { query } = require('../db');

const router = express.Router();

router.post('/register', async (req, res) => {
  try {
    const { name, dueDate, pregnancyWeek, preferredLanguage, disclaimerAccepted } = req.body;
    if (!name?.trim()) {
      return res.status(400).json({ error: 'Name is required' });
    }

    const result = await query(
      `INSERT INTO users (name, due_date, pregnancy_week, preferred_language, disclaimer_accepted)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [
        name.trim(),
        dueDate || null,
        pregnancyWeek || 24,
        preferredLanguage || 'English',
        disclaimerAccepted ?? true,
      ]
    );

    const user = result.rows[0];
    await query(
      'INSERT INTO water_logs (user_id, glasses, goal) VALUES ($1, 0, 8) ON CONFLICT (user_id, log_date) DO NOTHING',
      [user.id]
    );

    res.status(201).json(formatUser(user));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const result = await query('SELECT * FROM users WHERE id = $1', [req.params.id]);
    if (!result.rowCount) return res.status(404).json({ error: 'User not found' });
    res.json(formatUser(result.rows[0]));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const { name, dueDate, pregnancyWeek, preferredLanguage } = req.body;
    const result = await query(
      `UPDATE users SET
        name = COALESCE($2, name),
        due_date = COALESCE($3, due_date),
        pregnancy_week = COALESCE($4, pregnancy_week),
        preferred_language = COALESCE($5, preferred_language)
       WHERE id = $1 RETURNING *`,
      [req.params.id, name, dueDate, pregnancyWeek, preferredLanguage]
    );
    if (!result.rowCount) return res.status(404).json({ error: 'User not found' });
    res.json(formatUser(result.rows[0]));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

function formatUser(row) {
  return {
    id: row.id,
    name: row.name,
    dueDate: row.due_date,
    pregnancyWeek: row.pregnancy_week,
    preferredLanguage: row.preferred_language,
    disclaimerAccepted: row.disclaimer_accepted,
    createdAt: row.created_at,
  };
}

module.exports = router;
