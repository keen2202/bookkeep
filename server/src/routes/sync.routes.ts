import { Router } from 'express';
import { requireBookMember } from '../auth/book.middleware';
import { DbPool } from '../db/pool';
import { pullOps, pushOps } from '../sync/op.service';
import { validateOpBatch } from '../sync/validate';

interface SyncDeps {
  pool: DbPool;
}

export function syncRouter({ pool }: SyncDeps): Router {
  const router = Router();

  router.post('/push', requireBookMember(pool, { allowWrite: true }), async (req, res) => {
    const validated = validateOpBatch(req.body);
    if (!validated.ok) {
      res.status(422).json({ error: 'validation_failed', detail: validated.error });
      return;
    }
    const { accepted, acceptedSeq } = await pushOps(pool, validated.bookId, validated.ops);
    res.status(200).json({ accepted_seq: acceptedSeq, accepted });
  });

  router.get('/pull', requireBookMember(pool, { allowWrite: false }), async (req, res) => {
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
    const { ops, nextSeq } = await pullOps(pool, bookId, sinceSeq, limit);
    res.status(200).json({ ops, next_seq: nextSeq });
  });

  return router;
}
