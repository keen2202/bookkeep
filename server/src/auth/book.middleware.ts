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
 * book 粒度鉴权（Spec §1.3）：账本不存在时自动建账并授权调用者为 owner（P0 default book
 * 客户端自选 book_id 语义）；账本存在但非成员 → 403；viewer 不可写 → 403。
 */
export function requireBookMember(pool: DbPool, opts: { allowWrite: boolean }) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const userId = req.user?.sub;
    if (!userId) {
      res.status(401).json({ error: 'unauthorized' });
      return;
    }
    const bookId = (opts.allowWrite ? req.body?.book_id : req.query.book_id) as unknown;
    if (typeof bookId !== 'string' || !UUID_RE.test(bookId)) {
      res.status(400).json({ error: 'book_id must be a uuid' });
      return;
    }
    const normalized = bookId.toLowerCase();

    const existing = await pool.query('SELECT id FROM books WHERE id = $1', [normalized]);
    if (existing.rows.length === 0) {
      // 并发首推同一 book_id 时 ON CONFLICT 兜底，避免唯一键冲突 500（评审 M5）
      await pool.query(
        "INSERT INTO books (id, name, type, owner_id) VALUES ($1, 'default', 'default', $2) ON CONFLICT (id) DO NOTHING",
        [normalized, userId],
      );
      await pool.query(
        "INSERT INTO book_members (book_id, user_id, role) VALUES ($1, $2, 'owner') ON CONFLICT DO NOTHING",
        [normalized, userId],
      );
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
