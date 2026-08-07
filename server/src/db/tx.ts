import type { PoolClient } from 'pg';
import { DbPool } from './pool';

/**
 * 在同一连接上执行 BEGIN/COMMIT/ROLLBACK，确保多写路径的事务性
 * （审查 B-4：pool.query('BEGIN') 每次调用独立借还连接，语句散落不同客户端）。
 * 所有多写路由必须经此封装（评审清单/CONTRIBUTING 约定）。
 */
export async function withTransaction<T>(
  pool: DbPool,
  fn: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const r = await fn(client);
    await client.query('COMMIT');
    return r;
  } catch (e) {
    try {
      await client.query('ROLLBACK');
    } catch {
      // ROLLBACK 失败（连接已断）时保留原始错误
    }
    throw e;
  } finally {
    client.release();
  }
}
