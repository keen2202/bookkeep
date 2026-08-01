import express from 'express';
import { authMiddleware } from './auth/middleware';
import { DbPool } from './db/pool';
import { authRouter } from './routes/auth.routes';
import { healthRouter } from './routes/health.routes';
import { syncRouter } from './routes/sync.routes';

export interface AppDeps {
  pool: DbPool;
  jwtSecret?: string;
}

export function createApp({ pool, jwtSecret = 'dev-secret' }: AppDeps) {
  const app = express();
  // 500 ops × 完整快照批次可能超默认 100kb（BK-T-007 评审 M2）
  app.use(express.json({ limit: '2mb' }));

  app.use('/health', healthRouter(pool));
  app.use('/auth', authRouter({ pool, jwtSecret }));
  app.use('/sync', authMiddleware(jwtSecret), syncRouter({ pool }));

  app.get('/api/protected', authMiddleware(jwtSecret), (req, res) => {
    res.json({ user: req.user });
  });

  return app;
}
