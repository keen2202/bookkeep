# 30-UI体验问题修复 Spec 与任务分解

| 项 | 内容 |
| --- | --- |
| 文档编号 | BK-DOC-30 |
| 版本 | v1.0（规划稿，未实施） |
| 日期 | 2026-09-06 |
| 范围 | Flutter App（`app/`）7 个 UI/UX 问题的修复方案；不含代码实现 |
| 关联文档 | 26-界面与功能优化Spec、28-交互与导航优化Spec、19-玻璃拟态全链路设计文档 |
| 代码基线 | 本文所有「现状」均基于当前仓库源码逐行核对，附文件与行号 |

---

## 0. 代码基线核对结论（前置事实）

| # | 核对项 | 结论 |
| --- | --- | --- |
| 1 | 分类占比数据源 | `reports_repository.dart:231-272` `categoryBreakdown()` 按 `t.category_id` 直接分组，子分类各自成扇区，未聚合到一级分类 |
| 2 | 记账页标题与 Tab | `quick_entry_sheet.dart:161` 标题「记一笔 / 编辑账单」；`:167-188` 支出/收入/转账 `AppSegmentedButton` 位于 body 顶部；`GlassScaffold.title` 类型为 `Widget?`（`glass_nav.dart:144`），可直接承载分段控件 |
| 3 | 预算卡显示逻辑 | `quick_entry_sheet.dart:204`：`if (widget.editTarget == null) const BudgetSummaryCard()`——新增态下支出/收入/转账三种类型**均显示**预算卡 |
| 4 | 键盘布局 | 备注 `TextField`（`quick_entry_sheet.dart:230-243`）唤起系统 IME 后，页面底部自定义 `AmountKeyboard`（`:218-223`）不隐藏，与系统键盘堆叠挤压；切换 Tab 时备注焦点不释放 |
| 5 | 分类弹窗选中态 | `category_picker.dart` 选中态由 `GlassSelection` 四层叠加承载（`glass_selection.dart`）；chip 宿主为 G4 降档玻璃，选中增量按 G4 α 计算，浅/深主题下辨识度偏弱 |
| 6 | 周期记账页「启动」按钮 | **功能已确认**：`recurring_page.dart:38-42` 为 `play_arrow` 图标按钮（tooltip「立即补跑」），调用 `runAllRecurringRules()` → `recurringService.runAll()` 立即生成全部到期流水，功能真实有效。**但** `main.dart:110` 与 `app.dart:111` 冷启动已自动 `runAll()` 补跑，且列表项副标题已展示「下次入账」时间——手动入口冗余，建议移除 |
| 7 | 预算编辑页 ✔ | `budget_edit_sheet.dart:174-181` 使用裸 `SegmentedButton<bool>`（总预算/分类预算），M3 默认 `showSelectedIcon: true`，选中段头部渲染 ✔。项目收敛出口 `AppSegmentedButton`（`app_segmented_button.dart`）已统一关闭 ✔ 并改色块突显（AC7-1/AC7-2，规范 AC7-4 禁止页面散写） |

**附带发现（不在本次范围，记录备查）**：`recurring_page.dart:375/384`、`category_edit_sheet.dart:146/160`、`appearance_page.dart:285` 同样存在裸 `SegmentedButton`（同样带 ✔）。按本次需求范围仅处理预算编辑页，其余建议后续按 AC7-4 统一收敛。

---

# 第一部分 Spec（需求规格）

## UI-01 报表分类占比仅聚合一级分类

**现状描述**
报表页「分类占比」饼图（`reports_page.dart:282-290` → `report_charts.dart:74` `CategoryPieChart`）的数据源 `categoryBreakdown()` 按流水的 `category_id` 逐类分组。用户若在一级分类下建了多个二级分类（如「餐饮 / 早餐」「餐饮 / 午餐」），每个二级分类各占一个扇区与图例项，分类一多饼图碎片化、图例溢出难读。

