import express from 'express';
import { NextFunction, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { authMiddleware } from './auth/middleware';
import { booksRouter } from './books/books.routes';
import { DbPool } from './db/pool';
import { authRouter } from './routes/auth.routes';
import { healthRouter } from './routes/health.routes';
import { syncRouter } from './routes/sync.routes';

export interface AppDeps {
  pool: DbPool;
  jwtSecret?: string;
  /** CORS 白名单（审查 L-4）：缺省仅同源；生产经环境变量配置 */
  corsOrigins?: string[];
  /** 限流开关（审查 R-021）：集成测试注入 false 避免共享限流桶互扰；429 专项用例保持默认 */
  rateLimit?: boolean;
}

export function createApp({ pool, jwtSecret = 'dev-secret', corsOrigins, rateLimit }: AppDeps) {
  const app = express();
  // 500 ops × 完整快照批次可能超默认 100kb（BK-T-007 评审 M2）
  app.use(express.json({ limit: '2mb' }));

  // 安全基线（审查 L-4 / BK-R-012）：helmet 安全头 + CORS 白名单
  app.use(helmet());
  app.use(
    cors({
      origin: corsOrigins && corsOrigins.length > 0 ? corsOrigins : false,
      methods: ['GET', 'POST', 'PATCH', 'DELETE'],
    }),
  );

  app.use('/health', healthRouter(pool));
  app.use('/auth', authRouter({ pool, jwtSecret, rateLimit }));
  app.use('/books', authMiddleware(jwtSecret), booksRouter({ pool }));
  app.use('/sync', authMiddleware(jwtSecret), syncRouter({ pool, rateLimit }));

  app.get('/api/protected', authMiddleware(jwtSecret), (req, res) => {
    res.json({ user: req.user });
  });

  // 404 兜底：恒为 JSON（审查 L-10：禁 HTML 错误页）
  app.use((req, res) => {
    res.status(404).json({ error: 'not_found' });
  });

  // 统一 JSON 错误中间件（审查 L-10/L-12）：不泄露堆栈（非 production 输出错误码）
  app.use((err: unknown, req: Request, res: Response, next: NextFunction) => {
    if (res.headersSent) {
      next(err);
      return;
    }
    const status = (err as { status?: number })?.status ?? 500;
    if (status >= 500) {
      // eslint-disable-next-line no-console
      console.error('[error]', (err as Error)?.message ?? err);
    }
    res.status(status).json({
      error: status >= 500 ? 'internal_error' : ((err as { message?: string })?.message ?? 'error'),
    });
  });

  return app;
}
