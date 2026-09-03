# 28 - 交互与导航优化 Spec 规格说明（日历明细内嵌 / 滚动时间筛选 / 分类页改版 / 记账入口下沉 / 选中态统一 / 账单字号 / 年度趋势）

| 项目 | 内容 |
| --- | --- |
| 文档编号 | BK-DOC-28 |
| 版本 | v1.1 |
| 日期 | 2026-09-02 |
| 代码基线 | `4da0c8f`（2026-09-01，origin/master 最新；分析基线说明见「版本记录」） |
| 状态 | 已实施（代码落地完成；`flutter analyze` / 测试 / 门禁 / golden 再生成待在有 SDK 的环境执行） |
| 关联文档 | `docs/26-界面与功能优化Spec规格说明.md`（本次多项需求为其反向调整，见 §3）、`docs/09-UI设计文档-主题与视觉体系.md`、`docs/20-玻璃拟态全链路Spec规格说明.md` |
| 任务拆解 | `docs/29-交互与导航优化任务分解.md` |
| 适用范围 | `app/`（Flutter 3.44.x，Riverpod 2.6，Drift，table_calendar，fl_chart） |

> **版本记录**
> - v1.0（2026-09-02）：初版，基于 `afc079f` 分析生成。
> - v1.1（2026-09-02）：按最新拉取代码（`4da0c8f`）逐文件复核后重新生成。与 v1.0 分析基线相比，远端新增两个提交：`94d9792`（发布构建修复：`cashflow_chart.dart` 图表区改 `Expanded`、`fab_position.dart` 构造器写法、`category_icon.dart` 图标名 `vaccination→vaccines`、golden 基线再生成）与 `4da0c8f`（`report_charts.dart` 年份顶行标签去裸字号改 `context.text.labelSmall`）。以上均为一行级修复，**不影响本 Spec 九项需求的设计、冲突结论与任务拆分**；v1.1 同步修订：§2.9 实现要点补充轴标签 Token 现状、§6.2 golden 基线说明按 94d9792 更新。

---

## 1. 背景与目标

本 Spec 针对 9 项交互与信息架构优化：**收敛主导航（3 Tab + 拖拽 FAB → 2 Tab + 底栏中央记账按钮，分类下沉设置）**、**报表日历轻量化（移除现金流图、点日明细由弹窗改为日历下方滑动展开）**、**图表时间筛选改为滚动式年/月/日依次选择**、**分类页改版（默认折叠 + 支出/收入双栏 tab）**、**选中态去 ✔ 统一为颜色突显**、**账单行金额字号对齐分类名称**，并**为年维度统计新增收支趋势分析**。

九项需求概览：

| # | 需求 | 类型 | 一句话目标 | 主要模块 |
| --- | --- | --- | --- | --- |
| 1 | 日历取消现金流 | 移除 | 删除日历视图下方「近 30 天现金流」折线图 | 报表-日历 |
| 2 | 点日明细内嵌展开 | 重构 | 点选日期不再弹窗，改为日历下方滑动展开当日明细面板 | 报表-日历 |
| 3 | 滚动式时间筛选 | 重构 | 图表时间筛选改为滚轮依次选择年 → 月 → 日 | 报表-图表 |
| 4 | 分类页默认折叠 | 调整 | 进入分类页时一级分类全部折叠 | 分类 |
| 5 | 分类页收支 tab | 新增 | 分类页顶部新增「支出 / 收入」两栏 tab 切换展示 | 分类 |
| 6 | 记账按钮下沉底栏中央 | 重构 | 移除右下角浮动记账按钮，固定到底部导航中央；分类入口移至右上角设置菜单 | 主壳 / 导航 / 设置 / 分类 |
| 7 | 选中态去 ✔ | 调整 | 记账、报表中分段控件选中不再显示 ✔，改为颜色突显 | 记账 / 报表 / 共享样式 |
| 8 | 账单金额字号调小 | 调整 | 账单行金额字号与该行分类名称一致 | 账单 |
| 9 | 年度收支趋势 | 新增 | 图表以年为周期统计时，新增当年（选中年）收入支出趋势分析 | 报表-图表 |

### 1.1 信息架构变化（核心）

底部主导航由 **3 Tab + 可拖拽浮动 FAB** 变为 **2 Tab + 底栏中央记账按钮**：

```
现状：底部导航 [账单 | 分类 | 报表] + 右下角可拖拽浮动「+」（BK-DOC-26 需求4）
目标：底部导航 [账单 |  ＋  | 报表]，「+」固定于底栏中央，不可拖拽
```

- 「分类」不再作为主 Tab，**右上角设置弹层**新增「分类管理」入口，进入独立的分类管理页（同「周期记账」下沉设置的处理方式，见 BK-DOC-26 需求5 先例）。
- `AppModule` 枚举从 3 项收敛为 2 项（`bills / reports`）；`_tabTitles`、`IndexedStack`、`_tabActions` 同步收敛。
- **可拖拽 FAB 全链路移除**（`DraggableGlassFab` / `fabAnchorProvider` / `app_meta` 持久化键 / 启动注入 / 相关测试），详见 §3 冲突 C1。

> 说明：报表页「图表 / 日历」双视图切换（BK-DOC-26 需求6）保持不变；本次仅调整图表视图的时间筛选交互与日历视图的明细展示交互。

---

## 2. 需求明细

> 每项包含：目标说明 / 交互逻辑 / 界面变化 / 边界情况 / 实现要点与涉及文件 / 验收标准。

### 2.1 需求 1 —— 报表-日历取消现金流显示

**目标说明**：删除报表页日历视图底部的「近 30 天现金流」折线图（`CashflowChart`），日历视图聚焦月历每日收支净额与当日明细（需求 2）。释放出的空间由需求 2 的当日明细面板占用。

