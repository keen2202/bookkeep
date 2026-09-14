import { createHash, randomBytes } from 'crypto';
import jwt from 'jsonwebtoken';
import { DbPool } from '../db/pool';
import { withTransaction } from '../db/tx';

const ACCESS_TTL = '15m';
const REFRESH_TTL_INTERVAL = '30 days';

export function signAccessToken(userId: string, secret: string): string {
  return jwt.sign({ sub: userId }, secret, { expiresIn: ACCESS_TTL, algorithm: 'HS256' });
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
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, now() + interval '${REFRESH_TTL_INTERVAL}')`,
    [userId, hashToken(token)],
  );
  return token;
}

/** 校验 + 轮换：成功返回新 token 对；失败返回 null。撤销与签发同一事务（Spec R-10）。 */
export async function rotateRefreshToken(
  pool: DbPool,
  refreshToken: string,
  jwtSecret: string,
): Promise<{ access_token: string; refresh_token: string } | null> {
  const tokenHash = hashToken(refreshToken);
  const result = await withTransaction(pool, async (client) => {
    // 仅当令牌有效且未被撤销时才撤销并返回
    const rows = await client.query<{ user_id: string }>(
      `UPDATE refresh_tokens SET revoked_at = now()
       WHERE token_hash = $1 AND expires_at > now() AND revoked_at IS NULL
       RETURNING user_id`,
      [tokenHash],
    );
    if (rows.rows.length === 0) return null;

    const user_id = rows.rows[0].user_id;
    const nextToken = generateRefreshToken();
    await client.query(
      `INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, now() + interval '${REFRESH_TTL_INTERVAL}')`,
      [user_id, hashToken(nextToken)],
    );
    return { user_id, nextToken };
  });
  if (result === null) return null;

  // 顺带清理过期/已撤销超过 7 天的令牌（清理失败不得阻断轮换）
  try {
    await pool.query(
      `DELETE FROM refresh_tokens WHERE expires_at < now() OR (revoked_at IS NOT NULL AND revoked_at < now() - interval '7 days')`,
    );
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[warn] refresh token cleanup failed:', (err as Error)?.message ?? err);
  }

  return {
    access_token: signAccessToken(result.user_id, jwtSecret),
    refresh_token: result.nextToken,
  };
}
