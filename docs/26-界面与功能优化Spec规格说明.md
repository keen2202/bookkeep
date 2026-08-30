# 26 - 界面与功能优化 Spec 规格说明（账单字号 / 语音移除 / 外观简化 / FAB 拖拽 / 周期迁移 / 日历入报表 / 分类增强）

| 项目 | 内容 |
| --- | --- |
| 文档编号 | BK-DOC-26 |
| 版本 | v1.0 |
| 日期 | 2026-08-30 |
| 状态 | 已实施（静态复核完成；`flutter analyze`/`flutter test` 与 golden 基线再生成待 SDK 环境） |
| 关联文档 | `docs/09-UI设计文档-主题与视觉体系.md`、`docs/20-玻璃拟态全链路Spec规格说明.md`、`docs/23-iOS毛玻璃Spec规格说明.md`、`docs/27-界面与功能优化任务分解.md` |
| 任务拆解 | `docs/27-界面与功能优化任务分解.md` |
| 适用范围 | `app/`（Flutter 3.44.x，Riverpod 2.6，Drift） |

---

## 1. 背景与目标

本 Spec 针对现有记账应用实施 7 项界面与功能优化，目标是：**收敛信息架构（5 主 Tab → 3 主 Tab）**、**移除低频冗余能力（语音记账、图标风格选择）**、**增强核心能力（记账按钮可拖拽、周期记账可在设置中管理、日历并入报表、分类支持层级与图标自定义）**，并统一账单页视觉层级。

七项需求概览：

| # | 需求 | 类型 | 一句话目标 |
| --- | --- | --- | --- |
| 1 | 账单数字样式 | 视觉 | 账单行金额字号与页面标题字号一致（17sp），统一视觉层级 |
| 2 | 移除语音记账 | 移除 | 删除「语音记账」入口、页面与全部相关代码/测试 |
| 3 | 外观设置简化 | 移除 | 外观页删除「图标风格选择」，收敛 IconPack 配置面 |
| 4 | 记账按钮拖拽 | 新增交互 | 右下角 + 长按拖拽自由移动，默认底部正中，拖动有视觉反馈，位置持久化 |
| 5 | 周期记账迁移 | 重构+新增 | 从首页移除「周期记账」，整合为设置项，支持创建/编辑/删除，兼容存量规则 |
| 6 | 日历报表整合 | 重构 | 日历视图并入报表页，日历显示每日收支净额，点击某日查看当天账单明细 |
| 7 | 分类管理增强 | 新增 | 新增分类可选层级（一级/二级）+ 自定义图标 + 语义化内置图标库 |

### 1.1 信息架构变化（核心）

底部主导航由 **5 Tab** 收敛为 **3 Tab**：

```
现状：账单 │ 分类 │ 周期记账 │ 报表 │ 日历
目标：账单 │ 分类 │ 报表（内含「图表 / 日历」双视图）
```

- 「周期记账」下沉为**设置页独立入口**（需求 5）。
- 「日历」并入**报表页**作为一个视图模式（需求 6）。
- `AppModule` 枚举随之从 5 项收敛为 3 项（`bills / categories / reports`），`moduleIcon`、`_tabTitles`、`IndexedStack`、`_tabActions` 同步收敛。
- 「图标风格选择」移除后（需求 3），`moduleIcon` 不再依赖 `IconPack`，固定输出 outlined 变体。

> 说明：报表页保留原「图表」能力（分类占比饼图 + 周期对比柱状），并新增「日历」视图；两者通过页内分段控件切换，互不覆盖。

---

## 2. 需求明细

> 每项包含：目标说明 / 交互流程与 UI 变更 / 涉及文件 / 验收标准。

### 2.1 需求 1 —— 账单数字样式

**目标说明**：账单页交易行金额当前为 `tokens.amountStyle`（20sp），页面标题「账单」为 `context.text.titleLarge`（17sp / w600）。将**交易行金额**字号对齐页面标题字号（17sp），统一视觉层级；保留等宽数字（tabular-nums）与收支语义着色、脱敏逻辑。

**交互流程与 UI 变更**：
- 纯视觉调整，无交互变化。
- 账单行右侧金额由 20sp → 17sp（`titleLarge` 字号），颜色语义（支出红/收入绿/转账中性）与等宽对齐保持不变。
- 日汇总组头（`_DayHeader`）维持现状（与组头标题同档），不在本次调整范围。