**交互逻辑**：无新增交互；纯移除。

**界面变化**：
- 日历视图由「年份快选 + 月历 + 现金流趋势图」变为「年份快选 + 月历 + 当日明细面板（需求 2）」。
- 现金流趋势图连同其空态（「暂无数据」）与脱敏占位（`***`）一起消失。

**边界情况**：
- 无流水窗口：此前显示「暂无数据」空态，移除后无需处理。
- 脱敏态（隐私锁）：不再涉及（图已删除）。

**实现要点与涉及文件**：
- `features/calendar/calendar_page.dart`：删除 `Expanded(child: CashflowChart(...))` 及 import；`Column` 布局槽位由需求 2 的明细面板接管。
- `features/calendar/cashflow_chart.dart`：**整文件删除**（注：`94d9792` 已将其内部布局修正为 `Expanded(child: child)`，该修复随整文件删除一并消失，无迁移负担）。
- `calendarDailyTotalsProvider` 保留（月历日格与明细面板数据仍依赖）。
- 测试：`test/widget/calendar_page_test.dart`、`test/unit/features/calendar/calendar_test.dart` 中现金流相关断言清理（当前无直接引用，需 grep 确认）。

**验收标准**：
- AC1-1：日历视图不再出现「现金流」标题与折线图。
- AC1-2：`lib/` 中无 `CashflowChart` / `cashflow_chart.dart` 残留引用。
- AC1-3：月历每日净额展示、月份懒加载、年份快选不受影响。

---

### 2.2 需求 2 —— 日历选日改为下方滑动展开明细

**目标说明**：点选日历日期时，取消 `DayDetailSheet` 底部弹窗，改为**在日历下方以滑动方式展开**的当日记账明细面板，当日净额与逐笔流水原地可见，不再打断浏览上下文。

**交互逻辑**：
1. 进入日历视图：默认选中「今天」，明细面板**收起**（不占视觉焦点）。
2. 点选任一日期 → 面板以滑动 + 展开动画（200ms，`GlassMotion` 档位）从日历下缘展开，显示该日明细；再点同一日期 → 面板收起（切换展开/收起）。
3. 面板展开状态下点选另一日期 → 面板不收起，内容平滑切换为新选中日的明细。
4. 长按日期：与单击同语义（更新选中 + 展开面板），保留手势兼容。
5. 左右滑动切换月份：选中日与面板内容保持（`TableCalendar` 现行为）；若选中日在新月不可见，面板仍显示其明细（数据不失效）。
6. 点击相邻月份的淡色日期（`outsideBuilder` 日格）：选中该日、面板展示其明细，并跳转对应月份（现行为不变）。

**界面变化**：
- 删除 `showModalBottomSheet` 弹窗及 `DayDetailSheet` 组件。
- 日历下方新增明细面板（`GlassPanel` G2 容器，与图表容器同规格）：
  - 面板头：「M月D日 周X」+ 净额（收入绿/支出红/零中性）+「（N 笔）」。
  - 明细列表：逐笔展示分类图标/名称（含「父类 / 子类」路径）、金额（收支语义色、等宽数字）、时间（HH:mm）与备注；复用账单行视觉（`CircleAvatar` 图标 + 名称 + 金额）。
  - 列表在面板内独立滚动（大量流水时面板不撑爆页面）。
- 脱敏态（`amountMaskProvider`）：金额显示 `***`，净额显示 `***`（沿用现弹窗逻辑）。

**边界情况**：
- 当日无记账：面板仍展开，显示「当日无记账记录」空态文案 + 净额 ¥0.00（0 笔）。
- `viewer` 只读角色：面板为纯只读列表，可正常查看（与现弹窗一致）。
- 明细数据变更（保存/删除/同步合并流水后）：面板经 `ledgerVersionProvider` 自动刷新。
- 面板收起时：日历下方留白，不显示空占位。
- 测试视口：现有日历用例已按手机竖屏（390×844）验证（`reports_page_test.dart` 在 `94d9792` 前后引入的视口设定），改版后用例需保留该视口（月历 + 面板纵向空间敏感）。

**实现要点与涉及文件**：
- `features/calendar/calendar_page.dart`：
  - 新增面板状态 `_panelExpanded`（初始 false）；`onDaySelected` / `onDayLongPressed` 改为 `setState` 更新 `_selectedDay` + 展开面板（同日再点切换收起），**删除 `DayDetailSheet.show` 调用**。
  - 布局：`Column [年份快选, TableCalendar, Expanded(明细面板)]`；面板用 `AnimatedSize`（+ `AnimatedSwitcher` 切内容）承载滑动展开。
  - 删除 `DayDetailSheet` 类；其当日流水查询抽为 `dayTransactionsProvider`（`FutureProvider.family<List<Transaction>, DateTime>`，watch `ledgerVersionProvider`，查询条件与原弹窗一致：当前账本、未删除、当日 `[start, end)`、按 `occurredAt` 升序）。
- `test/widget/calendar_page_test.dart`：「点日弹窗看明细」用例改为「点日下方展开明细面板」语义断言。

**验收标准**：
- AC2-1：点选日期不再出现底部弹窗；日历下方以滑动动画展开当日明细。
- AC2-2：同一日期再点可收起；切换日期面板内容平滑更新不闪断。
- AC2-3：面板含当日净额、笔数与逐笔分类/金额/时间/备注；脱敏态金额与净额显示 `***`。
- AC2-4：无流水日显示空态；明细多时面板内可滚动。
- AC2-5：`viewer` 可查看；`lib/` 无 `DayDetailSheet` 残留。

---

### 2.3 需求 3 —— 图表时间筛选改为滚动式依次选择年、月、日

