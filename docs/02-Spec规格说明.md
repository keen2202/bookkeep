# Spec 规格说明文档

| 项目 | 值 |
|---|---|
| 文档版本 | v1.0 |
| 日期 | 2026-08-01 |
| 依据 | 《记账APP产品调研报告.html》P0/P1 结论 + 《01-开发建议.md》 |
| 范围 | 记账 App（Flutter 客户端 + Node.js 同步后端）P0/P1 全部功能 |
| 追踪规则 | Spec 章节号 ↔ 方案编号（BK-Px-xxx）↔ 任务编号（BK-T-xxx） |

## 1. 全局架构约定

### 1.1 仓库结构
```
bookkeep/
├── app/                    # Flutter 客户端
│   ├── lib/
│   │   ├── main.dart / app.dart
│   │   ├── core/           # constants, errors, utils, security
│   │   ├── data/           # models, repositories, datasources(local/remote)
│   │   ├── domain/         # entities, usecases, value objects
│   │   ├── features/       # 按功能分模块（见各 Spec 文件列表）
│   │   └── shared/         # 通用 widgets / 主题
│   └── test/               # unit / widget / integration
├── server/                 # 同步后端
│   ├── src/{routes,controllers,services,models,sync,auth}
│   └── tests/
└── docs/
```

### 1.2 核心数据模型（Drift / PostgreSQL 同构）
| 表 | 关键字段 | 说明 |
|---|---|---|
| books | id, name, type, owner_id, created_at | P1-001 引入，P0 阶段内置 default book |
| accounts | id, book_id, type, name, currency, initial_balance, archived | |
| categories | id, book_id, parent_id, name, icon, color, kind(expense/income), is_system, deleted_at | |
| transactions | id, book_id, account_id, category_id, type, amount_minor, currency, rate_snapshot, note, occurred_at, transfer_id, auto_generated, updated_at, deleted_at | 金额为整数最小单位 |
| budgets | id, book_id, category_id(null=总预算), period, amount_minor, threshold | |
| sync_ops | id, book_id, entity, entity_id, op(c/u/d), payload, lamport, client_id, pushed | 同步操作日志 |
| recurring_rules | id, book_id, frequency(day/week/month/quarter/year), interval, anchor_type(start/middle/end/custom), anchor_day, time_of_day, rrule, amount_minor, account_id, category_id, next_due, end_type | P1-004；锚点经 AnchorResolver 展开为 rrule |
| book_members | book_id, user_id, role(owner/editor/viewer) | P1-001 |
| exchange_rates | base, quote, rate, fetched_at | P1-005 |
| account_snapshots / mv_category_daily | 日聚合缓存 | 报表/日历性能 |

### 1.3 同步协议（契约先行，OpenAPI 3.1 定义）
- `POST /sync/push`：客户端上送 op 批次；服务端按 book 校验权限后落库，返回已受理 seq。
- `GET /sync/pull?book_id=&since=`：游标式增量拉取。
- 冲突：同实体按 `(lamport, client_id)` 比较，LWW；删除优先于修改。
- 认证：JWT access 15min + refresh 30d（轮换）；所有接口鉴权到 book 粒度。

### 1.4 测试全局门禁
- 领域逻辑（金额、预算、汇率、同步冲突）单元测试覆盖率 ≥ 80%。
- CI：每次 PR 跑 unit + widget；每晚跑 integration；发布前全量回归。
- 性能预算：冷启动 ≤ 1.5s；记账保存（本地落库）P95 ≤ 200ms。

---

## 2. P0 阶段 Spec

