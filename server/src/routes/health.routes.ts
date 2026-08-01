import { Router } from 'express';
import { DbPool } from '../db/pool';

export function healthRouter(pool: DbPool): Router {
  const router = Router();

  router.get('/', (_req, res) => {
    res.json({ status: 'ok', uptime: process.uptime(), timestamp: new Date().toISOString() });
  });

  router.get('/db', async (_req, res) => {
    try {
      await pool.query('SELECT 1');
      res.json({ status: 'ok', db: 'connected' });
    } catch {
      res.status(503).json({ status: 'error', db: 'unreachable' });
    }
  });

  return router;
}