**目标说明**：图表视图顶部的「日/周/月/年」分段控件 +「自定义时间范围」按钮，整体替换为**滚动式（滚轮）依次选择**的时间筛选器：先选年，再选月（可选「全部」），最后选日（可选「全部」）；统计粒度由选择深度决定（年 → 月 → 日）。

**交互逻辑**：
1. 筛选入口：图表视图顶部一行**时间选择 chip**（全宽可点按），展示当前统计期（如「2026年9月」），尾部展开图标；点击弹出底部选择弹层。
2. 弹层内**三列滚轮**（年 / 月 / 日，iOS 滚轮风格）：
   - 年列：2020–2035（与日历 `firstDay/lastDay`、日期选择器边界一致），默认当前统计年（首次进入为今年）。
   - 月列：「全部」+ 1–12 月；默认当前统计月（年维度时为「全部」）。
   - 日列：「全部」+ 1–N 日（N 随年月联动 28/29/30/31）；默认「全部」。
   - **依次联动**：月列为「全部」时日列禁用（灰显不可滚）；年变化 → 月保留（若非全部）、日重置「全部」；月变化 → 日重置「全部」。
3. 「确定」应用选择并关闭弹层；取消 / 下滑关闭则丢弃。统计口径随粒度更新：
   - 仅年 → 年维度（该年 1/1–12/31）；年 + 月 → 月维度；年 + 月 + 日 → 日维度。
4. 「图表 / 日历」视图切换、汇率折算、脱敏等既有行为不变。

**界面变化**：
- 移除「日/周/月/年」`SegmentedButton`、自定义范围 `IconButton`、自定义范围 `ActionChip` 与「退出自定义」按钮。
- 新增时间选择 chip（含当前期标签，如「2026年」/「2026年9月」/「2026年9月2日」）。
- 区块副标题随粒度更新：分类占比「2026年 / 2026年9月 / 2026年9月2日」；周期对比「最近5年 / 最近5个月 / 最近7天」。

**边界情况**：
- 闰年 2 月：日列联动 29 天；切换到平年 2 月且原选日 > 28 → 日重置「全部」。
- 未来日期：允许选择（记账日期允许未来，`lastDate` 2035）；无数据时图表空态。
- 弹层中途旋转/中断：以「确定」为准，未确认不落选。
- 周期对比取数口径映射：年 → 最近 5 年、月 → 最近 5 个月、日 → 最近 7 天（复用 `comparisonWindows`，锚点 = 选中周期起点）。
- 「周」与「自定义范围」失去入口（冲突 C4，见 §3）。

**实现要点与涉及文件**：
- `features/reports/reports_page.dart`：
  - 状态模型替换：`ReportRange _range` + `_customStart/_customEnd` → 选择模型 `ReportTimeSelection { int year; int? month; int? day; }`（新类型，可放本文件或 `reports_repository.dart` 纯函数区）。
  - 派生：`ReportWindow get _window`（日/月/年窗口）；粒度映射 `ReportRange { day, month, year }` 供 `periodBucketsProvider` 周期对比取数（`comparisonWindows` 的 week/custom 分支不再被 UI 触达）。
  - 新增滚轮选择弹层（`showAppSheet` + `CupertinoPicker`/`ListWheelScrollView` 三列联动 +「全部」项 + 确定按钮）；时间 chip 触发。
  - `_pieSubtitle` / `_comparisonSubtitle` 改为按选择标签生成；删除 `_pickCustomRange` / `customWindow` UI 通路与 `customBucketGranularity` 调用。
- `data/repositories/reports_repository.dart`：查询层**不改**（`periodBuckets` 复用于需求 9；`comparisonWindows` week/custom 分支保留）。
- 测试：`test/widget/reports_page_test.dart` 时间筛选用例重写（chip → 弹层 → 滚轮联动 → 粒度断言）；`test/unit/data/repositories/reports_repository_test.dart` 不受影响。

**验收标准**：
- AC3-1：图表视图无「日/周/月/年」分段控件与自定义范围入口。
- AC3-2：点时间 chip 弹出三列滚轮；月「全部」时日列禁用；年/月变化时下级正确重置。
- AC3-3：仅选年 → 年窗口；年+月 → 月窗口；年+月+日 → 日窗口；两图表数据随窗口刷新。
- AC3-4：周期对比副标题与口径正确（最近5年/5月/7天）；分类占比副标题显示所选周期。
- AC3-5：取消不改变当前统计期；闰年 2 月日列联动正确。

---

### 2.4 需求 4 —— 分类页进入时默认全部折叠

**目标说明**：分类管理页进入时，所有一级分类**默认全部折叠**（现默认全部展开），仅显示一级分类组头；点击组头展开二级分类。降低长列表的初始视觉密度。

**交互逻辑**：
1. 进入分类管理页：全部一级分类折叠，仅显示组头行（图标 + 名称 + 展开箭头 + 操作菜单）。
2. 点击组头 → 展开该组二级分类；再点 → 收起。
3. 离开页面后再进入 → 恢复默认全折叠（**不持久化**展开状态）。
4. 无子级的一级分类：无折叠箭头，点击行为不变（现行为：不响应折叠，整行仅菜单可操作）。

**界面变化**：列表初始高度大幅缩短；组头箭头方向语义反转（默认收起 → 显示「展开」方向箭头 `expand_more`，展开后 `expand_less`）。

**边界情况**：
- 切换支出/收入 tab（需求 5）：**切换时重置为全折叠**（与「进入默认折叠」心智一致）。
- 新建/编辑/删除分类后：列表经 `categoriesViewModelProvider` 重建；展开状态保持当前内存态（不因数据刷新整体重置，仅页面重进/tab 切换重置）。
- 只有一级分类（无任何二级）时：折叠语义无差别，界面与现状一致。

