# 32-全面代码审查改进 Spec 规格说明

| 项 | 内容 |
|---|---|
| 文档编号 | BK-REV-2026-SPEC |
| 版本 | v1.0 |
| 日期 | 2026-08-27 |
| 范围 | `app/lib/**`、`server/src/**`、CI/配置 |
| 前置审查 | 五维度全面代码审查（逻辑/冗余/安全/性能/质量） |
| 状态 | 待实施 |

---

## 1. 背景与目标

### 1.1 背景

对 bookkeep 全库（Flutter 客户端 + Node 同步后端）完成五维度代码审查，人工复核后确认若干数据正确性、隐私与权限类高危缺陷，以及一批中低优先级可维护性问题。

### 1.2 目标

1. **P0（本 Spec 必修）**：消除数据丢失/权限失效/隐私泄露/明文传输类缺陷。
2. **P1（本 Spec 应修）**：修复同步边界不一致、性能热点、关键路径可用性。
3. **P2（本 Spec 建议）**：收敛冗余、加固工程规范、补日志与测试缺口。

### 1.3 非目标

- 不重写同步协议架构（op-log + LWW 保留）。
- 不引入新的后端框架或状态管理方案。
- 不在本轮处理 BK-T-009（TLS 证书固定）——需真机发布渠道。

---

## 2. 问题分类与优先级总表

| ID | 严重度 | 维度 | 摘要 | 主文件 |
|---|---|---|---|---|
| R-01 | P0 | 逻辑/数据 | 合并流水丢失 `rate_snapshot` | `sync_merger.dart` |
| R-02 | P0 | 逻辑/数据 | `findDuplicate` 时区截断导致导入去重失效 | `transaction_repository.dart` |
| R-03 | P0 | 逻辑 | 分类预算 `spentForPeriod` 未含子分类 | `budget_repository.dart` |
| R-04 | P0 | 安全 | accept-invite 可降级 owner | `books.routes.ts` |
| R-05 | P0 | 安全 | 备份恢复列名拼 SQL | `backup_service.dart` |
| R-06 | P0 | 安全 | 同步 API 无 HTTPS 强制 + 明文 localhost | `constants.dart` / `sync_api.dart` |
| R-07 | P0 | 安全 | PIN 解锁无限流/冷却 | `lock_gate.dart` |
| R-08 | P0 | 安全/隐私 | 账单详情金额未脱敏 | `bill_detail_sheet.dart` |
| R-09 | P0 | 逻辑 | autoCreate 账本双 INSERT 非事务 | `book.middleware.ts` |
| R-10 | P0 | 逻辑 | refresh 撤销与签发非原子 | `tokens.ts` |
| R-11 | P1 | 逻辑/数据 | 账单日分组未 `toLocal()` | `bills_grouping.dart` |
| R-12 | P1 | 逻辑 | 新建转账丢弃备注 | `quick_entry_controller.dart` |
| R-13 | P1 | 逻辑 | `Money.convert` 整数溢出 | `money.dart` |
| R-14 | P1 | 安全 | 生物识别未限制 biometricOnly | `biometric.dart` |
| R-15 | P1 | 安全 | 备份含 PIN 哈希未排除 | `backup_service.dart` |
| R-16 | P1 | 逻辑 | login 401 自动 register 误建账户 | `sync_providers.dart` / `sync_engine.dart` |
| R-17 | P1 | 逻辑 | 合并更新路径 FK 丢弃不入重放；分类置 null | `sync_merger.dart` |
| R-18 | P1 | 逻辑 | book 实体无 update 合并路径 | `sync_merger.dart` |
| R-19 | P1 | 性能/数据 | transactions 缺 book_id/remote_id/account_id 索引 | `transactions_table.dart` |
| R-20 | P1 | 性能 | 账单/账户无分页全表拉取 | `bills_providers.dart` 等 |
| R-21 | P1 | 性能 | App 壳滚动 setState + ThemeData 全量重建 | `app.dart` |
| R-22 | P1 | 性能 | IndexedStack 常驻报表取数 | `app.dart` |
| R-23 | P1 | 可用性 | CategoryPicker 不可滚动 | `category_picker.dart` |
| R-24 | P1 | 质量 | `capture_confirm_page` 相对导入越级 | `capture_confirm_page.dart` |
| R-25 | P1 | 安全 | 服务端 autoCreate/成员路径与 sync 未认证限流缺口 | `app.ts` / routes |
| R-26 | P2 | 逻辑 | roleOf 缺失默认 owner（fail-open） | `book_repository.dart` |
| R-27 | P2 | 逻辑 | 周期表缺 FK；分期去重依赖 note | `recurring_*` |
| R-28 | P2 | 性能 | 币种 seed N+1；存在性查询全量加载 | `currency_repository.dart` 等 |
| R-29 | P2 | 冗余 | 双 exchangeRateServiceProvider / HTTP 重复 | providers / api |
| R-30 | P2 | 质量 | analysis_options 过松；catch(_) 吞异常；死代码 | 多处 |

