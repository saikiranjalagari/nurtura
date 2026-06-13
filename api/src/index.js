const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const { Client } = require('pg');
require('dotenv').config();

const { pool } = require('./db');
const { runSchema, runMigrations, seed } = require('./seed');
const { syncKnowledgeBase } = require('./rag');

const usersRouter = require('./routes/users');
const homeRouter = require('./routes/home');
const pregnancyRouter = require('./routes/pregnancy');
const dietRouter = require('./routes/diet');
const emergencyRouter = require('./routes/emergency');
const appointmentsRouter = require('./routes/appointments');
const chatRouter = require('./routes/chat');

let embeddedPg = null;

async function ensureDatabase() {
  const config = {
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME || 'nurtura',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
  };

  try {
    await pool.query('SELECT 1');
    await runSchema();
    await runMigrations();
    await seed();
    try {
      await syncKnowledgeBase();
    } catch (err) {
      console.warn('RAG sync warning:', err.message);
    }
    return;
  } catch {
    console.log('PostgreSQL not reachable, starting embedded instance...');
  }

  let EmbeddedPostgres;
  try {
    EmbeddedPostgres = require('embedded-postgres').default;
  } catch {
    EmbeddedPostgres = require('embedded-postgres');
  }

  const dataDir = path.join(__dirname, '..', 'data', 'pg');
  fs.mkdirSync(dataDir, { recursive: true });

  embeddedPg = new EmbeddedPostgres({
    databaseDir: dataDir,
    user: config.user,
    password: config.password,
    port: config.port,
    persistent: true,
  });

  const clusterExists = fs.existsSync(path.join(dataDir, 'PG_VERSION'));
  if (!clusterExists) {
    await embeddedPg.initialise();
  }
  await embeddedPg.start();

  const admin = new Client({ ...config, database: 'postgres' });
  await admin.connect();
  const exists = await admin.query('SELECT 1 FROM pg_database WHERE datname = $1', [config.database]);
  if (exists.rowCount === 0) {
    await admin.query(`CREATE DATABASE ${config.database}`);
  }
  await admin.end();

  await runSchema();
  await runMigrations();
  await seed();
  try {
    await syncKnowledgeBase();
  } catch (err) {
    console.warn('RAG sync warning:', err.message);
  }
  console.log('Embedded PostgreSQL ready.');
}

const app = express();
app.use(cors());
app.use(express.json());

app.get('/api/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    const rag = await pool.query(
      `SELECT COUNT(*)::int AS chunks,
              COUNT(embedding)::int AS embedded
       FROM knowledge_chunks`
    );
    res.json({
      status: 'ok',
      database: 'connected',
      rag: rag.rows[0],
    });
  } catch (err) {
    res.status(503).json({ status: 'error', message: err.message });
  }
});

app.get('/', (_req, res) => {
  res.type('html').send(`
    <!DOCTYPE html>
    <html>
      <head><title>Nurtura API</title></head>
      <body style="font-family: system-ui; max-width: 520px; margin: 48px auto; padding: 0 20px;">
        <h1 style="color:#F06292">Nurtura API</h1>
        <p>This is the <strong>backend API</strong>, not the app UI.</p>
        <p>Open the Flutter app here:</p>
        <p><a href="http://localhost:8081" style="color:#F06292;font-size:18px">http://localhost:8081</a></p>
        <p>API health: <a href="/api/health">/api/health</a></p>
      </body>
    </html>
  `);
});

app.use('/api/users', usersRouter);
app.use('/api/home', homeRouter);
app.use('/api/pregnancy', pregnancyRouter);
app.use('/api/diet', dietRouter);
app.use('/api/emergency', emergencyRouter);
app.use('/api/appointments', appointmentsRouter);
app.use('/api/chat', chatRouter);

app.use('/api', (_req, res) => {
  res.status(404).json({ error: 'API route not found' });
});

app.use((err, _req, res, next) => {
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    return res.status(400).json({ error: 'Invalid JSON request body' });
  }
  console.error('API error:', err.message);
  res.status(err.status || 500).json({ error: err.message || 'Server error' });
});

const PORT = process.env.PORT || 3000;

ensureDatabase()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`Nurtura API running at http://localhost:${PORT}`);
      console.log(`Health check: http://localhost:${PORT}/api/health`);
    });
  })
  .catch((err) => {
    console.error('Failed to start server:', err);
    process.exit(1);
  });

process.on('SIGINT', async () => {
  await pool.end();
  if (embeddedPg) await embeddedPg.stop();
  process.exit(0);
});
