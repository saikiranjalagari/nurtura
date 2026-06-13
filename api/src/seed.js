const fs = require('fs');
const path = require('path');
const { pool, query } = require('./db');

async function runMigrations() {
  await query(`
    CREATE TABLE IF NOT EXISTS chat_threads (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      title VARCHAR(120) NOT NULL DEFAULT 'New chat',
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    )
  `);

  await query(`
    ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS thread_id INTEGER REFERENCES chat_threads(id) ON DELETE CASCADE
  `);

  const orphanUsers = await query(
    'SELECT DISTINCT user_id FROM chat_messages WHERE thread_id IS NULL'
  );

  for (const row of orphanUsers.rows) {
    const thread = await query(
      `INSERT INTO chat_threads (user_id, title, updated_at)
       VALUES ($1, $2, NOW()) RETURNING id`,
      [row.user_id, 'Previous chat']
    );
    await query(
      'UPDATE chat_messages SET thread_id = $1 WHERE user_id = $2 AND thread_id IS NULL',
      [thread.rows[0].id, row.user_id]
    );
  }

  await query('CREATE INDEX IF NOT EXISTS idx_chat_thread ON chat_messages(thread_id)');
  await query('CREATE INDEX IF NOT EXISTS idx_chat_threads_user ON chat_threads(user_id)');

  await query(`
    CREATE TABLE IF NOT EXISTS knowledge_chunks (
      id SERIAL PRIMARY KEY,
      source_type VARCHAR(40) NOT NULL,
      source_id VARCHAR(80) NOT NULL,
      title VARCHAR(200) NOT NULL,
      content TEXT NOT NULL,
      content_hash VARCHAR(64) NOT NULL UNIQUE,
      embedding JSONB,
      metadata JSONB DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    )
  `);
  await query('CREATE INDEX IF NOT EXISTS idx_knowledge_source ON knowledge_chunks(source_type)');
}

async function seed() {
  const userCount = await query('SELECT COUNT(*)::int AS c FROM users');
  if (userCount.rows[0].c > 0) {
    console.log('Database already seeded.');
    return;
  }

  const user = await query(
    `INSERT INTO users (name, due_date, pregnancy_week, preferred_language, disclaimer_accepted)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    ['Priya Sharma', '2026-10-15', 24, 'English', true]
  );
  const userId = user.rows[0].id;

  const weeks = [
    [20, '2nd Trimester', 'Banana', 25.0, 300, 'Baby can hear sounds.', 'You may feel more movement.', 'Stay hydrated and rest well.'],
    [21, '2nd Trimester', 'Carrot', 26.5, 360, 'Digestive system develops.', 'Skin may feel itchy as it stretches.', 'Use moisturizer daily.'],
    [22, '2nd Trimester', 'Papaya', 27.5, 430, 'Lips and eyebrows form.', 'Back pain may increase.', 'Try gentle prenatal yoga.'],
    [23, '2nd Trimester', 'Mango', 28.5, 500, 'Blood vessels in lungs develop.', 'Swollen feet possible.', 'Elevate legs when resting.'],
    [24, '2nd Trimester', 'Corn', 30.0, 600, 'Lungs develop surfactant. Baby responds to light and voice.', 'Increased appetite and Braxton Hicks.', 'Sleep on your left side.'],
    [25, '2nd Trimester', 'Cauliflower', 34.0, 660, 'Baby starts adding fat.', 'Heartburn may occur.', 'Eat smaller frequent meals.'],
  ];

  for (const w of weeks) {
    await query(
      `INSERT INTO pregnancy_weeks (week, trimester, baby_size, length_cm, weight_gm, development, body_changes, tips)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT (week) DO NOTHING`,
      w
    );
  }

  const symptoms = [
    [24, 'Back pain', 'back'],
    [24, 'Heartburn', 'heartburn'],
    [24, 'Fatigue', 'fatigue'],
    [24, 'Swelling', 'swelling'],
  ];
  for (const s of symptoms) {
    await query(
      'INSERT INTO week_symptoms (week, label, icon_key) VALUES ($1,$2,$3)',
      s
    );
  }

  const categories = ['Iron Rich Foods', 'Calcium Rich Foods'];
  const catIds = {};
  for (const name of categories) {
    const r = await query(
      'INSERT INTO diet_categories (name) VALUES ($1) ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name RETURNING id',
      [name]
    );
    catIds[name] = r.rows[0].id;
  }

  const foods = [
    [catIds['Iron Rich Foods'], 'Spinach', 'eco', '#66BB6A'],
    [catIds['Iron Rich Foods'], 'Lentils', 'grain', '#8D6E63'],
    [catIds['Iron Rich Foods'], 'Dates', 'circle', '#795548'],
    [catIds['Calcium Rich Foods'], 'Milk', 'drink', '#42A5F5'],
    [catIds['Calcium Rich Foods'], 'Yogurt', 'icecream', '#FFB74D'],
    [catIds['Calcium Rich Foods'], 'Cheese', 'breakfast', '#FFCA28'],
  ];
  for (const f of foods) {
    await query(
      'INSERT INTO diet_foods (category_id, name, icon_key, color_hex) VALUES ($1,$2,$3,$4)',
      f
    );
  }

  const emergency = [
    'Heavy Bleeding',
    'Severe Headache',
    'Reduced Baby Movement',
    'High Fever',
    'Severe Abdominal Pain',
  ];
  for (let i = 0; i < emergency.length; i++) {
    await query('INSERT INTO emergency_symptoms (name, sort_order) VALUES ($1,$2)', [
      emergency[i],
      i + 1,
    ]);
  }

  const prompts = [
    'What causes headaches?',
    'How to manage fever?',
    'Signs of high blood pressure?',
    'When should I see a doctor?',
  ];
  for (const p of prompts) {
    await query('INSERT INTO ai_prompts (text) VALUES ($1)', [p]);
  }

  await query(
    `INSERT INTO tips (title, description, icon_key) VALUES ($1,$2,$3)`,
    ['Stay Hydrated', 'Drink at least 8 glasses of water today', 'water_drop']
  );

  await query(
    `INSERT INTO appointments (user_id, title, appointment_date, appointment_time, doctor_name, is_past)
     VALUES
       ($1, $2, $3, $4, $5, $6),
       ($1, $7, $8, $9, $10, $11),
       ($1, $12, $13, $14, $15, $16)`,
    [
      userId,
      'Anomaly Scan', '2026-06-05', '10:30', 'Dr. Mehta', false,
      'Routine Checkup', '2026-06-20', '11:00', 'Dr. Sharma', false,
      'First Trimester Scan', '2026-03-10', '09:00', 'Dr. Mehta', true,
    ]
  );

  const thread = await query(
    `INSERT INTO chat_threads (user_id, title) VALUES ($1, $2) RETURNING id`,
    [userId, 'Back pain in week 24']
  );
  const threadId = thread.rows[0].id;

  await query(
    `INSERT INTO chat_messages (user_id, thread_id, message, is_user) VALUES
     ($1, $2, 'Hi Priya! How can I help you today?', false),
     ($1, $2, 'Is mild back pain normal in week 24?', true),
     ($1, $2, 'Yes, mild back pain is common in the second trimester. Try gentle stretches and rest. Contact your doctor if pain is severe.', false)`,
    [userId, threadId]
  );

  await query(
    'INSERT INTO water_logs (user_id, glasses, goal) VALUES ($1, 6, 8)',
    [userId]
  );

  console.log(`Seeded demo user id=${userId}`);
}

async function runSchema() {
  const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  await pool.query(schema);
}

module.exports = { runSchema, runMigrations, seed };
