import type { QueryResult, QueryResultRow } from 'pg';

export interface DbPool {
  query<R extends QueryResultRow = QueryResultRow>(
    text: string,
    params?: unknown[],
  ): Promise<QueryResult<R>>;
}