### §3.1 极速记账（BK-P0-001 / BK-T-002）
**技术实现**
- 记账流：`+` → 类型(支出/收入/转账) → 数字键盘输金额 → 选分类（默认上次）→ 保存。保存即写本地 + 入 `sync_ops`，UI 立即返回成功（乐观写）。
- 数字键盘：自绘，支持 `.`、`+/-` 简易运算；金额 parse 为整数分，非法输入抖动提示。
- 秒开模式：设置项开启后冷启动直达记账页。
**涉及文件（新建）**
- `app/lib/features/quick_entry/quick_entry_sheet.dart`
- `app/lib/features/quick_entry/amount_keyboard.dart`
- `app/lib/features/quick_entry/quick_entry_controller.dart`
- `app/lib/domain/usecases/create_transaction.dart`
- `app/lib/data/repositories/transaction_repository.dart`（新建方法）
- `app/lib/shared/widgets/category_picker.dart`
**修改范围**：`main.dart`（秒开路由）、`app.dart`（导航挂载）；不动账户/分类模块内部。
**验证标准**：启动→保存成功 ≤ 3 秒（Profile 实测）；保存后主列表即时可见；断网可保存且恢复联网后自动同步。
**测试方案**
- 单元：金额解析（含运算式）、默认分类/账户回填、create_transaction 乐观写与 op 生成。
- 集成：本地 DB 写入→列表刷新→sync_ops 入队链路。
- 回归：性能基准测试（启动时间、保存耗时）纳入 CI 门禁。

### §3.2 多账户/资产管理（BK-P0-002 / BK-T-003）
**技术实现**
- 5 类账户；余额 = initial_balance + Σ流水，快照表日缓存；转账 = 双流水 + transfer_id。
- 净资产 = Σ资产账户 − Σ负债账户。
**涉及文件（新建）**
- `app/lib/features/accounts/{accounts_page,account_edit_sheet,account_card}.dart`
- `app/lib/domain/services/account_balance_calculator.dart`
- `app/lib/data/repositories/account_repository.dart`
- `app/lib/data/local/tables/accounts_table.dart`、`account_snapshots_table.dart`
**修改范围**：`transaction_repository.dart`（转账关联）；快照刷新挂到流水写路径。
**验证标准**：新增/编辑/归档账户即时反映余额；转账两账户余额联动正确（误差为 0）；归档账户不出现在选择器但历史报表可见。
**测试方案**
- 单元：余额聚合（含负数/跨类型）、转账双向一致性、归档过滤。
- 集成：大额随机流水（1 万条）下余额 = 逐笔累加结果一致。
- 回归：升级迁移（无账户旧数据 → default 账户）测试。

### §3.3 分类体系+自定义（BK-P0-003 / BK-T-004）
**技术实现**
- 一二级分类；seed 60+ 系统分类（version 字段控制迁移）；自定义增删改排序；软删除保留历史流水分类名快照。
**涉及文件（新建）**
- `app/lib/features/categories/{categories_page,category_edit_sheet}.dart`
- `app/lib/domain/services/category_resolver.dart`
- `app/lib/data/local/tables/categories_table.dart`
- `app/assets/seed/categories_seed.json`
**修改范围**：`category_picker.dart`（两级展开）；数据库 migration v1→v2 加 seed version。
**验证标准**：首次安装 seed 完整；删除被引用分类时提示并保留历史显示；排序/颜色修改即时生效。
**测试方案**
- 单元：resolver id→显示、软删除语义、seed 解析。
- 集成：migration 后系统分类齐全且用户分类不丢。
- 回归：升级场景（老库 → 新 seed version）自动化。

### §3.4 预算（BK-P0-004 / BK-T-005）
**技术实现**
- 月度总预算 + 一级分类预算；月起始日可配；80% 预警/100% 超支通知；日均动态 = 剩余/剩余天数。
**涉及文件（新建）**
- `app/lib/features/budgets/{budgets_page,budget_edit_sheet,budget_progress_bar}.dart`
- `app/lib/domain/services/budget_progress_calculator.dart`
- `app/lib/data/repositories/budget_repository.dart`
- `app/lib/data/local/tables/budgets_table.dart`
**修改范围**：记账保存后触发预算重算事件（Riverpod provider invalidate）；通知中心接入。
**验证标准**：周期边界（含自定义起始日）计算正确；达到阈值恰好触发一次提醒；跨周期自动重置。
**测试方案**
- 单元：周期窗口计算（起始日为 1/5/31 等边界）、阈值触发、日均公式。
- 集成：连续多日流水下进度曲线正确。
- 回归：时区/夏令时边界用例。

