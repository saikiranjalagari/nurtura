const { query } = require('./db');
const {
  contentHash,
  cosineSimilarity,
  keywordScore,
  embedText,
  embedTexts,
  getClient,
} = require('./embeddings');

const TOP_K = Number(process.env.RAG_TOP_K || 4);
const MIN_SCORE = Number(process.env.RAG_MIN_SCORE || 0.32);

const GENERAL_MEDICAL_CHUNKS = [
  {
    sourceType: 'general_health',
    sourceId: 'headache',
    title: 'Headaches',
    content:
      'Headaches may be caused by tension, dehydration, lack of sleep, sinus pressure, or illness. Mild headaches often improve with rest, fluids, and reduced screen time. Seek medical care for sudden severe headache, headache with fever and stiff neck, vision changes, or frequent worsening headaches.',
  },
  {
    sourceType: 'general_health',
    sourceId: 'fever',
    title: 'Fever',
    content:
      'Fever is a common sign of infection. Rest, fluids, and monitoring temperature are important. Contact a doctor for persistent high fever, fever with breathing difficulty, rash, confusion, severe pain, or if pregnant with fever.',
  },
  {
    sourceType: 'general_health',
    sourceId: 'blood_pressure',
    title: 'Blood pressure',
    content:
      'High blood pressure can increase risks during pregnancy and in general health. Lifestyle changes and prescribed medicines may help. Seek urgent care for severe headache, chest pain, shortness of breath, or very high readings with symptoms.',
  },
  {
    sourceType: 'general_health',
    sourceId: 'diabetes',
    title: 'Diabetes and blood sugar',
    content:
      'Diabetes management includes diet, activity, monitoring, and prescribed medicines. Never change medication without a doctor. Contact your care team for very high or low readings, excessive thirst, frequent urination, dizziness, or pregnancy with uncontrolled blood sugar.',
  },
  {
    sourceType: 'general_health',
    sourceId: 'mental_health',
    title: 'Mental health',
    content:
      'Anxiety, stress, and mood changes are common and treatable. Talk to a doctor or counselor if symptoms affect sleep, appetite, work, or daily life. Seek emergency help immediately for thoughts of self-harm.',
  },
  {
    sourceType: 'general_health',
    sourceId: 'medications',
    title: 'Medicines safety',
    content:
      'Take medicines only as prescribed. Do not start, stop, or combine medicines without medical advice, especially during pregnancy. Contact your doctor or pharmacist about side effects, interactions, and safe alternatives.',
  },
  {
    sourceType: 'general_health',
    sourceId: 'digestive',
    title: 'Digestive symptoms',
    content:
      'Nausea, vomiting, diarrhea, and stomach pain may come from infection, food issues, or irritation. Use fluids and bland foods for mild cases. See a doctor for severe pain, blood in vomit or stool, dehydration, or symptoms lasting more than a couple of days.',
  },
  {
    sourceType: 'general_health',
    sourceId: 'when_to_see_doctor',
    title: 'When to see a doctor',
    content:
      'See a doctor promptly for symptoms that are severe, sudden, worsening, or interfering with daily life. During pregnancy, contact your provider for reduced baby movement, heavy bleeding, severe pain, high fever, breathing difficulty, or any symptom that worries you.',
  },
];

async function upsertChunk(chunk) {
  const hash = contentHash(chunk.content);
  const existing = await query(
    'SELECT id, content_hash, embedding FROM knowledge_chunks WHERE content_hash = $1',
    [hash]
  );

  if (existing.rowCount > 0) {
    return existing.rows[0];
  }

  const inserted = await query(
    `INSERT INTO knowledge_chunks (source_type, source_id, title, content, content_hash, metadata)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, content_hash, embedding`,
    [
      chunk.sourceType,
      chunk.sourceId,
      chunk.title,
      chunk.content,
      hash,
      JSON.stringify(chunk.metadata || {}),
    ]
  );
  return inserted.rows[0];
}

async function collectChunksFromDatabase() {
  const chunks = [...GENERAL_MEDICAL_CHUNKS];

  const weeks = await query(
    `SELECT week, trimester, baby_size, length_cm, weight_gm, development, body_changes, tips
     FROM pregnancy_weeks ORDER BY week`
  );
  for (const row of weeks.rows) {
    chunks.push({
      sourceType: 'pregnancy_week',
      sourceId: String(row.week),
      title: `Pregnancy week ${row.week}`,
      content: `Week ${row.week} (${row.trimester}). Baby size: ${row.baby_size}. Development: ${row.development}. Body changes: ${row.body_changes}. Tips: ${row.tips}.`,
      metadata: { week: row.week },
    });
  }

  const symptoms = await query(
    `SELECT ws.week, ws.label, pw.trimester
     FROM week_symptoms ws
     JOIN pregnancy_weeks pw ON pw.week = ws.week
     ORDER BY ws.week, ws.label`
  );
  for (const row of symptoms.rows) {
    chunks.push({
      sourceType: 'symptom',
      sourceId: `${row.week}-${row.label}`,
      title: `${row.label} in week ${row.week}`,
      content: `Symptom: ${row.label} during pregnancy week ${row.week} (${row.trimester}). Discuss persistent or severe symptoms with your healthcare provider.`,
      metadata: { week: row.week, label: row.label },
    });
  }

  const foods = await query(
    `SELECT dc.name AS category, df.name AS food
     FROM diet_foods df
     JOIN diet_categories dc ON dc.id = df.category_id
     ORDER BY dc.name, df.name`
  );
  for (const row of foods.rows) {
    chunks.push({
      sourceType: 'diet',
      sourceId: `${row.category}-${row.food}`,
      title: row.food,
      content: `Diet food: ${row.food}. Category: ${row.category}. Helpful for pregnancy nutrition when included in a balanced diet approved by your doctor.`,
      metadata: { category: row.category, food: row.food },
    });
  }

  const emergency = await query('SELECT name FROM emergency_symptoms ORDER BY sort_order');
  for (const row of emergency.rows) {
    chunks.push({
      sourceType: 'emergency',
      sourceId: row.name,
      title: row.name,
      content: `Emergency warning sign during pregnancy: ${row.name}. Seek urgent medical care immediately if this occurs.`,
      metadata: { emergency: true },
    });
  }

  const tips = await query('SELECT title, description FROM tips ORDER BY id');
  for (const row of tips.rows) {
    chunks.push({
      sourceType: 'tip',
      sourceId: row.title,
      title: row.title,
      content: `${row.title}: ${row.description}`,
      metadata: {},
    });
  }

  return chunks;
}

