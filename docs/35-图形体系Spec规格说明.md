# 35 - 图形体系 Spec 规格说明（BK-ICON · 对齐 FGDS）

| 项目 | 内容 |
| --- | --- |
| 文档编号 | BK-DOC-35 |
| 版本 | v1.0 |
| 日期 | 2026-08 |
| 状态 | 待评审 · 可实施 |
| 关联设计 | `docs/34-GraphicSystemDesignSpecifications.md`（**唯一事实来源**） |
| 关联任务 | `docs/36-图形体系任务分解.md` |
| 关联视觉基线 | `docs/23-iOS毛玻璃Spec规格说明.md`（G1–G5 / GlassIcon 容器）、`docs/22-iOS毛玻璃设计文档.md` |
| 代码基线 | `app/lib/shared/theme/`、`app/lib/shared/widgets/glass_icon.dart`、`app/lib/shared/utils/category_icon.dart`、`app/lib/app.dart`、`app/lib/features/bills/`、`app/lib/features/reports/` |
| 效力 | 图形本体（路径、描边、选中态、命名、颜色绑定、迁移与验收）以 34 与本文为准；玻璃容器参数仍以 BK-DOC-23 为准，**本文不改 G1–G5 数值** |

**术语对齐（与 34 一致）**

| 术语 | 含义 |
| --- | --- |
| BK-ICON | bookkeep 自有矢量图标体系 |
| `bk.<族>.<语义>` | 设计侧图标 ID |
| ThemePalette | 多主题预设颜色 Token（`theme_presets.dart`） |
| GlassIcon / G1 | 既有 28/36/44 图标玻璃容器 |
| fill / duo | Tab 选中态：单色填充 / 容器双色 |

---

## 1. 问题分类与优先级

设计规范（34）已锁定 D1–D8。本 Spec 将 **当前实现与目标体系之间的缺口** 分类如下，作为实施排序依据。

### 1.1 分类总表

| ID | 分类 | 优先级 | 问题摘要 | 影响面 |
| --- | --- | --- | --- | --- |
| P-01 | 架构/接口 | P0 | 无 BK-ICON 统一出口；业务直引 `Icons.*`，与 GlassIcon 容器脱节可审计 | 全客户端 UI |
| P-02 | 视觉一致性 | P0 | 模块 outlined / 分类 filled / 操作系统默认混用，线宽不齐；账单列表/转账按 2026-09 产品决策采用 Material，Bk Painter 不接生产 | 首页、账单、报表、分类 |
| P-03 | 产品语义 | P0 | 底栏 `receipt_long_outlined` / `bar_chart_outlined` 财务辨识弱；中央记账未用 D3 圆内加号 | 底栏导航、极速记账入口 |
| P-04 | 状态机 | P0 | Tab 无规范选中填充/双色；`GlassIcon` 仅 tint，无 `selected` 路径语义 | 底栏、Segment |
| P-05 | 主题绑定 | P0 | 图标色存在散落字面量风险；未强制 paint 时读 ThemePalette | 多主题 t1–t8 + custom |
| P-06 | 空态产品化 | P1 | `AppEmpty` 空态为 Material 单图 + 圆底，无 CTA 纪律；且与 D4「无二层装饰」需对齐 | 账单/报表空态转化 |
| P-07 | 报表图形 | P1 | 图表/日历切换、周期等图标未进 `bk.rpt.*` 命名与线性规格；隐藏金额按产品定义仅自动脱敏，不提供手动图标入口 | 报表页 |
| P-08 | 状态图形 | P1 | 同步/锁定/预警分散，无统一 `bk.status.*` | 同步、隐私锁、预算阈值 |
| P-09 | 工程实现 | P0 | 目标为 CustomPainter；当前依赖 Material IconData，缺路径源与 shouldRepaint 约定 | shared/icons 新层 |
| P-10 | 质量门禁 | P1 | 无裸 `Icons.` 扫描、无图标对比度场景、无 Tab 双态 Golden | CI、验收 AC-01/03/04/06/08 |
| P-11 | 分类库 | P2 | 60+ seed 图标填充族，与线性体系冲突（保留 iconName 契约） | `category_icon.dart`、分类选择器 |
| P-12 | 性能/资源 | P1 | 若每图标独立 Painter 且 Tab 动画重建不当，可能增加 paint 开销；禁 flutter_svg 运行时解析 | 底栏热路径、列表滚动 |

### 1.2 优先级排序原则

1. **P0**：阻塞「首页可辨识 + 主题正确 + 可扫描验收」——Phase 0–1 必须完成；
2. **P1**：完整账单/报表链路与门禁——Phase 2–4；
3. **P2**：分类库与 `bk.status.ok` 等非阻塞项——Phase 5。