### §3.5 基础报表（BK-P0-005 / BK-T-006）
**技术实现**
- 饼图（分类占比）、柱状（周期对比）、折线（趋势）；日/周/月/年 + 自定义区间；数据来自 `mv_category_daily` 物化视图。
**涉及文件（新建）**
- `app/lib/features/reports/{reports_page,charts/pie,charts/bar,charts/line}.dart`
- `app/lib/data/repositories/reports_repository.dart`
- `app/lib/data/local/views/mv_category_daily.dart`
**修改范围**：流水写路径增量刷新物化视图；无业务表结构变更。
**验证标准**：报表合计 = 流水明细合计（任意区间，误差 0）；空数据态友好；万条数据首屏渲染 ≤ 500ms。
**测试方案**
- 单元：聚合 DTO 正确性、区间过滤。
- 集成：物化视图增量刷新一致性（插入/删除流水后）。
- 回归：大数据量渲染性能基线。

### §3.6 云端同步 + 隐私锁（BK-P0-006 / BK-T-007, BK-T-008）
**技术实现**
- 同步：op-log + lamport 时钟；push/pull 分离；状态机 + 断网恢复；服务端 PostgreSQL 事务内批量落 op。
- 隐私锁：生物识别 + PIN（PBKDF2 ≥100k 迭代）；锁定时列表/报表/日历脱敏；后台 30s 自动上锁。
**涉及文件（新建）**
- 客户端：`app/lib/features/sync/{sync_engine,sync_state,sync_queue}.dart`、`app/lib/features/auth_lock/{lock_gate,pin_pad,biometric}.dart`、`app/lib/core/security/{cipher,key_store}.dart`
- 服务端：`server/src/sync/{sync.controller,sync.service,op.model}.ts`（或 .js）、`server/src/auth/{jwt,middleware}.ts`、`server/src/routes/sync.routes.ts`
**修改范围**：`transaction_repository.dart` 等所有写路径统一经 `OpLogger`；`main.dart` 挂 LockGate。
**验证标准**：多设备并发改同一条流水最终一致（LWW）；断网 100 条 op 恢复后全部同步且无重复；锁开启后进程被杀再进仍锁；PIN 不以明文/可逆形式存储。
**测试方案**
- 单元：冲突解决矩阵（u/u、u/d、d/d）、lamport 比较、PIN 哈希校验。
- 集成：双模拟客户端并发 push/pull 一致性；服务端鉴权/越权用例（403）。
- 回归：同步风暴（1000 ops）压测；升级后 op 重放幂等。

---

## 3. P1 阶段 Spec

### §4.1 多账本+共享账本（BK-P1-001 / BK-T-010）
**技术实现**
- books CRUD + 模板（生活/家庭/旅行/生意）；邀请链接（72h 一次性 token）；角色权限矩阵 owner/editor/viewer；所有查询强制 book 过滤。
**涉及文件（新建）**
- `app/lib/features/books/{books_page,book_switcher,share_invite_sheet,member_manager}.dart`
- `server/src/books/{books.controller,members.service}.ts`
**修改范围**：全部业务 Repository 基类注入 book 上下文；`sync_ops` 按 book 分区；数据库 migration 加 `book_id`（回填 default）。
**验证标准**：viewer 无法写（UI 与服务端双重拒绝）；移除成员后其客户端 pull 立即失效；不同 book 数据完全隔离。
**测试方案**
- 单元：权限矩阵全组合、book 过滤注入。
- 集成：双用户共享账本协同记账→双方一致；邀请 token 过期/复用拒绝。
- 回归：migration（老数据归 default book）验证。

### §4.2 自动/智能记账（BK-P1-002 / BK-T-011）
**技术实现**
- CSV 导入：支付宝/微信 Parser（策略模式），字段映射可配，去重（金额+时间+对方）；
- Android 通知/短信解析：正则抽取金额/商户 → `CaptureCandidate` → 确认页；
- AI 语音：STT → 规则引擎抽取 → 确认页；LLM 接口抽象（默认关闭）。
**涉及文件（新建）**
- `app/lib/features/auto_capture/{csv_import/{alipay_parser,wechat_parser,import_page},notification_listener.dart,sms_parser.dart,voice_entry_sheet.dart,capture_confirm_page.dart}`
- `app/lib/domain/services/capture_candidate.dart`
**修改范围**：`create_transaction` 增加 `auto_generated` 入参；设置页新增权限引导。
**验证标准**：导入 500 条 CSV 无重复且分类映射准确 ≥ 90%；所有自动候选必须经确认页；权限被拒绝时功能优雅降级。
**测试方案**
- 单元：两个 Parser 各 30+ 样本、去重逻辑、金额抽取正则。
- 集成：CSV 端到端导入→列表→报表一致。
- 回归：导入重复执行幂等。

