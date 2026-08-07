import { Pool } from 'pg';
import { migrate } from './migrate';

// CLI 引导（独立文件：migrate.ts 保持纯函数可测，Jest 覆盖率不统计本文件）
// 用法：npm run migrate（或 node dist/db/migrate-cli.js）
const pool = new Pool({
  connectionString: process.env.DATABASE_URL ?? 'postgres://bookkeep:bookkeep_dev@localhost:5432/bookkeep',
});
migrate(pool)
  .then(() => {
    console.log('schema migrated');
    return pool.end();
  })
  .catch((err) => {
    console.error('migration failed:', err);
    process.exitCode = 1;
    return pool.end();
  });
