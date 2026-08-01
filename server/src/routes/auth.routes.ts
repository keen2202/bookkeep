import { Router } from 'express';
import { DbPool } from '../db/pool';
import { hashPassword, verifyPassword } from '../auth/password';
import { issueRefreshToken, rotateRefreshToken, signAccessToken } from '../auth/tokens';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

interface AuthDeps {
  pool: DbPool;
  jwtSecret: string;
}

export function authRouter({ pool, jwtSecret }: AuthDeps): Router {
  const router = Router();

  router.post('/register', async (req, res) => {
    const { email, password } = req.body ?? {};
    if (typeof email !== 'string' || !EMAIL_RE.test(email) || typeof password !== 'string' || password.length < 8) {
      res.status(400).json({ error: 'invalid_credentials' });
      return;
    }
    const passwordHash = await hashPassword(password);
    let userId: string;
    try {
      const result = await pool.query<{ id: string }>(
        'INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id',
        [email.toLowerCase(), passwordHash],
      );
      userId = result.rows[0].id;
    } catch (err) {
      if ((err as { code?: string }).code === '23505') {
        res.status(409).json({ error: 'email_taken' });
        return;
      }
      throw err;
    }

    // 账本由客户端首推时自动建（book.middleware 自选 book_id 语义，Spec §1.2 P0 default book）

    res.status(201).json({
      access_token: signAccessToken(userId, jwtSecret),
      refresh_token: await issueRefreshToken(pool, userId),
    });
  });

  router.post('/login', async (req, res) => {
    const { email, password } = req.body ?? {};
    if (typeof email !== 'string' || typeof password !== 'string') {
      res.status(400).json({ error: 'invalid_credentials' });
      return;
    }
    const rows = await pool.query<{ id: string; password_hash: string }>(
      'SELECT id, password_hash FROM users WHERE email = $1',
      [email.toLowerCase()],
    );
    if (rows.rows.length === 0) {
      res.status(401).json({ error: 'invalid_credentials' });
      return;
    }
    const { id, password_hash } = rows.rows[0];
    const ok = await verifyPassword(password, password_hash);
    if (!ok) {
      res.status(401).json({ error: 'invalid_credentials' });
      return;
    }
    res.status(200).json({
      access_token: signAccessToken(id, jwtSecret),
      refresh_token: await issueRefreshToken(pool, id),
    });
  });

  router.post('/refresh', async (req, res) => {
    const { refresh_token } = req.body ?? {};
    if (typeof refresh_token !== 'string') {
      res.status(401).json({ error: 'invalid_refresh_token' });
      return;
    }
    const pair = await rotateRefreshToken(pool, refresh_token, jwtSecret);
    if (!pair) {
      res.status(401).json({ error: 'invalid_refresh_token' });
      return;
    }
    res.status(200).json(pair);
  });

  return router;
}
