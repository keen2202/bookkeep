# bookkeep — 极速记账 App

一款主打「3 秒记一笔」的个人/家庭记账应用：本地优先、乐观写入、离线可用，通过 op-log 增量同步实现多设备/多成员最终一致。覆盖 P0 核心闭环（极速记账、多账户、分类、预算、报表、云同步、隐私锁）与 P1 差异化功能（多账本共享、自动记账、备份导出、周期分期、多币种、日历视图）。

> 规格与验收基线：`docs/02-Spec规格说明.md`（Spec v1.0）、`docs/03-任务分解.md`、`docs/04-验收报告.md`

## 功能特性

### P0 核心闭环
| 功能 | 说明 |
|---|---|
| 极速记账 | 自绘数字键盘（支持 `+/-` 简易运算）、默认分类/账户回填、乐观写本地落库 + `sync_ops` 入队、秒开模式（冷启动直达记账页） |
| 多账户/资产管理 | 多类型账户 CRUD + 归档（软删除）、余额日快照缓存、转账双流水（`transfer_id` 双向关联）、净资产计算 |
| 分类体系 | 两级分类（14 父 + 60 子系统分类 seed，版本化安装）+ 自定义增删改排序，软删除保留历史流水分类名快照 |
| 预算 | 月度总预算 + 一级分类预算、月起始日可配、80%/100% 阈值提醒（恰好一次）、跨周期自动重置、日均消耗 |
| 基础报表 | 饼图（分类占比）+ 柱状图（周期对比：日=最近7天 / 周=最近5周 / 月=最近5月 / 年=最近5年，支出红/收入绿双柱对比）、隐藏金额开关，基于日聚合查询层（万条数据 < 500ms） |
| 云端同步 | op-log 增量同步、Lamport 时钟 + LWW 冲突解决（删除优先）、断网队列恢复、双客户端最终一致 |
| 隐私锁 | 生物识别 + PIN（PBKDF2 ≥100k 迭代 + 随机盐 + 常量时间比较）、30s 自动上锁、启动即锁、锁定态金额脱敏 |

### P1 差异化
| 功能 | 说明 |
|---|---|
| 多账本 + 共享账本 | 账本 CRUD + 场景模板、邀请链接（72h 一次性 token，仅存 SHA-256）、三角色权限矩阵（owner/editor/viewer，UI + 服务端双校验）、book 粒度数据与同步隔离 |
| 自动/智能记账 | 支付宝/微信 CSV 解析导入（去重 + 幂等）、Android 通知/短信解析、AI 语音入口（规则引擎抽取，LLM 抽象层默认关闭）；全部经确认页才入账，杜绝静默写库 |
| 备份 + 导出 | CSV 导出（区间/账本/类型筛选）、AES-256-GCM 加密备份（PBKDF2 派生密钥，口令不落盘）、WebDAV 上传/恢复（仅 HTTPS）、单事务原子恢复 |
| 周期/分期记账 | 日/周/月/季/年频率 + 按频率的锚点选项（月初/月中/月末等）、RRULE 子集展开引擎（月末回退、闰年、跨年）、启动补跑幂等、分期计划（等额末笔补差，合计误差 0） |
| 多币种 + 汇率 | 156 种 ISO 4217 币种 seed、流水三要素（原币/币种/汇率快照）、24h TTL 汇率缓存 + 手动汇率、报表按主币种折算（定点整数 half-up，精度到分） |
| 日历/现金流视图 | 月历日格收支净额（支出红/收入绿）、点击进当日明细、30 天滑动窗口现金流趋势图、月份懒加载 |

## 架构

```
bookkeep/
├── app/        # Flutter 客户端（Riverpod + Drift + SQLCipher）
├── server/     # Node.js 同步后端（Express + PostgreSQL + JWT）
├── docs/       # Spec、任务分解、验收报告、OpenAPI 契约、产品调研
└── .github/    # CI（PR lint + unit）/ Nightly 集成测试
```

### 客户端分层（`app/lib/`）