**预期行为**
- 分类占比按**一级分类**聚合：二级分类流水金额归入其一级分类，饼图扇区数 = 有流水的一级分类数；
- 图例显示一级分类名与聚合金额；扇区百分比口径不变（占当期总支出比例）；
- 流水直接挂在一级分类（无子级）的，归入该一级分类本身；
- 未分类流水（`category_id IS NULL`）仍归入「未分类」桶，行为不变；
- 多币种折算口径（`rate_snapshot` 快照优先、缺失回退汇率表）保持不变；
- 排序保持按聚合金额降序。

**影响范围**
- 数据层：`app/lib/data/repositories/reports_repository.dart`（`categoryBreakdown()` SQL 与 Dart 侧聚合 key）
- 展示层：`CategoryPieChart` 无需改动（消费 `List<CategorySlice>` 结构不变）
- 测试：`app/test/unit/data/repositories/reports_repository_test.dart`（`:114-120` 既有用例 + 新增子分类聚合用例）

**验收标准（可测试）**
1. 构造数据：一级分类「餐饮」下有子类「早餐」「午餐」，当期各有流水；查询结果中「餐饮」为**单个** slice，金额 = 早餐 + 午餐 + 直接挂「餐饮」的流水之和；
2. 饼图扇区数量 ≤ 一级分类（含「未分类」）数量，图例不出现任何二级分类名；
3. 全部 slice 金额之和 = 当期支出总额（与改造前一致，总额不变）；
4. `flutter test test/unit/data/repositories/reports_repository_test.dart` 全绿（含新增聚合用例：子类聚合、跨币种子类聚合、父类已删除时子类流水归入「未分类」或保留兜底名）。

---

## UI-02 记账页取消「记一笔」标题，类型 Tab 上移整合至标题栏

**现状描述**
记账页（`QuickEntrySheet`，`quick_entry_sheet.dart`）为全屏路由页：`GlassScaffold` 标题栏显示文字「记一笔」（编辑态「编辑账单」），body 第一行是支出/收入/转账 `AppSegmentedButton`（`:167-188`）。标题栏与分段控件上下分离，浪费一行纵向空间，且「记一笔」标题信息价值低。

**预期行为**
- 新增记账态：移除「记一笔」文字标题，支出/收入/转账分段控件**上移至标题栏**（`GlassScaffold.title` 槽位），body 内原分段控件移除；
- 编辑态（`editTarget != null`，类型锁定 `typeLocked`）：保留「编辑账单」文字标题，标题栏**不**放分段控件（编辑态类型不可改，展示禁用态分段无意义）；body 内分段控件同步移除，编辑态不再展示类型切换；
- 分段控件在标题栏内居中、宽度自适应，不与左侧返回键（`GlassAppBar` 自动 leading）重叠；小屏（≤360dp 逻辑宽）不溢出、不截断文字；
- 类型切换行为、禁用逻辑（编辑收支禁转账）与 `_controller.setType` 链路完全不变。

**影响范围**
- `app/lib/features/quick_entry/quick_entry_sheet.dart`（build 结构）
- 不改动 `glass_nav.dart`（`GlassScaffold.title` 已是 `Widget?`，直接复用）；如标题栏内分段控件高度与 `kToolbarHeight` 冲突，允许在 quick_entry 内做尺寸收敛包装，不改共享组件

**验收标准（可测试）**
1. 新增记账：标题栏无「记一笔」文字，可见支出/收入/转账分段控件且可正常切换；body 顶部不再出现分段控件；
2. 编辑账单：标题栏显示「编辑账单」，页面中不出现类型分段控件；
3. 编辑收支流水时转账段禁用逻辑不回归（编辑态无分段控件，由 controller `typeLocked` 保证，无需 UI 验证）；
4. 360dp 窄屏模拟器/真机：标题栏无 overflow 警告，返回键与分段控件均完整可见；
5. golden 测试（`test/golden/`）如涉及记账页需更新基线。