---

## 3. P0 修复方案（详细）

### R-01 合并流水丢失 rate_snapshot

| 项 | 内容 |
|---|---|
| 位置 | `app/lib/features/sync/sync_merger.dart` `_createTransaction` ~264-277；`_updateTransaction` ~324-352 |
| 现状 | payload 含 `rate_snapshot`（本地 enqueue 时写入），合并端未提取，表默认 1.0 |
| 影响 | 多币种跨设备报表折算错误 |
| 方案 | create：`rateSnapshot: Value(_int(p, 'rate_snapshot') ?? kRateScale)`；update：增加 `rateSnapshot` 字段提取（与 currency 同模式 `_intField`） |
| 文件 | `sync_merger.dart`；测试 `sync_merger_test.dart` |
| 验收 | 设备 A 以汇率 7.2 记 USD → 同步后设备 B `rate_snapshot == 7200000`；update 路径同 |

### R-02 findDuplicate 时区截断

| 项 | 内容 |
|---|---|
| 位置 | `transaction_repository.dart:437-443` |
| 现状 | `DateTime.utc(localY, localM, localD, localH, localMin)` 在非 UTC 时区得到错误窗口 |
| 方案 | 先 `final utc = occurredAt.isUtc ? occurredAt : occurredAt.toUtc();` 再按 utc 分量截断 |
| 验收 | `TZ=Asia/Shanghai` 下同分钟重复导入只落一条；UTC 下行为不变 |

### R-03 分类预算不含子分类

| 项 | 内容 |
|---|---|
| 位置 | `budget_repository.dart:117-140` |
| 现状 | 注释「含子分类」但 SQL 仅 `category_id = ?` |
| 方案 | `AND (category_id = ? OR category_id IN (SELECT id FROM categories WHERE parent_id = ? AND deleted_at IS NULL))`；父类预算计入全部子类支出 |
| 验收 | 父类预算下挂子类流水，spent 等于子类合计；单测覆盖 |

### R-04 accept-invite 降级 owner

| 项 | 内容 |
|---|---|
| 位置 | `server/src/books/books.routes.ts:131-146` |
| 方案 | UPDATE 前查询现有 role；若为 owner 则 422 `owner_cannot_accept_role_change`，不消耗 token；或 upsert 加 `WHERE role != 'owner'` 且已 owner 时幂等成功不改角色 |
| 推荐 | 已是 owner：返回 200 + 当前 role=owner，token 标记 used（防重放），角色不变 |
| 验收 | 集成测试：owner 接受 viewer 邀请后仍为 owner |

### R-05 备份恢复列名注入

| 项 | 内容 |
|---|---|
| 位置 | `backup_service.dart:83-95` |
| 方案 | 为 `_tables` 中每表定义合法列名白名单（可从 Drift 表定义生成常量 Map）；恢复时 `columns.where(whitelist.contains)`，含未知列直接抛 `BackupCipherException` |
| 验收 | 构造含 `id) VALUES(1);--` 列名的备份 → 恢复失败且库未被改动 |

