# 06-审查修复 Spec 规格说明（v1.1 增量）

| 项目 | 值 |
|---|---|
| 文档版本 | v1.1（在 v1.0《02-Spec规格说明.md》基础上的审查修复增量） |
| 日期 | 2026-08-07 |
| 依据 | 《代码审查报告-v0.2.1.html》+《05-代码审查改进建议.md》 |
| 范围 | 审查发现的全部阻塞/高/中严重度问题修复；低危项择要纳入 |
| 追踪规则 | 问题编号（B-x/F-x/L-x/U-x）↔ 方案编号（BK-FX-xxx）↔ 任务编号（BK-R-xxx） |
| 约束 | v1.0 Spec 的数据模型、同步协议、加密标准等约定继续有效；本文档仅定义增量与修正 |

---

## 1. 问题分类与优先级排序

### 1.1 严重度定义

| 级别 | 定义 | 处置时限 |
|---|---|---|
| 🔴 阻塞 | 核心功能不闭环 / 数据丢失 / 安全合规违背 | 立即（第一波） |
| 🟠 高 | 主链路断点 / 并发下数据错乱 / 可被攻击利用 | 第二波内 |
| 🟡 中 | 功能半成品 / 边界缺陷 / 体验明显受损 | 第三波内 |
| 🟢 低 | 代码质量 / 可维护性 / 轻微体验问题 | 持续清偿 |

### 1.2 问题全景（56 项，按波次排序）

| 波次 | 编号 | 级别 | 问题 | 方案 | 任务 |
|---|---|---|---|---|---|
| 一 | B-4 | 🔴 | 服务端 pool.query 事务失效 | BK-FX-003 | BK-R-001 |
| 一 | B-3 | 🔴 | 周期流水写入占位账本（生成即丢失） | BK-FX-002 | BK-R-004 |
| 一 | B-2 | 🔴 | SQLCipher 未启用，数据库明文落盘 | BK-FX-006 | BK-R-007 |
| 一 | B-1 | 🔴 | 同步引擎未接线 + 无登录入口 | BK-FX-010 | BK-R-008 |
| 一 | F-1 | 🟠 | 记账保存后报表/日历不刷新 | BK-FX-001 | BK-R-005 |
| 一 | F-2 | 🟠 | 周期补跑/分期到期无自动触发 | BK-FX-002 | BK-R-006 |
| 一 | L-1 | 🟠 | 建账竞态双 owner + 带副作用 GET | BK-FX-008 | BK-R-003 |
| 一 | L-2 | 🟠 | 邀请 token 可复用 | BK-FX-008 | BK-R-002 |
| 二 | L-3 | 🟠 | pull BIGSERIAL 游标丢 op 窗口 | BK-FX-008 | BK-R-009 |
| 二 | F-6 | 🟠 | FK 未就绪流水跳过即永久丢失 | BK-FX-009 | BK-R-009 |
| 二 | F-3 | 🟠 | 共享账本无本地落地 | BK-FX-010 | BK-R-011 |
| 二 | F-4 | 🟠 | 备份遗漏 4 张表 | BK-FX-013 | BK-R-014 |
| 二 | F-5 | 🟠 | 预算阈值失效 + 提醒闭环缺失 | BK-FX-011 | BK-R-018 |
| 二 | L-4 | 🟠 | 服务端零安全中间件 | BK-FX-007 | BK-R-012 |
| 二 | L-10/L-12 | 🟡 | HTML 错误页 / refresh 半完成态 | BK-FX-007 | BK-R-012 |
| 二 | L-11 | 🟡 | PATCH 可提升 owner | BK-FX-008 | BK-R-002 |
| 二 | U-1 | 🟠 | 嵌套 Scaffold 双 AppBar/双 FAB | BK-FX-005 | BK-R-013 |
| 二 | U-9 | 🟡 | Tab 切换无状态保持 | BK-FX-005 | BK-R-013 |
| 二 | U-3/U-4 | 🟠 | 键盘无 SafeArea / 保存无防重入 | BK-FX-015 | BK-R-016 |
| 三 | L-5~L-9 | 🟡 | 汇率快照/月末漂移/save死锁/日历净额/CSV | BK-FX-012/013 | BK-R-014, BK-R-019, BK-R-022 |
| 三 | F-7~F-11 | 🟡 | 周期收入/多币种/预算编辑/恢复刷新 | BK-FX-011~013 | BK-R-014, BK-R-018, BK-R-019 |
| 三 | 体积 | 🟠 | APK 71MB（三 ABI 单包 + sqlcipher 死重） | BK-FX-014 | BK-R-015 |
| 三 | U-2/U-5/U-8 | 🟠🟡 | 深色模式缺失/语义色硬编码/对比度 | BK-FX-016 | BK-R-017 |
| 三 | U-图表 | 🟠🟡 | 饼图重叠/无图例/tooltip 未格式化/脱敏泄露 | BK-FX-009/015 | BK-R-016, BK-R-017 |
| 四 | U-7/U-12/U-13 | 🟡🟢 | 触控目标/可发现性/无反馈无语义 | BK-FX-017 | BK-R-020 |
| 四 | 测试基建 | 🟡 | 无并发用例/jest 配置失效/污染开发库 | — | BK-R-021 |
| 四 | 低危项 | 🟢 | N+1/死代码/占位依赖/PRAGMA 插值等 | BK-FX-004 | BK-R-022 |

