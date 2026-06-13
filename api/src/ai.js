const OpenAI = require('openai');
const { query } = require('./db');
const { retrieveContext } = require('./rag');

let client = null;

function getClient() {
  if (!process.env.OPENAI_API_KEY) {
    return null;
  }
  if (!client) {
    client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  }
  return client;
}

const SYSTEM_PROMPT = `You are Nurtura AI, a calm and supportive health companion assistant.

Rules:
- Answer questions across general health and medical topics: symptoms, common conditions, medications, nutrition, mental health, women's health, men's health, chronic disease, infections, pain, lab tests, and preventive care — not only pregnancy.
- When the user profile shows they are pregnant, connect guidance to their pregnancy week when relevant, but still answer any medical or health question they ask.
- Do not refuse general medical questions. Provide helpful educational information for all health-related topics.
- You are NOT a doctor and cannot diagnose or prescribe. Always recommend consulting a qualified healthcare provider for diagnosis, treatment decisions, prescription changes, or emergencies.
- Be warm, concise, and practical. Use simple language.
- For urgent symptoms (chest pain, difficulty breathing, severe bleeding, stroke signs, high fever, loss of consciousness, severe allergic reaction), urge immediate emergency care.
- Keep responses under 120 words unless the user asks for detail.`;

async function getUserContext(userId) {
  const result = await query('SELECT name, pregnancy_week, due_date FROM users WHERE id = $1', [userId]);
  if (!result.rowCount) return '';
  const u = result.rows[0];
  return `User profile: ${u.name}, pregnancy week ${u.pregnancy_week}, due date ${u.due_date ?? 'not set'}. Use this for pregnancy-related context when helpful, but answer all medical topics the user asks about.`;
}

async function getRecentMessages(userId, threadId, limit = 6) {
  const result = await query(
    `SELECT message, is_user FROM chat_messages
     WHERE user_id = $1 AND thread_id = $2 ORDER BY created_at DESC LIMIT $3`,
    [userId, threadId, limit]
  );
  return result.rows.reverse().map((row) => ({
    role: row.is_user ? 'user' : 'assistant',
    content: row.message,
  }));
}

function getLastUserMessage(messages) {
  for (let i = messages.length - 1; i >= 0; i -= 1) {
    if (messages[i].role === 'user') return messages[i].content;
  }
  return '';
}

async function buildMessages(userId, threadId) {
  const [userContext, history] = await Promise.all([
    getUserContext(userId),
    getRecentMessages(userId, threadId),
  ]);
  const userMessage = getLastUserMessage(history);
  const ragContext = await retrieveContext(userMessage, userId);

  const systemParts = [SYSTEM_PROMPT, userContext];
  if (ragContext) systemParts.push(ragContext);

  return [
    { role: 'system', content: systemParts.join('\n\n') },
    ...history,
  ];
}

function getModelOptions() {
  return {
    model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
    max_tokens: 220,
    temperature: 0.6,
  };
}

async function generateAiReply(userId, threadId) {
  const openai = getClient();
  const messages = await buildMessages(userId, threadId);
  const userMessage = getLastUserMessage(messages);

  if (!openai) {
    return fallbackReply(userMessage);
  }

  try {
    const completion = await openai.chat.completions.create({
      ...getModelOptions(),
      messages,
    });

    return completion.choices[0]?.message?.content?.trim() || fallbackReply(userMessage);
  } catch (err) {
    console.error('OpenAI error:', err.message);
    return fallbackReply(userMessage);
  }
}

async function streamAiReply(userId, threadId, onDelta) {
  const openai = getClient();
  const messages = await buildMessages(userId, threadId);
  const userMessage = getLastUserMessage(messages);

  if (!openai) {
    const reply = fallbackReply(userMessage);
    onDelta(reply);
    return reply;
  }

  try {
    const stream = await openai.chat.completions.create({
      ...getModelOptions(),
      messages,
      stream: true,
    });

    let full = '';
    for await (const chunk of stream) {
      const delta = chunk.choices[0]?.delta?.content;
      if (delta) {
        full += delta;
        onDelta(delta);
      }
    }

    return full.trim() || fallbackReply(userMessage);
  } catch (err) {
    console.error('OpenAI stream error:', err.message);
    const reply = fallbackReply(userMessage);
    onDelta(reply);
    return reply;
  }
}