**实现要点**：`AppAmountText` 新增可选 `TextStyle? style` 尺寸覆盖参数（仍叠加语义色与等宽数字）；`bills_page.dart` 交易行传入 `context.text.titleLarge`。全程走 Design Token，不引入裸 `fontSize:`（满足 `check_ui_tokens.dart` 门禁）。

**涉及文件**：
- `app/lib/shared/widgets/app_amount_text.dart`
- `app/lib/features/bills/bills_page.dart`
- `app/test/widget/bills_page_test.dart`（新增字号断言）

**验收标准**：
- AC1-1：账单行金额渲染字号 == 页面标题字号（`titleLarge`，17sp）。
- AC1-2：等宽数字保留（金额列纵向对齐不回归）。
- AC1-3：收/支/转着色与脱敏（`¥***`）行为不变。
- AC1-4：`check_ui_tokens.dart` 无裸字号违规。

---

### 2.2 需求 2 —— 移除语音记账

**目标说明**：删除设置中的「语音记账」功能入口、`VoiceEntrySheet` 页面、`VoiceRecognizer/DisabledVoiceRecognizer/VoiceRuleEngine` 抽象与全部冗余代码、相关配置项与测试。短信解析（`SmsCaptureParser`）与 CSV 导入**保留**。

**交互流程与 UI 变更**：
- 设置弹层「CSV 导入 / 通知短信自动记账」区块中，移除「语音记账」`ListTile`。
- 无任何入口可再进入语音记账。

**实现要点**：删除 `voice_entry_sheet.dart`；移除 `csv_import_page.dart` 中对应 `ListTile` 与 import；清理 `capture_candidate.dart`、`capture_confirm_page.dart`、`sms_parser.dart` 中对「语音」的注释引用（保留短信/CSV 语义）；删除/裁剪相关测试。

**涉及文件**：
- `app/lib/features/auto_capture/voice_entry_sheet.dart`（删除）
- `app/lib/features/auto_capture/csv_import/csv_import_page.dart`
- `app/lib/features/auto_capture/capture_confirm_page.dart`（注释）
- `app/lib/features/auto_capture/sms_parser.dart`（注释）
- `app/lib/domain/services/capture_candidate.dart`（注释）
- `app/test/widget/voice_entry_sheet_test.dart`（删除）
- `app/test/unit/features/auto_capture/sms_voice_test.dart`（删除语音组，保留短信组）

**验收标准**：
- AC2-1：设置中无「语音记账」入口。
- AC2-2：`lib/` 与 `test/` 中不再有 `Voice`/`语音` 残留（短信/CSV 除外）。
- AC2-3：短信解析与 CSV 导入功能及测试保留且通过。

---

### 2.3 需求 3 —— 外观设置简化（移除图标风格选择）

**目标说明**：外观页删除「图标风格选择」选项，并收敛其整条配置链路（`IconPack` 枚举、`ThemeSettings.iconPack`、`ThemeController.setIconPack`、`SettingsRepository` 图标键、`appIcon`/`moduleIcon` 的 pack 参数），使模块图标固定为 outlined 变体。

**交互流程与 UI 变更**：
- 外观页移除「图标风格」分区（含 `SegmentedButton<IconPack>` 与模块图标预览行）。
- 外观页仅保留「主题方案」与「玻璃质感」两区。
- 底部导航/各模块图标固定 outlined 风格，不再可切换。

**实现要点**：`moduleIcon(AppModule)` 去掉 `IconPack` 参数、固定 outlined；删除 `IconPack` 枚举与 `appIcon`；`ThemeSettings` 移除 `iconPack` 字段与 `copyWith` 分支；`SettingsRepository` 停止读写 `theme_icon_pack`（存量键忽略，见 §3）；更新外观/主题测试。

**涉及文件**：
- `app/lib/features/settings/appearance_page.dart`
- `app/lib/shared/theme/app_icons.dart`
- `app/lib/shared/theme/theme_settings.dart`
- `app/lib/shared/theme/theme_controller.dart`
- `app/lib/data/repositories/settings_repository.dart`
- `app/lib/app.dart`（`moduleIcon(m)` 调用）
- `app/test/widget/appearance_page_test.dart`
- `app/test/unit/features/theme/theme_settings_test.dart`

