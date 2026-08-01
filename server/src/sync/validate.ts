const ENTITIES = ['account', 'category', 'transaction', 'budget', 'recurring_rule'] as const;
const OPS = ['c', 'u', 'd'] as const;
const MAX_BATCH = 500;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface SyncOp {
  entity: string;
  entity_id: string;
  op: 'c' | 'u' | 'd';
  payload: Record<string, unknown> | null;
  lamport: number;
  client_id: string;
  book_id?: string;
}

export type OpBatchResult =
  | { ok: true; bookId: string; ops: SyncOp[] }
  | { ok: false; error: string };

function isUuid(v: unknown): v is string {
  return typeof v === 'string' && UUID_RE.test(v);
}

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

const isOneOf = <T extends string>(v: unknown, allowed: readonly T[]): v is T =>
  typeof v === 'string' && (allowed as readonly string[]).includes(v);

export function validateOpBatch(body: unknown): OpBatchResult {
  if (!isRecord(body)) return { ok: false, error: 'body must be an object' };
  if (!isUuid(body.book_id)) return { ok: false, error: 'book_id must be a uuid' };
  if (!Array.isArray(body.ops) || body.ops.length === 0) {
    return { ok: false, error: 'ops must be a non-empty array' };
  }
  if (body.ops.length > MAX_BATCH) {
    return { ok: false, error: `ops must not exceed ${MAX_BATCH} items` };
  }

  const ops: SyncOp[] = [];
  for (const raw of body.ops) {
    if (!isRecord(raw)) return { ok: false, error: 'each op must be an object' };
    const { entity, entity_id, op, payload, lamport, client_id } = raw;
    if (!isOneOf(entity, ENTITIES)) {
      return { ok: false, error: `unknown entity: ${String(entity)}` };
    }
    if (!isUuid(entity_id)) return { ok: false, error: 'entity_id must be a uuid' };
    if (!isOneOf(op, OPS)) {
      return { ok: false, error: `unknown op: ${String(op)}` };
    }
    if (typeof lamport !== 'number' || !Number.isInteger(lamport) || lamport < 1) {
      return { ok: false, error: 'lamport must be an integer >= 1' };
    }
    if (!isUuid(client_id)) return { ok: false, error: 'client_id must be a uuid' };
    if (payload !== null && payload !== undefined && !isRecord(payload)) {
      return { ok: false, error: 'payload must be an object or null' };
    }
    if ((op === 'c' || op === 'u') && (payload === null || payload === undefined)) {
      return { ok: false, error: 'create/update ops require a payload snapshot' };
    }
    ops.push({
      entity,
      entity_id: entity_id.toLowerCase(),
      op,
      payload: (payload ?? null) as Record<string, unknown> | null,
      lamport,
      client_id: client_id.toLowerCase(),
      book_id: body.book_id.toLowerCase(),
    });
  }
  return { ok: true, bookId: body.book_id.toLowerCase(), ops };
}
