import { createHash, randomBytes } from 'crypto';
import jwt from 'jsonwebtoken';
import { DbPool } from '../db/pool';

const ACCESS_TTL = '15m';
const REFRESH_TTL_DAYS = 30;

export function signAccessToken(userId: string, secret: string): string {
  return jwt.sign({ sub: userId }, secret, { expiresIn: ACCESS_TTL });
}

export function generateRefreshToken(): string {
  return randomBytes(32).toString('base64url');
}

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export async function issueRefreshToken(pool: DbPool, userId: string): Promise<string> {
  const token = generateRefreshToken();
  await pool.query(
    'INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, now() + interval \'30 days\')',
    [userId, hashToken(token)],
  );
  return token;
}

/** 校验 + 轮换：成功返回新 token 对；失败返回 null。原子撤销避免并发竞态（BK-T-007 评审 H2）。 */
export async function rotateRefreshToken(
  pool: DbPool,
  refreshToken: string,
  jwtSecret: string,
): Promise<{ access_token: string; refresh_token: string } | null> {
  const tokenHash = hashToken(refreshToken);
  // 单语句原子轮换：仅当令牌有效且未被撤销时才撤销并返回
  const rows = await pool.query<{ user_id: string }>(
    `UPDATE refresh_tokens SET revoked_at = now()
     WHERE token_hash = $1 AND expires_at > now() AND revoked_at IS NULL
     RETURNING user_id`,
    [tokenHash],
  );
  if (rows.rows.length === 0) return null;

  // 顺带清理过期/已撤销超过 7 天的令牌
  await pool.query(
    `DELETE FROM refresh_tokens WHERE expires_at < now() OR (revoked_at IS NOT NULL AND revoked_at < now() - interval '7 days')`,
  );

  const user_id = rows.rows[0].user_id;
  const nextRefresh = await issueRefreshToken(pool, user_id);
  return { access_token: signAccessToken(user_id, jwtSecret), refresh_token: nextRefresh };
}