---

## UI-03 收入、转账表单中移除预算显示

**现状描述**
记账页新增态（`editTarget == null`）下，`BudgetSummaryCard`（`quick_entry_sheet.dart:204`）无条件渲染——「本月预算」是**支出**预算进度卡（`budget_summary_card.dart`：已花/总额/剩余），在收入、转账表单中同样显示，语义不符且占用首屏空间。

**预期行为**
- 仅当当前类型为**支出**（`TransactionType.expense`）且为新增态时显示预算卡；
- 切换到收入或转账 Tab 时预算卡不渲染（不留占位空白）；
- 预算卡点按进入预算管理弹层的行为在支出 Tab 下保持不变；
- 编辑态维持现状（不显示预算卡）。

**影响范围**
- `app/lib/features/quick_entry/quick_entry_sheet.dart`（build 中预算卡渲染条件）
- `BudgetSummaryCard` 组件本身不改动

**验收标准（可测试）**
1. 新增记账默认（支出）Tab：预算卡正常显示，点按可进入预算管理；
2. 切到收入 Tab：预算卡消失，备注栏上移顶替其位置，无残留空白；
3. 切到转账 Tab：预算卡消失；切回支出 Tab 预算卡恢复；
4. 预算卡显隐切换不触发额外数据请求（`monthBudgetSummaryProvider` watch 关系不因 Tab 切换产生重建风暴——以 provider watch 位置在组件内为准，不显式断言次数，人工确认无卡顿即可）。

---

## UI-04 键盘弹起状态下的布局适配（备注残留修复）

**现状描述**
记账页 body 为固定 `Column`：分段控件 → 金额大字 → `Expanded(ListView[预算卡/备注/选择区])` → 自定义 `AmountKeyboard`。点击备注 `TextField` 唤起系统输入法后：
- 自定义金额键盘**不隐藏**，与系统键盘上下堆叠，中间 `ListView` 被挤压到极小高度；
- 此时切换支出/收入/转账 Tab，备注输入框仍保持焦点、系统键盘不收起，表单区（日期/账户/分类）重排后备注区域残留在可视区上方，布局错乱观感差。

**预期行为**
- 系统 IME 弹起（`MediaQuery.viewInsetsOf(context).bottom > 0`）时，**隐藏自定义 `AmountKeyboard`**（避免双键盘堆叠），金额输入区让位给系统键盘；
- 切换类型 Tab 时：备注 `TextField` 主动失焦（`FocusNode.unfocus`），系统键盘收起，随后按正常布局重绘；
- 系统键盘收起后自定义金额键盘恢复显示；
- 整个过程中无 RenderFlex overflow、无黄黑警告条纹、无布局跳动残留；
- 备注已输入内容不因失焦/键盘收起而丢失。

**影响范围**
- `app/lib/features/quick_entry/quick_entry_sheet.dart`（备注 `FocusNode` 管理、`AmountKeyboard` 条件渲染、Tab 切换回调）
- `amount_keyboard.dart` 不改动（由父级控制显隐）

**验收标准（可测试）**
1. 点击备注 → 系统键盘弹起：自定义金额键盘不可见，备注框完整可见且不被遮挡；
2. 系统键盘弹起状态下点击「收入」或「转账」Tab：系统键盘收起、备注失焦，页面按新类型表单正常布局，无备注区域残留、无 overflow 警告（debug 控制台无 `RenderFlex overflowed`）；
3. 点系统键盘「完成」/手势收起：自定义金额键盘恢复，金额可正常输入并保存；
4. 输入备注内容后切 Tab 再切回：备注文字保留；
5. 回归：不触备注直接数字键盘输入金额 → 保存，流程不受影响。

---

## UI-05 记账页分类选择弹窗选中态视觉优化

