import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { DbPool } from '../db/pool';
import { hashPassword, verifyPassword } from '../auth/password';
import { issueRefreshToken, rotateRefreshToken, signAccessToken } from '../auth/tokens';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_PASSWORD_LEN = 128;

// 登录/注册爆破防护（审查 L-4）：5 次/分钟/IP
const authRateLimit = rateLimit({
  windowMs: 60_000,
  limit: 5,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: { error: 'rate_limited' },
});

// 用户不存在时仍执行一次等成本 scrypt 校验（时序抹平，审查 L-4 时序差 < 20ms）；
// dummy 哈希惰性生成一次并缓存
let dummyHash: string | null = null;

async function timingEqualizer(password: string): Promise<void> {
  dummyHash ??= await hashPassword('dummy-password-00000000');
  await verifyPassword(password, dummyHash).catch(() => undefined);
}

interface AuthDeps {
  pool: DbPool;
  jwtSecret: string;
}

export function authRouter({ pool, jwtSecret }: AuthDeps): Router {
  const router = Router();
  router.use(authRateLimit);

  router.post('/register', async (req, res) => {
    const { email, password } = req.body ?? {};
    if (
      typeof email !== 'string' ||
      !EMAIL_RE.test(email) ||
      typeof password !== 'string' ||
      password.length < 8 ||
      password.length > MAX_PASSWORD_LEN
    ) {
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
    if (
      typeof email !== 'string' ||
      typeof password !== 'string' ||
      password.length > MAX_PASSWORD_LEN
    ) {
      res.status(400).json({ error: 'invalid_credentials' });
      return;
    }
    const rows = await pool.query<{ id: string; password_hash: string }>(
      'SELECT id, password_hash FROM users WHERE email = $1',
      [email.toLowerCase()],
    );
    if (rows.rows.length === 0) {
      // 用户不存在：仍执行等成本 scrypt 校验（时序抹平）
      await timingEqualizer(password);
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