---

## 2. 修复方案与技术实现细节

### 2.1 第一波：阻塞修复

#### BK-R-001 服务端事务封装（B-4）
- **根因**：`pool.query('BEGIN')` 每次调用独立借还连接，BEGIN/INSERT/COMMIT 落在不同客户端。
- **实现**：
  ```ts
  // server/src/db/tx.ts（新增）
  export async function withTransaction<T>(pool: DbPool, fn: (c: PoolClient) => Promise<T>): Promise<T> {
    const client = await pool.connect();
    try { await client.query('BEGIN'); const r = await fn(client); await client.query('COMMIT'); return r; }
    catch (e) { await client.query('ROLLBACK'); throw e; }
    finally { client.release(); }
  }
  ```
  `DbPool` 接口补 `connect(): Promise<PoolClient>`；`POST /books` 与 `accept-invite` 改用 withTransaction。
- **涉及文件**：`server/src/db/pool.ts`、`server/src/db/tx.ts`(新增)、`server/src/books/books.routes.ts:56-70,150-163`
- **验证**：集成测试模拟 INSERT 中途失败，断言数据库无半提交残留（当前测试因同一 bug 无法暴露，需改写）。

#### BK-R-002 邀请原子化与角色收敛（L-2、L-11）
- **实现**：accept-invite 改单语句原子更新：
  ```sql
  UPDATE invite_tokens SET used_at=now()
  WHERE token_hash=$1 AND used_at IS NULL AND expires_at>now()
  RETURNING book_id, role
  ```
  无返回行 → 409。`PATCH /members` 目标角色白名单限定 `('editor','viewer')`，移除 `'owner'`。
- **涉及文件**：`server/src/books/books.routes.ts:133-158,214`
- **验证**：并发双请求接受同一 token，断言仅一个 2xx；PATCH owner 断言 403。

#### BK-R-003 建账竞态与 pull 只读化（L-1）
- **实现**：自动建账仅从 push 路径触发；`book_members` 加部分唯一索引：
  ```sql
  CREATE UNIQUE INDEX one_owner_per_book ON book_members(book_id) WHERE role='owner';
  ```
  `GET /sync/pull`（`book.middleware.ts:39-53` allowWrite:false 分支）对不存在账本返回 404，不再建账。
- **涉及文件**：`server/src/auth/book.middleware.ts`、`server/src/db/migrate.ts`（新迁移）
- **验证**：两用户并发首推同一 book_id，断言仅一个 owner；GET pull 随机 UUID 断言 404 且 DB 无新增。

