import request from 'supertest';
import jwt from 'jsonwebtoken';
import { Pool } from 'pg';
import { createApp } from '../src/app';
import { migrate } from '../src/db/migrate';

const DATABASE_URL =
  process.env.DATABASE_URL ?? 'postgres://bookkeep:bookkeep_dev@localhost:5432/bookkeep';
const SECRET = 'integration-secret';

describe('auth routes (integration, real PostgreSQL)', () => {
  let pool: Pool;

  beforeAll(async () => {
    pool = new Pool({ connectionString: DATABASE_URL });
    await migrate(pool);
  });

  afterAll(async () => {
    await pool.end();
  });

  const email = () => `auth-${crypto.randomUUID()}@test.local`;

  it('registers a user and returns a token pair', async () => {
    const app = createApp({ pool, jwtSecret: SECRET });
    const res = await request(app)
      .post('/auth/register')
      .send({ email: email(), password: 'password-123' });

    expect(res.status).toBe(201);
    expect(typeof res.body.access_token).toBe('string');
    expect(typeof res.body.refresh_token).toBe('string');
    const decoded = jwt.verify(res.body.access_token, SECRET) as { sub: string };
    expect(decoded.sub).toBeTruthy();
  });

  it('returns 409 for a duplicate email', async () => {
    const app = createApp({ pool, jwtSecret: SECRET });
    const mail = email();
    await request(app).post('/auth/register').send({ email: mail, password: 'password-123' });
    const res = await request(app).post('/auth/register').send({ email: mail, password: 'password-123' });

    expect(res.status).toBe(409);
  });

  it('rejects invalid credentials shape with 400', async () => {
    const app = createApp({ pool, jwtSecret: SECRET });
    const res = await request(app).post('/auth/register').send({ email: 'not-an-email', password: 'x' });
    expect(res.status).toBe(400);
  });

  it('logs in with valid credentials and rejects wrong ones', async () => {
    const app = createApp({ pool, jwtSecret: SECRET });
    const mail = email();
    await request(app).post('/auth/register').send({ email: mail, password: 'password-123' });

    const ok = await request(app).post('/auth/login').send({ email: mail, password: 'password-123' });
    expect(ok.status).toBe(200);
    expect(ok.body.access_token).toBeTruthy();

    const bad = await request(app).post('/auth/login').send({ email: mail, password: 'wrong-password' });
    expect(bad.status).toBe(401);

    const unknown = await request(app).post('/auth/login').send({ email: email(), password: 'password-123' });
    expect(unknown.status).toBe(401);
  });

  it('rotates the refresh token pair and invalidates the old token', async () => {
    const app = createApp({ pool, jwtSecret: SECRET });
    const mail = email();
    const reg = await request(app).post('/auth/register').send({ email: mail, password: 'password-123' });
    const oldRefresh = reg.body.refresh_token;

    const rotated = await request(app).post('/auth/refresh').send({ refresh_token: oldRefresh });
    expect(rotated.status).toBe(200);
    expect(rotated.body.access_token).toBeTruthy();
    expect(rotated.body.refresh_token).not.toBe(oldRefresh);

    const reuse = await request(app).post('/auth/refresh').send({ refresh_token: oldRefresh });
    expect(reuse.status).toBe(401);

    const again = await request(app).post('/auth/refresh').send({ refresh_token: rotated.body.refresh_token });
    expect(again.status).toBe(200);
  });

  it('rejects a garbage refresh token with 401', async () => {
    const app = createApp({ pool, jwtSecret: SECRET });
    const res = await request(app).post('/auth/refresh').send({ refresh_token: 'not-a-token' });
    expect(res.status).toBe(401);
  });

  it('allows only one concurrent rotation of the same refresh token', async () => {
    const app = createApp({ pool, jwtSecret: SECRET });
    const mail = email();
    const reg = await request(app).post('/auth/register').send({ email: mail, password: 'password-123' });
    const token = reg.body.refresh_token;

    const [a, b] = await Promise.all([
      request(app).post('/auth/refresh').send({ refresh_token: token }),
      request(app).post('/auth/refresh').send({ refresh_token: token }),
    ]);

    const statuses = [a.status, b.status].sort();
    expect(statuses).toEqual([200, 401]);
  });
});