**验收标准**：
- AC3-1：外观页无「图标风格」选项。
- AC3-2：`IconPack` 类型在 `lib/` 中不再被引用。
- AC3-3：主题切换/自定义/玻璃降级其余能力不受影响。
- AC3-4：存量 `theme_icon_pack` 键被安全忽略，不致崩溃。

---

### 2.4 需求 4 —— 记账按钮（FAB）长按拖拽 + 持久化

**目标说明**：右下角「+」按钮支持**长按后拖动、自由移动位置**；默认位置为**屏幕底部正中间**（水平居中、贴近底部导航上方）；拖动过程提供**明显视觉反馈**；停止拖动后位置**持久化**，重启应用保持不变。

**交互流程与 UI 变更**：
1. 默认态：+ 按钮位于底部水平居中（替代原右下角固定位）。
2. 长按（约 0.5s）→ 进入拖拽态：触发一次中等强度触觉反馈；按钮放大约 1.1× 并出现主色光晕/悬浮阴影，明确「可移动」。
3. 手指移动 → 按钮实时跟随，并被钳制在内容区安全范围内（不出屏、不压入状态栏/底部导航）。
4. 松手 → 退出拖拽态（恢复原尺寸/光晕消失），当前位置以归一化坐标写入 `app_meta`。
5. 重启 → 从 `app_meta` 读取归一化坐标并还原；未设置过则回落底部正中默认位。
6. 普通点按（非长按）仍打开「记一笔」；`viewer` 只读角色仍隐藏按钮。

**实现要点**：
- 将 `Scaffold.floatingActionButton` 改为覆盖在 `body` 之上的自定位浮层（`Stack` + `LayoutBuilder`），由新组件 `DraggableGlassFab` 承载。
- 位置模型：归一化锚点 `FabAnchor = ({double ax, double ay})`（按钮中心相对内容区宽高比例）；`null` 表示默认底部正中。渲染时按内容区尺寸反算像素并钳制边界。
- 状态：`fabAnchorProvider`（`Notifier<FabAnchor?>`），`main()` 启动读取 `SettingsRepository.fabAnchor()` 注入，拖拽结束 `save()` 落库（与 `themeControllerProvider` 的启动注入模式一致）。
- 持久化键：`fab_anchor_x` / `fab_anchor_y`（`app_meta`）。
- 视觉反馈用 `AnimatedScale`/光晕 `AnimatedContainer` + `HapticFeedback`，动效走 `GlassMotion` 档位。

**涉及文件**：
- `app/lib/app.dart`（FAB 装配改为浮层 + `viewer` 隐藏）
- `app/lib/shared/widgets/draggable_fab.dart`（新增）
- `app/lib/features/settings/fab_position.dart`（新增：`fabAnchorProvider`）
- `app/lib/data/repositories/settings_repository.dart`（`fabAnchor`/`setFabAnchor`）
- `app/lib/main.dart`（启动注入）
- `app/test/widget/`（新增拖拽/持久化测试）

**验收标准**：
- AC4-1：默认位置为底部水平居中。
- AC4-2：长按可拖动，拖动中按钮放大 + 光晕/阴影 + 触觉反馈。
- AC4-3：松手后位置写入 `app_meta`；重启（重新注入）后位置一致。
- AC4-4：拖拽被钳制在内容区内，不出界。
- AC4-5：普通点按仍打开记账；`viewer` 仍不可见。

---

### 2.5 需求 5 —— 周期记账迁移至设置（含创建/编辑/删除）

**目标说明**：从首页菜单移除「周期记账」，整合为**设置页的独立设置项**；用户可在设置中**创建、编辑、删除**周期记账规则；**兼容保留**用户已有规则数据（无 schema 变更）。

**交互流程与 UI 变更**：
1. 底部导航移除「周期记账」Tab。
2. 设置弹层新增「周期记账」`ListTile`（副标题如「自动周期入账 / 分期」），点击进入独立页 `RecurringSettingsPage`（`GlassScaffold`，标题「周期记账」）。
3. 页内为规则列表 + AppBar 动作（新建规则、立即补跑）。
4. 点击规则行 → 打开 `RuleEditSheet`（编辑态，预填频率/锚点/账户/金额/收支类型）→ 保存即更新并重算 `nextDue`。
5. 规则行提供删除入口 → 二次确认 → 删除该规则（已生成的历史流水不受影响）。
6. 「立即补跑」保留（复用 `runAllRecurringRules`）。

