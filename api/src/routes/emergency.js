const express = require('express');
const { query } = require('../db');

const router = express.Router();

router.get('/symptoms', async (_req, res) => {
  try {
    const result = await query(
      'SELECT id, name FROM emergency_symptoms ORDER BY sort_order'
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
