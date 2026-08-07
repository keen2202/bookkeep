// 幂等 DDL：users / books / book_members / sync_ops / refresh_tokens（Spec §1.2）
export const SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS books (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'default',
  owner_id UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS book_members (
  book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (book_id, user_id)
);

-- 审查 L-1：owner 唯一性由数据库约束兜底（先清理既有双 owner，保留最早创建者）
DELETE FROM book_members m
USING book_members m2
WHERE m.role = 'owner' AND m2.role = 'owner'
  AND m.book_id = m2.book_id
  AND m.created_at > m2.created_at;

CREATE UNIQUE INDEX IF NOT EXISTS one_owner_per_book
  ON book_members(book_id) WHERE role = 'owner';

CREATE TABLE IF NOT EXISTS sync_ops (
  id BIGSERIAL PRIMARY KEY,
  book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  entity TEXT NOT NULL CHECK (entity IN ('account', 'category', 'transaction', 'budget', 'recurring_rule')),
  entity_id TEXT NOT NULL,
  op TEXT NOT NULL CHECK (op IN ('c', 'u', 'd')),
  payload JSONB,
  lamport INTEGER NOT NULL CHECK (lamport >= 1),
  client_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (book_id, entity, entity_id, lamport, client_id)
);
CREATE INDEX IF NOT EXISTS idx_sync_ops_book_seq ON sync_ops (book_id, id);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS invite_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token_hash TEXT NOT NULL UNIQUE,
  book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('editor', 'viewer')),
  created_by UUID NOT NULL REFERENCES users(id),
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
`;