### R-06 同步 HTTPS 强制

| 项 | 内容 |
|---|---|
| 位置 | `constants.dart:8`；`sync_api.dart`；`sync_providers.dart:35,99` |
| 方案 | 1) `HttpSyncApi` 构造或 `_request` 增加 `assertSecure()`（拒绝非 https，debug 可允许 localhost http）；2) 发布配置经 `String.fromEnvironment('SERVER_URL')` 注入，生产必须 https |
| 验收 | 单测：http 非 localhost 抛错；https 通过；debug localhost 允许 |

### R-07 PIN 试错冷却

| 项 | 内容 |
|---|---|
| 位置 | `lock_gate.dart`；`lock_controller.dart` / `lock_repository.dart` |
| 方案 | 连续失败计数持久化到 `app_meta`（`privacy_pin_fails`、`privacy_pin_lock_until`）；≥5 次锁 30s，≥10 次锁 5min；解锁成功清零；锁定期间禁止 `verifyPin` |
| 验收 | 5 次错误后 30s 内无法解锁；成功后计数清零；widget 重建不重置 |

### R-08 账单详情脱敏

| 项 | 内容 |
|---|---|
| 位置 | `bill_detail_sheet.dart:168-169` |
| 方案 | `masked: ref.watch(amountMaskProvider)`；同步检查 `quick_entry_sheet` 大数字与 `capture_confirm_page` 金额是否需接 mask |
| 验收 | 配置 PIN → 切后台 → 系统快照不显示真实金额（详情页打开时） |

### R-09 autoCreate 事务化

| 项 | 内容 |
|---|---|
| 位置 | `server/src/auth/book.middleware.ts:46-66` |
| 方案 | 使用 `withTransaction(pool, ...)` 包裹 books + book_members 两条 INSERT |
| 验收 | 单测/mock：第二条失败时无孤儿 books 行 |

### R-10 refresh 轮换原子性

| 项 | 内容 |
|---|---|
| 位置 | `server/src/auth/tokens.ts:30-57` |
| 方案 | `withTransaction` 内：UPDATE revoke RETURNING → INSERT new token → 清理可放事务外或同事务 |
| 验收 | 集成测试：mock 第二步失败时旧 token 仍有效或整体回滚 |

---

## 4. P1 修复方案（摘要）

| ID | 方案要点 |
|---|---|
| R-11 | `groupBillsByDay` 先 `t.occurredAt.toLocal()` 再取 Y/M/D；与 `bills_page` 展示、calendar 日窗对齐 |
| R-12 | `createTransfer` 增加 `note` 参数并入 op payload；UI 已有备注框则贯通 |
| R-13 | 乘法前溢出检查：`\|amountMinor\| > (1<<62)~/rateScaled` 时抛 ArgumentError 或改 BigInt |
| R-14 | `authenticate(..., options: AuthenticationOptions(biometricOnly: true))` |
| R-15 | `_excludedMetaPrefixes` 增加 `'privacy_'` |
| R-16 | login 401 不自动 register；区分「账户不存在」错误码，UI 引导注册；引擎 `_ensureTokens` 同步收紧 |
| R-17 | 更新路径：account 缺失入 `_pendUpdate`/重放；category 缺失跳过而非置 null |
| R-18 | `_localIdByRemoteId` 增加 book 分支 + `_updateBook` |
| R-19 | 迁移加索引：`(book_id, occurred_at)`、`(remote_id)`、`(account_id)`、`(type, deleted_at, occurred_at)` |
| R-20 | 账单窗口加载 + 分页；余额 SQL 聚合 |
| R-21 | `_scrolled` 下沉局部；`materialThemesFor` 按 settings 缓存 |
| R-22 | ReportsPage 懒挂载/首次进入再 watch |
| R-23 | CategoryPicker 外包 `SingleChildScrollView` 或 ListView |
| R-24 | 改为 `import '../../shared/widgets/glass_nav.dart';` 并 `flutter analyze` |
| R-25 | `/sync/*` 在 authMiddleware 前加 IP 限流；auth 路由补 `ipKeyGenerator` |

