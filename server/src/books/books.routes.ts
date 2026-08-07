import { createHash, randomBytes, randomUUID } from 'crypto';
import { Router } from 'express';
import { requireBookMember, MemberRole } from '../auth/book.middleware';
import { DbPool } from '../db/pool';
import { withTransaction } from '../db/tx';

interface BooksDeps {
  pool: DbPool;
}

const INVITE_TTL_MS = 72 * 60 * 60 * 1000; // 72h（Spec §4.1 / BK-P1-001）
const INVITE_ROLES: MemberRole[] = ['editor', 'viewer'];

function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

/**
 * 账本 CRUD + 邀请（72h 一次性 token）+ 成员管理（Spec §4.1 / BK-P1-001）。
 * 权限矩阵：owner 管理成员；owner/editor 发邀请；viewer 只读（sync 层已拒绝写）。
 */
export function booksRouter({ pool }: BooksDeps): Router {
  const router = Router();

  /** 当前用户可见的账本列表（成员或 owner） */
  router.get('/', async (req, res) => {
    const userId = req.user?.sub;
    if (!userId) {
      res.status(401).json({ error: 'unauthorized' });
      return;
    }
    const rows = await pool.query(
      `SELECT b.id, b.name, b.type, b.owner_id, b.created_at, m.role
         FROM books b
         JOIN book_members m ON m.book_id = b.id
        WHERE m.user_id = $1
        ORDER BY b.created_at`,
      [userId],
    );
    res.json({ books: rows.rows });
  });

  /** 创建账本（场景模板：生活/家庭/旅行/生意），创建者为 owner */
  router.post('/', async (req, res) => {
    const userId = req.user?.sub;
    if (!userId) {
      res.status(401).json({ error: 'unauthorized' });
      return;
    }
    const name = req.body?.name;
    const type = req.body?.type ?? 'default';
    if (typeof name !== 'string' || name.trim().length === 0 || name.length > 30) {
      res.status(422).json({ error: 'name must be a non-empty string ≤ 30 chars' });
      return;
    }
    const bookId = randomUUID();
    await withTransaction(pool, async (client) => {
      await client.query(
        'INSERT INTO books (id, name, type, owner_id) VALUES ($1, $2, $3, $4)',
        [bookId, name.trim(), type, userId],
      );
      await client.query(
        "INSERT INTO book_members (book_id, user_id, role) VALUES ($1, $2, 'owner')",
        [bookId, userId],
      );
    });
    const row = await pool.query('SELECT * FROM books WHERE id = $1', [bookId]);
    res.status(201).json({ book: row.rows[0], role: 'owner' });
  });

  /** 成员列表（含邮箱；owner/editor 可管理，viewer 可查看） */
  router.get('/:bookId/members', requireBookMember(pool, { allowWrite: false }), async (req, res) => {
    const bookId = req.bookId as string;
    const rows = await pool.query(
      `SELECT m.user_id, m.role, m.created_at, u.email
         FROM book_members m
         JOIN users u ON u.id = m.user_id
        WHERE m.book_id = $1
        ORDER BY m.created_at`,
      [bookId],
    );
    res.json({ members: rows.rows });
  });

  /** 创建邀请（owner/editor）；返回一次性 token（72h），仅存 SHA-256 哈希 */
  router.post('/:bookId/invites', requireBookMember(pool, { allowWrite: true }), async (req, res) => {
    const bookId = req.bookId as string;
    const role = req.body?.role as MemberRole | undefined;
    if (role !== undefined && !INVITE_ROLES.includes(role)) {
      res.status(422).json({ error: 'role must be editor or viewer' });
      return;
    }
    const member = await pool.query<{ role: MemberRole }>(
      'SELECT role FROM book_members WHERE book_id = $1 AND user_id = $2',
      [bookId, req.user!.sub],
    );
    if (member.rows[0]?.role === 'viewer') {
      res.status(403).json({ error: 'viewer_cannot_invite' });
      return;
    }
    const token = randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + INVITE_TTL_MS);
    await pool.query(
      `INSERT INTO invite_tokens (token_hash, book_id, role, created_by, expires_at)
       VALUES ($1, $2, $3, $4, $5)`,
      [sha256(token), bookId, role ?? 'editor', req.user!.sub, expiresAt],
    );
    res.status(201).json({
      token,
      expires_at: expiresAt.toISOString(),
      book_id: bookId,
      role: role ?? 'editor',
    });
  });

  /** 接受邀请：一次性（used_at 标记），72h 过期拒绝 */
  router.post('/accept-invite', async (req, res) => {
    const userId = req.user?.sub;
    const token = req.body?.token;
    if (!userId) {
      res.status(401).json({ error: 'unauthorized' });
      return;
    }
    if (typeof token !== 'string' || token.length === 0) {
      res.status(422).json({ error: 'token required' });
      return;
    }
    const hash = sha256(token);
    // 单语句原子消耗 token（L-2）：used_at 置位与条件校验在同一 UPDATE 中，
    // 并发双请求仅一个能 RETURNING 出行，其余得到空集 → 409
    const invite = await withTransaction(pool, async (client) => {
      const row = await client.query<{ book_id: string; role: MemberRole }>(
        `UPDATE invite_tokens SET used_at = now()
         WHERE token_hash = $1 AND used_at IS NULL AND expires_at > now()
         RETURNING book_id, role`,
        [hash],
      );
      if (row.rows.length === 0) return null;
      // 已是成员则幂等更新角色（复用邀请不重复建行）
      await client.query(
        `INSERT INTO book_members (book_id, user_id, role) VALUES ($1, $2, $3)
         ON CONFLICT (book_id, user_id) DO UPDATE SET role = EXCLUDED.role`,
        [row.rows[0].book_id, userId, row.rows[0].role],
      );
      return row.rows[0];
    });
    if (invite === null) {
      res.status(409).json({ error: 'invalid_or_used_token' });
      return;
    }
    const book = await pool.query('SELECT id, name, type FROM books WHERE id = $1', [invite.book_id]);
    res.status(200).json({ book: book.rows[0], role: invite.role });
  });

  /** 移除成员（仅 owner；不能移除 owner 本人） */
  router.delete(
    '/:bookId/members/:userId',
    requireBookMember(pool, { allowWrite: true }),
    async (req, res) => {
      const bookId = req.bookId as string;
      const target = req.params.userId;
      const caller = req.user!.sub!;
      const callerRole = await pool.query<{ role: MemberRole }>(
        'SELECT role FROM book_members WHERE book_id = $1 AND user_id = $2',
        [bookId, caller],
      );
      if (callerRole.rows[0]?.role !== 'owner') {
        res.status(403).json({ error: 'owner_only' });
        return;
      }
      const targetRow = await pool.query<{ role: MemberRole }>(
        'SELECT role FROM book_members WHERE book_id = $1 AND user_id = $2',
        [bookId, target],
      );
      if (targetRow.rows.length === 0) {
        res.status(404).json({ error: 'member_not_found' });
        return;
      }
      if (targetRow.rows[0].role === 'owner') {
        res.status(422).json({ error: 'cannot_remove_owner' });
        return;
      }
      await pool.query('DELETE FROM book_members WHERE book_id = $1 AND user_id = $2', [
        bookId,
        target,
      ]);
      // 移除后其 pull/push 因成员缺失立即 403（Spec §4.1 验证标准）
      res.status(204).end();
    },
  );

  /** 变更成员角色（仅 owner；owner 角色不可被改） */
  router.patch(
    '/:bookId/members/:userId',
    requireBookMember(pool, { allowWrite: true }),
    async (req, res) => {
      const bookId = req.bookId as string;
      const target = req.params.userId;
      const caller = req.user!.sub!;
      const role = req.body?.role as MemberRole | undefined;
      // 目标角色白名单仅 editor/viewer（L-11：owner 不可经 API 制造/转移）
      if (role !== 'editor' && role !== 'viewer') {
        res.status(403).json({ error: 'owner_role_immutable' });
        return;
      }
      const callerRole = await pool.query<{ role: MemberRole }>(
        'SELECT role FROM book_members WHERE book_id = $1 AND user_id = $2',
        [bookId, caller],
      );
      if (callerRole.rows[0]?.role !== 'owner') {
        res.status(403).json({ error: 'owner_only' });
        return;
      }
      const targetRow = await pool.query<{ role: MemberRole }>(
        'SELECT role FROM book_members WHERE book_id = $1 AND user_id = $2',
        [bookId, target],
      );
      if (targetRow.rows.length === 0) {
        res.status(404).json({ error: 'member_not_found' });
        return;
      }
      if (targetRow.rows[0].role === 'owner') {
        res.status(422).json({ error: 'cannot_change_owner_role' });
        return;
      }
      await pool.query('UPDATE book_members SET role = $1 WHERE book_id = $2 AND user_id = $3', [
        role,
        bookId,
        target,
      ]);
      res.status(200).json({ user_id: target, role });
    },
  );

  return router;
}