**现状描述**
分类选择弹窗（`showAppSheet` + `CategoryPicker`，`quick_entry_sheet.dart:446-464` → `category_picker.dart`）中：
- 二级分类 chip（`_CategoryChip`）宿主为 G4 降档玻璃填充 + 0.5px 发丝描边，选中时叠加 `GlassSelection` 四层（增亮/光晕/渐变/描边）；
- 由于 chip 宿主本身 fill α 极低（G4），四层叠加后的增亮增量有限，选中与未选中 chip 在浅色主题下差异微弱；文字与图标颜色选中前后不变，颜色不是有效信号；
- 无子级的一级分类（`_ParentTile`）选中态同样仅靠四层叠加，辨识度不足。

**预期行为**（视觉目标值，实施时以设计走查微调）
- 选中 chip/父分类项：文字与图标着色改为 `palette.primary`，外缘描边由 0.5px 提升至 1px 且 `primary` α 提高（建议 α0.6），保留 FG-SEL 四层叠加的玻璃语义（遵守 AC-07：禁止实色填充、禁止仅文字变色作为唯一信号）；
- 未选中态维持 G4 玻璃 + 发丝描边不变；
- 选中态在浅色与深色主题下均可一眼辨识（对比明显）；
- 选中过渡动画沿用 `GlassMotion.state`（200ms），无卡顿；
- 该选中态仅作用于 `CategoryPicker`（记账页弹窗与分类管理共用此组件时同步受益），不改 `GlassSelection` 共享层语义。

**影响范围**
- `app/lib/shared/widgets/category_picker.dart`（`_CategoryChip`、`_ParentTile` 选中态样式参数）
- 可能涉及 `glass_selection.dart` 的参数化扩展（如允许调用方覆盖描边宽度/α），**不得**改变其默认行为（底部导航等既有使用方不回归）

**验收标准（可测试）**
1. 打开分类弹窗，任选二级分类：选中 chip 文字/图标变为 primary 色、描边加粗，与相邻未选中 chip 差异肉眼立即可辨（浅、深主题各验一次）；
2. 选中无子级的一级分类：同样的高辨识度选中态；
3. 再次打开弹窗（已带 `initialCategoryId`）：预选分类正确呈现选中态；
4. 底部导航、报表视图切换等其他 `GlassSelection` 使用方样式无变化（回归目测）；
5. golden 测试如涉及分类弹窗需更新基线。

---

## UI-06 周期记账页右上角「启动」按钮处理

**现状描述（功能已确认）**
周期记账页（设置入口 `RecurringSettingsPage`，`recurring_page.dart:48-59`）右上角有两个动作：
- `+` 新建规则（`RuleEditSheet.show`）——保留；
- `▶`（`play_arrow`，tooltip「立即补跑」）——`runAllRecurringRules()` → `recurringService.runAll()`，立即对全部到期规则生成流水并 bump 刷新总线。**功能真实有效，并非死按钮。**

但经核对：`main.dart:110`（冷启动）与 `app.dart:111`（进入主壳）均已自动 `runAll()` 补跑；规则列表副标题已展示「下次 YYYY-MM-DD」入账时间。手动补跑入口与自动补跑能力重叠，且图标语义（播放键）易被误读为「启用/启动规则」。

**预期行为（决策：移除）**
- 移除周期记账页右上角「立即补跑」按钮（含 `recurringPageActions` 中对应 `IconButton`）；
- 保留「+」新建规则按钮；viewer 只读逻辑（`recurringPageActions` 返回空）不变；
- 自动补跑链路（冷启动 `runAll`）不受影响；
- `runAllRecurringRules()` 函数若无其他调用方可一并移除；如有其他调用方则保留函数、仅移除按钮（实施时以全局引用检索为准）。

**影响范围**
- `app/lib/features/recurring/recurring_page.dart`（`recurringPageActions`）
- 预期无其他调用方（已检索：`runAllRecurringRules` 仅被该按钮引用）

