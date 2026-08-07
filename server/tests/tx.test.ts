import type { PoolClient } from 'pg';
import { DbPool } from '../src/db/pool';
import { withTransaction } from '../src/db/tx';

function fakePool(log: string[]) {
  let released = 0;
  const query = jest.fn(async (sql: string) => {
    log.push(sql);
    return { rows: [] };
  });
  const client = {
    release: () => {
      released++;
    },
    query,
  } as unknown as PoolClient;
  const pool = {
    connect: jest.fn(async () => client),
    query: jest.fn(),
  } as unknown as DbPool;
  return { pool, client, query, released: () => released };
}

describe('withTransaction', () => {
  it('BEGIN → fn → COMMIT → release, in order', async () => {
    const log: string[] = [];
    const { pool, released } = fakePool(log);
    const result = await withTransaction(pool, async (c) => {
      await c.query('INSERT INTO t VALUES (1)');
      return 'done';
    });
    expect(result).toBe('done');
    expect(log).toEqual(['BEGIN', 'INSERT INTO t VALUES (1)', 'COMMIT']);
    expect(released()).toBe(1);
    expect(pool.connect).toHaveBeenCalledTimes(1);
  });

  it('fn throws → ROLLBACK → original error rethrown → release', async () => {
    const log: string[] = [];
    const { pool, query, released } = fakePool(log);
    const boom = new Error('insert failed');
    query.mockImplementationOnce(async (sql: string) => {
      log.push(sql);
      if (sql === 'BEGIN') return { rows: [] };
      throw boom;
    });
    await expect(
      withTransaction(pool, async () => {
        throw boom;
      }),
    ).rejects.toThrow('insert failed');
    expect(log).toEqual(['BEGIN', 'ROLLBACK']);
    expect(released()).toBe(1);
  });

  it('ROLLBACK itself failing still releases and rethrows the original error', async () => {
    const log: string[] = [];
    const { pool, query, released } = fakePool(log);
    const boom = new Error('midway');
    query.mockImplementation(async (sql: string) => {
      log.push(sql);
      if (sql === 'ROLLBACK') throw new Error('connection lost');
      return { rows: [] };
    });
    await expect(
      withTransaction(pool, async () => {
        throw boom;
      }),
    ).rejects.toThrow('midway');
    expect(released()).toBe(1);
  });
});