**实现要点与涉及文件**：
- `features/categories/categories_page.dart`：`_CategoryListState._collapsed`（默认空 = 全展开）语义反转为 `_expanded`（默认空 = 全折叠）；`_ParentHeader` 的 `collapsed` 参数与箭头图标随之调整；`didUpdateWidget` 或 tab 切换回调中清空 `_expanded`。
- 记账页内 `CategoryPicker`（`shared/widgets/category_picker.dart`）**不在本需求范围**，保持默认展开（选择场景以快为目标；如需统一另行立项）。
- 测试：`test/widget/categories_page_test.dart` 增加「进入默认全折叠 / 点组头展开 / 重进重置」断言（该文件在最新基线含输入框失焦等测试基建修复，新增用例沿用其 `unfocus` 约定）。

**验收标准**：
- AC4-1：进入分类页所有一级分类处于折叠态。
- AC4-2：点组头可展开/收起；无子级组头无箭头。
- AC4-3：退出重进、切换收支 tab 后恢复全折叠。
- AC4-4：记账页分类选择器默认展开行为不变。

---

### 2.5 需求 5 —— 分类页顶部新增支出/收入两栏 tab

**目标说明**：分类管理页顶部新增「支出 / 收入」两栏 tab，切换展示对应 `CategoryKind` 的分类树，替代当前收支混排的单列表。

**交互逻辑**：
1. 页面顶部（AppBar 之下、列表之上）两栏 tab：默认选中「支出」。
2. 切换 tab → 列表切换为对应类型的一级分类及其子级；切换时列表重置为全折叠（需求 4）。
3. 右上角「新建分类」入口：预填当前 tab 的收支类型（支出 tab → 默认支出；收入 tab → 默认收入），弹层内仍可手动改类型。

**界面变化**：
- 顶部新增两栏分段控件（支出 | 收入）；选中态遵循需求 7（无 ✔、颜色突显）。
- 列表按 kind 过滤：只显示当前类型的分类（当前为收支混排）。

**边界情况**：
- 收入分类为空（如全新安装且 seed 未含收入分类的账本）：显示空态「暂无收入分类，点击右上角新建」。
- 新建分类时切换了类型导致当前 tab 无该新分类：列表按 kind 过滤自然不显示，属预期。
- 「归属一级分类」下拉（新建二级）继续按所选类型过滤（现行为不变）。

**实现要点与涉及文件**：
- `features/categories/categories_page.dart`：页面级状态 `CategoryKind _kind`（默认 expense）；过滤 `parents = categories.where((c) => c.parentId == null && c.kind == _kind)`；tab 用需求 7 的统一分段控件样式。
- `features/categories/category_edit_sheet.dart`：`CategoryEditSheet.show` 增加可选 `initialKind` 参数（预填 `_kind` 初始值，编辑态忽略）。
- 测试：`test/widget/categories_page_test.dart` 增加 tab 切换过滤 + 新建预填类型断言。

**验收标准**：
- AC5-1：分类页顶部有「支出 / 收入」两栏 tab，默认支出。
- AC5-2：切换 tab 仅显示对应类型分类；切换后列表回到全折叠。
- AC5-3：从某 tab 新建分类默认预填该类型。
- AC5-4：空类型显示空态提示；编辑/删除/权限（viewer 只读）行为不回归。

---

### 2.6 需求 6 —— 记账按钮固定底栏中央 + 分类入口移至设置

**目标说明**：移除右下角可拖拽浮动记账按钮，把「记一笔」**固定为底部主菜单栏中央按钮**；「分类」从底部 Tab 移除，入口移至**右上角设置菜单**。

**交互逻辑**：
1. 底部导航变为 `[账单] [＋] [报表]`：＋ 为中央动作按钮（非 Tab，不改变选中态），点按打开「记一笔」（`openQuickEntrySheet`），与原 FAB 行为一致（保存成功弹「已保存」）。
2. ＋ 按钮**不可拖拽**、位置固定；viewer 只读角色隐藏（两侧 Tab 均分补位）。
3. 右上角设置弹层新增「分类管理」`ListTile`（置于「外观」附近的功能区），点击进入独立的分类管理页（`GlassScaffold`，标题「分类」，返回键返回；AppBar 挂「新建分类」动作，viewer 隐藏）。
4. 主页 AppBar 仅剩账本切换 + 设置；Tab 专属动作区（原分类 tab 的 +）移除。

**界面变化**：
- 主导航 3 Tab → 2 Tab + 中央按钮；`AppModule` 收敛为 `bills / reports`。
- 右下角浮动 ＋ 及其拖拽光晕消失。
- 账单页空态文案「点击右下角 + 记一笔」改为「点击底部 + 记一笔」。
- 设置弹层新增「分类管理」入口。

**边界情况**：
- viewer：中央 ＋ 隐藏（同原 FAB）；分类管理页对 viewer 只读（隐藏新建/编辑/删除，现行为）。
- 秒开模式（冷启动直达记账页）：不受影响（`QuickEntrySheet` 以路由推入主界面之上）。
- 窄屏 / 横屏：中央按钮固定宽（约 48dp），两侧 Tab `Expanded` 自适应。
- 原 FAB 拖拽位置持久化数据（`app_meta` `fab_anchor_x/y`）：停止读写，存量键忽略（同 `theme_icon_pack` 废弃键先例）。
- 分类页路由化后不再驻留 `IndexedStack`：每次进入重新加载（滚动位置/展开状态不保留，与需求 4「进入默认折叠」语义一致）。
- `golden_path_test.dart` 等既有用例存在「SnackBar 遮挡 FAB」时序处理（最新基线已加等待），FAB 移除后相关等待随删除清理，不影响其余断言。