async function syncKnowledgeBase() {
  const chunks = await collectChunksFromDatabase();
  const pendingEmbeds = [];

  for (const chunk of chunks) {
    const row = await upsertChunk(chunk);
    if (!row.embedding) {
      pendingEmbeds.push({ id: row.id, content: chunk.content });
    }
  }

  if (!pendingEmbeds.length) {
    console.log(`RAG knowledge base ready (${chunks.length} chunks).`);
    return { total: chunks.length, embedded: 0 };
  }

  const openai = getClient();
  if (!openai) {
    console.log(`RAG knowledge synced (${chunks.length} chunks). Embeddings skipped: no OPENAI_API_KEY.`);
    return { total: chunks.length, embedded: 0 };
  }

  const batchSize = 20;
  let embedded = 0;
  try {
    for (let i = 0; i < pendingEmbeds.length; i += batchSize) {
      const batch = pendingEmbeds.slice(i, i + batchSize);
      const vectors = await embedTexts(batch.map((item) => item.content));
      for (let j = 0; j < batch.length; j += 1) {
        if (!vectors[j]) continue;
        await query('UPDATE knowledge_chunks SET embedding = $1, updated_at = NOW() WHERE id = $2', [
          JSON.stringify(vectors[j]),
          batch[j].id,
        ]);
        embedded += 1;
      }
    }
  } catch (err) {
    console.warn(`RAG embedding partial/failed: ${err.message}. Keyword search fallback is active.`);
  }

  console.log(`RAG knowledge base ready (${chunks.length} chunks, ${embedded} newly embedded).`);
  return { total: chunks.length, embedded };
}

async function getUserPregnancyWeek(userId) {
  const result = await query('SELECT pregnancy_week FROM users WHERE id = $1', [userId]);
  return result.rowCount ? result.rows[0].pregnancy_week : null;
}

function parseEmbedding(value) {
  if (!value) return null;
  if (Array.isArray(value)) return value;
  if (typeof value === 'string') {
    try {
      return JSON.parse(value);
    } catch {
      return null;
    }
  }
  return null;
}

async function retrieveContext(queryText, userId) {
  const text = queryText?.trim();
  if (!text) return '';

  const rows = await query(
    `SELECT id, source_type, source_id, title, content, embedding, metadata
     FROM knowledge_chunks
     ORDER BY id`
  );
  if (!rows.rowCount) return '';

  const pregnancyWeek = await getUserPregnancyWeek(userId);
  const openai = getClient();
  let queryEmbedding = null;

  if (openai) {
    try {
      queryEmbedding = await embedText(text);
    } catch (err) {
      console.error('RAG embedding error:', err.message);
    }
  }

  const scored = rows.rows.map((row) => {
    const embedding = parseEmbedding(row.embedding);
    let score = 0;

    if (queryEmbedding && embedding) {
      score = cosineSimilarity(queryEmbedding, embedding);
    } else {
      score = keywordScore(text, `${row.title} ${row.content}`) * 0.75;
    }

    if (pregnancyWeek && row.source_type === 'pregnancy_week' && String(row.source_id) === String(pregnancyWeek)) {
      score += 0.2;
    }
    const metadata = typeof row.metadata === 'string' ? JSON.parse(row.metadata) : (row.metadata || {});
    if (pregnancyWeek && metadata.week === pregnancyWeek) {
      score += 0.15;
    }

    return { row, score };
  });

  const selected = scored
    .filter((item) => item.score >= MIN_SCORE)
    .sort((a, b) => b.score - a.score)
    .slice(0, TOP_K);

  if (!selected.length) {
    const fallback = scored.sort((a, b) => b.score - a.score).slice(0, 2);
    if (!fallback.length || fallback[0].score <= 0) return '';
    return formatContext(fallback);
  }

  return formatContext(selected);
}

function formatContext(items) {
  const lines = items.map((item, index) => {
    const chunk = item.row;
    return `${index + 1}. [${chunk.source_type}] ${chunk.title}: ${chunk.content}`;
  });
  return `Relevant knowledge from Nurtura database:\n${lines.join('\n')}`;
}

module.exports = {
  syncKnowledgeBase,
  retrieveContext,
  collectChunksFromDatabase,
};