#### BK-R-004 Repository 依赖注入收口（B-3）
- **实现**：`TransactionRepository` 构造要求显式 bookId（删除 `kDefaultBookId` 回退）；`RecurringService` 经 Riverpod 注入携带 currentBookId 的实例；全局 grep `Repository(db)` / `Repository(this.db)` 排查同类。
- **涉及文件**：`app/lib/features/recurring/recurring_service.dart:13-14`、`app/lib/data/repositories/transaction_repository.dart`、`app/lib/core/constants/constants.dart:10`、`app/lib/features/recurring/recurring_page.dart:30`
- **验证**：新装设备建周期规则 → 立即补跑 → 流水出现在当前账本列表/报表。

#### BK-R-005 账本刷新总线（F-1、F-12、L-7）
- **实现**：
  ```dart
  // app/lib/core/ledger_version.dart（新增）
  final ledgerVersionProvider = StateProvider<int>((_) => 0);
  void bumpLedgerVersion(Ref ref) => ref.read(ledgerVersionProvider.notifier).state++;
  ```
  `dailyTotalsProvider`、`categoryBreakdownProvider`、`calendarDailyTotalsProvider`、账户/预算 provider 全部 `ref.watch(ledgerVersionProvider)`；写操作（记账/转账/CSV commit/备份恢复/同步合并）统一 `bumpLedgerVersion`。`quick_entry_controller.save()` 包 try/finally 复位 `saving`。
- **涉及文件**：`quick_entry_sheet.dart:94-95`、`quick_entry_controller.dart:127-160`、`reports_repository` 相关 providers、`calendar_page.dart`、`backup_page.dart:71`、`sync_merger.dart`
- **验证**：记一笔 → 切报表/日历立即见新数据；恢复备份后全页面数据一致。

#### BK-R-006 周期/分期自动补跑（F-2）
- **实现**：`main()` 完成首帧后 `RecurringService.runAll()` + `runInstallmentDues()`；`AppLifecycleState.resumed` 时重跑（WidgetsBindingObserver 挂在 shell）。补跑结果静默，失败记日志不阻塞启动。
- **涉及文件**：`app/lib/main.dart`、`app/lib/app.dart`、`recurring_service.dart:116`
- **验证**：规则 next_due 设在昨天 → 杀进程重进 → 流水自动生成且幂等（重复启动不重复入账）。

#### BK-R-007 启用 SQLCipher（B-2）
- **实现**：启动序列：KeyStore 读/生成 32 字节密钥（flutter_secure_storage）→ 检测库头（明文 `SQLite format 3` → `sqlcipher_export` 迁移并校验行数）→ `openEncrypted`。`PRAGMA key` 参数化。密钥损坏兜底：提示用户"重置本地库"（明确数据丢失警告）。
- **涉及文件**：`app/lib/main.dart:33`、`app/lib/data/local/database_provider.dart:9`、`database.dart:41-43`、`core/security/key_store.dart:10`
- **验证**：adb pull 库文件 hexdump 前 16 字节非明文头；旧明文库升级后数据完整；错误密钥启动走兜底路径不崩溃。

#### BK-R-008 同步引擎接线与登录（B-1）
- **实现**：设置页"账户与同步"分组（登录/注册/同步状态/手动同步）；`main()` 读 refresh_token → SyncEngine.start()；未登录纯本地降级（op-log 照常入队，登录后追平）。
- **涉及文件**：`app/lib/features/sync/sync_engine.dart:16`、`main.dart`、`features/settings`（新增分组）、`core/security`（token 存储）
- **验证**：双设备同账号记账互见；401 自动刷新；断网记账联网后自动推送。

### 2.2 第二波：数据安全与并发

