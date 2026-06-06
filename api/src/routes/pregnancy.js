const express = require('express');
const { query } = require('../db');

const router = express.Router();

router.get('/weeks/:week', async (req, res) => {
  try {
    const week = Number(req.params.week);
    const weekResult = await query('SELECT * FROM pregnancy_weeks WHERE week = $1', [week]);
    const symptoms = await query(
      'SELECT label, icon_key AS iconKey FROM week_symptoms WHERE week = $1',
      [week]
    );

    if (!weekResult.rowCount) {
      return res.status(404).json({ error: 'Week not found' });
    }

    const w = weekResult.rows[0];
    res.json({
      week: w.week,
      trimester: w.trimester,
      babySize: w.baby_size,
      lengthCm: Number(w.length_cm),
      weightGm: w.weight_gm,
      development: w.development,
      bodyChanges: w.body_changes,
      tips: w.tips,
      symptoms: symptoms.rows,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/weeks', async (_req, res) => {
  try {
    const result = await query('SELECT week FROM pregnancy_weeks ORDER BY week');
    res.json(result.rows.map((r) => r.week));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
