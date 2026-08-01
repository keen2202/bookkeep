import request from 'supertest';
import { createApp } from '../src/app';

describe('GET /health', () => {
  it('returns 200 with ok status, uptime and timestamp', async () => {
    const app = createApp({ pool: { query: jest.fn() } });
    const res = await request(app).get('/health');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(typeof res.body.uptime).toBe('number');
    expect(typeof res.body.timestamp).toBe('string');
  });

  it('returns 200 with db connected when pool query succeeds', async () => {
    const pool = { query: jest.fn().mockResolvedValue({ rows: [{ '?column?': 1 }] }) };
    const app = createApp({ pool });
    const res = await request(app).get('/health/db');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.db).toBe('connected');
    expect(pool.query).toHaveBeenCalledWith('SELECT 1');
  });

  it('returns 503 with db unreachable when pool query fails', async () => {
    const pool = { query: jest.fn().mockRejectedValue(new Error('connection refused')) };
    const app = createApp({ pool });
    const res = await request(app).get('/health/db');

    expect(res.status).toBe(503);
    expect(res.body.status).toBe('error');
    expect(res.body.db).toBe('unreachable');
  });
});
