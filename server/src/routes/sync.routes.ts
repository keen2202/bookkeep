import { Router } from 'express';
import rateLimit, { ipKeyGenerator } from 'express-rate-limit';
import { requireBookMember } from '../auth/book.middleware';
import { DbPool } from '../db/pool';
import { pullOps, pushOps } from '../sync/op.service';
import { validateOpBatch } from '../sync/validate';

interface SyncDeps {
  pool: DbPool;
  /** 限流开关（测试注入）：集成用例关闭避免共享桶互扰 */
  rateLimit?: boolean;
}

// sync 按用户配额（审查 L-4）：每轮同步 2 请求（push+pull），
// 120 次/分钟 = 40 轮/分钟，远超正常记账频率，防滥用刷接口
const syncRateLimit = rateLimit({
  windowMs: 60_000,
  limit: 120,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  // IPv6 经 ipKeyGenerator 归一化（IPv4-mapped 共享限流桶，消除 ERR_ERL_KEY_GEN_IPV6 告警）
  keyGenerator: (req) => String((req as { user?: { sub?: string } }).user?.sub ?? ipKeyGenerator(req.ip ?? 'ip')),
  message: { error: 'rate_limited' },
});

export function syncRouter({ pool, rateLimit = true }: SyncDeps): Router {
  const router = Router();
  if (rateLimit) router.use(syncRateLimit);

  router.post('/push', requireBookMember(pool, { allowWrite: true, autoCreate: true }), async (req, res) => {
    const validated = validateOpBatch(req.body);
    if (!validated.ok) {
      res.status(422).json({ error: 'validation_failed', detail: validated.error });
      return;
    }
    const { accepted, acceptedSeq } = await pushOps(pool, validated.bookId, validated.ops);
    res.status(200).json({ accepted_seq: acceptedSeq, accepted });
  });

  router.get('/pull', requireBookMember(pool, { allowWrite: false, autoCreate: false }), async (req, res) => {
    const bookId = req.bookId as string;
    const sinceRaw = req.query.since_seq;
    if (typeof sinceRaw !== 'string' || !/^\d+$/.test(sinceRaw)) {
      res.status(400).json({ error: 'since_seq must be a non-negative integer' });
      return;
    }
    const sinceSeq = Number(sinceRaw);
    let limit = 500;
    if (req.query.limit !== undefined) {
      const raw = Number(req.query.limit);
      if (!Number.isInteger(raw) || raw < 1 || raw > 1000) {
        res.status(400).json({ error: 'limit must be an integer in [1, 1000]' });
        return;
      }
      limit = raw;
    }
    const { ops, nextSeq, serverTime } = await pullOps(pool, bookId, sinceSeq, limit);
    res.status(200).json({ ops, next_seq: nextSeq, server_time: serverTime });
  });

  return router;
}