**实现要点**：
- `RecurringPage` 保留为列表主体，外包 `GlassScaffold` 成独立路由页；`recurringPageActions` 迁移为该页 AppBar 动作。
- `RuleEditSheet` 增加可选 `rule` 参数以支持编辑态；保存分流：编辑→`updateRecurringRule`，新建→原插入逻辑。
- `RecurringService` 新增 `updateRecurringRule(...)`（写回字段并以 `RecurringEngine.firstDueAfter` 重算 `nextDue`）与 `deleteRecurringRule(id)`。
- 补跑链路（`app.dart._runCatchup`、`main.dart._runRecurringCatchup`、`recurringServiceProvider`）**不变**；`recurringRulesProvider` 仍按 `bookId` 过滤。

**涉及文件**：
- `app/lib/app.dart`（移除 Tab + 设置入口）
- `app/lib/features/recurring/recurring_page.dart`（独立页 + 编辑/删除）
- `app/lib/features/recurring/recurring_service.dart`（update/delete）
- `app/lib/features/recurring/recurring_providers.dart`
- `app/lib/shared/theme/app_icons.dart`（移除 `AppModule.recurring`）
- `app/test/widget/role_permissions_test.dart`、`app/test/golden/golden_tabs_test.dart`、`app/test/widget/app_smoke_test.dart`

**验收标准**：
- AC5-1：首页无「周期记账」Tab；设置中有入口。
- AC5-2：可在设置中创建规则（与既有新建一致）。
- AC5-3：可编辑既有规则并保存，`nextDue` 重算正确。
- AC5-4：可删除规则（二次确认）；历史流水不受影响。
- AC5-5：存量规则数据升级后完整可见、可继续补跑。
- AC5-6：`viewer` 只读时动作入口隐藏。

---

### 2.6 需求 6 —— 日历融入报表

**目标说明**：将日历功能并入报表页：通过日历视图直观查看**每日收支汇总（净额）**，**点击某一天查看当天账单明细**。移除独立「日历」Tab。

**交互流程与 UI 变更**：
1. 报表页顶部新增分段控件「图表 / 日历」。
2. 「图表」= 现有时间范围选择 + 分类占比饼图 + 周期对比柱状。
3. 「日历」= 月历日格显示每日**净额**（收入绿/支出红，复用报表按日聚合 `calendarDailyTotalsProvider`）；下方保留 30 天现金流趋势图。
4. **点击某日 → 打开当天账单明细弹层 `DayDetailSheet`**（净额 + 逐笔金额/备注/时间）。原「点日进记账、长按看明细」改为「点日看明细」。
5. 月份切换懒加载、年份快选保留。

**实现要点**：
- `CalendarPage` 保留为可嵌入视图（无内层 Scaffold），`onDaySelected` 改为打开 `DayDetailSheet`（替换 `openQuickEntrySheet` 跳转）；`viewer` 仍可看明细（只读）。
- `ReportsPage` 增加 `ReportsTab` 状态：图表态渲染原内容；日历态 `Expanded(child: CalendarPage())`（不嵌入 `ListView`，避免 `Expanded` 无限高问题）。
- 移除「日历」Tab 与 `AppModule.calendar`。

**涉及文件**：
- `app/lib/app.dart`（移除日历 Tab）
- `app/lib/features/reports/reports_page.dart`（新增分段 + 日历态）
- `app/lib/features/calendar/calendar_page.dart`（点日 → 明细）
- `app/lib/shared/theme/app_icons.dart`（移除 `AppModule.calendar`）
- `app/test/widget/calendar_page_test.dart`、`app/test/widget/reports_page_test.dart`、`app/test/golden/golden_tabs_test.dart`

**验收标准**：
- AC6-1：首页无「日历」Tab；报表页提供「图表 / 日历」切换。
- AC6-2：日历日格正确显示每日净额（与报表按日聚合一致）。
- AC6-3：点击某日打开当天账单明细（含逐笔记录）。
- AC6-4：月份切换/年份快选/现金流图正常；`viewer` 可查看明细。
- AC6-5：原报表图表能力不回归。