#### BK-R-009 pull 安全窗口与重放队列（L-3、F-6）
- **服务端**：`/sync/pull` 增加 `AND created_at < now() - interval '2 seconds'` 安全窗口；响应带 `server_time`。
- **客户端**：已收 op 按 op_id 去重容忍重拉；新增 `pending_replay` 表，`_createTransaction` 因 FK 未就绪跳过的 op 入表，相关实体 op 到达后触发重放，成功才推进游标语义。
- **涉及文件**：`server/src/sync/op.service.ts:58-63`、`app/lib/features/sync/sync_merger.dart:163`、`sync_engine.dart:171`、迁移 v6→v7（pending_replay）
- **验证**：并发 push A/B 乱序提交脚本断言双端最终一致；构造 account 晚于 transaction 到达的 op 序列断言流水不丢。

#### BK-R-010 同步客户端完善（B-1 衍生）
- `_request` 扩展 DELETE/PATCH；解析服务端 `{error}` 字段纳入 SyncApiException；401 刷新竞态加单飞锁。
- **涉及文件**：`app/lib/features/sync/sync_api.dart:85-90,104`

#### BK-R-011 共享账本落地（F-3）
- serverBooksProvider 拉取后 `createLocalBook` 缓存服务端账本；SyncMerger `_entities` 增加 'book'；账本切换器混合展示本地+共享（角色角标）。
- **涉及文件**：`app/lib/features/books/books_page.dart:190-206`、`sync_merger.dart:25`
- **验证**：被邀请账号登录 → 共享账本出现在切换器 → viewer 写操作被拦截（现有权限模型复用）。

#### BK-R-012 服务端安全基线（L-4、L-10、L-12）
- helmet + CORS 白名单 + auth 路由 5 次/分钟/IP 限流 + sync 按用户配额；统一 JSON error middleware + 404 handler；登录 dummy-hash 抹平时序；refresh 清理 try/catch；JWT_SECRET 缺失拒绝启动；SIGTERM 优雅停机。
- **涉及文件**：`server/src/app.ts:14-29`、`index.ts:15-17`、`auth.routes.ts:52-59`、`tokens.ts:46-48`

#### BK-R-013 UI 结构重构（U-1、U-9）
- 页面级组件剥离内层 Scaffold/AppBar/FAB；主 shell 按 Tab 配置标题与动作；`body` 改 IndexedStack 保持状态。
- **涉及文件**：`app/lib/app.dart:67-111`、`categories_page.dart`、`budgets_page.dart`、`reports_page.dart`、`calendar_page.dart`、`accounts_page.dart`

#### BK-R-014 数据生命周期（F-4、L-6、F-7、F-8 部分）
- 备份补 `currencies/recurring_rules/installment_plans/installment_schedules` + `schemaVersion` 校验；分期排期复用 `_dayInMonth` 月末回退；周期规则表加 `type` 字段（迁移 v6→v7 合并）；`refreshSnapshots` 批量查询；CSV commit 包事务。
- **涉及文件**：`backup_service.dart:24-33`、`recurring_service.dart:46,98-102`、`account_repository.dart:221-250`、`capture_confirm_page.dart:73-84`

### 2.3 第三波：体验与体积

#### BK-R-015 体积压缩（71MB → ~25MB）
- `flutter build appbundle` 为主分发；`--split-per-abi` 兜底；release `abiFilters` 去 x86_64；`minifyEnabled/shrinkResources`；`--obfuscate --split-debug-info`；SQLCipher 去留按 BK-R-007 结论；占位依赖 audit。
- **涉及文件**：`app/android/app/build.gradle.kts`、`app/pubspec.yaml:17-18`、CI 工作流
- **验证**：arm64 APK ≤ 28MB；AAB 上传 Play Console 各 ABI 下发包 ≤ 26MB；符号表归档可符号化崩溃。

#### BK-R-016 UI 性能与记账核心路径（U-3、U-4、U-10、图表）
- AmountKeyboard 包 `SafeArea(top:false)`；quick_entry 保存 busy 锁；RuleEditSheet 补 viewInsets；五处列表改 builder；饼图外置 legend + 扇区仅百分比；折线 tooltip 金额格式化；坐标轴可读刻度。
- **涉及文件**：`amount_keyboard.dart:19-33`、`quick_entry_sheet.dart:82-152`、`recurring_page.dart:236-318`、`report_charts.dart:24-45,66,145`、五处列表页