---

## 2. 改进建议（四维可落地方案）

> 说明：以下方案**不引入实现代码**，仅规定实现边界与验收口径；具体任务见 36 文档。

### 2.1 代码重构

| 建议 | 对应问题 | 做法 | 排除 |
| --- | --- | --- | --- |
| 建立 `shared/icons` 唯一出口 | P-01, P-09 | 新增 `bk_icons.dart`（名称常量）+ `bk_icon.dart`（Widget）+ `painters/`；业务只依赖 `BkIcon`/`BkIcons` + 既有 `GlassIcon` | 禁止 feature 内再复制 Path |
| `moduleIcon` 改为返回 Bk 语义 | P-03 | `app_icons.dart` 的 `AppModule` 映射改为 `bk.nav.bills` / `bk.nav.reports` | 删除正式路径上的 Material 引用 |
| GlassIcon 与 CustomPaint 组合 | P-04, P-09 | **假设 A1**：`GlassIcon` 增加 `custom`/`child` 槽位或新增 `BkGlassIcon` 组合组件，容器材质仍走 G1，不改 blur/fill | 不在业务页手写 BackdropFilter |
| Tab selected 状态机 | P-04 | `BkIcon(selected:)`；选中默认 **fill 单色**（34 §8.1 推荐） | **假设 A2**：全 Tab 栏统一 fill，不做 bills fill + reports duo 混用 |
| fallback 映射表 | 过渡 | `materialFallback` 仅覆盖尚未迁移 ID，命中则 debugPrint | **假设 A3**：Phase 4 结束后冻结新增 fallback，Phase 5 前删除正式路径 fallback |

### 2.2 安全性 / 隐私增强

图形体系无网络与密钥面，安全相关点收敛为 **脱敏与无障碍误用**：

| 建议 | 对应问题 | 做法 |
| --- | --- | --- |
| 脱敏态图标语义 | P-06, 隐私锁 | 隐藏金额由 `amountMaskProvider` 自动脱敏，不提供 `bk.rpt.hide-amount` 手动开关；锁定脱敏旁路信息用 `textTertiary`/`textDisabled`，**不得单独作为可点主操作**（34 §5.3） |
| 禁止图标旁路金额泄露 | 隐私 | 空态/报表插画位不得内嵌真实金额文案；Golden 测试需在脱敏开启下抽一组 |
| 无远程资源 | P-09 | AC-09：无 flutter_svg、无 http 图标 CDN、无运行时 SVG 解析 → 无供应链图标注入面 |

### 2.3 架构优化

| 建议 | 做法 |
| --- | --- |
| Token 单源 | 颜色只经 `ThemePalette`/`AppColors`；描边/栅格常量进 `BkIconTokens`（与 `GlassIconTokens` 并列，**不**混入 G1 blur 表） |
| 数据流 | `ThemePalette`（注入）→ `BkIcon` 解析 color/selected → `CustomPainter.paint` 绘制 24 栅格 Path → 缩放至 GlassIcon 本体尺寸 |
| 模块边界 | `shared/icons` 不依赖任何 `features/*`；features 只 import 常量与 Widget |
| 版本边界 | `bk-icons` semver 与 34 §9.2 一致；Path 变更走 PR + Golden |
| 与分类契约 | P2 保留 `iconName` 字符串；映射层由 Material → Bk Painter 渐进替换，**不改 DB seed 字段** |

**数据流（文字图）**

```
ThemePalette (t1..t8/custom)
        │ color tokens
        ▼
GlassIcon (G1 容器, 28/36/44)
        │ 本体尺寸 = 容器×0.55
        ▼
BkIcon(name, selected, color)
        │ 解析 Path + 态
        ▼
BkXxxPainter.paint (24×24 栅格, stroke 1.75)
```

### 2.4 性能改进

| 建议 | 指标/约束 |
| --- | --- |
| Path 静态化 | 每个图标 Path 为编译期常量或惰性 final，避免每帧 `Path()` 堆分配 |
| shouldRepaint | 仅 `selected` / `color` / `strokeScale` 变化时 true（34 §8.3） |
| Tab 动画 | 200ms 使用现有 `GlassMotion.curve`；减弱动态 100ms；禁止每帧重建 Widget 树深路径 |
| 列表 | 账单列表行图标与行分离 repaint（RepaintBoundary 可选，仅在 profile 发现 jank 时） |
| 包体积 | 无 SVG 运行时依赖；17 枚首期 Painter 预估体积可忽略 |
| 预算 | **假设 A4**：底栏切换 60fps 不掉帧；列表滚动维持现有 golden/性能基线（与毛玻璃 AC 不冲突） |

