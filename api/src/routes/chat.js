const express = require('express');
const { query } = require('../db');
const { generateAiReply, streamAiReply } = require('../ai');

const router = express.Router();

const DEFAULT_PROMPTS = [
  'What causes headaches?',
  'How to manage fever?',
  'Signs of high blood pressure?',
  'When should I see a doctor?',
  'Are these medicines safe?',
];

function formatThread(row) {
  return {
    id: row.id,
    title: row.title,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function verifyThread(userId, threadId) {
  const result = await query(
    'SELECT id, title FROM chat_threads WHERE id = $1 AND user_id = $2',
    [threadId, userId]
  );
  if (!result.rowCount) {
    const err = new Error('Thread not found');
    err.status = 404;
    throw err;
  }
  return result.rows[0];
}

async function touchThread(threadId, message) {
  const existing = await query('SELECT title FROM chat_threads WHERE id = $1', [threadId]);
  const title = existing.rows[0]?.title;
  if (title === 'New chat') {
    const nextTitle = message.length > 48 ? `${message.slice(0, 48).trim()}...` : message.trim();
    await query(
      'UPDATE chat_threads SET title = $1, updated_at = NOW() WHERE id = $2',
      [nextTitle || 'New chat', threadId]
    );
    return;
  }
  await query('UPDATE chat_threads SET updated_at = NOW() WHERE id = $1', [threadId]);
}

router.get('/prompts', (_req, res) => {
  res.json(DEFAULT_PROMPTS);
});

router.get('/:userId/threads', async (req, res) => {
  try {
    const result = await query(
      `SELECT id, title, created_at, updated_at
       FROM chat_threads
       WHERE user_id = $1
       ORDER BY updated_at DESC`,
      [req.params.userId]
    );
    res.json(result.rows.map(formatThread));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/:userId/threads', async (req, res) => {
  try {
    const title = req.body?.title?.trim() || 'New chat';
    const result = await query(
      `INSERT INTO chat_threads (user_id, title)
       VALUES ($1, $2)
       RETURNING id, title, created_at, updated_at`,
      [req.params.userId, title]
    );
    res.status(201).json(formatThread(result.rows[0]));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:userId/threads/:threadId', async (req, res) => {
  try {
    await verifyThread(req.params.userId, req.params.threadId);
    await query('DELETE FROM chat_threads WHERE id = $1', [req.params.threadId]);
    res.json({ ok: true });
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message });
  }
});

router.get('/:userId/threads/:threadId/messages', async (req, res) => {
  try {
    await verifyThread(req.params.userId, req.params.threadId);
    const result = await query(
      `SELECT id, message, is_user AS "isUser", created_at AS "createdAt"
       FROM chat_messages
       WHERE user_id = $1 AND thread_id = $2
       ORDER BY created_at`,
      [req.params.userId, req.params.threadId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message });
  }
});

router.post('/:userId/threads/:threadId/stream', async (req, res) => {
  try {
    const { message } = req.body;
    if (!message?.trim()) {
      return res.status(400).json({ error: 'Message is required' });
    }

    const userId = req.params.userId;
    const threadId = req.params.threadId;
    const trimmed = message.trim();

    await verifyThread(userId, threadId);

    await query(
      'INSERT INTO chat_messages (user_id, thread_id, message, is_user) VALUES ($1, $2, $3, true)',
      [userId, threadId, trimmed]
    );
    await touchThread(threadId, trimmed);

    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders?.();

    res.write(`data: ${JSON.stringify({ userMessage: trimmed })}\n\n`);

    const reply = await streamAiReply(userId, threadId, (delta) => {
      res.write(`data: ${JSON.stringify({ delta })}\n\n`);
    });

    const aiResult = await query(
      `INSERT INTO chat_messages (user_id, thread_id, message, is_user)
       VALUES ($1, $2, $3, false)
       RETURNING id, message, is_user AS "isUser", created_at AS "createdAt"`,
      [userId, threadId, reply]
    );

    await query('UPDATE chat_threads SET updated_at = NOW() WHERE id = $1', [threadId]);

    res.write(`data: ${JSON.stringify({ done: true, aiMessage: aiResult.rows[0] })}\n\n`);
    res.end();
  } catch (err) {
    if (!res.headersSent) {
      res.status(err.status || 500).json({ error: err.message });
    } else {
      res.write(`data: ${JSON.stringify({ error: err.message })}\n\n`);
      res.end();
    }
  }
});

router.post('/:userId/threads/:threadId', async (req, res) => {
  try {
    const { message } = req.body;
    if (!message?.trim()) {
      return res.status(400).json({ error: 'Message is required' });
    }

    const userId = req.params.userId;
    const threadId = req.params.threadId;
    const trimmed = message.trim();

    await verifyThread(userId, threadId);

    await query(
      'INSERT INTO chat_messages (user_id, thread_id, message, is_user) VALUES ($1, $2, $3, true)',
      [userId, threadId, trimmed]
    );
    await touchThread(threadId, trimmed);

    const reply = await generateAiReply(userId, threadId);
    const aiResult = await query(
      `INSERT INTO chat_messages (user_id, thread_id, message, is_user)
       VALUES ($1, $2, $3, false)
       RETURNING id, message, is_user AS "isUser", created_at AS "createdAt"`,
      [userId, threadId, reply]
    );

    await query('UPDATE chat_threads SET updated_at = NOW() WHERE id = $1', [threadId]);

    res.status(201).json({
      userMessage: trimmed,
      aiMessage: aiResult.rows[0],
    });
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message });
  }
});

module.exports = router;
