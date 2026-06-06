const express = require('express');
const { query } = require('../db');

const router = express.Router();

router.get('/categories', async (_req, res) => {
  try {
    const result = await query('SELECT id, name FROM diet_categories ORDER BY id');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/foods', async (_req, res) => {
  try {
    const result = await query(
      `SELECT c.name AS category, f.name, f.icon_key AS iconKey, f.color_hex AS colorHex
       FROM diet_foods f
       JOIN diet_categories c ON c.id = f.category_id
       ORDER BY c.id, f.id`
    );

    const grouped = {};
    for (const row of result.rows) {
      if (!grouped[row.category]) grouped[row.category] = [];
      grouped[row.category].push({
        name: row.name,
        iconKey: row.iconkey || row.iconKey,
        colorHex: row.colorhex || row.colorHex,
      });
    }
    res.json(grouped);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/water/:userId', async (req, res) => {
  try {
    const result = await query(
      'SELECT glasses, goal FROM water_logs WHERE user_id = $1 AND log_date = CURRENT_DATE',
      [req.params.userId]
    );
    if (!result.rowCount) {
      return res.json({ glasses: 0, goal: 8 });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/water/:userId', async (req, res) => {
  try {
    const { glasses, goal } = req.body;
    const result = await query(
      `INSERT INTO water_logs (user_id, glasses, goal, log_date)
       VALUES ($1, $2, $3, CURRENT_DATE)
       ON CONFLICT (user_id, log_date)
       DO UPDATE SET glasses = $2, goal = COALESCE($3, water_logs.goal)
       RETURNING glasses, goal`,
      [req.params.userId, glasses ?? 0, goal ?? 8]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