---

## 3. 分步修复 / 实施方案

对齐 34 §9.3 Phase 0–5。每步含技术要点与退出条件。

### Step 0 — 基建（P0）

1. 新建目录 `app/lib/shared/icons/`（bk_icon / bk_icons / painters/）。
2. 定义 `BkIconTokens`：canvas 24、safe 2、stroke 1.75、cap/join round；**不**复制 G1 blur。
3. 定义 `BkIcons` 首期常量（§11 清单 P0+P1）。
4. `BkIcon` Widget：默认 `color = palette.textPrimary`，`selected=false`；paint 时读色（D1）。
5. 组合 GlassIcon：**假设 A1** 采用组合封装，避免改坏 FG-ICON。
6. Golden 模板：浅/深 × 底栏。

**退出**：可编译；首页三枚可替换但尚未强制；无 flutter_svg。

### Step 1 — 首页导航（P0）

1. 实现 `bk.nav.bills` / `bk.nav.reports` / `bk.act.entry` Painter（含 bills/reports `selected` fill）。
2. `app_icons.dart` + `app.dart` 底栏接入；中央动作改 D3 圆内加号。
3. 动画：选中 200ms / 减弱动态 100ms。

**退出**：AC-01 预检、AC-06、AC-10 走查通过。

### Step 2 — 账单链路（P0）

1. `bk.bill.empty` 与 `bk.bill.filter` 生产接线；`bk.bill.list/transfer` 保留 P2 储备，账单行按 2026-09 产品决策采用 Material。
2. `bills_page` / 空态 `AppEmpty` 插画位改 `bk.bill.empty` 主形（D4 单层）。
3. 筛选入口（类型/分类）接入；转账 Material 图标不染红绿。

**退出**：账单空态 CTA 策略、筛选入口与 AC-07 预检。

### Step 3 — 报表链路（P0）

1. `bk.rpt.pie/bars/calendar/empty`（P1 period 可同 PR）；`bk.rpt.hide-amount` 仅保留 Painter 储备，不接手动入口。
2. Segment 双视图、空态接入；隐藏金额由 `amountMaskProvider` 自动脱敏，不提供手动开关。
3. 图例仍走 `chartSeriesColorsFromPalette`，不占用 BK-ICON。

**退出**：报表双视图 Golden 更新策略明确。

### Step 4 — 状态 + 门禁（P1）

1. `bk.status.sync/lock/warn`（ok 为 P2）。
2. `tool/check_bk_icons.dart`：扫描 `lib/features` + `app.dart` 的裸 `Icons.`（白名单）。
3. 扩展 `tool/check_fg_contrast.dart` 图标场景（AC-04）。
4. 移除正式路径 fallback（A3）。

**退出**：AC-01/03/04 扫描绿。

### Step 5 — 分类库（P2）

1. 保留 `iconName`；分组结构 `categoryIconGroups` 不变。
2. 按父类批量生成/手写 Bk Path；选择器与列表行换 Painter。
3. 盲测扩展到常用分类（非 AC-05 必选项）。

**退出**：无 Material 分类图标正式引用（或白名单为空）。

---

## 4. 接口与数据结构（规范级）

### 4.1 图标 ID

见 34 §6 / §11。代码常量：

```dart
abstract final class BkIcons {
  static const bills = 'bk.nav.bills';
  static const reports = 'bk.nav.reports';
  static const entry = 'bk.act.entry';
  static const billList = 'bk.bill.list';
  // ...
}
```

### 4.2 BkIcon 参数

| 参数 | 类型 | 默认 | 约束 |
| --- | --- | --- | --- |
| name | String | 必填 | 必须在注册表中 |
| size | double? | null | null 时由父级 GlassIcon 决定；绘制坐标系仍 24 |
| selected | bool | false | 仅 nav 族语义启用；非 nav 忽略或 no-op |
| color | Color? | null | null → `palette.textPrimary`；selected 且 nav → `palette.primary` |

### 4.3 Painter 注册表

```dart
typedef BkIconPainterFactory = CustomPainter Function({
  required Color color,
  required bool selected,
});
// name → factory；未知 ID → fallback 策略见假设 A3
```

### 4.4 与 GlassIcon 关系

| 项 | 约定 |
| --- | --- |
| 容器材质 | 仍为 G1（BK-DOC-23 §4.1） |
| tint | selected 时可 tint 容器（与 duo 兼容）；**默认 fill 态本体 primary，容器 tint 可选** |
| 本体缩放 | 容器 × 0.55，Painter 内 scale from 24 |
| 豁免 | 表格内文字符号不设容器（沿用 FG-ICON 豁免） |

