-- Nurtura local PostgreSQL schema

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  due_date DATE,
  pregnancy_week INTEGER NOT NULL DEFAULT 24,
  preferred_language VARCHAR(40) DEFAULT 'English',
  disclaimer_accepted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pregnancy_weeks (
  week INTEGER PRIMARY KEY,
  trimester VARCHAR(20) NOT NULL,
  baby_size VARCHAR(80) NOT NULL,
  length_cm NUMERIC(5,1),
  weight_gm INTEGER,
  development TEXT,
  body_changes TEXT,
  tips TEXT
);

CREATE TABLE IF NOT EXISTS week_symptoms (
  id SERIAL PRIMARY KEY,
  week INTEGER REFERENCES pregnancy_weeks(week) ON DELETE CASCADE,
  label VARCHAR(80) NOT NULL,
  icon_key VARCHAR(40) NOT NULL
);

CREATE TABLE IF NOT EXISTS diet_categories (
  id SERIAL PRIMARY KEY,
  name VARCHAR(60) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS diet_foods (
  id SERIAL PRIMARY KEY,
  category_id INTEGER REFERENCES diet_categories(id) ON DELETE CASCADE,
  name VARCHAR(80) NOT NULL,
  icon_key VARCHAR(40) NOT NULL,
  color_hex VARCHAR(10) NOT NULL
);

CREATE TABLE IF NOT EXISTS emergency_symptoms (
  id SERIAL PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  sort_order INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS ai_prompts (
  id SERIAL PRIMARY KEY,
  text VARCHAR(200) NOT NULL
);

CREATE TABLE IF NOT EXISTS tips (
  id SERIAL PRIMARY KEY,
  title VARCHAR(120) NOT NULL,
  description TEXT NOT NULL,
  icon_key VARCHAR(40) DEFAULT 'water_drop'
);

CREATE TABLE IF NOT EXISTS appointments (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(120) NOT NULL,
  appointment_date DATE NOT NULL,
  appointment_time TIME NOT NULL,
  doctor_name VARCHAR(120) NOT NULL,
  is_past BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chat_threads (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(120) NOT NULL DEFAULT 'New chat',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chat_messages (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  is_user BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS water_logs (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  log_date DATE NOT NULL DEFAULT CURRENT_DATE,
  glasses INTEGER NOT NULL DEFAULT 0,
  goal INTEGER NOT NULL DEFAULT 8,
  UNIQUE (user_id, log_date)
);

CREATE INDEX IF NOT EXISTS idx_appointments_user ON appointments(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_user ON chat_messages(user_id);
