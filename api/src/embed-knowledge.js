require('dotenv').config();
const { pool } = require('./db');
const { runSchema, runMigrations } = require('./seed');
const { syncKnowledgeBase } = require('./rag');

async function main() {
  await runSchema();
  await runMigrations();
  const result = await syncKnowledgeBase();
  console.log('Embedding complete:', result);
  await pool.end();
}

main().catch((err) => {
  console.error('Embedding failed:', err.message);
  process.exit(1);
});
