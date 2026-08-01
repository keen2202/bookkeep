import { validateOpBatch } from '../src/sync/validate';

const BOOK = '11111111-1111-4111-8111-111111111111';
const CLIENT = '22222222-2222-4222-8222-222222222222';
const ENTITY = '33333333-3333-4333-8333-333333333333';

function validOp(overrides: Record<string, unknown> = {}) {
  return {
    entity: 'transaction',
    entity_id: ENTITY,
    op: 'c',
    payload: { amount_minor: 100 },
    lamport: 1,
    client_id: CLIENT,
    ...overrides,
  };
}

describe('validateOpBatch', () => {
  it('accepts a valid batch', () => {
    const r = validateOpBatch({ book_id: BOOK, ops: [validOp(), validOp({ lamport: 2 })] });
    expect(r.ok).toBe(true);
    if (r.ok) {
      expect(r.bookId).toBe(BOOK);
      expect(r.ops).toHaveLength(2);
    }
  });

  it('rejects a missing or non-uuid book_id', () => {
    expect(validateOpBatch({ ops: [validOp()] }).ok).toBe(false);
    expect(validateOpBatch({ book_id: 'not-a-uuid', ops: [validOp()] }).ok).toBe(false);
  });

  it('rejects an empty ops array', () => {
    expect(validateOpBatch({ book_id: BOOK, ops: [] }).ok).toBe(false);
  });

  it('rejects more than 500 ops', () => {
    const ops = Array.from({ length: 501 }, (_, i) => validOp({ lamport: i + 1 }));
    expect(validateOpBatch({ book_id: BOOK, ops }).ok).toBe(false);
  });

  it('rejects an unknown entity', () => {
    expect(validateOpBatch({ book_id: BOOK, ops: [validOp({ entity: 'gadget' })] }).ok).toBe(false);
  });

  it('rejects an unknown op code', () => {
    expect(validateOpBatch({ book_id: BOOK, ops: [validOp({ op: 'x' })] }).ok).toBe(false);
  });

  it('rejects a non-uuid entity_id', () => {
    expect(validateOpBatch({ book_id: BOOK, ops: [validOp({ entity_id: '42' })] }).ok).toBe(false);
  });

  it('rejects a lamport below 1 or non-integer', () => {
    expect(validateOpBatch({ book_id: BOOK, ops: [validOp({ lamport: 0 })] }).ok).toBe(false);
    expect(validateOpBatch({ book_id: BOOK, ops: [validOp({ lamport: 1.5 })] }).ok).toBe(false);
    expect(validateOpBatch({ book_id: BOOK, ops: [validOp({ lamport: '2' })] }).ok).toBe(false);
  });

  it('rejects a non-uuid client_id', () => {
    expect(validateOpBatch({ book_id: BOOK, ops: [validOp({ client_id: 'abc' })] }).ok).toBe(false);
  });

  it('requires a payload object for create ops', () => {
    expect(validateOpBatch({ book_id: BOOK, ops: [validOp({ payload: null })] }).ok).toBe(false);
    expect(validateOpBatch({ book_id: BOOK, ops: [validOp({ payload: 'text' })] }).ok).toBe(false);
  });

  it('allows a null payload for delete ops', () => {
    expect(validateOpBatch({ book_id: BOOK, ops: [validOp({ op: 'd', payload: null })] }).ok).toBe(true);
  });
});