### §4.3 备份+导出（BK-P1-003 / BK-T-012）
**技术实现**
- CSV 导出（区间/账本/类型筛选）；Excel 可选；WebDav 加密备份（zip = DB 快照 + manifest，AES-256-GCM，密钥 PBKDF2 派生）；恢复 = 导入→校验→原子切换。
**涉及文件（新建）**
- `app/lib/features/backup/{export_page,backup_service,webdav_client_wrapper,restore_page}.dart`
- `app/lib/core/security/backup_cipher.dart`
**修改范围**：设置页新增「备份与导出」；不动业务模块。
**验证标准**：导出 CSV 与库内数据逐行一致；加密备份在另一台设备用正确口令完整恢复；错误口令/损坏文件有明确报错且不破坏现有数据。
**测试方案**
- 单元：加解密往返、CSV 序列化（含中文/逗号/换行转义）。
- 集成：备份→清空→恢复全链路；WebDav mock server 往返。
- 回归：跨版本备份兼容（v1 备份 → v2 恢复）。

### §4.4 周期/分期记账（BK-P1-004 / BK-T-013）
**技术实现**
- 频率支持 **日/周/月/季/年** + 间隔 + 结束条件；季度以 `FREQ=MONTHLY;INTERVAL=3` 等价展开（不引入非标准 FREQ），自然季度 Q1=1~3月、Q2=4~6月、Q3=7~9月、Q4=10~12月。
- **时间锚点选项（按频率展示）**：日=具体时刻；周=周一~周日；月=月初(1日)/月中(15日)/月末(最后一日)/自定义；**季=季度初(季度首月1日)/季度中(季度次月15日)/季度末(季度末月最后一日)/自定义**；年=年初(1月1日)/年中(7月1日)/年末(12月31日)/自定义。
- 规则表持久化 `frequency + interval + anchor_type + anchor_day + time_of_day`，由 `AnchorResolver` 统一解析为 RRULE/日期序列（锚点语义集中，UI 不做日期推算）；启动补跑（幂等去重 rule_id+due_date）；分期等额生成计划表并关联信用卡；还款提醒通知。
**涉及文件（新建）**
- `app/lib/features/recurring/{recurring_page,rule_edit_sheet,recurring_engine,anchor_resolver,installment_plan}.dart`
- `app/lib/data/local/tables/recurring_rules_table.dart`
**修改范围**：记账保存路径复用；通知中心接入；规则编辑页按频率动态渲染锚点选项（含季度三项）。
**验证标准**：
- 季度规则跨年（Q4→Q1）展开正确：季度初=1/4/7/10月1日，季度中=2/5/8/11月15日，季度末=3/6/9/12月最后一日；
- 闰年 2 月月末锚点 = 2月29日（平年 2月28日）；
- App 30 天未开，打开后补齐全部到期流水且无重复；分期每期金额合计 = 总额（误差 0）；删除规则不影响已生成流水。
**测试方案**
- 单元：AnchorResolver 全频率×全锚点矩阵（含季度初/中/末、跨年 Q4→Q1、闰年 2 月）；RRULE 展开（含月末 31 日/2 月边界）；幂等去重；等额分期舍入（末笔补差）。
- 集成：时间旅行（mock clock）跨月/跨季/跨年执行。
- 回归：规则编辑（含锚点变更）后历史流水不受影响；季度规则连续 8 个季度展开无漂移。

