const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
const { runSchema, runMigrations, seed } = require('./seed');
require('dotenv').config();

async function tryConnect(config) {
  const client = new Client(config);
  await client.connect();
  await client.end();
  return true;
}

async function setupEmbeddedPostgres() {
  let EmbeddedPostgres;
  try {
    EmbeddedPostgres = require('embedded-postgres').default;
  } catch {
    EmbeddedPostgres = require('embedded-postgres');
  }

  const dataDir = path.join(__dirname, '..', 'data', 'pg');
  fs.mkdirSync(dataDir, { recursive: true });

  const pg = new EmbeddedPostgres({
    databaseDir: dataDir,
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    port: Number(process.env.DB_PORT || 5432),
    persistent: true,
  });

  console.log('Starting embedded PostgreSQL (first run may download binaries)...');
  await pg.initialise();
  await pg.start();

  const admin = new Client({
    host: 'localhost',
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    database: 'postgres',
  });
  await admin.connect();

  const dbName = process.env.DB_NAME || 'nurtura';
  const exists = await admin.query('SELECT 1 FROM pg_database WHERE datname = $1', [dbName]);
  if (exists.rowCount === 0) {
    await admin.query(`CREATE DATABASE ${dbName}`);
    console.log(`Created database "${dbName}"`);
  }
  await admin.end();

  console.log('Embedded PostgreSQL is running on port', process.env.DB_PORT || 5432);
  return pg;
}

async function main() {
  const config = {
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME || 'nurtura',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
  };

  let embedded;
  try {
    await tryConnect(config);
    console.log('Connected to existing PostgreSQL.');
  } catch {
    embedded = await setupEmbeddedPostgres();
  }

  const { pool } = require('./db');
  await runSchema();
  await runMigrations();
  await seed();
  await pool.end();

  if (embedded) {
    console.log('\nNote: Embedded PostgreSQL was started for setup.');
    console.log('Run "npm start" — the server will auto-start embedded PostgreSQL if needed.\n');
    await embedded.stop();
  }

  console.log('Database setup complete.');
}

main().catch((err) => {
  console.error('Setup failed:', err.message);
  process.exit(1);
});
