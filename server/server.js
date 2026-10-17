import express from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

const app = express();
app.use(helmet());
app.use(express.json({ limit: '20kb' }));
app.use(rateLimit({ windowMs: 60_000, limit: 20, standardHeaders: true, legacyHeaders: false }));

app.get('/health', (_req, res) => res.json({ ok: true }));

// Natural speech generation. The API key stays on the server and is never shipped in the APK.
app.post('/speech', async (req, res) => {
  const text = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
  if (!text) return res.status(400).json({ error: 'Текст для озвучивания пустой.' });
  if (text.length > 4000) return res.status(413).json({ error: 'Текст для озвучивания слишком длинный.' });
  if (!process.env.OPENAI_API_KEY) {
    return res.status(503).json({ error: 'На сервере не настроен OPENAI_API_KEY.' });
  }

  try {
    const upstream = await fetch('https://api.openai.com/v1/audio/speech', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: process.env.OPENAI_TTS_MODEL || 'gpt-4o-mini-tts',
        voice: process.env.OPENAI_TTS_VOICE || 'onyx',
        input: text,
        instructions: 'Speak in Russian with a natural, confident, warm adult male voice. Conversational, clear diction, relaxed pace, subtle friendly energy. Sound human and expressive, not robotic, not exaggerated. Use natural Russian pronunciation and intonation.',
        response_format: 'mp3',
        speed: 1.0
      }),
      signal: AbortSignal.timeout(40_000)
    });

    if (!upstream.ok) {
      console.error('OpenAI speech API error status:', upstream.status);
      return res.status(502).json({ error: 'Не удалось создать голос. Проверь доступ к TTS API и лимиты.' });
    }
    const audio = Buffer.from(await upstream.arrayBuffer());
    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Cache-Control', 'no-store');
    return res.status(200).send(audio);
  } catch (error) {
    console.error('Speech request failed:', error?.name || 'unknown error');
    return res.status(504).json({ error: 'Сервис озвучивания не ответил вовремя.' });
  }
});

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
