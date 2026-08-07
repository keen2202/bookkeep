import { DbPool } from '../db/pool';
import { SyncOp } from './validate';

export interface StoredOp {
  id: number;
  entity: string;
  entity_id: string;
  op: 'c' | 'u' | 'd';
  payload: Record<string, unknown> | null;
  lamport: number;
  client_id: string;
}

export interface PushResult {
  accepted: number;
  acceptedSeq: number;
}

/**
 * 单条 INSERT..ON CONFLICT 语句原子落批（Spec §3.6：服务端事务内批量落 op，
 * PostgreSQL 单语句天然原子）；按 (book_id, entity, entity_id, lamport, client_id) 去重。
 */
export async function pushOps(pool: DbPool, bookId: string, ops: SyncOp[]): Promise<PushResult> {
  const result = await pool.query<{ id: number }>(
    `INSERT INTO sync_ops (book_id, entity, entity_id, op, payload, lamport, client_id)
     SELECT * FROM UNNEST($1::uuid[], $2::text[], $3::text[], $4::text[], $5::jsonb[], $6::int[], $7::text[])
     ON CONFLICT (book_id, entity, entity_id, lamport, client_id) DO NOTHING
     RETURNING id`,
    [
      ops.map(() => bookId),
      ops.map((o) => o.entity),
      ops.map((o) => o.entity_id),
      ops.map((o) => o.op),
      ops.map((o) => JSON.stringify(o.payload)),
      ops.map((o) => o.lamport),
      ops.map((o) => o.client_id),
    ],
  );

  if (result.rows.length === 0) {
    const max = await pool.query<{ m: number }>(
      'SELECT COALESCE(MAX(id), 0) AS m FROM sync_ops WHERE book_id = $1',
      [bookId],
    );
    return { accepted: 0, acceptedSeq: Number(max.rows[0].m) };
  }

  const ids = result.rows.map((r) => Number(r.id));
  return { accepted: ids.length, acceptedSeq: Math.max(...ids) };
}

export async function pullOps(
  pool: DbPool,
  bookId: string,
  sinceSeq: number,
  limit: number,
): Promise<{ ops: StoredOp[]; nextSeq: number; serverTime: string }> {
  // 安全窗口（审查 L-3）：BIGSERIAL 在语句执行时分配、commit 时可见——
  // 并发推送期间，先提交的 op 可能被拉到但后提交的仍不可见，客户端若推进游标
  // 会永久丢失窗口内的 op。拉取仅暴露 commit 满 2 秒的 op，客户端按 op_id
  // 去重容忍安全窗口内的重拉。
  const result = await pool.query<StoredOp>(
    `SELECT id, entity, entity_id, op, payload, lamport, client_id
     FROM sync_ops WHERE book_id = $1 AND id > $2
       AND created_at < now() - interval '2 seconds'
     ORDER BY id LIMIT $3`,
    [bookId, sinceSeq, limit],
  );
  const time = await pool.query<{ now: string }>('SELECT now() AS now');
  const ops = result.rows;
  const nextSeq = ops.length > 0 ? Number(ops[ops.length - 1].id) : sinceSeq;
  return { ops, nextSeq, serverTime: time.rows[0].now };
}
