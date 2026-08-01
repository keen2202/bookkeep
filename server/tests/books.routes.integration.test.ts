import { createHash } from 'crypto';
import request from 'supertest';
import jwt from 'jsonwebtoken';
import { Pool } from 'pg';
import { createApp } from '../src/app';
import { migrate } from '../src/db/migrate';

const DATABASE_URL =
  process.env.DATABASE_URL ?? 'postgres://bookkeep:bookkeep_dev@localhost:5432/bookkeep';
const SECRET = 'books-integration-secret';

interface Tokens {
  access_token: string;
  refresh_token: string;
}

async function registerUser(app: ReturnType<typeof createApp>, email: string, password: string): Promise<Tokens> {
  const res = await request(app).post('/auth/register').send({ email, password });
  expect(res.status).toBe(201);
  return res.body as Tokens;
}

const CLIENT = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

describe('books routes (integration, real PostgreSQL)', () => {
  let pool: Pool;
  let app: ReturnType<typeof createApp>;
  let owner: Tokens;
  let collaborator: Tokens;
  let outsider: Tokens;
  let bookId: string;

  beforeAll(async () => {
    pool = new Pool({ connectionString: DATABASE_URL });
    await migrate(pool);
    app = createApp({ pool, jwtSecret: SECRET });
    const suffix = crypto.randomUUID().slice(0, 8);
    owner = await registerUser(app, `bk-owner-${suffix}@test.local`, 'password-123');
    collaborator = await registerUser(app, `bk-collab-${suffix}@test.local`, 'password-123');
    outsider = await registerUser(app, `bk-out-${suffix}@test.local`, 'password-123');
  });

  afterAll(async () => {
    await pool.end();
  });

  const authed = (tokens: Tokens) => ({ Authorization: `Bearer ${tokens.access_token}` });

  const subOf = (tokens: Tokens): string => {
    const payload = jwt.decode(tokens.access_token) as { sub: string };
    return payload.sub;
  };

  describe('POST /books', () => {
    it('creates a book with the caller as owner and lists it', async () => {
      const res = await request(app)
        .post('/books')
        .set(authed(owner))
        .send({ name: '家庭账本', type: 'family' });
      expect(res.status).toBe(201);
      expect(res.body.role).toBe('owner');
      expect(res.body.book.name).toBe('家庭账本');
      bookId = res.body.book.id;

      const list = await request(app).get('/books').set(authed(owner));
      expect(list.status).toBe(200);
      expect(list.body.books.map((b: { id: string }) => b.id)).toContain(bookId);
    });

    it('rejects empty/overlong names', async () => {
      const bad = await request(app).post('/books').set(authed(owner)).send({ name: '  ' });
      expect(bad.status).toBe(422);
      const long = await request(app)
        .post('/books')
        .set(authed(owner))
        .send({ name: 'x'.repeat(31) });
      expect(long.status).toBe(422);
    });
  });

  describe('invite flow (72h one-time token)', () => {
    it('owner creates invite; collaborator accepts and gets editor role', async () => {
      const invite = await request(app)
        .post(`/books/${bookId}/invites`)
        .set(authed(owner))
        .send({ role: 'editor' });
      expect(invite.status).toBe(201);
      expect(invite.body.token).toMatch(/^[0-9a-f]{64}$/);
      const expires = new Date(invite.body.expires_at).getTime();
      expect(expires - Date.now()).toBeGreaterThan(71 * 3600 * 1000);
      expect(expires - Date.now()).toBeLessThanOrEqual(72 * 3600 * 1000 + 5000);

      const accept = await request(app)
        .post('/books/accept-invite')
        .set(authed(collaborator))
        .send({ token: invite.body.token });
      expect(accept.status).toBe(200);
      expect(accept.body.book.id).toBe(bookId);
      expect(accept.body.role).toBe('editor');
    });

    it('editor can push; viewer cannot write (403)', async () => {
      await request(app)
        .post(`/books/${bookId}/invites`)
        .set(authed(owner))
        .send({ role: 'viewer' })
        .then(async (invite) => {
          await request(app)
            .post('/books/accept-invite')
            .set(authed(outsider))
            .send({ token: invite.body.token });
        });

      const pushEditor = await request(app)
        .post('/sync/push')
        .set(authed(collaborator))
        .send({
          book_id: bookId,
          ops: [
            {
              entity: 'transaction',
              entity_id: crypto.randomUUID(),
              op: 'c',
              payload: { amount_minor: 100 },
              lamport: 1,
              client_id: CLIENT,
            },
          ],
        });
      expect(pushEditor.status).toBe(200);

      const pushViewer = await request(app)
        .post('/sync/push')
        .set(authed(outsider))
        .send({ book_id: bookId, ops: [] });
      expect(pushViewer.status).toBe(403);
    });

    it('token is one-time: reuse rejected with 409', async () => {
      const invite = await request(app)
        .post(`/books/${bookId}/invites`)
        .set(authed(owner))
        .send({ role: 'viewer' });
      const token = invite.body.token as string;
      await request(app).post('/books/accept-invite').set(authed(outsider)).send({ token });
      const reuse = await request(app).post('/books/accept-invite').set(authed(outsider)).send({ token });
      expect(reuse.status).toBe(409);
    });

    it('invalid token rejected; expired token rejected (410)', async () => {
      const invalid = await request(app)
        .post('/books/accept-invite')
        .set(authed(outsider))
        .send({ token: 'ffff'.repeat(16) });
      expect(invalid.status).toBe(404);

      const invite = await request(app)
        .post(`/books/${bookId}/invites`)
        .set(authed(owner))
        .send({ role: 'viewer' });
      await pool.query(
        'UPDATE invite_tokens SET expires_at = now() - interval \'1 hour\' WHERE token_hash = $1',
        [createHash('sha256').update(invite.body.token).digest('hex')],
      );
      const expired = await request(app)
        .post('/books/accept-invite')
        .set(authed(outsider))
        .send({ token: invite.body.token });
      expect(expired.status).toBe(410);
    });

    it('viewer cannot create invites (403)', async () => {
      const res = await request(app).post(`/books/${bookId}/invites`).set(authed(outsider));
      expect(res.status).toBe(403);
    });
  });

  describe('member management (owner only)', () => {
    it('lists members with emails', async () => {
      const res = await request(app).get(`/books/${bookId}/members`).set(authed(owner));
      expect(res.status).toBe(200);
      const emails = res.body.members.map((m: { email: string }) => m.email);
      expect(emails.length).toBeGreaterThanOrEqual(3);
    });

    it('editor cannot remove members (403 owner_only)', async () => {
      const res = await request(app)
        .delete(`/books/${bookId}/members/${subOf(outsider)}`)
        .set(authed(collaborator));
      expect(res.status).toBe(403);
    });

    it('owner cannot remove owner', async () => {
      const res = await request(app)
        .delete(`/books/${bookId}/members/${subOf(owner)}`)
        .set(authed(owner));
      expect(res.status).toBe(422);
    });

    it('removed member loses access immediately: pull returns 403', async () => {
      // outsider 以 viewer 身份邀请加入（通过另一一次性 token）
      const invite = await request(app)
        .post(`/books/${bookId}/invites`)
        .set(authed(owner))
        .send({ role: 'viewer' });
      await request(app).post('/books/accept-invite').set(authed(outsider)).send({ token: invite.body.token });

      const before = await request(app).get(`/sync/pull?book_id=${bookId}&since_seq=0`).set(authed(outsider));
      expect(before.status).toBe(200);

      const rm = await request(app)
        .delete(`/books/${bookId}/members/${subOf(outsider)}`)
        .set(authed(owner));
      expect(rm.status).toBe(204);

      const after = await request(app).get(`/sync/pull?book_id=${bookId}&since_seq=0`).set(authed(outsider));
      expect(after.status).toBe(403);
    });

    it('owner can change role editor -> viewer', async () => {
      const change = await request(app)
        .patch(`/books/${bookId}/members/${subOf(collaborator)}`)
        .set(authed(owner))
        .send({ role: 'viewer' });
      expect(change.status).toBe(200);
      const pushNow = await request(app)
        .post('/sync/push')
        .set(authed(collaborator))
        .send({ book_id: bookId, ops: [] });
      expect(pushNow.status).toBe(403);
      // 恢复 editor，避免影响其他用例
      await request(app)
        .patch(`/books/${bookId}/members/${subOf(collaborator)}`)
        .set(authed(owner))
        .send({ role: 'editor' });
    });
  });

  describe('book isolation', () => {
    it('ops pushed to book A are not visible when pulling book B', async () => {
      const other = await request(app)
        .post('/books')
        .set(authed(owner))
        .send({ name: '生意账本', type: 'business' });
      const otherId = other.body.book.id as string;
      const entityId = crypto.randomUUID();
      await request(app)
        .post('/sync/push')
        .set(authed(owner))
        .send({
          book_id: bookId,
          ops: [
            {
              entity: 'transaction',
              entity_id: entityId,
              op: 'c',
              payload: { amount_minor: 999 },
              lamport: 2,
              client_id: CLIENT,
            },
          ],
        });
      const pullA = await request(app).get(`/sync/pull?book_id=${bookId}&since_seq=0`).set(authed(owner));
      expect(pullA.body.ops.map((o: { entity_id: string }) => o.entity_id)).toContain(entityId);

      const pullB = await request(app).get(`/sync/pull?book_id=${otherId}&since_seq=0`).set(authed(owner));
      expect(pullB.body.ops.map((o: { entity_id: string }) => o.entity_id)).not.toContain(entityId);
    });
  });
});