---

## 5. P2 修复方案（摘要）

| ID | 方案要点 |
|---|---|
| R-26 | `roleOf` 默认 `'viewer'` |
| R-27 | 周期表加 FK；分期去重键改为 `(auto_generated, amount, occurred_at, book_id, account_id)` |
| R-28 | 币种 seed `batch`；存在性 `limit(1)`/exists |
| R-29 | 合并 `exchangeRateServiceProvider` 到 currency；抽取 HTTP 客户端基类 |
| R-30 | analysis_options 开 strict 三件套；关键路径 `catch (e) { debugPrint }`；删 `REFRESH_TTL_DAYS` 等死代码；JWT `algorithms: ['HS256']` |

---

## 6. 架构与工程优化方向

### 6.1 同步契约

- 为 push payload 定义 wire DTO（两端共享字段清单），禁止「本地写有、合并读无」。
- `rate_snapshot` 修复后补双向序列化测试：本地 enqueue → merger apply → 行等价。

### 6.2 时区约定（全局）

- 存储：一律 UTC（已有）。
- 展示/分组/日窗：显式 `toLocal()`。
- 禁止用本地分量构造 `DateTime.utc()`。

### 6.3 安全基线清单（发布前门禁）

- [x] 生产 `kServerBaseUrl` / flavor 为 HTTPS（`String.fromEnvironment` + assertSecure）
- [x] `HttpSyncApi.assertSecure`
- [x] PIN 冷却生效
- [x] 备份列白名单
- [x] accept-invite 不降级 owner
- [x] 详情金额接 mask（记账/导入页仍待接入）

### 6.4 性能预算（回归）

- 冷启动：不因 IndexedStack 触发报表 SQL
- 滚动阈值切换：无全树 ThemeData 重建
- 10k 流水：列表首屏 < 500ms（保持既有验收）

---

## 7. 涉及文件清单

### 客户端

```
app/lib/features/sync/sync_merger.dart
app/lib/features/sync/sync_api.dart
app/lib/features/sync/sync_engine.dart
app/lib/features/sync/sync_providers.dart
app/lib/features/auth_lock/lock_gate.dart
app/lib/features/auth_lock/lock_controller.dart
app/lib/features/auth_lock/lock_repository.dart  (或 data/repositories/lock_repository.dart)
app/lib/features/auth_lock/biometric.dart
app/lib/features/bills/bill_detail_sheet.dart
app/lib/features/bills/bills_grouping.dart
app/lib/features/bills/bills_providers.dart
app/lib/features/quick_entry/quick_entry_controller.dart
app/lib/features/backup/backup_service.dart
app/lib/features/auto_capture/capture_confirm_page.dart
app/lib/shared/widgets/category_picker.dart
app/lib/data/repositories/transaction_repository.dart
app/lib/data/repositories/budget_repository.dart
app/lib/data/repositories/book_repository.dart
app/lib/data/repositories/currency_repository.dart
app/lib/data/repositories/account_repository.dart
app/lib/data/local/tables/transactions_table.dart
app/lib/data/local/tables/recurring_tables.dart
app/lib/data/local/database.dart
app/lib/core/constants/constants.dart
app/lib/core/utils/money.dart
app/lib/app.dart
app/lib/main.dart
```

### 服务端

```
server/src/books/books.routes.ts
server/src/auth/book.middleware.ts
server/src/auth/tokens.ts
server/src/auth/middleware.ts
server/src/routes/auth.routes.ts
server/src/routes/sync.routes.ts
server/src/app.ts
server/src/sync/op.service.ts
server/src/db/schema.ts
```

### 测试