**验收标准（可测试）**
1. 打开 设置 → 周期记账：右上角仅剩「+」按钮，无 ▶ 按钮；
2. viewer 角色：右上角无任何按钮（不回归）；
3. 构造一条已到期的周期规则，杀掉 App 冷启动重进：到期流水自动生成（自动补跑链路不回归）；
4. `flutter analyze` 无未使用函数警告（若函数一并删除）。

---

## UI-07 编辑预算页取消「✔」选中效果

**现状描述**
预算编辑弹层（`BudgetEditSheet`，`budget_edit_sheet.dart:174-181`）的「总预算 / 分类预算」切换使用裸 `SegmentedButton<bool>`，M3 默认 `showSelectedIcon: true`，选中段头部渲染 ✔ 图标——与全项目「去 ✔、颜色突显」的选中态规范（BK-DOC-28 需求7 / AC7-1~AC7-4）不一致。

**预期行为**
- 该处裸 `SegmentedButton` 替换为项目收敛出口 `AppSegmentedButton<bool>`（`app_segmented_button.dart`）；
- 选中段：无 ✔，以 primary α0.12 底 + primary 前景突显；未选中段样式不变；
- 切换逻辑（`_isTotal` 状态与分类下拉联动）完全不变。

**影响范围**
- `app/lib/features/budgets/budget_edit_sheet.dart`（import 与组件替换，约 2 行改动）

**验收标准（可测试）**
1. 打开 记账页 → 预算卡 → 预算管理 → 新建/编辑预算：「总预算/分类预算」选中段无 ✔ 图标，以颜色突显；
2. 切换「分类预算」：分类下拉正常出现，选中态样式正确；
3. 保存、删除流程不回归。

---

## 问题间依赖与冲突关系

| 关系 | 涉及问题 | 说明 |
| --- | --- | --- |
| 强依赖（同文件同方法） | UI-02 → UI-04 | 两者均改 `quick_entry_sheet.dart` 的 build 布局结构。Tab 上移标题栏后，键盘弹起时的顶部布局随之变化，UI-04 必须在 UI-02 定稿的结构上实施，否则返工 |
| 同区域相邻改动 | UI-02 ↔ UI-03 | 预算卡（`:204`）与分段控件（`:167-188`）在同一 build 方法内相邻。UI-03 改动小，可与 UI-02 同 PR 或紧随其后，但验收互相独立 |
| 弱关联 | UI-04 ↔ UI-03 | 预算卡条件显隐会改变 ListView 内容高度，键盘弹起布局验证需覆盖「支出有预算卡 / 收入无预算卡」两种内容高度 |
| 无冲突 | UI-01、UI-05、UI-06、UI-07 | 分别位于 data 层、shared widgets、recurring、budgets 模块，与上述改动互不干扰，可并行 |

---

# 第二部分 Task（任务拆分）

## 任务总览表

| ID | 任务 | 对应 Spec | 模块 | 优先级 | Status | blockedBy | blocks |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T01 | 分类占比聚合一级分类 | UI-01 | data/reports | P1 | pending | — | — |
| T02 | 记账页类型 Tab 上移标题栏 | UI-02 | quick_entry | P1 | pending | — | T04 |
| T03 | 收入/转账表单隐藏预算卡 | UI-03 | quick_entry | P2 | pending | — | T04（弱） |
| T04 | 键盘弹起布局适配 | UI-04 | quick_entry | P1 | pending | T02 | — |
| T05 | 分类弹窗选中态视觉优化 | UI-05 | shared/widgets | P2 | pending | — | — |
| T06 | 移除周期记账「立即补跑」按钮 | UI-06 | recurring | P3 | pending | — | — |
| T07 | 预算编辑页分段控件去 ✔ | UI-07 | budgets | P2 | pending | — | — |

