const express = require('express');
const { query } = require('../db');

const router = express.Router();

router.get('/:userId', async (req, res) => {
  try {
    const userId = req.params.userId;
    const userResult = await query('SELECT * FROM users WHERE id = $1', [userId]);
    if (!userResult.rowCount) return res.status(404).json({ error: 'User not found' });

    const user = userResult.rows[0];
    const week = user.pregnancy_week;

    const weekResult = await query('SELECT * FROM pregnancy_weeks WHERE week = $1', [week]);
    const weekData = weekResult.rows[0] || {
      week,
      trimester: '2nd Trimester',
      baby_size: 'Corn',
      length_cm: 30,
      weight_gm: 600,
    };

    const tipResult = await query('SELECT * FROM tips ORDER BY id LIMIT 1');
    const apptResult = await query(
      `SELECT * FROM appointments WHERE user_id = $1 AND is_past = false
       ORDER BY appointment_date ASC LIMIT 1`,
      [userId]
    );

    const greeting = getGreeting();

    res.json({
      greeting: `${greeting}, ${user.name.split(' ')[0]} 🌸`,
      pregnancyWeek: week,
      babySize: weekData.baby_size,
      progress: week / 40,
      tip: tipResult.rows[0] || null,
      nextAppointment: apptResult.rows[0]
        ? formatAppointment(apptResult.rows[0])
        : null,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

function getGreeting() {
  const hour = new Date().getHours();
  if (hour < 12) return 'Good Morning';
  if (hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

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
