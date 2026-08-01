import { Pool } from 'pg';
import { DbPool } from './pool';
import { SCHEMA_SQL } from './schema';

export async function migrate(pool: DbPool): Promise<void> {
  await pool.query(SCHEMA_SQL);
}

// CLI: node dist/db/migrate.js（或 ts-node src/db/migrate.ts）
if (require.main === module) {
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
}
