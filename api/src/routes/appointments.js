const express = require('express');
const { query } = require('../db');

const router = express.Router();

router.get('/:userId', async (req, res) => {
  try {
    const { upcoming } = req.query;
    let sql = 'SELECT * FROM appointments WHERE user_id = $1';
    if (upcoming === 'true') sql += ' AND is_past = false';
    if (upcoming === 'false') sql += ' AND is_past = true';
    sql += ' ORDER BY appointment_date DESC, appointment_time DESC';

    const result = await query(sql, [req.params.userId]);
    res.json(result.rows.map(formatAppointment));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/:userId', async (req, res) => {
  try {
    const { title, date, time, doctorName } = req.body;
    if (!title || !date || !time || !doctorName) {
      return res.status(400).json({ error: 'title, date, time, doctorName required' });
    }

    const result = await query(
      `INSERT INTO appointments (user_id, title, appointment_date, appointment_time, doctor_name)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [req.params.userId, title, date, time, doctorName]
    );
    res.status(201).json(formatAppointment(result.rows[0]));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

function formatAppointment(row) {
  return {
    id: row.id,
    title: row.title,
    date: row.appointment_date,
    time: row.appointment_time,
    doctorName: row.doctor_name,
    isPast: row.is_past,
  };
}

module.exports = router;
