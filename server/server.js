import express from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

const app = express();
app.use(helmet());
app.use(express.json({ limit: '20kb' }));
app.use(rateLimit({ windowMs: 60_000, limit: 20, standardHeaders: true, legacyHeaders: false }));

app.get('/health', (_req, res) => res.json({ ok: true }));

app.post('/chat', async (req, res) => {
  const message = typeof req.body?.message === 'string' ? req.body.message.trim() : '';
  if (!message) return res.status(400).json({ error: 'Сообщение пустое.' });
  if (message.length > 6000) return res.status(413).json({ error: 'Сообщение слишком длинное.' });
  if (!process.env.OPENAI_API_KEY) {
    return res.status(503).json({ error: 'На сервере не настроен OPENAI_API_KEY.' });
  }

  try {
    const upstream = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'Тебя зовут Димон. Ты дерзкий, чёткий, дружелюбный ИИ-помощник. Отвечай по-русски, кратко и по делу. Не утверждай, что выполнил действие на устройстве, если это не так.'
          },
          { role: 'user', content: message }
        ],
        temperature: 0.7
      }),
      signal: AbortSignal.timeout(40_000)
    });

    const data = await upstream.json().catch(() => ({}));
    if (!upstream.ok) {
      console.error('OpenAI API error status:', upstream.status);
      return res.status(502).json({ error: 'ИИ-сервис вернул ошибку. Проверь ключ, доступ и лимиты API.' });
    }

    const reply = data?.choices?.[0]?.message?.content;
    if (typeof reply !== 'string' || !reply.trim()) {
      return res.status(502).json({ error: 'ИИ-сервис вернул пустой ответ.' });
    }
    return res.json({ reply: reply.trim() });
  } catch (error) {
    console.error('Chat request failed:', error?.name || 'unknown error');
    return res.status(504).json({ error: 'ИИ-сервис не ответил вовремя. Попробуй ещё раз.' });
  }
});

const port = Number(process.env.PORT || 3000);
app.listen(port, '0.0.0.0', () => {
  console.log(`Dimon API listening on port ${port}`);
});