#### BK-R-017 深色模式与设计系统（U-2、U-5、U-8、图表泄露）
- `buildTheme(Brightness)` + darkTheme + themeMode:system；`AppColorsExtension` 语义色替换 6 处硬编码；字号下限 12sp；cashflow 脱敏态坐标尺度固定化。
- **涉及文件**：`app/lib/app.dart:61-64`、`main.dart:27-32,53-60`、`shared/theme`（新增）、`cashflow_chart.dart:52-64`、`calendar_page.dart:198`

#### BK-R-018 预算提醒闭环（F-5、F-10）
- 阈值读 `budgets.threshold`；保存流水后评估 → `flutter_local_notifications` 本地通知（每周期每预算一次，`markAlertNotified` 补 onConflict）；预算编辑/删除 UI + 同分类唯一性校验。
- **涉及文件**：`budget_progress_calculator.dart:6`、`budget_repository.dart:146,152-156`、`budgets_page.dart`

#### BK-R-019 多币种贯通（F-8、F-9、L-5）
- 账户币种字段 + 转账按账户币种写 rate_snapshot；手动汇率 UI；未设置汇率显式提示（废 0.1 占位静默）；报表折算读 `rate_snapshot`。
- **涉及文件**：`transaction_repository.dart:116,126`、`account_edit_sheet`、`currency_repository.dart:86`、`reports_repository.dart:189-195`

### 2.4 第四波：加固与清偿

#### BK-R-020 可访问性与交互反馈（U-7、U-12、U-13）
- 触控目标 ≥48dp；HapticFeedback + Semantics；账户 trailing more 图标；备份操作 busy 态；报表错误态重试。

#### BK-R-021 并发测试与测试基建
- 并发用例：双 owner / 邀请复用 / pull 丢 op / refresh 轮换；jest 默认排除 integration、独立 `bookkeep_test` 库、去除 `--coverage=false`（80% 覆盖率门禁由 CI `test:coverage` 全量套件实际执行）。
- **涉及文件**：`server/jest.config.js`、`server/tests/`

#### BK-R-022 技术债清偿（低危项集合）
- 删重复 createTransfer；占位依赖清理；PRAGMA 参数化（并入 R-007 则免）；CSV 表头自动定位 + 金额整数解析；`firstDueAfter` 窗口动态化；LWW 删除优先语义写文档+测试锁定。

---

## 3. 涉及文件清单汇总

### 3.1 Flutter 客户端（app/lib）

