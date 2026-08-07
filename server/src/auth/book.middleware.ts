import { NextFunction, Request, Response } from 'express';
import { DbPool } from '../db/pool';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type MemberRole = 'owner' | 'editor' | 'viewer';

declare global {
  namespace Express {
    interface Request {
      bookId?: string;
    }
  }
}

/**
 * book 粒度鉴权（Spec §1.3）：仅 sync push 路径允许自动建账并授权调用者为 owner
 * （P0 default book 客户端自选 book_id 语义）；其余路径（pull / 成员管理）对不存在
 * 的账本返回 404，GET 无副作用（审查 L-1）。账本存在但非成员 → 403；viewer 不可写 → 403。
 */
export function requireBookMember(pool: DbPool, opts: { allowWrite: boolean; autoCreate?: boolean }) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const userId = req.user?.sub;
    if (!userId) {
      res.status(401).json({ error: 'unauthorized' });
      return;
    }
    // book 来源：body.book_id（sync push）/ query.book_id（sync pull）/ 路径参数 :bookId（成员管理，BK-T-010）
    const bookId = (
      opts.allowWrite
        ? (req.body?.book_id ?? req.params.bookId)
        : (req.query.book_id ?? req.params.bookId)
    ) as unknown;
    if (typeof bookId !== 'string' || !UUID_RE.test(bookId)) {
      res.status(400).json({ error: 'book_id must be a uuid' });
      return;
    }
    const normalized = bookId.toLowerCase();

    const existing = await pool.query('SELECT id FROM books WHERE id = $1', [normalized]);
    if (existing.rows.length === 0) {
      if (!opts.autoCreate) {
        res.status(404).json({ error: 'book_not_found' });
        return;
      }
      // 并发首推同一 book_id：ON CONFLICT 兜底 + one_owner_per_book 部分唯一索引
      // 保证仅一人成为 owner；失败者（非成员）在此被 403 拦截（评审 M5 / L-1）
      await pool.query(
        "INSERT INTO books (id, name, type, owner_id) VALUES ($1, 'default', 'default', $2) ON CONFLICT (id) DO NOTHING",
        [normalized, userId],
      );
      await pool.query(
        "INSERT INTO book_members (book_id, user_id, role) VALUES ($1, $2, 'owner') ON CONFLICT DO NOTHING",
        [normalized, userId],
      );
      const race = await pool.query<{ role: MemberRole }>(
        'SELECT role FROM book_members WHERE book_id = $1 AND user_id = $2',
        [normalized, userId],
      );
      if (race.rows.length === 0) {
        res.status(403).json({ error: 'forbidden' });
        return;
      }
      req.bookId = normalized;
      next();
      return;
    }

    const member = await pool.query<{ role: MemberRole }>(
      'SELECT role FROM book_members WHERE book_id = $1 AND user_id = $2',
      [normalized, userId],
    );
    if (member.rows.length === 0) {
      res.status(403).json({ error: 'forbidden' });
      return;
    }
    if (opts.allowWrite && member.rows[0].role === 'viewer') {
      res.status(403).json({ error: 'viewer_cannot_write' });
      return;
    }
    req.bookId = normalized;
    next();
  };
}