**建议实施顺序**：T02 → T03 → T04（同一文件连续改动，一次走查）与 T01 并行先行；T05、T07 随后；T06 任意时间插入（独立小改动）。
即：`[T02 → T03 → T04] ∥ [T01]` → `[T05, T07]` → `[T06]`。

---

## T01 分类占比聚合一级分类

- **模块**：`app/lib/data/repositories/reports_repository.dart`
- **优先级**：P1　**Status**：pending
- **Dependencies**：blockedBy = 无；blocks = 无

**Checklist**
- [ ] `categoryBreakdown()` SQL 增加二次关联：`LEFT JOIN categories p ON p.id = c.parent_id`，分组键改为 `COALESCE(p.id, t.category_id)`，名称取 `COALESCE(p.name, c.name)`（`category_id IS NULL` 保持「未分类」）
- [ ] Dart 侧 `byCategory` 聚合 key 同步改为一级分类 id；多币种 `_convertWith` 折算逻辑不变
- [ ] 排序（金额降序）与返回类型 `List<CategorySlice>` 不变
- [ ] 新增单测：子类金额聚合到父类；流水直接挂父类；跨币种子类聚合折算正确；父分类被删（join 落空）时兜底行为明确
- [ ] 既有用例（`reports_repository_test.dart:114-120` 等）按新口径调整并全绿

**验证方式**
- `flutter test test/unit/data/repositories/reports_repository_test.dart`
- 手动：报表页 → 图表视图 → 分类占比，扇区与图例仅出现一级分类名；总金额与改造前对账一致

---

## T02 记账页类型 Tab 上移标题栏

- **模块**：`app/lib/features/quick_entry/quick_entry_sheet.dart`
- **优先级**：P1　**Status**：pending
- **Dependencies**：blockedBy = 无；blocks = T04

**Checklist**
- [ ] 新增态：`GlassScaffold.title` 由 `Text('记一笔')` 改为支出/收入/转账 `AppSegmentedButton`（做尺寸收敛包装以适配 `kToolbarHeight`，不挤压返回键）
- [ ] body 内原分段控件（`:167-188`）移除
- [ ] 编辑态：标题保留 `Text('编辑账单')`，标题栏不放分段控件，body 内分段控件一并移除
- [ ] 类型切换回调 `_controller.setType`、转账禁用条件（`transferOptionEnabled && !typeLocked`）原样迁移
- [ ] 360dp 窄屏无 overflow；相关 golden 基线更新

**验证方式**
- 手动路径：底栏中央「+」→ 记账页标题栏直接切换三种类型；账单页 → 任一账单「修改」→ 编辑态标题为「编辑账单」且无类型切换
- debug 控制台无 overflow 警告；`flutter analyze` 通过

---

## T03 收入/转账表单隐藏预算卡

- **模块**：`app/lib/features/quick_entry/quick_entry_sheet.dart`
- **优先级**：P2　**Status**：pending
- **Dependencies**：blockedBy = 无；blocks = T04（弱关联：影响键盘态内容高度，建议先于 T04 完成）

**Checklist**
- [ ] 预算卡渲染条件改为 `widget.editTarget == null && _controller.type == TransactionType.expense`
- [ ] 切换 Tab 时预算卡显隐无占位残留、无布局跳动
- [ ] `BudgetSummaryCard` 组件零改动

**验证方式**
- 手动：新增记账页，支出 ↔ 收入 ↔ 转账三 Tab 往返切换，确认预算卡仅在支出 Tab 出现；支出 Tab 下点预算卡可进预算管理

---

## T04 键盘弹起布局适配

- **模块**：`app/lib/features/quick_entry/quick_entry_sheet.dart`
- **优先级**：P1　**Status**：pending
- **Dependencies**：blockedBy = T02（布局结构定稿后实施）；blocks = 无