**实现要点与涉及文件**：
- `shared/widgets/glass_nav.dart`：`GlassBottomBar` 新增可选中央动作槽（如 `centerAction: ({icon, semanticLabel, onTap})`）；布局 `Row [Expanded(item0), 中央按钮, Expanded(item1)]`；中央按钮采用 `GlassFab` 主操作视觉（primary 着色 G5、白色 ＋ 图标、圆形 48dp），随底栏 `SafeArea` 底部安全区。
- `app.dart`：移除 `DraggableGlassFab` 装配与 `fabAnchorProvider` 读写；`_tabTitles = ['账单', '报表']`；`IndexedStack` 收敛为 `BillsPage / ReportsPage`；`_tabActions` 置空移除分类分支；`_SettingsSheet` 新增「分类管理」入口。
- `features/categories/categories_page.dart`：新增 `CategoryManagementPage`（`GlassScaffold` 包装现有 `CategoriesPage` 内容，AppBar 动作复用 `categoriesPageAction`）。
- `shared/theme/app_icons.dart`：`AppModule` 移除 `categories`，`moduleIcon` 收敛。
- 清理链路：删除 `shared/widgets/draggable_fab.dart`、`features/settings/fab_position.dart`；`main.dart` 移除 `fabAnchor` 读取与 `overrideWith` 注入；`data/repositories/settings_repository.dart` 移除 `fabAnchor()/setFabAnchor()` 与键常量；删除 `test/widget/draggable_fab_test.dart`。
- `features/bills/bills_page.dart`：空态文案更新。
- 测试：`app_smoke_test`（2 Tab + 中央按钮断言）、`role_permissions_test`（viewer 中央按钮隐藏）、`golden_tabs_test` / `golden_ui_test`（基线再生成）。

**验收标准**：
- AC6-1：底部导航为 账单 / ＋ / 报表；＋ 固定中央、点按打开记一笔、不可拖拽。
- AC6-2：右下角无浮动按钮；`lib/` 无 `DraggableGlassFab` / `fabAnchorProvider` 残留。
- AC6-3：设置弹层有「分类管理」入口；进入独立页可新建/编辑/删除分类（viewer 只读）。
- AC6-4：主页 Tab 仅 账单/报表；Tab 切换、账本切换、设置其余入口不回归。
- AC6-5：viewer 中央 ＋ 隐藏；秒开模式正常。
- AC6-6：重启后无 FAB 位置相关读写报错（存量 `fab_anchor_*` 键被忽略）。

---

### 2.7 需求 7 —— 记账/报表选中效果去 ✔，改为颜色突显

**目标说明**：记账、报表中的分段选择控件（M3 `SegmentedButton`）当前在选中段头部渲染 ✔ 图标（`showSelectedIcon` 框架默认 true）。改为**取消 ✔，仅以颜色突显**表示选中。

**交互逻辑**：选中行为不变；仅视觉信号从「✔ + 底色」变为「底色 + 前景色突显」。

**界面变化**：
- 记账页「支出 / 收入 / 转账」类型选择：选中段无 ✔，以主色低透明底 + 主色前景文字突显。
- 报表页「图表 / 日历」视图切换：同上（时间筛选已由需求 3 替换为滚轮，不涉及）。
- 分类页新增的「支出 / 收入」tab（需求 5）同样采用该样式（新控件直接按新规范实现）。

**边界情况**：
- 选中底色须与未选中段及页面背景在浅/深主题下均有可辨对比（过 `check_fg_contrast.dart` 门禁）。
- 玻璃规范 AC-07（禁实色填充选中态）：选中底色采用 primary α0.12 低透明叠加（与 `chipTheme.selectedColor` 口径一致），不做实色填充。
- 无障碍：保留 `SegmentedButton` 语义（selected 状态对读屏可辨），颜色不再是唯一语义通道。
- 转账段禁用态（编辑收支时）：禁用样式不受影响。

**实现要点与涉及文件**：
- 新增共享组件 `shared/widgets/app_segmented_button.dart`：包装 `SegmentedButton<T>`，统一 `showSelectedIcon: false` + `ButtonStyle`（`selectedBackgroundColor: palette.primary.withValues(alpha: 0.12)`、`selectedForegroundColor: palette.primary`）。
- `features/quick_entry/quick_entry_sheet.dart`、`features/reports/reports_page.dart`（视图切换）、`features/categories/categories_page.dart`（需求 5 tab）替换为该组件。
- **范围说明**：需求明确限定「记账、报表」。`category_edit_sheet` / `budget_edit_sheet` / `recurring_page` / `appearance_page` 中其余 `SegmentedButton` 作为一致性建议项（P2 可选）同步替换，不列为本需求验收门槛。
- 分类弹层颜色选择器中的 `Icons.check`（`category_edit_sheet.dart:232`）属「色板选中标记」而非本需求的分段控件选中态，保持不变（色块上白/黑勾是对比色可辨的惯例做法）。
- 测试：`quick_entry_sheet_test` / `reports_page_test` 断言选中段无 `Icons.check`；新增组件测试。

**验收标准**：
- AC7-1：记账类型选择与报表视图切换的选中段无 ✔ 图标。
- AC7-2：选中段以颜色（底色 + 前景色）突显，浅/深主题均可辨（对比度门禁通过）。
- AC7-3：选中行为、禁用态、语义（读屏 selected）不回归。
- AC7-4：样式收敛为共享组件，页面不各自散写 `showSelectedIcon`。

---

### 2.8 需求 8 —— 账单行金额字号对齐分类名称

**目标说明**：账单页单笔记账行的金额数字当前为 `titleLarge`（17sp / w600，BK-DOC-26 需求1 设定），明显大于同行分类名称（`dense ListTile` 标题 = `bodyMedium` 13sp）。将**金额字号调小至与分类名称一致**（13sp），降低金额对列表的压迫感；保留等宽数字、收支语义着色、字重与脱敏。