| 文件 | 变更 | 任务 |
|---|---|---|
| main.dart | openEncrypted 启动序列、自动补跑、主题联动、系统栏 | R-006, R-007, R-008, R-017 |
| app.dart | 双 Scaffold 根治、IndexedStack、darkTheme、resumed 补跑 | R-006, R-013, R-017 |
| core/ledger_version.dart（新增） | 刷新总线 | R-005 |
| core/constants/constants.dart | 删除 kDefaultBookId 回退 | R-004 |
| data/local/database.dart / database_provider.dart | openEncrypted 接线、PRAGMA 参数化、迁移 v7 | R-007, R-009, R-014 |
| data/repositories/transaction_repository.dart | bookId 必传、删重复 createTransfer、转账币种 | R-004, R-019, R-022 |
| data/repositories/account_repository.dart | 删 createTransfer 重复、N+1 批量 | R-014, R-022 |
| data/repositories/budget_repository.dart | onConflict、阈值接线 | R-018 |
| data/repositories/currency_repository.dart | 废 0.1 占位、手动汇率 | R-019 |
| data/repositories/reports_repository.dart | rate_snapshot 折算 | R-019 |
| features/quick_entry/* | 刷新总线、busy 锁、SafeArea、try/finally | R-005, R-016 |
| features/recurring/* | DI 收口、月末回退、type 字段、键盘避让 | R-004, R-006, R-014, R-016 |
| features/sync/* | 引擎接线、重放队列、book 实体、DELETE/PATCH | R-008~R-011 |
| features/backup/* | 补 4 表、schemaVersion、busy 态 | R-014, R-020 |
| features/books/books_page.dart | 共享账本落地、teal 硬编码 | R-011, R-017 |
| features/budgets/* | 阈值、提醒、编辑/删除 | R-018 |
| features/reports/* / features/calendar/* | provider watch 总线、图表整改、字号 | R-005, R-016, R-017 |
| shared/theme/（新增） | buildTheme + AppColorsExtension | R-017 |
| features/settings/（新增分组） | 登录/注册/同步状态 | R-008 |

### 3.2 服务端（server/src）

| 文件 | 变更 | 任务 |
|---|---|---|
| db/pool.ts / db/tx.ts（新增） | connect() + withTransaction | R-001 |
| db/migrate.ts | 部分唯一索引、pending 表 | R-003 |
| books/books.routes.ts | 事务化、邀请原子化、角色白名单 | R-001, R-002 |
| auth/book.middleware.ts | 建账收敛、pull 404 | R-003 |
| sync/op.service.ts | pull 安全窗口 | R-009 |
| app.ts / index.ts | helmet/CORS/限流/错误中间件/优雅停机 | R-012 |
| routes/auth.routes.ts / auth/tokens.ts | 时序抹平、清理容错、密钥强制 | R-012 |
| jest.config.js / tests/ | 并发用例、集成拆分、独立测试库 | R-021 |

### 3.3 构建与配置

| 文件 | 变更 | 任务 |
|---|---|---|
| app/android/app/build.gradle.kts | abiFilters、minify、shrinkResources | R-015 |
| app/pubspec.yaml | 占位依赖 audit、flutter_local_notifications | R-015, R-018, R-022 |
| CI 工作流 | AAB/split-per-abi、符号表归档 | R-015 |

---

## 4. 实施进度追踪表

> 状态与《07-审查修复任务分解.md》实时同步；规则沿用 v1.0：任一时刻 ≥1 个 in_progress。

| 任务 | 波次 | 状态 | 负责人 | 预计 | 完成日期 |
|---|---|---|---|---|---|
| BK-R-001 服务端事务封装 | 一 | **completed** | — | 0.5d | 2026-08-07 |
| BK-R-002 邀请原子化与角色收敛 | 一 | completed | — | 0.5d | 2026-08-07 |
| BK-R-003 建账竞态与 pull 只读化 | 一 | completed | — | 1d | 2026-08-07 |
| BK-R-004 Repository DI 收口 | 一 | completed | — | 1d | 2026-08-07 |
| BK-R-005 账本刷新总线 | 一 | completed | — | 0.5d | 2026-08-07 |
| BK-R-006 周期/分期自动补跑 | 一 | completed | — | 0.5d | 2026-08-07 |
| BK-R-007 启用 SQLCipher | 一 | completed（设备验证待做） | — | 2d | 2026-08-07 |
| BK-R-008 同步引擎接线与登录 | 一 | completed（e2e 待设备） | — | 3d | 2026-08-07 |
| BK-R-009 pull 安全窗口与重放队列 | 二 | completed | — | 2d | 2026-08-07 |
| BK-R-010 同步客户端完善 | 二 | completed | — | 0.5d | 2026-08-07 |
| BK-R-011 共享账本落地 | 二 | completed（e2e 待设备） | — | 1d | 2026-08-07 |
| BK-R-012 服务端安全基线 | 二 | completed（集成用例 CI） | — | 1d | 2026-08-07 |
| BK-R-013 UI 结构重构 | 二 | completed | — | 1d | 2026-08-07 |
| BK-R-014 数据生命周期 | 二 | completed | — | 1.5d | 2026-08-07 |
| BK-R-015 体积压缩 | 三 | completed（体积实测待 CI） | — | 1d | 2026-08-07 |
| BK-R-016 UI 性能与记账核心路径 | 三 | completed（真机走查待设备） | — | 2d | 2026-08-07 |
| BK-R-017 深色模式与设计系统 | 三 | completed（走查待真机） | — | 2d | 2026-08-07 |
| BK-R-018 预算提醒闭环 | 三 | completed | — | 1.5d | 2026-08-07 |
| BK-R-019 多币种贯通 | 三 | completed | — | 2d | 2026-08-07 |
| BK-R-020 可访问性与交互反馈 | 四 | completed（读屏走查待真机） | — | 1d | 2026-08-07 |
| BK-R-021 并发测试与测试基建 | 四 | completed | — | 2d | 2026-08-07 |
| BK-R-022 技术债清偿 | 四 | completed | — | 1.5d | 2026-08-07 |

**里程碑**：MR-1（第一波完成）= P0 流程全部闭环可发内测；MR-2（第二波）= 数据安全达标；MR-3（第三波）= 可上商店的体验与体积；MR-4（第四波）= v1.0 质量门禁。

---

## 5. 验证与测试方案

### 5.1 单元测试（新增/补强）

| 目标 | 用例 | 断言 |
|---|---|---|
| withTransaction | 中途抛错 | 无任何半提交残留；连接已 release |
| 邀请原子化 | 并发双接受 | 仅一个 2xx；token used_at 非空 |
| 建账竞态 | 并发首推同 book_id | 仅一个 owner（部分唯一索引生效） |
| pull 安全窗口 | 乱序提交 A/B | 双端最终一致，无丢 op |
| DI 收口 | RecurringService 注入当前 bookId | 生成流水 book_id = 当前账本 |
| 刷新总线 | 写操作后 bump | 所有报表 provider 重建 |
| 月末回退 | 1月31日起分期 | 2月28/29 日生成，无 3月3日 漂移 |
| 预算阈值 | threshold=50 | 50% 触发提醒且每周期仅一次 |
| rate_snapshot | 历史流水改汇率后 | 报表金额不变 |

### 5.2 集成测试

- 服务端：并发套件（双 owner / 邀请复用 / pull 乱序 / refresh 轮换）；统一 JSON 错误形态断言（无 HTML）；限流触发 429。
- 客户端：备份全表往返（含 4 张补录表）逐行比对；sqlcipher_export 迁移后行数校验；CSV 真实支付宝/微信样本（20 行元信息头）导入成功。
- jest：默认 `npm test` 仅单元（无 DB 可跑，jest 默认不收集覆盖率）；`test:integration` 连 `bookkeep_test` 独立库；coverageThreshold 80% 由 CI `test:coverage` 全量单元+集成套件门禁。

### 5.3 端到端 / 设备验证

- 双设备同账号互同步（登录→记账→对端可见→冲突 LWW 收敛）。
- 记账键盘在 targetSdk 36 edge-to-edge 设备上"确定"键无遮挡；深色模式全页面走查；大字体（textScaler 1.3）日历不溢出。
- 备份→卸载→重装→恢复→全页面数据一致（刷新总线验证）。

### 5.4 安全验证清单（并入原 BK-T-009）

- adb pull 数据库 hexdump 前 16 字节非 `SQLite format 3` 明文头。
- 爆破脚本打 /auth/login 触发 429；响应时间差 < 20ms（时序抹平）。
- 非 production 环境错误响应不泄露堆栈；JWT_SECRET 缺失进程拒绝启动。
- 脱敏态图表坐标尺度不含真实金额量级。

### 5.5 体积与性能验收

- arm64 APK ≤ 28MB；AAB 各 ABI 下发包 ≤ 26MB（对比基线 71MB）。
- 冷启动 ≤ 3s 保持（R-006/R-007 不得引入回归，启动补跑异步化）。
- 符号表归档且崩溃可符号化。

### 5.6 回归门禁

- 全部既有测试保持绿（app 242 + server 55 为基线，新增用例只增不减）。
- flutter analyze 0 issues；jest coverage ≥ 80%。
- 每波次完成后更新：本表 §4、《07-审查修复任务分解.md》、《04-验收报告.md》追加审计记录。
