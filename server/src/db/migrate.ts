import { Pool } from 'pg';
import { SCHEMA_SQL } from './schema';

// Fixed per-database advisory lock id ("book" = 0x626F6F6B); serializes concurrent
// migrate() calls (integration suites run in parallel Jest workers).
const MIGRATE_LOCK_ID = 1650557803;

export async function migrate(pool: Pool): Promise<void> {
  // Advisory lock is session-scoped: the DDL must share the connection holding it.
  const client = await pool.connect();
  try {
    await client.query('SELECT pg_advisory_lock($1::bigint)', [MIGRATE_LOCK_ID]);
    try {
      await client.query(SCHEMA_SQL);
    } finally {
      await client.query('SELECT pg_advisory_unlock($1::bigint)', [MIGRATE_LOCK_ID]);
    }
  } finally {
    client.release();
  }
}