### 4.5 异常与边界

| 场景 | 处理 |
| --- | --- |
| 未知 name | fallback（A3）或 assert（debug）+ release 回退 `Icons.category` |
| selected 传给非 nav | 忽略 selected，按线性绘制 |
| size < 16 | 允许绘制，但设计验收不保证清晰度 |
| 主题切换中 | Path 不变，仅 color lerp（`ThemePalette.lerp`） |
| 无障碍 reduce motion | 状态切换 100ms 淡入淡出，无路径 morph |
| 高对比/脱敏 | 颜色 Token 降档，不修改 Path |

---

## 5. 非功能性要求

| 维度 | 要求 | 来源 |
| --- | --- | --- |
| 视觉 | stroke 1.75±0.05；24 栅格；round cap/join | 34 §4 |
| 颜色 | 仅 ThemePalette；禁止业务裸 hex | D1, AC-03 |
| 对比度 | 图标 ≥3:1；Tab 标签文字 ≥4.5:1 | 34 §5.3 |
| 动效 | 200ms / 100ms reduced | 34 §8.2 |
| 性能 | 无 SVG 运行时；shouldRepaint 精确；Tab 无掉帧 | §2.4, A4 |
| 可维护 | semver + Golden + 扫描门禁 | 34 §9.2 |
| 包体积 | 不引入 flutter_svg | AC-09 |
| 测试 | Widget + Golden + 扫描 + 内部盲测 | 34 §10 |

---

## 6. 涉及文件清单

| 路径 | 改动类型 | 说明 |
| --- | --- | --- |
| `app/lib/shared/icons/bk_icon.dart` | 新建 | BkIcon Widget |
| `app/lib/shared/icons/bk_icons.dart` | 新建 | 名称常量 |
| `app/lib/shared/icons/bk_icon_tokens.dart` | 新建 | 栅格/描边 Token（可选并入 bk_icon.dart） |
| `app/lib/shared/icons/painters/*.dart` | 新建 | 各图标 CustomPainter |
| `app/lib/shared/icons/bk_icon_registry.dart` | 新建 | name → painter 注册与 fallback |
| `app/lib/shared/widgets/glass_icon.dart` | 修改 | 组合 CustomPaint 槽位或等价扩展（A1） |
| `app/lib/shared/theme/app_icons.dart` | 修改 | `moduleIcon` → Bk 常量 |
| `app/lib/app.dart` | 修改 | 底栏与中央记账入口 |
| `app/lib/features/bills/bills_page.dart` | 修改 | 列表/空态图标、筛选栏 |
| `app/lib/features/bills/bill_filter_sheet.dart` | 新建 | 筛选弹层（类型/分类） |
| `app/lib/features/bills/bills_providers.dart` | 修改 | BillFilter / 过滤逻辑 |
| `app/lib/features/reports/reports_page.dart` | 修改 | Segment、自动脱敏状态等 |
| `app/lib/shared/widgets/app_empty.dart` | 修改 | 插画位支持 Widget/BkIcon（D4） |
| `app/lib/shared/utils/category_icon.dart` | 修改（P2） | 映射底层绘制 |
| `app/lib/shared/theme/glass_tokens.dart` | 只读引用 | 不改 G1–G5；可引用 GlassMotion |
| `tool/check_bk_icons.dart` | 新建 | 裸 Icons 扫描 |
| `tool/check_fg_contrast.dart` | 修改 | 图标对比度场景 |
| `app/test/golden/**` | 修改/新增 | 底栏、账单、报表双态 |
| `app/test/unit/shared/icons/**` | 新建 | 注册表、颜色默认值、selected |
| `design/icons/bk/**` | 可选新建 | SVG 设计源（不进 App 包） |
| `docs/34-GraphicSystemDesignSpecifications.md` | 只读 | 唯一事实来源 |
| `docs/35-图形体系Spec规格说明.md` | 本文 | — |
| `docs/36-图形体系任务分解.md` | 新建 | 任务分解 |

---

## 7. 实施进度追踪表

