# Contributing

## 服务端事务约定（评审 B-4 增补）

**所有多写路径（≥2 条写语句的请求）必须经 `withTransaction`（`server/src/db/tx.ts`）执行**，禁止在路由中用 `pool.query('BEGIN')` 手写事务——pg `Pool.query` 每次调用独立借还连接，BEGIN/INSERT/COMMIT 会散落不同客户端导致事务失效。

- 单条写语句（如单 INSERT..ON CONFLICT）无需事务。
- 事务内一律使用 `withTransaction` 回调中的 `client`，而非外层 `pool`。
- 新增多写路由时在代码评审中核对本约定。
