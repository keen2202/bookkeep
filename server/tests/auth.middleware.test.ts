import request from 'supertest';
import jwt from 'jsonwebtoken';
import { createApp } from '../src/app';

const SECRET = 'test-secret';
const validToken = jwt.sign({ sub: 'user-1', bookId: 'book-1' }, SECRET, { expiresIn: '15m' });
const expiredToken = jwt.sign({ sub: 'user-1', bookId: 'book-1' }, SECRET, { expiresIn: '-1s' });

describe('JWT auth middleware', () => {
  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp({ pool: { query: jest.fn() }, jwtSecret: SECRET });
    const res = await request(app).get('/api/protected');

    expect(res.status).toBe(401);
  });

  it('returns 401 for a malformed token', async () => {
    const app = createApp({ pool: { query: jest.fn() }, jwtSecret: SECRET });
    const res = await request(app).get('/api/protected').set('Authorization', 'Bearer not-a-jwt');

    expect(res.status).toBe(401);
  });

  it('returns 401 for an expired token', async () => {
    const app = createApp({ pool: { query: jest.fn() }, jwtSecret: SECRET });
    const res = await request(app).get('/api/protected').set('Authorization', `Bearer ${expiredToken}`);

    expect(res.status).toBe(401);
  });

  it('accepts a valid token and exposes user on the request', async () => {
    const app = createApp({ pool: { query: jest.fn() }, jwtSecret: SECRET });
    const res = await request(app)
      .get('/api/protected')
      .set('Authorization', `Bearer ${validToken}`);

    expect(res.status).toBe(200);
    expect(res.body.user.sub).toBe('user-1');
    expect(res.body.user.bookId).toBe('book-1');
  });
});
