import request from 'supertest';
import jwt from 'jsonwebtoken';
import { Pool } from 'pg';
import { createApp } from '../src/app';
import { migrate } from '../src/db/migrate';

jest.setTimeout(30_000);

const DATABASE_URL =
  process.env.DATABASE_URL ?? 'postgres://bookkeep:bookkeep_dev@localhost:5432/bookkeep_test';
const SECRET = 'sync-integration-secret';

interface Tokens {
  access_token: string;
  refresh_token: string;
}

async function registerUser(app: ReturnType<typeof createApp>, email: string, password: string): Promise<Tokens> {
  const res = await request(app).post('/auth/register').send({ email, password });
  expect(res.status).toBe(201);
  return res.body as Tokens;
}

// 每次运行随机 book id：避免跨运行残留数据影响成员鉴权（固定 id 会复用于新用户）
const BOOK = crypto.randomUUID();
const CLIENT_A = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const CLIENT_B = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

function op(entityId: string, overrides: Record<string, unknown> = {}) {
  return {
    entity: 'transaction',
    entity_id: entityId,
    op: 'c' as const,
    payload: { amount_minor: 100, note: 'test' },
    lamport: 1,
    client_id: CLIENT_A,
    ...overrides,
  };
}

describe('sync routes (integration, real PostgreSQL)', () => {
  let pool: Pool;
  let app: ReturnType<typeof createApp>;
  let userA: Tokens;
  let userB: Tokens;

  beforeAll(async () => {
    pool = new Pool({ connectionString: DATABASE_URL });
    await migrate(pool);
    app = createApp({ pool, jwtSecret: SECRET });
    const suffix = crypto.randomUUID().slice(0, 8);
    userA = await registerUser(app, `sync-a-${suffix}@test.local`, 'password-123');
    userB = await registerUser(app, `sync-b-${suffix}@test.local`, 'password-123');
  });

  afterAll(async () => {
    await pool.end();
  });

  const authed = (tokens: Tokens) => ({ Authorization: `Bearer ${tokens.access_token}` });

  describe('POST /sync/push', () => {
    it('accepts a batch and returns the last accepted seq', async () => {
      const res = await request(app)
        .post('/sync/push')
        .set(authed(userA))
        .send({ book_id: BOOK, ops: [op('11111111-1111-4111-8111-111111111111', { lamport: 1 })] });

      expect(res.status).toBe(200);
      expect(res.body.accepted).toBe(1);
      expect(res.body.accepted_seq).toBeGreaterThan(0);
    });

    it('deduplicates identical ops and counts only new ones', async () => {
      const ops = [
        op('22222222-2222-4222-8222-222222222222', { lamport: 1 }),
        op('22222222-2222-4222-8222-222222222222', { lamport: 1 }),
        op('33333333-3333-4333-8333-333333333333', { lamport: 2 }),
      ];
      const first = await request(app).post('/sync/push').set(authed(userA)).send({ book_id: BOOK, ops });
      expect(first.body.accepted).toBe(2);

      const again = await request(app).post('/sync/push').set(authed(userA)).send({ book_id: BOOK, ops });
      expect(again.status).toBe(200);
      expect(again.body.accepted).toBe(0);
      expect(again.body.accepted_seq).toBe(first.body.accepted_seq);
    });

    it('rejects a batch with validation errors as 422', async () => {
      const bad = await request(app)
        .post('/sync/push')
        .set(authed(userA))
        .send({ book_id: BOOK, ops: [op('44444444-4444-4444-8444-444444444444', { op: 'x' })] });
      expect(bad.status).toBe(422);

      const empty = await request(app).post('/sync/push').set(authed(userA)).send({ book_id: BOOK, ops: [] });
      expect(empty.status).toBe(422);
    });

    it('rejects cross-book access with 403', async () => {
      const res = await request(app)
        .post('/sync/push')
        .set(authed(userB))
        .send({ book_id: BOOK, ops: [op('55555555-5555-4555-8555-555555555555')] });
      expect(res.status).toBe(403);
    });

    it('rejects pushes from a viewer role with 403', async () => {
      const userAId = (jwt.decode(userA.access_token) as { sub: string }).sub;
      const userBId = (jwt.decode(userB.access_token) as { sub: string }).sub;
      const book = (await pool.query('SELECT id FROM books WHERE owner_id = $1', [userAId])).rows[0];
      // user B 以 viewer 身份加入 A 的账本
      await pool.query('INSERT INTO book_members (book_id, user_id, role) VALUES ($1, $2, $3)', [book.id, userBId, 'viewer']);
      const res = await request(app)
        .post('/sync/push')
        .set(authed(userB))
        .send({ book_id: book.id, ops: [op('66666666-6666-4666-8666-666666666666')] });
      expect(res.status).toBe(403);
      // viewer 可拉取
      const pull = await request(app).get('/sync/pull').set(authed(userB)).query({ book_id: book.id, since_seq: 0 });
      expect(pull.status).toBe(200);
      // 清理测试数据：删除该成员
      await pool.query('DELETE FROM book_members WHERE book_id = $1 AND user_id = $2', [book.id, userBId]);
    });

    it('auto-provisions a fresh book for the caller on first push', async () => {
      const freshBook = crypto.randomUUID();
      const res = await request(app)
        .post('/sync/push')
        .set(authed(userB))
        .send({ book_id: freshBook, ops: [op('77777777-7777-4777-8777-777777777777')] });
      expect(res.status).toBe(200);
      const members = await pool.query('SELECT role FROM book_members WHERE book_id = $1 AND user_id = $2', [
        freshBook,
        (jwt.decode(userB.access_token) as { sub: string }).sub,
      ]);
      expect(members.rows[0].role).toBe('owner');
    });

    it('concurrent first-push on the same book_id: exactly one owner (unique index)', async () => {
      const racedBook = crypto.randomUUID();
      const payload = { book_id: racedBook, ops: [op(crypto.randomUUID())] };
      const [a, b] = await Promise.all([
        request(app).post('/sync/push').set(authed(userA)).send(payload),
        request(app).post('/sync/push').set(authed(userB)).send(payload),
      ]);
      const owners = await pool.query<{ user_id: string }>(
        "SELECT user_id FROM book_members WHERE book_id = $1 AND role = 'owner'",
        [racedBook],
      );
      expect(owners.rows).toHaveLength(1);
      const succeeded = [a, b].filter((r) => r.status === 200);
      const forbidden = [a, b].filter((r) => r.status === 403);
      expect(succeeded.length + forbidden.length).toBe(2);
      expect(forbidden.length).toBeGreaterThanOrEqual(0);
    });
  });

  describe('GET /sync/pull', () => {
    it('returns ops since the cursor with the next cursor', async () => {
      const push = await request(app)
        .post('/sync/push')
        .set(authed(userA))
        .send({ book_id: BOOK, ops: [op('88888888-8888-4888-8888-888888888888', { lamport: 3 })] });
      const seq = push.body.accepted_seq;

      const pull = await request(app).get('/sync/pull').set(authed(userA)).query({ book_id: BOOK, since_seq: seq });
      expect(pull.status).toBe(200);
      expect(pull.body.ops).toHaveLength(0);
      expect(pull.body.next_seq).toBe(seq);
    });

    it('paginates with the limit parameter', async () => {
      const bookId = `9${crypto.randomUUID().slice(1)}`;
      const ids = ['99999999-9999-4999-8999-999999999990', '99999999-9999-4999-8999-999999999991', '99999999-9999-4999-8999-999999999992'];
      const batch = ids.map((entityId, i) => op(entityId, { lamport: i + 1, client_id: crypto.randomUUID() }));
      await request(app).post('/sync/push').set(authed(userA)).send({ book_id: bookId, ops: batch });
      // 安全窗口：op 提交满 2 秒才可被拉取（审查 L-3）
      await new Promise((r) => setTimeout(r, 2300));

      const page1 = await request(app).get('/sync/pull').set(authed(userA)).query({ book_id: bookId, since_seq: 0, limit: 2 });
      expect(page1.status).toBe(200);
      expect(page1.body.ops).toHaveLength(2);
      const page2 = await request(app).get('/sync/pull').set(authed(userA)).query({ book_id: bookId, since_seq: page1.body.next_seq });
      expect(page2.body.ops).toHaveLength(1);
    });

    it('rejects cross-book pull with 403', async () => {
      const res = await request(app).get('/sync/pull').set(authed(userB)).query({ book_id: BOOK, since_seq: 0 });
      expect(res.status).toBe(403);
    });

    it('rejects a missing or invalid since_seq with 400', async () => {
      const res = await request(app).get('/sync/pull').set(authed(userA)).query({ book_id: BOOK });
      expect(res.status).toBe(400);
    });

    it('safety window: fresh ops invisible for 2s, visible after, server_time present (L-3)', async () => {
      const bookId = `a${crypto.randomUUID().slice(1)}`;
      const entityId = `aaaa${crypto.randomUUID().slice(4)}`;
      await request(app).post('/sync/push').set(authed(userA)).send({
        book_id: bookId,
        ops: [op(entityId, { lamport: 1 })],
      });
      // 提交未满 2 秒：不可见，游标不前进
      const fresh = await request(app).get('/sync/pull').set(authed(userA)).query({ book_id: bookId, since_seq: 0 });
      expect(fresh.status).toBe(200);
      expect(fresh.body.ops).toHaveLength(0);
      expect(fresh.body.next_seq).toBe(0);
      expect(typeof fresh.body.server_time).toBe('string');
      // 满 2 秒后可见
      await new Promise((r) => setTimeout(r, 2300));
      const settled = await request(app).get('/sync/pull').set(authed(userA)).query({ book_id: bookId, since_seq: 0 });
      expect(settled.body.ops.map((o: { entity_id: string }) => o.entity_id)).toContain(entityId);
      expect(settled.body.next_seq).toBeGreaterThan(0);
    });

    it('pulling a non-existent book returns 404 and creates nothing (GET side-effect-free)', async () => {
      const ghost = crypto.randomUUID();
      const res = await request(app).get('/sync/pull').set(authed(userA)).query({ book_id: ghost, since_seq: 0 });
      expect(res.status).toBe(404);
      const book = await pool.query('SELECT 1 FROM books WHERE id = $1', [ghost]);
      expect(book.rows).toHaveLength(0);
      const member = await pool.query('SELECT 1 FROM book_members WHERE book_id = $1', [ghost]);
      expect(member.rows).toHaveLength(0);
    });
  });

  describe('dual-client consistency and stress', () => {
    it('lets two clients converge on the same op set and dedupe under replay', async () => {
      const bookId = `e${crypto.randomUUID().slice(1)}`;
      const ops = Array.from({ length: 20 }, (_, i) => ({
        entity: 'transaction',
        entity_id: `eeeeeeee-eeee-4eee-8eee-${String(i).padStart(12, '0')}`,
        op: 'c' as const,
        payload: { amount_minor: i * 100 },
        lamport: i + 1,
        client_id: i % 2 === 0 ? CLIENT_A : CLIENT_B,
      }));

      const pushA = await request(app).post('/sync/push').set(authed(userA)).send({ book_id: bookId, ops: ops.slice(0, 10) });
      expect(pushA.body.accepted).toBe(10);

      // 共享账本：user B 以 editor 身份加入（P0 无邀请 API，直接建成员关系）
      const userBId = (jwt.decode(userB.access_token) as { sub: string }).sub;
      await pool.query("INSERT INTO book_members (book_id, user_id, role) VALUES ($1, $2, 'editor')", [bookId, userBId]);

      const pushB = await request(app).post('/sync/push').set(authed(userB)).send({ book_id: bookId, ops: ops.slice(10) });
      expect(pushB.body.accepted).toBe(10);
      // 安全窗口：等待全部 op 提交满 2 秒（审查 L-3）
      await new Promise((r) => setTimeout(r, 2300));

      // 双方各自完整拉取：内容一致、无重复
      const pullA = await request(app).get('/sync/pull').set(authed(userA)).query({ book_id: bookId, since_seq: 0 });
      const pullB = await request(app).get('/sync/pull').set(authed(userB)).query({ book_id: bookId, since_seq: 0 });
      expect(pullA.body.ops).toHaveLength(20);
      expect(pullB.body.ops).toHaveLength(20);

      const keyA = pullA.body.ops.map((o: { id: unknown }) => o.id).sort();
      const keyB = pullB.body.ops.map((o: { id: unknown }) => o.id).sort();
      expect(keyA).toEqual(keyB);

      // 双方各自重放一遍（幂等）：服务端不再接受重复
      const replay = await request(app).post('/sync/push').set(authed(userA)).send({ book_id: bookId, ops });
      expect(replay.body.accepted).toBe(0);
    });

    it('handles 1000 ops in batches without loss or duplicates', async () => {
      const bookId = `f${crypto.randomUUID().slice(1)}`;
      const total = 1000;
      const ops = Array.from({ length: total }, (_, i) => ({
        entity: 'transaction',
        entity_id: `ffffffff-ffff-4fff-8fff-${String(i).padStart(12, '0')}`,
        op: 'c' as const,
        payload: { amount_minor: i },
        lamport: i + 1,
        client_id: CLIENT_A,
      }));

      let accepted = 0;
      for (let start = 0; start < total; start += 500) {
        const res = await request(app)
          .post('/sync/push')
          .set(authed(userA))
          .send({ book_id: bookId, ops: ops.slice(start, start + 500) });
        expect(res.status).toBe(200);
        accepted += res.body.accepted;
      }
      expect(accepted).toBe(total);
      // 安全窗口：等待全部 op 提交满 2 秒（审查 L-3）
      await new Promise((r) => setTimeout(r, 2300));

      const seen = new Set<string>();
      let cursor = 0;
      for (;;) {
        const pull = await request(app)
          .get('/sync/pull')
          .set(authed(userA))
          .query({ book_id: bookId, since_seq: cursor, limit: 500 });
        expect(pull.status).toBe(200);
        for (const o of pull.body.ops) {
          expect(seen.has(o.entity_id)).toBe(false);
          seen.add(o.entity_id);
        }
        if (pull.body.ops.length === 0) break;
        cursor = pull.body.next_seq;
      }
      expect(seen.size).toBe(total);
    });
  });
});