```
app/test/unit/features/sync/sync_merger_test.dart
app/test/unit/data/repositories/transaction_repository_test.dart
app/test/unit/data/repositories/budget_repository_test.dart
app/test/unit/features/auth_lock/lock_controller_test.dart
app/test/unit/features/backup/backup_service_test.dart
app/test/unit/core/utils/money_format_test.dart  (+ money overflow 用例)
server/tests/books.routes.integration.test.ts
server/tests/auth.routes.integration.test.ts
server/tests/sync.routes.integration.test.ts
```

---

## 8. 实施进度追踪表

| ID | 任务 | 负责人 | 状态 | 开始 | 完成 | 备注 |
|---|---|---|---|---|---|---|
| R-01~R-10 | P0 批 | agent | completed | 2026-08-27 | 2026-08-27 | 见任务分解 BK-R01~10 |
| R-11~R-19 | P1 逻辑/同步 | agent | completed | 2026-08-27 | 2026-08-27 | 见任务分解 |
| R-20 | 账单窗口加载 | agent | completed | 2026-08-27 | 2026-08-27 | limit + 加载更早 |
| R-21 | 主题缓存/局部 setState | agent | completed | 2026-08-27 | 2026-08-27 | ValueNotifier + themesProvider |
| R-22 | 报表懒挂载 | agent | completed | 2026-08-27 | 2026-08-27 | 首次进入再建 |
| R-23~R-26 | P1/P2 杂项 | agent | completed | 2026-08-27 | 2026-08-27 | 见任务分解 |
| R-27 | 周期 FK+分期去重 | agent | completed | 2026-08-27 | 2026-08-27 | 新库 FK；去重不依赖 note |
| R-28 | 币种 seed 批量 | agent | completed | 2026-08-27 | 2026-08-27 | insertOrIgnore batch |
| R-29 | 汇率 Provider 单源 | agent | completed | 2026-08-27 | 2026-08-27 | 合并 accounts/currency |
| R-30 | lints/日志/JWT | agent | completed | 2026-08-27 | 2026-08-27 | strict + catch 日志 + HS256 |

状态取值：`pending` / `in_progress` / `completed` / `blocked`。

---

## 9. 验证与测试方案

### 9.1 单元测试

| 区域 | 新增用例 |
|---|---|
| Money | 最大金额 × 高汇率溢出边界 |
| findDuplicate | 本地/UTC/跨日界 |
| spentForPeriod | 父类+子类合计；软删排除 |
| BackupService | 恶意列名拒绝；privacy_ 排除 |
| Pin cooldown | 5 次锁定、成功清零、重建不重置 |
| SyncMerger | rate_snapshot create/update 往返 |
| books.routes | owner 接受邀请角色不变 |

### 9.2 集成测试（server + PG）

- accept-invite owner 降级场景
- autoCreate 并发/失败无孤儿
- refresh 轮换失败回滚

### 9.3 手工/真机

- HTTPS 生产地址登录同步
- 账单详情切后台系统快照脱敏
- 多币种双端同步报表金额一致

### 9.4 回归命令

```bash
cd server && npx tsc --noEmit && npm test && npm run test:integration
cd app && flutter analyze && flutter test
```

---

## 10. 风险与回滚

| 风险 | 缓解 |
|---|---|
| 预算含子分类改变历史进度展示 | 说明为 bugfix；提供迁移说明 |
| PIN 冷却影响正常用户 | 阈值可配；仅连续失败触发 |
| HTTPS 强制影响本地开发 | debug 允许 localhost http |
| 索引迁移增加安装时间 | CREATE INDEX IF NOT EXISTS；CI 覆盖 |

单项修复独立可回滚（按文件/按 PR）。

---

## 11. 与既有 Spec 关系

- 不替代 `docs/02-Spec` 产品基线。
- 冲突时以本 Spec 的安全与数据正确性条目为准。
- BK-T-009（证书固定）仍 blocked，本 Spec 仅要求 HTTPS 端点。