**交互逻辑**：纯视觉调整，无交互变化。

**界面变化**：
- 账单行右侧金额：17sp → 13sp（`context.text.bodyMedium` 槽位），保留 w600 字重与等宽数字。
- 日汇总组头（`_DayHeader`，titleSmall 13sp w600）不在本次范围，维持现状。

**边界情况**：
- 长金额（如 `¥12,345.67`）：字号变小后更不易溢出；如遇极端窄屏，`AppAmountText` 现有 `maxLines` 能力可用。
- 脱敏态 `¥***`：字号同步变小。
- 账单详情弹层金额、报表图例金额等其余金额位不在本次范围。

**实现要点与涉及文件**：
- `features/bills/bills_page.dart`：`_BillTile` trailing 的 `AppAmountText.minor(..., style: context.text.titleLarge)` 改为 `context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)`。
- `test/widget/bills_page_test.dart`：原「金额字号 == titleLarge」断言（约 L300-303）改为「金额字号 == 分类名称（ListTile dense 标题 bodyMedium）字号」。
- 本项是对 BK-DOC-26 需求1 的**反向调整**（冲突 C3，见 §3）。

**验收标准**：
- AC8-1：账单行金额渲染字号 == 该行分类名称渲染字号（13sp）。
- AC8-2：等宽数字（金额列对齐）、收支语义着色、脱敏行为保持。
- AC8-3：日汇总组头字号不变；`check_ui_tokens.dart` 无裸字号违规。

---

### 2.9 需求 9 —— 年维度统计新增当年收支趋势分析

**目标说明**：图表视图以**年**为统计周期时（需求 3 中仅选年），新增「收支趋势」分析区块：按月展示该年 1–12 月的收入与支出，帮助观察全年收支走势。

**交互逻辑**：
1. 时间筛选粒度为「年」（仅选年，月/日为全部）时，图表视图新增第三个区块「收支趋势」；月/日粒度下不显示该区块。
2. 区块内容：该选中年 12 个月的支出/收入**双柱图**（复用 `PeriodBarChart`：支出红 / 收入绿、可触摸查看金额、脱敏隐藏左轴与触摸），x 轴「1月…12月」（同年无顶行年份）。
3. 区块副标题：「{year}年 · 按月汇总」。
4. 无数据的月份渲染 0 柱（全空年显示「暂无数据」空态）。

**界面变化**：图表视图在「分类占比」「周期对比」之后新增「收支趋势」区块（同为 G2 `GlassPanel` 容器，`_Section` 规格）。

**边界情况**：
- 选中年无任何流水：空态「暂无数据」。
- 脱敏态：左轴刻度隐藏、触摸禁用（`PeriodBarChart` 现有 `hideAmounts` 行为），图例保留。
- 汇率折算：与报表其余口径一致（记账时快照优先，缺省回退汇率表，`reportRatesProvider`）。
- 未来年份（如 2027）：允许选择，图表为 0 柱/空态。
- 「周期对比」区块在年粒度下仍为「最近 5 年」对比（与趋势区块语义互补：趋势看选中年内部月度走势，对比看近 5 年年度总览），不冲突。

**实现要点与涉及文件**：
- `features/reports/reports_page.dart`：新增 `yearlyTrendProvider`（`FutureProvider.family<List<PeriodBucket>, int>`，watch `ledgerVersionProvider` + `reportRatesProvider`，调 `repo.periodBuckets(start: DateTime(year), end: DateTime(year + 1), granularity: BucketGranularity.month, rates: ...)`）；UI 层把仅有数据的月份补零为 12 桶（label `YYYY-MM` → `periodAxisLabels` 渲染「M月」）。
- 复用 `PeriodBarChart`（`charts/report_charts.dart` 无需改动；最新基线其年份顶行轴标签已改用 `context.text.labelSmall`，天然满足 Token 门禁）；区块用 `_chartOrRetry` 三态包装。
- 测试：`reports_page_test` 年粒度出现「收支趋势」区块、月/日粒度不出现；单测覆盖补零 12 桶逻辑（纯函数化便于测试）。

**验收标准**：
- AC9-1：年粒度下出现「收支趋势」区块；月/日粒度不出现。
- AC9-2：12 个月双柱（支出红/收入绿），无数据月为 0 柱；触摸显示「支出/收入 + 金额」。
- AC9-3：数据口径与报表一致（账本过滤、汇率快照、脱敏）；空年显示空态。
- AC9-4：选中年切换时趋势图随之年份更新。

---

## 3. 与现有实现的冲突标注与调整建议

逐项核对最新基线（`4da0c8f`）代码后，以下变更与既有实现（含已实施的 BK-DOC-26）存在冲突，处理策略如下：

