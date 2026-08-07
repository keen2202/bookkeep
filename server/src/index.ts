import { Pool } from 'pg';
import { createApp } from './app';

const port = Number(process.env.PORT ?? 3000);
const pool = new Pool({
  connectionString: process.env.DATABASE_URL ?? 'postgres://bookkeep:bookkeep_dev@localhost:5432/bookkeep',
});

// 密钥强制（审查 L-12）：JWT_SECRET 缺失拒绝启动（生产与开发一致，防弱密钥上线）
if (!process.env.JWT_SECRET) {
  console.error('JWT_SECRET is required');
  process.exit(1);
}
const app = createApp({ pool, jwtSecret: process.env.JWT_SECRET });

// 未捕获拒绝/异常兜底：记录后优雅退出（审查 L-12）
process.on('unhandledRejection', (reason) => {
  console.error('[fatal] unhandledRejection:', reason);
  shutdown(1);
});
process.on('uncaughtException', (err) => {
  console.error('[fatal] uncaughtException:', err);
  shutdown(1);
});

const server = app.listen(port, () => {
  console.log(`bookkeep server listening on :${port}`);
});

// SIGTERM 优雅停机（审查 L-12）：停止接新连接 → 释放连接池 → 退出
let shuttingDown = false;
function shutdown(code: number): void {
  if (shuttingDown) return;
  shuttingDown = true;
  server.close(() => {
    pool
      .end()
      .then(() => process.exit(code))
      .catch(() => process.exit(code));
  });
  // 兜底：10s 未完成则强制退出
  setTimeout(() => process.exit(code), 10_000).unref();
}
process.on('SIGTERM', () => shutdown(0));
process.on('SIGINT', () => shutdown(0));
