import request from 'supertest';
import { Pool } from 'pg';
import { createApp } from '../src/app';

const DATABASE_URL =
  process.env.DATABASE_URL ?? 'postgres://bookkeep:bookkeep_dev@localhost:5432/bookkeep';

describe('GET /health/db (integration, real PostgreSQL)', () => {
  let pool: Pool;

  beforeAll(() => {
    pool = new Pool({ connectionString: DATABASE_URL });
  });

  afterAll(async () => {
    await pool.end();
  });

  it('reports connected against a live database', async () => {
    const app = createApp({ pool });
    const res = await request(app).get('/health/db');

    expect(res.status).toBe(200);
    expect(res.body.db).toBe('connected');
  });
});