| # | 冲突 | 现有实现 | 本次变更 | 调整建议（已采纳进 §2） |
| --- | --- | --- | --- | --- |
| C1 | 拖拽 FAB（BK-DOC-26 需求4）整体撤销 | `DraggableGlassFab` 全链路：拖拽手势、`fabAnchorProvider`、`app_meta` 持久化（`fab_anchor_x/y`）、`main.dart` 启动注入、`draggable_fab_test.dart` | 记账按钮固定底栏中央，不可拖拽 | **整体删除**该链路（组件/Provider/Repository 方法/启动注入/测试）；存量 `fab_anchor_*` 键按废弃键忽略策略处理（读取代码移除后自然不触碰），与 `theme_icon_pack` 先例一致 |
| C2 | 日历现金流图（BK-DOC-26 需求6 子项「下方保留 30 天现金流趋势图」）撤销 | `CashflowChart` 30 天滑动窗口净额折线 + 空态/脱敏处理（`94d9792` 刚修复其 `Expanded` 布局以通过发布构建） | 移除现金流显示 | 删除 `cashflow_chart.dart` 与装配；`calendarDailyTotalsProvider` 保留（月历/明细依赖）。若后续需要回归趋势，可由本 Spec 需求 9 的月度趋势（年粒度）部分替代 |
| C3 | 账单金额字号（BK-DOC-26 需求1「金额 == titleLarge 17sp」）反向调整 | `bills_page.dart` 金额传 `context.text.titleLarge`，测试断言 titleLarge | 调小至与分类名称一致（bodyMedium 13sp） | 直接覆盖原样式与测试断言；`AppAmountText.style` 覆盖参数（为需求 1 引入）继续复用 |
| C4 | 时间维度「周」「自定义范围」失去入口 | `ReportRange` 五维（日/周/月/年/自定义）+ `showDateRangePicker` + 自定义 chip/退出按钮 | 滚动式仅年/月/日 | UI 层移除周与自定义入口；`reports_repository.dart` 的 `comparisonWindows(week)` / `periodBuckets(week|month)` / `customWindow` **保留**（`periodBuckets` 被需求 9 复用，repo 测试不回归）；`ReportRange` 枚举保留但 UI 仅触达 day/month/year。**产品确认项**：如需保留「周/自定义」能力，建议以时间筛选弹层内「更多」入口回归，不阻塞本次 |
| C5 | `DayDetailSheet` 弹窗交互（BK-DOC-26 需求6「点日 → 明细弹层」）替换 | `showModalBottomSheet` + `DraggableScrollableSheet` | 日历下方滑动展开面板 | 删除 `DayDetailSheet`；查询逻辑抽为 `dayTransactionsProvider` 供面板复用；长按手势同步改绑面板展开 |
| C6 | `IndexedStack` Tab 状态保持（审查 U-9）覆盖分类页 | 分类作为常驻 Tab，滚动/展开状态跨 Tab 切换保留 | 分类页路由化（设置入口进入） | 接受状态不保留（与周期记账下沉先例一致）；配合需求 4「进入默认折叠」，语义自洽 |
| C7 | `GlassBottomBar` API 仅支持均分 items | `Row [Expanded(item)...]`，items 由 `AppModule.values` 驱动 | 底栏中央动作按钮 | 组件新增可选中央动作槽（非 Tab 项）；无中央动作时回退纯 items 行为，保持组件可独立测试 |
| C8 | M3 `SegmentedButton` 框架默认 ✔ 来自框架而非业务代码 | `showSelectedIcon` 默认 true，各页面未显式关闭 | 去 ✔ 改颜色突显 | 收敛为共享包装组件统一关闭并定义选中色；注意玻璃规范 AC-07 禁实色填充 → 选中底色用 primary α0.12（对齐 `chipTheme.selectedColor` 口径） |
| C9 | 需求 5/6 交互耦合：分类页从主 Tab 变独立页 | 分类 tab 顶部动作 `categoriesPageAction` 由主 shell AppBar 注入 | 支出/收入 tab 放在独立页顶部 | 新建分类动作随 `CategoryManagementPage` 的 AppBar 走；tab 状态为页面级（默认支出） |

> 补充说明（非冲突，实施提示）：需求 2 与需求 1 共用日历视图同一布局槽位（原现金流图位置），须**同批次落地**避免中间态布局空缺；需求 9 依赖需求 3 的「年粒度」判定（`ReportTimeSelection`），建议先落地需求 3。

---

## 4. 存量数据兼容处理方案

| 数据/配置 | 影响需求 | 兼容策略 |
| --- | --- | --- |
| `app_meta` 键 `fab_anchor_x/y` | 需求 6 | 停止读写；存量行忽略不报错（同 `theme_icon_pack` 废弃键先例）；无迁移负担 |
| 分类数据 `categories` | 需求 4/5 | 零 schema 变更：kind 字段既有（expense/income），tab 仅前端过滤；折叠为纯 UI 状态不落库 |
| 流水 `transactions` | 需求 2/9 | 零变更：日明细查询、按月分桶复用现有 SQL（账本过滤/软删除/汇率快照口径不变） |
| 报表查询层 | 需求 3/9 | `ReportsRepository` 不改接口；`ReportRange` 枚举保留（week/custom 分支不可达但可编译），repo 单测全部保持通过 |
| 设置页其余入口（外观/备份/账户/周期/汇率/锁） | 需求 6 | 不变，仅新增「分类管理」一项 |
| 秒开模式 / 隐私锁 / 同步 | 需求 6 | 不受影响（`QuickEntrySheet` 路由推入方式不变；`ledgerVersionProvider` 刷新总线不变） |

---

## 5. 优先级排序

按「结构风险 × 用户价值 × 实施成本」排序：

| 优先级 | 需求 | 理由 |
| --- | --- | --- |
| **P0** | 需求 6（导航重构） | 决定主壳/`AppModule`/`GlassBottomBar` 最终形态，且含 C1 全链路删除，牵连测试最多，须最先落地避免反复改写 `app.dart` |
| **P0** | 需求 1 + 2（日历改版，同批） | 同一日历布局槽位；交互替换（弹窗 → 内嵌面板）为核心浏览体验，需求 2 依赖需求 1 释放的空间 |
| **P0** | 需求 3（滚动时间筛选） | 报表页状态模型重构，是需求 9 的前置；牵连周/自定义入口移除（C4） |
| **P1** | 需求 9（年度趋势） | 新增分析能力，依赖需求 3 的年粒度判定，数据层复用度高 |
| **P1** | 需求 5 + 4（分类页改版，同批） | 依赖需求 6 的独立页形态；两者同改 `categories_page.dart`，合并落地 |
| **P1** | 需求 7（选中态统一） | 跨记账/报表的样式收敛，含共享组件；报表侧应晚于需求 3（同一区域避免返工） |
| **P2** | 需求 8（账单字号） | 低风险单点样式调整，随时可收尾 |

