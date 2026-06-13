const crypto = require('crypto');
const OpenAI = require('openai');

let client = null;

function getClient() {
  if (!process.env.OPENAI_API_KEY) return null;
  if (!client) {
    client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  }
  return client;
}

function contentHash(text) {
  return crypto.createHash('sha256').update(text.trim()).digest('hex');
}

function cosineSimilarity(a, b) {
  if (!a?.length || !b?.length || a.length !== b.length) return 0;
  let dot = 0;
  let normA = 0;
  let normB = 0;
  for (let i = 0; i < a.length; i += 1) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (!normA || !normB) return 0;
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

function keywordScore(query, text) {
  const words = query.toLowerCase().split(/\W+/).filter((w) => w.length > 2);
  if (!words.length) return 0;
  const haystack = text.toLowerCase();
  let hits = 0;
  for (const word of words) {
    if (haystack.includes(word)) hits += 1;
  }
  return hits / words.length;
}

async function embedTexts(texts) {
  const openai = getClient();
  if (!openai || !texts.length) return [];

  const model = process.env.OPENAI_EMBEDDING_MODEL || 'text-embedding-3-small';
  const response = await openai.embeddings.create({ model, input: texts });
  return response.data
    .sort((a, b) => a.index - b.index)
    .map((item) => item.embedding);
}

async function embedText(text) {
  const [embedding] = await embedTexts([text]);
  return embedding || null;
}

module.exports = {
  getClient,
  contentHash,
  cosineSimilarity,
  keywordScore,
  embedText,
  embedTexts,
};