### §4.5 多币种+汇率（BK-P1-005 / BK-T-014）
**技术实现**
- 100+ 币种；流水三要素（原币金额/币种/汇率快照）；主币种汇总；汇率 24h 缓存 + 手动修改。
**涉及文件（新建）**
- `app/lib/features/currency/{currency_picker,rate_settings}.dart`
- `app/lib/domain/value_objects/money.dart`
- `app/lib/data/services/exchange_rate_service.dart`
- `app/lib/data/local/tables/exchange_rates_table.dart`
**修改范围**：账户/报表聚合层接入 Money 换算；transactions 表加 currency/rate_snapshot（migration）。
**验证标准**：历史流水不随后续汇率波动而改变折算值；汇总折算精度到分（四舍五入银行家算法一致）；离线用缓存汇率并标注。
**测试方案**
- 单元：Money 换算定点运算、舍入策略、快照语义。
- 集成：汇率服务失败降级路径。
- 回归：migration 老数据默认主币种且 rate=1。

### §4.6 日历/现金流视图（BK-P1-006 / BK-T-015）
**技术实现**
- 月历日格显示收支净额；点击日进明细；现金流趋势 = 日净额滑动窗口；数据复用 `mv_category_daily`。
**涉及文件（新建）**
- `app/lib/features/calendar/{calendar_page,day_cell,cashflow_chart}.dart`
**修改范围**：仅新增只读模块；物化视图查询扩展。
**验证标准**：日聚合 = 当日明细合计（误差 0）；月份快速切换无闪烁（懒加载）；与报表页同区间数据一致。
**测试方案**
- 单元：日聚合 DTO、滑动窗口算法。
- 集成：与报表模块交叉一致性。
- 回归：大跨度（3 年）渲染性能。

---

## 4. 实施进度追踪表（里程碑）

| 里程碑 | 目标日期 | 范围 | 出口标准 | 状态 |
|---|---|---|---|---|
| M0 项目初始化 | 2026-08-07 | BK-T-001 | 骨架可跑通 CI；DB migration 框架就绪；同步契约 OpenAPI 定稿 | completed（2026-08-01） |
| M1 P0 功能完成 | 2026-09-04 | BK-T-002~008 | 6 个 P0 Spec 验证标准全过；单测覆盖率 ≥ 80% | pending |
| M2 P0 验收 / Alpha | 2026-09-11 | BK-T-009 | 核心路径回归通过；性能预算达标；Alpha 内测包发布 | pending |
| M3 P1 功能完成 | 2026-10-16 | BK-T-010~015 | 6 个 P1 Spec 验证标准全过；权限/安全用例全过 | pending |
| M4 Beta 回归 | 2026-10-30 | BK-T-016（前半） | 全量回归 + 迁移测试 + 双设备协同压测通过 | pending |
| M5 1.0 发布 | 2026-11-06 | BK-T-016（后半） | 商店资料/隐私政策齐备；灰度发布无 P0 级缺陷 | pending |

> 进度更新规则：每个任务状态变更同步更新本表与《03-任务分解.md》；里程碑延误 > 3 天需记录原因与补救措施。

---

## 5. 验证与测试总方案

### 5.1 单元测试
- 范围：`domain/` 全部 usecase/service/value object；Parser；加解密；同步冲突。
- 门禁：核心模块行覆盖 ≥ 80%，金额/汇率/预算模块 ≥ 90%。

### 5.2 集成测试
- 客户端：DB + Repository + 状态层链路（in-memory → 真机各一）。
- 服务端：Supertest 覆盖全部路由，含鉴权/越权/幂等。
- 端到端：integration_test 跑「记账→预算→报表→同步→锁」黄金路径。

### 5.3 回归测试
- 每个里程碑执行全量回归；数据库升级迁移测试（最近 3 个版本快照）；
- 性能回归：启动时间、保存耗时、万条数据渲染基线写入 CI 对比。

### 5.4 安全测试清单
- [ ] TLS 证书固定生效（抓包验证失败）
- [ ] SQLCipher 库文件不可明文读取
- [ ] PIN/口令哈希存储（无明文/可逆）
- [ ] 服务端越权访问 book 返回 403
- [ ] 备份文件错误口令无法恢复且不破坏数据
- [ ] 日志无金额/备注明文