- **core/** — 常量、错误、工具（金额/CSV）、安全（`pin_hash`、`backup_cipher`、`cipher`、`key_store`）
- **data/** — Drift 数据库（13 张表，schema v7 迁移链）、按实体划分的 Repository（transaction/account/category/budget/book/currency/settings/reports/lock）、`OpLogger` 操作日志
- **domain/** — 实体模型、值对象、服务（`AccountBalanceCalculator`、`BudgetProgressCalculator`、`CategoryResolver`、`LwwResolver`）、用例（`create_transaction`）
- **features/** — 按功能分模块：quick_entry、accounts、categories、budgets、reports、calendar、books、auto_capture、recurring、currency、backup、auth_lock、sync

- **shared/theme/** — iOS 毛玻璃视觉体系（FGDS v1.0，BK-FG 系列）：
  - `glass_tokens.dart` — 唯一参数源：G1–G5 层级表（blur/fill/双层描边/顶部内高光/环境投影/圆角）+ 主题色/背景/遮罩/文字四档/动效常量（Spec §2–§6）；
  - `glass_prefs.dart` — 唯一可调项：磨砂降级开关（禁用 BackdropFilter 时 fill α+0.10 补偿）；
  - `background/app_background.dart` — §2.2 白名单纯净底色（#F2F2F7 / #000000），无光斑无背景图；
  - 一致性门禁：`tool/check_glass_consistency.sh`（BackdropFilter 唯一出口 + σ 单源 + ambient/旧系统零残留）、`tool/check_fg_contrast.dart`（§7.1 对比度验算），CI 强制。
  - 设计依据：`docs/22~24` iOS 毛玻璃三件套（22 设计 / 23 Spec / 24 任务分解）；验收报告：`docs/25-iOS毛玻璃验收报告.md`。
- **shared/** — 通用组件（`category_picker` 两级选择器等）

状态管理使用 Riverpod：`currentBookIdProvider` 注入账本上下文（查询强制过滤、写路径打标、sync_ops 按账本分区）；`amountMaskProvider` 统一注入锁定脱敏。

### 本地存储

- 数据库：Drift（SQLite）+ 设备端 SQLCipher 加密（PRAGMA key 打开后立即执行），密钥托管于 Keystore/Keychain；加密经 sqlite3 native-assets hooks（`hooks.user_defines.sqlite3.source: sqlcipher`）提供，勿误删 hooks 或回退旧打包方式
- 金额一律以整数最小单位（分）存储，计算用定点整数，避免浮点误差
- 跨设备实体身份：各业务表 `remote_id`（uuid v4），`sync_ops` 记录完整实体快照（lamport + client_id）

### 同步协议（契约先行，OpenAPI 3.1：`docs/openapi/sync-api.yaml`）

- 客户端本地写 → 追加 op（c/u/d + 完整快照 + Lamport 时钟）→ `POST /sync/push` 批量上送 → `GET /sync/pull?since=` 游标拉取
- 冲突解决：同实体按 `(lamport, client_id)` 比较 LWW，删除优先于修改；畸形 op 单条跳过不阻塞同步
- 认证：JWT access 15min + refresh 30d 轮换；所有接口鉴权到 book 粒度（viewer 写 403、跨账本 403）

### 服务端（`server/src/`）

Express + PostgreSQL：`routes/{auth,sync,health,books}`、`sync/{validate,op.service}`（op 校验与落库）、`auth/`（JWT、密码哈希、book 中间件）。数据库迁移见 `db/migrate.ts`。

## 技术栈

| 层 | 技术 |
|---|---|
| 客户端 | Flutter / Dart ≥3.3、Riverpod 2.x、Drift 2.x + SQLCipher、fl_chart、table_calendar、local_auth、flutter_secure_storage、cryptography |
| 服务端 | Node.js / TypeScript、Express 5、PostgreSQL 16、jsonwebtoken |
| 测试 | flutter_test（unit/widget/integration）、mocktail、Jest + supertest（含真实 PG 集成测试） |
| CI | GitHub Actions：PR 触发 lint + unit（服务端覆盖率门禁 80%），nightly 跑集成测试 |

## 快速开始

依赖：Flutter ≥ 3.19（stable）、Node.js ≥ 20、Docker（本地 PG）。

```bash
# 一键安装依赖
make setup          # = server npm ci + app flutter pub get

# 服务端本地数据库（Docker 起 PostgreSQL 16）
make db-up
make server-migrate # 或 cd server && npm run migrate

# 运行服务端
cd server && npm run dev          # 默认 http://localhost:3000

# 运行 App
cd app && flutter run
```

Flutter 新手入门资源：

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)
- [Flutter 在线文档](https://docs.flutter.dev/)（tutorials、samples、API 参考）

## 测试与质量门禁

```bash
make lint           # server: tsc --noEmit + app: flutter analyze
make test           # server: jest + app: flutter test
make server-coverage
make app-coverage
```

当前基线（`docs/04-验收报告.md` 2026-08-02 实测）：客户端 **242/242** 测试通过、`flutter analyze` 0 issues、服务端 **55/55** 测试通过；性能预算达标（100 次保存平均 < 200ms、10k 条报表渲染 < 500ms）。App 覆盖率实测 68.2%（CI 仅收集不设门禁）、服务端 87.7%（门禁 80% 通过）。

## 文档

| 文档 | 内容 |
|---|---|
| `docs/01-开发建议.md` | 技术选型与开发建议（BK-Px-xxx 方案编号） |
| `docs/02-Spec规格说明.md` | 规格 v1.0：全局架构约定、P0/P1 各功能实现方案与验证标准、测试总方案、安全清单 |
| `docs/03-任务分解.md` | 任务 DAG（BK-T-xxx）与逐项 Checklist |
| `docs/04-验收报告.md` | 验收审计：测试/覆盖率实测、任务逐项判定、已知缺口 |
| `docs/openapi/sync-api.yaml` | 同步协议 OpenAPI 3.1 契约 |

## 项目状态

- 15 项任务中 13 项完成（BK-T-001~008、010~015，P0 与 P1 功能主体全部落地）
- BK-T-009（P0 验收门禁/Alpha 发布）blocked：需真机/发布渠道验证 TLS 证书固定与 SQLCipher 密文
- BK-T-016（Beta 回归与 1.0 发布）pending：全量回归、近 3 版本迁移测试、灰度发布