实施批次建议：**批次 A**（需求 6）→ **批次 B**（需求 1+2 ∥ 需求 3，可并行）→ **批次 C**（需求 9、需求 4+5、需求 7）→ **批次 D**（需求 8 + 全量验证）。

---

## 6. 验证与测试方案

### 6.1 自动化（随 CI）

- `flutter analyze`：零 error/warning。
- `dart run tool/check_ui_tokens.dart`：无裸 `Color(0x…)` / 裸 `fontSize:`（中央按钮、滚轮弹层、字号调整均走 Token；最新基线 `4da0c8f` 已清空 `report_charts.dart` 最后一处裸字号，本次不得回潮）。
- `bash ../tool/check_glass_consistency.sh` + `dart ../tool/check_fg_contrast.dart`：玻璃与对比度门禁（重点：需求 7 选中色、需求 6 中央按钮）。
- `flutter test --coverage`：全量通过。

### 6.2 受影响测试清单

| 测试 | 处理 |
| --- | --- |
| `widget/draggable_fab_test.dart` | **删除**（需求 6，C1；最新基线含 `didUpdateWidget` 锚点同步修复，随文件整体删除） |
| `widget/app_smoke_test.dart` | 断言 2 Tab + 中央记一笔按钮 + 设置「分类管理」入口（需求 6） |
| `widget/role_permissions_test.dart` | viewer：中央 ＋ 隐藏、分类管理页只读（需求 6） |
| `golden/golden_tabs_test.dart`、`golden/golden_ui_test.dart` | 主导航/报表/账单 golden 基线**再生成**（需求 3/6/7/8 视觉变更均为预期）。注：基线已在 `94d9792`（发布构建修复）再生成过一轮，本次以该版本为对照基准 |
| `widget/calendar_page_test.dart` | 点日 → 下方展开明细面板（非弹窗）；现金流断言移除（需求 1/2）；保留手机竖屏视口设定（`reports_page_test` 最新基线已引入 390×844） |
| `widget/reports_page_test.dart` | 时间筛选滚轮交互 + 三粒度窗口 + 年趋势区块（需求 3/9）；现有「点日弹层后需 tapAt 关闭弹层才能切视图」的步骤随弹窗移除而删除 |
| `widget/categories_page_test.dart` | 独立页 + 默认折叠 + 收支 tab + 新建预填（需求 4/5/6）；沿用其 `unfocus` 后再点按的测试约定 |
| `widget/quick_entry_sheet_test.dart` | 类型选择选中段无 ✔（需求 7） |
| `widget/bills_page_test.dart` | 金额字号断言改为对齐分类名称（需求 8） |
| `widget/golden_path_test.dart` | FAB 移除后清理「SnackBar 遮挡 FAB」等待步骤（需求 6）；记账主链路断言保持 |
| `unit/data/repositories/reports_repository_test.dart` | **不改**（repo 层无接口变更，防回归基线；最新基线 `afc079f` 对其的适配保持原样） |
| 新增 `widget/app_segmented_button_test.dart` | 共享分段组件样式（需求 7） |

### 6.3 手工验证要点

- 底栏中央 ＋ 记账（含保存成功提示）、viewer 隐藏；设置 → 分类管理全流程；拖拽 FAB 痕迹清零。
- 日历点日展开/收起/切换内容、无流水日空态、脱敏态、月份翻页后面板表现。
- 时间筛选滚轮联动（闰年 2 月、月「全部」禁用日列）、三粒度图表数据与副标题、年粒度趋势区块 12 桶。
- 分类页默认折叠、收支 tab 切换重置折叠、新建预填类型。
- 记账/报表/分类 tab 无 ✔ 且浅深主题选中可辨；账单行金额与分类名称同字号走查。
- 8 套预制主题 + 深色模式整体观感走查。

### 6.4 约束说明

- 本环境**未安装 Flutter SDK**，无法本地执行 `flutter test` / `flutter analyze`；以静态细读 + 门禁同规则 grep 自查保障，最终由 CI 把关；golden 基线需在具备 SDK 的环境再生成（同 BK-DOC-26 先例）。

---

## 7. 风险与缓解

| 风险 | 缓解 |
| --- | --- |
| 主壳重构（2 Tab + 中央按钮）牵连 smoke/role/golden 多测试 | 批次 A 集中落地，一次性更新全部导航相关断言，避免碎片化中间态 |
| 中央按钮与底栏 SafeArea/高度适配（玻璃层级 G5 在 G3 栏内的观感） | 复用 `GlassFab` 既有视觉；组件级测试 + golden 覆盖浅深主题 |
| 滚轮联动状态机（年月日重置/禁用/闰月）出错 | 选择模型纯函数化 + 单测（闰年/平年/跨年重置矩阵）；`CupertinoPicker` 成熟控件不自绘滚轮 |
| 日历明细面板与 `TableCalendar` 高度竞争（月历固定高 + 面板滚动） | 沿用现 `Column + Expanded` 骨架（原现金流图同槽位，`94d9792` 已验证该槽位 `Expanded` 布局在发布构建下可行），面板内独立 `ListView` |
| 周/自定义维度移除引发用户反馈（C4） | Spec 中标注为产品确认项；repo 层保留能力，可低成本以「更多」入口回归 |
| 选中色仅靠颜色区分的可达性 | 底色 + 前景双信号、过对比度门禁；保留读屏 selected 语义 |
| 账单金额 13sp 在大金额/长备注下的可读性 | 等宽数字与 w600 保留；走查极端金额（¥1,234,567.89）与脱敏态 |
