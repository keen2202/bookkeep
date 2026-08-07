import request from 'supertest';
import { Pool } from 'pg';
import { createApp } from '../src/app';
import { migrate } from '../src/db/migrate';
import { withTransaction } from '../src/db/tx';

jest.setTimeout(30_000);

const DATABASE_URL =
  process.env.DATABASE_URL ?? 'postgres://bookkeep:bookkeep_dev@localhost:5432/bookkeep_test';

describe('withTransaction (integration, real PostgreSQL)', () => {
  let pool: Pool;

  beforeAll(async () => {
    pool = new Pool({ connectionString: DATABASE_URL });
    await migrate(pool);
  });

  afterAll(async () => {
    await pool.end();
  });

  it('fn throws mid-transaction → no partial rows remain', async () => {
    const bookId = crypto.randomUUID();
    await expect(
      withTransaction(pool, async (client) => {
        await client.query(
          'INSERT INTO books (id, name, type, owner_id) VALUES ($1, $2, $3, (SELECT id FROM users LIMIT 1))',
          [bookId, 'tx-failure', 'default'],
        );
        throw new Error('boom after insert');
      }),
    ).rejects.toThrow('boom after insert');
    const rows = await pool.query('SELECT 1 FROM books WHERE id = $1', [bookId]);
    expect(rows.rows).toHaveLength(0);
  });

  it('POST /books fails mid-write (book_members insert) → no half-created book', async () => {
    const register = await request(appWithFailingMembersInsert()).post('/auth/register').send({
      email: `tx-route-${crypto.randomUUID().slice(0, 8)}@test.local`,
      password: 'password-123',
    });
    expect(register.status).toBe(201);
    const auth = { Authorization: `Bearer ${register.body.access_token}` };

    const res = await request(appWithFailingMembersInsert())
      .post('/books')
      .set(auth)
      .send({ name: '半提交账本' });
    // 第二写（book_members）抛错 → 500，且 books 无残留
    expect(res.status).toBe(500);

    const books = await pool.query("SELECT * FROM books WHERE name = '半提交账本'");
    expect(books.rows).toHaveLength(0);
  });
});

// 包装真实 pool：book_members INSERT 恒抛错，验证事务回滚路径
function appWithFailingMembersInsert() {
  const failing = {
    query: pool.query.bind(pool),
    connect: async () => {
      const client = await pool.connect();
      const orig = client.query.bind(client);
      const wrapped = (async (sql: string, params?: unknown[]) => {
        if (/INSERT INTO book_members/i.test(sql)) {
          throw new Error('injected book_members failure');
        }
        return orig(sql as never, params as never);
      }) as typeof client.query;
      return { ...client, query: wrapped };
    },
  };
  return createApp({ pool: failing, jwtSecret: 'tx-route-secret' });
}