| Phase | 任务簇（见 36） | 状态 | 出口条件 |
| --- | --- | --- | --- |
| P0 基建 | BK-IC-001…005 | **completed** | 组件可编译、Token 单源、注册表可解析 |
| P1 首页导航 | BK-IC-010…014 | **completed** | AC-01/06/10 预检 |
| P2 账单链路 | BK-IC-020…023 | **completed** | 账单空态/列表/筛选接入 |
| P3 报表链路 | BK-IC-030…033 | **completed**（hide-amount 手动验收按产品定义移除） | 双视图/自动脱敏/空态 |
| P4 门禁与状态 | BK-IC-040…044 | **completed** | AC-01/03/04 扫描绿 |
| P5 分类库 | BK-IC-050…052 | **pending**（P2 可延期） | P2 迁移完成或明确延期 |
| 验收 | BK-IC-060…063 | **in_progress**（060/061 已完成；062/063 待办） | AC-01~10 + 盲测记录归档 |

> 进度状态以 36 文档 Status 字段为执行真源；本表仅作阶段汇总。

---

## 8. 验证与测试方案

### 8.1 静态与扫描

| 检查 | 命令/方式 | 对应 AC |
| --- | --- | --- |
| 无 flutter_svg 依赖 | `pubspec` 审查 + import 扫描 | AC-09 |
| 裸 Icons 收敛 | `tool/check_bk_icons.dart` | AC-01 |
| 裸 hex | 业务 icons 路径扫描 Color(0x) | AC-03 |
| analyze | `flutter analyze` | 通用 |

### 8.2 单元 / Widget

- 注册表：全部 P0/P1 ID 可解析；
- 默认色：无 color 参数时等于 `textPrimary`；
- nav selected：color == primary；非 nav selected 被忽略；
- shouldRepaint：仅目标字段变化触发；
- reduce motion：100ms 路径。

### 8.3 Golden

| 场景 | 覆盖 |
| --- | --- |
| 浅色/深色 × 底栏 | bills/reports/entry + selected 切换帧（可静态两帧） |
| 账单空态 / 报表空态 | D4 单层主形 |
| 至少 1 套非默认主题预设 | D1 多主题 |

策略：与现有 `app/test/golden` 一致；改图标 Path 必须附 diff 说明。

### 8.4 人工走查 / 盲测

- 走查：描边、圆角端点、Tab fill 一致性、空态无装饰、记账为圆内加号；
- 盲测（AC-05 / D7）：内部 5 人 × 10 轮；20px 与 16px；账单/报表/记账正确率 ≥90%；记录表归档 `docs/` 验收附件。

### 8.5 性能

- Profile 底栏切换与账单列表滚动；
- 确认无每帧 Path 重建；同屏 GlassIcon 数量与毛玻璃预算不叠加恶化。

### 8.6 验收门禁（合并条件）

P0 PR：AC-01 预检（首页路径）、AC-06、AC-09、AC-10。  
全量：AC-01~10 全绿后输出验收报告（建议 `docs/37-图形体系验收报告.md`，**待确认编号**）。

---

## 9. 假设与待确认

| ID | 假设 / 待确认 | 现状 | 若否决的影响 |
| --- | --- | --- | --- |
| A1 | GlassIcon 通过组合扩展支持 CustomPaint，不重写 G1 材质 | 34 建议 BkIcon + GlassIcon | 需改 FG-ICON API，回归面变大 |
| A2 | Tab 选中态全栏统一 **fill**（不采用 duo） | 34 §8.1 推荐 fill | duo 需补 primaryContainer 容器态规范 |
| A3 | fallback 为过渡期工具，Phase 4 移除正式路径依赖 | 34 §9.4 / 风险表 | 永久 fallback 会削弱 AC-01 |
| A4 | 性能以现有 App 基线为准，不另设 fps 数字（除毛玻璃既有） | 34 未给定量 fps | 需产品给出 55/60fps 门禁 |
| A5 | 16px 时 stroke 2.0 为可选优化，非 AC 硬性 | 34 §4.3「可升至」 | 若硬性需补 16px Golden |
| A6 | SVG 设计源可选；Phase 0 可手写 Path | 34 §9.1「可放」 | 若要求 SVG 必备则增加资产流水线任务 |
| A7 | 中央记账容器若为主按钮实色，本体用 `onPrimary` | 34 §7.1 | 需在 app.dart 确认现容器形态 |
| A8 | 验收报告文档号 37 待占用确认 | 仓库 docs 已用到 36 规划 | 编号冲突则顺延 |
| A9 | 灰度开关不在本期默认范围 | 34 风险表「可灰度」 | 若要灰度需增加远程配置任务 |

---

## 10. 修订记录

| 版本 | 日期 | 说明 |
| --- | --- | --- |
| v1.0 | 2026-08 | 依据 BK-DOC-34 首版；问题分类 P-01~P-12；四维改进建议；Phase 0–5 与 AC 映射；任务见 BK-DOC-36 |