function fallbackReply(message) {
  const lower = message.toLowerCase();

  if (lower.includes('headache') || lower.includes('migraine')) {
    return 'Headaches can have many causes, including tension, dehydration, sinus issues, or illness. Rest, fluids, and a quiet dark room may help mild cases. See a doctor if headaches are severe, sudden, frequent, or come with fever, vision changes, or neck stiffness.';
  }
  if (lower.includes('fever') || lower.includes('temperature')) {
    return 'Fever often means the body is fighting infection. Rest, fluids, and monitoring temperature are important. Seek medical care for very high fever, fever lasting more than 3 days, or fever with breathing difficulty, rash, confusion, or severe pain.';
  }
  if (lower.includes('diabetes') || lower.includes('blood sugar')) {
    return 'Diabetes management usually includes diet, activity, blood sugar monitoring, and prescribed medicines. Never change medication without your doctor. Contact your care team if you have very high or low readings, excessive thirst, frequent urination, or feeling faint.';
  }
  if (lower.includes('blood pressure') || lower.includes('hypertension')) {
    return 'High blood pressure increases risk for heart, kidney, and stroke problems. Lifestyle changes and prescribed medicines often help. Seek urgent care for severe headache, chest pain, shortness of breath, or very high readings with symptoms.';
  }
  if (lower.includes('anxiety') || lower.includes('depression') || lower.includes('stress') || lower.includes('mental')) {
    return 'Mental health matters as much as physical health. Talk to a doctor or counselor if mood changes, anxiety, sleep problems, or low energy affect daily life. If you have thoughts of self-harm, contact emergency services or a crisis helpline immediately.';
  }
  if (lower.includes('cough') || lower.includes('cold') || lower.includes('flu') || lower.includes('sore throat')) {
    return 'Colds and flu usually improve with rest, fluids, and symptom relief. See a doctor if breathing is difficult, fever is high, symptoms worsen after improving, or you are in a high-risk group such as pregnancy, elderly age, or chronic illness.';
  }
  if (lower.includes('allergy') || lower.includes('rash') || lower.includes('itch')) {
    return 'Allergies and rashes can come from food, medicine, plants, or infection. Avoid known triggers when possible. Get urgent care for swelling of lips or tongue, trouble breathing, widespread rash with fever, or a rash that spreads quickly.';
  }
  if (lower.includes('medicine') || lower.includes('medication') || lower.includes('tablet') || lower.includes('drug')) {
    return 'Medicines should be taken only as prescribed. Do not start, stop, or mix medicines without medical advice, especially during pregnancy. Contact your doctor or pharmacist about side effects, interactions, or safe alternatives.';
  }
  if (lower.includes('stomach') || lower.includes('nausea') || lower.includes('vomit') || lower.includes('diarrhea')) {
    return 'Digestive symptoms are often caused by infection, food issues, or irritation. Sip fluids and eat bland foods for mild cases. See a doctor for severe pain, blood in vomit or stool, dehydration, or symptoms lasting more than a couple of days.';
  }
  if (lower.includes('back pain') || lower.includes('backache')) {
    return 'Back pain is common and may come from muscle strain, posture, or underlying conditions. Gentle movement, rest, and heat may help mild pain. See a doctor if pain is severe, radiates to legs, causes numbness, or follows an injury.';
  }
  if (lower.includes('heart') || lower.includes('chest pain')) {
    return 'Chest pain can be serious. Seek emergency care immediately for chest pressure, pain spreading to arm or jaw, shortness of breath, sweating, or dizziness — do not wait to see if it passes.';
  }

  return 'I can help with general medical and health questions on symptoms, conditions, nutrition, medicines, mental health, and more. For diagnosis and treatment tailored to you, please consult your doctor or healthcare provider.';
}

module.exports = { generateAiReply, streamAiReply };