---

### 2.7 需求 7 —— 分类管理增强（层级 + 图标库）

**目标说明**：新增分类时支持选择**层级**——既可直接创建**一级分类**，也可归属到某个一级分类下作为**二级分类**；支持**自定义分类图标**，并提供**与分类语义相关、内容丰富的内置图标库**。

**交互流程与 UI 变更**：
1. 新建/编辑分类弹层新增「层级」选择：`一级分类 / 二级分类`（分段控件）。
2. 选「二级分类」时显示「归属一级分类」下拉，仅列出与当前收支类型（`CategoryKind`）一致的既有一级分类。
3. 新增「图标」选择区：按语义分组（餐饮/交通/购物/居家/娱乐/医疗/教育/人情/通讯/金融/其他）展示内置图标网格，点选即预览；默认按所选分组首个或 `tag`。
4. 保存：按所选 `parentId`（一级为 `null`）与 `icon` 写入；编辑态支持改名/改色/改图标。
5. 图标库为纯矢量 `IconData` 映射（沿用 `categoryIcon`），不引入图片资源。

**实现要点**：
- `category_icon.dart`：扩充 `_icons` 映射并按语义分组暴露 `categoryIconGroups`（组名 → 图标名列表）供选择器渲染；`categoryIcon(name)` 保持不变。
- `CategoryEditSheet`：新增层级分段、父级下拉、图标网格选择器；`_save` 传入 `parentId` 与 `icon`；编辑态允许改 `icon`。
- `CategoryRepository.createCategory` 已支持 `parentId`；`updateCategory` 已支持 `icon`——**无需 schema 变更**，存量数据天然兼容。

**涉及文件**：
- `app/lib/shared/utils/category_icon.dart`
- `app/lib/features/categories/category_edit_sheet.dart`
- `app/lib/features/categories/categories_page.dart`（如需）
- `app/test/widget/categories_page_test.dart`、`app/test/unit/data/repositories/category_repository_test.dart`

**验收标准**：
- AC7-1：新建可选「一级/二级」；二级须选父级且父级收支类型一致。
- AC7-2：可从内置图标库选择图标，保存后在分类页/账单/记账页正确显示。
- AC7-3：图标库按语义分组、数量丰富（覆盖主要消费场景）。
- AC7-4：编辑既有分类可改图标；存量分类显示不回归。
- AC7-5：`viewer` 只读时不提供新建/编辑入口。

---

## 3. 存量数据兼容处理方案

| 数据/配置 | 影响需求 | 兼容策略 |
| --- | --- | --- |
| 周期记账规则 `recurring_rules` | 需求 5 | **零 schema 变更**。仅 UI 下沉 + 新增编辑/删除；`recurringRulesProvider` 仍按 `bookId` 过滤，存量规则升级后原样可见、可补跑。补跑游标 `next_due` 语义不变。 |
| 分期计划 `installment_plans/schedules` | 需求 5 | 不受影响，补跑逻辑保留。 |
| 自定义分类 `categories` | 需求 7 | **零 schema 变更**。表已含 `parent_id` 与 `icon` 列；新 UI 只是把既有能力显性化。存量分类（`parent_id`/`icon` 已置）展示与引用不回归；系统种子分类不受影响。 |
| 主题键 `theme_icon_pack` | 需求 3 | 停止读写，存量行**忽略**（读取时不解析、不报错），与既有废弃键（`bg_*`/`glass_quality`）同一处理方式。 |
| 主题键 `theme_seed/mode/preset_id` | 需求 3 | 不变，旧键兼容迁移逻辑保留。 |
| `app_meta` 新增 `fab_anchor_x/y` | 需求 4 | 新键，缺失回落默认底部正中；不影响既有键。 |
| 语音相关 | 需求 2 | 语音为无状态能力，无持久化数据，直接移除无迁移负担。 |
| 日历/报表查询 | 需求 6 | 纯视图整合，复用同一 `ReportsRepository` 查询层，无数据变更。 |

---

## 4. 优先级排序

按「结构风险 × 用户价值 × 实施成本」排序：