**Checklist**
- [ ] 备注 `TextField` 增加显式 `FocusNode` 管理（`dispose` 释放）
- [ ] `AmountKeyboard` 按 `MediaQuery.viewInsetsOf(context).bottom > 0` 条件隐藏，系统键盘收起后恢复
- [ ] 类型 Tab 切换回调中先 `unfocus` 备注再 `setType`
- [ ] 键盘弹起/收起全程无 `RenderFlex overflowed`；备注内容不失
- [ ] 覆盖「支出（有预算卡）/ 收入（无预算卡）」两种内容高度下的键盘态验证（依赖 T03 的最终显隐逻辑）

**验证方式**
- 手动路径：记账页 → 点备注唤起输入法 → 依次切收入、转账 Tab → 观察键盘收起、布局正常；收起输入法 → 自定义金额键盘恢复 → 输入金额保存成功
- debug 控制台无 overflow 警告

---

## T05 分类弹窗选中态视觉优化

- **模块**：`app/lib/shared/widgets/category_picker.dart`（必要时参数化 `glass_selection.dart`）
- **优先级**：P2　**Status**：pending
- **Dependencies**：blockedBy = 无；blocks = 无

**Checklist**
- [ ] 选中 chip/父分类项：文字与图标着 `palette.primary`，外缘描边 1px、primary α 提升（建议 α0.6，走查微调）
- [ ] 保留 FG-SEL 四层叠加，遵守 AC-07（禁实色填充/禁仅文字变色）
- [ ] `GlassSelection` 默认行为不变；如需扩展以可选参数形式提供
- [ ] 浅/深主题各走查一次；涉及 golden 基线更新
- [ ] 底部导航等其他 `GlassSelection` 使用方目测回归

**验证方式**
- 手动：记账页 → 分类弹窗 → 选中二级分类与无子级一级分类，选中态一眼可辨；关闭重开弹窗预选态正确；切换深浅主题复验

---

## T06 移除周期记账「立即补跑」按钮

- **模块**：`app/lib/features/recurring/recurring_page.dart`
- **优先级**：P3　**Status**：pending
- **Dependencies**：blockedBy = 无；blocks = 无

**Checklist**
- [ ] `recurringPageActions` 中移除「立即补跑」`IconButton`，保留「+」新建规则
- [ ] 全局检索 `runAllRecurringRules`：无其他引用则删除该函数（已预检索仅按钮引用）
- [ ] viewer 只读逻辑不变；冷启动自动补跑（`main.dart:110`、`app.dart:111`）不动

**验证方式**
- 手动：设置 → 周期记账，右上角仅「+」；构造到期规则后冷启动重进确认自动补跑生成流水
- `flutter analyze` 无未使用警告

---

## T07 预算编辑页分段控件去 ✔

- **模块**：`app/lib/features/budgets/budget_edit_sheet.dart`
- **优先级**：P2　**Status**：pending
- **Dependencies**：blockedBy = 无；blocks = 无

**Checklist**
- [ ] 裸 `SegmentedButton<bool>` 替换为 `AppSegmentedButton<bool>`（补 import）
- [ ] 选中段无 ✔、颜色突显；`_isTotal` 联动与保存/删除逻辑不变
- [ ] （备查，不在本任务）其余裸 `SegmentedButton` 散写点记录在案：`recurring_page.dart:375/384`、`category_edit_sheet.dart:146/160`、`appearance_page.dart:285`

**验证方式**
- 手动：预算管理 → 新建/编辑预算 → 切换「总预算/分类预算」，选中段无 ✔；保存与删除流程回归

---

## 全局验证（全部任务完成后）

- [ ] `flutter analyze` 零警告
- [ ] `flutter test` 全绿（含新增/调整的 reports 用例与更新的 golden 基线）
- [ ] 手动全链路走查：记一笔（三 Tab + 备注 + 键盘）→ 报表分类占比 → 预算编辑 → 周期记账页，对照 UI-01~UI-07 验收标准逐项勾选