| 优先级 | 需求 | 理由 |
| --- | --- | --- |
| **P0** | 需求 5（周期迁移）、需求 6（日历入报表）、需求 3（外观简化） | 三者共同决定底部导航/`AppModule`/`moduleIcon` 的最终形态，须成批落地避免 `app.dart`/`app_icons.dart` 反复改写；周期迁移含新增 CRUD，风险最高。 |
| **P0** | 需求 4（FAB 拖拽） | 全新交互 + 持久化，独立于导航重构但涉及主壳装配，需尽早验证手势与布局。 |
| **P1** | 需求 7（分类增强） | 纯增量能力，依赖既有 `parentId`/`icon` 字段，风险中等。 |
| **P2** | 需求 1（账单字号）、需求 2（移除语音） | 低风险样式/移除改动，最后收尾。 |

实施批次建议：**批次 A**（P0 结构）→ **批次 B**（P0 FAB + P1 分类）→ **批次 C**（P2 收尾）。

---

## 5. 验证与测试方案

### 5.1 自动化（随 CI）

- `flutter analyze`：零 error/warning。
- `dart run tool/check_ui_tokens.dart`：`lib/` 无裸 `Color(0x…)`/ARGB 字面量/裸 `fontSize:`。
- `bash ../tool/check_glass_consistency.sh` + `dart ../tool/check_fg_contrast.dart`：玻璃/对比度门禁不回归。
- `flutter test --coverage`：全量单测/组件测试通过。

### 5.2 受影响测试清单

| 测试 | 处理 |
| --- | --- |
| `widget/bills_page_test.dart` | 保留 + 新增金额字号断言（需求 1） |
| `widget/voice_entry_sheet_test.dart` | **删除**（需求 2） |
| `unit/.../sms_voice_test.dart` | 删除语音组，保留短信组（需求 2） |
| `widget/appearance_page_test.dart` | 移除图标风格用例与设置页「图标风格」断言（需求 3） |
| `unit/.../theme_settings_test.dart` | 去除对 `iconPack` 的隐式依赖（需求 3） |
| `widget/role_permissions_test.dart` | 周期记账动作改经设置入口验证（需求 5） |
| `golden/golden_tabs_test.dart` | 周期/报表 golden 随页面改版更新基准（需求 5/6） |
| `widget/app_smoke_test.dart` | 断言 3 Tab（需求 5/6） |
| `widget/calendar_page_test.dart` | 点日 → 明细语义更新（需求 6） |
| `widget/reports_page_test.dart` | 新增「图表/日历」切换断言（需求 6） |
| `widget/categories_page_test.dart`、`unit/.../category_repository_test.dart` | 新增层级 + 图标用例（需求 7） |
| 新增 `widget/draggable_fab_test.dart` | FAB 拖拽 + 持久化（需求 4） |

### 5.3 手工验证要点

- 3 Tab 导航切换、设置入口、周期记账 CRUD、报表图表/日历切换、日历点日明细、分类层级/图标选择、FAB 拖拽与重启还原、8 套预制主题 + 深色模式观感走查。

### 5.4 约束说明

- 本环境**未安装 Flutter SDK**，无法本地执行 `flutter test`/`flutter analyze`；以**静态细读 + token 门禁自查**保障正确性，最终由 CI 把关。涉及金级（golden）基准图需在具备 SDK 的环境重新生成。

---

## 6. 风险与缓解

| 风险 | 缓解 |
| --- | --- |
| 5→3 Tab 结构改动牵连测试多 | 批次 A 集中落地，统一更新 `app_smoke`/`role_permissions`/`golden`，避免碎片化中间态 |
| FAB 拖拽与页面滚动手势冲突 | 手势仅绑定在按钮自身；长按进入拖拽，普通滑动不受影响 |
| 编辑周期规则重算 `nextDue` 出错 | 复用 `RecurringEngine.firstDueAfter`，并以单测覆盖月/季/年 + 自定义锚点 |
| 日历嵌入报表的布局溢出 | 日历态以 `Expanded` 直挂（不进 `ListView`），规避 `Expanded` 无限高 |
| 图标库扩张引入裸色值/裸字号 | 图标仅用 `IconData` + `categoryIcon`，颜色沿用分类自身 `color`，不触碰门禁 |
