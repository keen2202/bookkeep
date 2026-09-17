# bookkeep 图形体系设计规范

| 字段 | 值 |
|---|---|
| 文档编号 | BK-DOC-34 |
| 状态 | 已确认决策 · 可进入实施 |
| 基线视觉 | FGDS v1.0（iOS 毛玻璃，BK-FG 系列） |
| 关联文档 | `docs/22-iOS毛玻璃设计文档.md`、`docs/23-iOS毛玻璃Spec规格说明.md`、`docs/09-UI设计文档-主题与视觉体系.md` |
| 代码基线 | `app/lib/shared/theme/`、`app/lib/shared/widgets/glass_icon.dart`、`app/lib/shared/utils/category_icon.dart` |
| 平台 | iOS / Android（Flutter） |
| 优先范围 | 首页：账单 Tab、报表 Tab、记账入口；及账单/报表核心链路 |

---

## 1. 目标与范围

### 1.1 目标

将当前以 Material Icons 为主、填充/线性混用的图形用法，收敛为与 FGDS 毛玻璃容器同源的 **BK-ICON 矢量体系**：

- 风格统一：**全线性，描边 1.75px**；
- 着色统一：图标颜色只来自 **`ThemePalette`**（多主题预设），禁止裸 hex；
- 载体统一：功能图标继续落在 **G1 `GlassIcon`（28/36/44）** 容器内；
- 实现统一：**CustomPainter 生成**（不引入 flutter_svg 运行时）；
- Tab 选中态：支持 **填充/双色** 两态切换，同样由 CustomPainter 绘制。

### 1.2 本期范围（P0）

| 类别 | 包含 |
|---|---|
| 导航 | 账单 Tab、报表 Tab、中央记账动作 |
| 账单 | 列表流水、转账、筛选、空态、常用操作 |
| 报表 | 图表/日历切换、周期、隐藏金额、空态 |
| 状态 | 同步、锁定、预警、完成 |
| 组件 | `BkIcon` / `BkIcons` 常量、选中态 API |

### 1.3 延后范围（P2）

分类 seed 图标库（14 父 + 60 子）二期迁移：保留既有 `iconName` 字符串契约，仅更换底层绘制，不改动用户数据。

### 1.4 非目标

- 不引入商业图标库付费授权；
- 不做双色 duotone 彩绘插画体系（空态亦保持单色/主色）；
- 不改变 G1–G5 玻璃参数与背景白名单。

---

## 2. 已确认决策（锁定）

| # | 决策 | 约束含义 |
|---|---|---|
| D1 | **有多主题预设，图标着色 Token 跟 `ThemePalette`** | tint / 选中 / 语义色一律取自当前 `context.palette`，禁止组件内写死 `Color(0xFF0A84FF)` |
| D2 | **全线性 1.75px** | 所有 BK-ICON 默认 outline；无 filled 家族并行（Tab 选中态除外，见 D6） |
| D3 | **中央记账按钮 = 克制的圆内加号** | 不采用「票据+加号」复合图形；圆形轮廓 + 中心「+」 |
| D4 | **空态不需要二层装饰** | 仅主图形 + 主色圆底容器；禁止漂浮票据、小柱等点缀 |
| D5 | **CustomPainter 生成** | SVG 为设计源；构建期/手写转换为 `CustomPainter` 或路径常量，运行时不解析 SVG |
| D6 | **Tab 选中态：填充/双色** | 未选中 = 线性；选中 = 同路径填充或「容器 primary 容器色 + 本体 primary」双色；Painter 需暴露 `selected` |
| D7 | **验收盲测 = 内部 5 人** | 5 人 × 10 轮，20px 与 16px 下账单/报表/记账辨识正确率 ≥ 90% |
| D8 | **规范路径** | 本文件 `docs/34-GraphicSystemDesignSpecifications.md` |

---

## 3. 设计原则

1. **容器不变，本体升级**：继续使用 `GlassIcon` / `GlassIconTokens`；只替换图标本体与命名层。
2. **线性优先、语义可辨**：20px 下「账单 / 报表 / 记账」必须可区分。
3. **主题跟随**：默认 `palette.textPrimary`；强调 `palette.primary`；收入/支出仍以 **金额文字色** 承担，图标不染红绿。
4. **双模式同源**：浅/深同一套路径，仅 Color Token 分流（与 Spec §7.2 一致，禁止组件内散写 `isDark ?`）。
5. **可验收**：稳定 ID、固定栅格、Golden 基线、对比度脚本。

---

## 4. 视觉语言规格

### 4.1 风格

| 项 | 规格 |
|---|---|
| 风格 | 线性 Outline（对齐 SF Symbols Regular 的视觉重量） |
| 画布 | 24 × 24 |
| 安全区 | 四周 2px；活动区 20 × 20 |
| 描边 | **1.75px**（16px 显示时可升至 2.0px） |
| 端点/连接 | `strokeCap.round` / `strokeJoin.round` |
| 圆角半径 | 1.5–2.0px；禁止尖锐直角 |
| 光学对齐 | 中心对齐 24 网格；对角线允许半像素 |

### 4.2 与 GlassIcon 的尺寸关系

沿用 `GlassIconTokens`（`app/lib/shared/theme/glass_tokens.dart`）：

| 容器 | 圆角（×0.28） | 图标本体（×0.55） | 用途 |
|---|---|---|---|
| 28 | 7.84 | 15.4 | AppBar 动作 |
| 36 | 10.08 | 19.8 | 列表图标 |
| 44 | 12.32 | 24.2 | 主要功能 / Tab |

BkIcon 绘制坐标系固定为 **24**，由 `Icon`/`CustomPaint` 缩放至容器本体尺寸，避免为每档改 path。

### 4.3 极值尺寸

- 最小有效展示：16（笔画密度允许时描边 2.0）；
- 标准功能：24 / 容器 36·44；
- Tab：容器 44，本体约 24。

---

## 5. 色彩与 ThemePalette 绑定

### 5.1 绑定规则（D1）

图标绘制颜色 **只允许** 来自当前主题 `ThemePalette` 槽位：

| 场景 | Token | 说明 |
|---|---|---|
| 默认图标 | `palette.textPrimary` | 未选中 Tab、列表图标 |
| 次要图标 | `palette.textSecondary` | 辅助操作、弱化态 |
| 禁用/脱敏 | `palette.textDisabled` / `textTertiary` | 隐藏金额、锁定脱敏旁路信息 |
| 选中/tint | `palette.primary` | Tab 选中、强调入口 |
| 选中容器 | `palette.primaryContainer` | 双色态底（可配 GlassIcon tint，其 fill 已混入 primary） |
| 收入/支出语义色 | `AppColors.income` / `expense`（见 `app_theme.dart`） | **原则上不用于分类图标本体**，仅用于金额与图表序列 |

### 5.2 多主题

- 预设 `t1..t8` 与自定义种子色均通过同一 `ThemePalette` 注入；
- BkIcon **不得**缓存主题色；应在 `paint` 时读取传入的 `Color`；
- 主题切换过渡使用现有 `ThemePalette.lerp`，图标颜色随主题插值，路径不变。

### 5.3 无障碍

- 图标本体对承载背景对比度 **≥ 3:1**；
- Tab 标签文字 ≥ 4.5:1，图标尽量与标签同色；
- 深色预设下优先使用该预设的 `primary`（通常对纯黑 ≥ 3:1），CI 用 `tool/check_fg_contrast.dart` 扩展图标场景。

---

## 6. 命名与分组

### 6.1 设计侧命名

```
bk.<族>.<语义>[.<变体>]
```

| 族 | 示例 |
|---|---|
| `nav` | `bk.nav.bills` · `bk.nav.reports` |
| `act` | `bk.act.entry`（圆内加号） |
| `bill` | `bk.bill.list` · `bk.bill.transfer` · `bk.bill.empty` |
| `rpt` | `bk.rpt.pie` · `bk.rpt.bars` · `bk.rpt.calendar` · `bk.rpt.hide-amount` · `bk.rpt.empty` |
| `status` | `bk.status.sync` · `bk.status.lock` · `bk.status.warn` · `bk.status.ok` |
| `cat`（P2） | `bk.cat.food.coffee` · `bk.cat.transit.metro` |

变体：尺寸不进文件名；`selected` 为运行时状态而非独立资源。

### 6.2 代码侧

```dart
// 建议新增
abstract final class BkIcons {
  static const bills = 'bk.nav.bills';
  static const reports = 'bk.nav.reports';
  static const entry = 'bk.act.entry';
  // ...
}

class BkIcon extends StatelessWidget {
  const BkIcon(
    super.name, {
    this.size,
    this.selected = false,
    this.color,
  });
  // color 默认 textPrimary；selected 时按第 8 节双态规则绘制
}
```

业务代码 **禁止** 直接引用 `Icons.*`（过渡期白名单 + CI 扫描）。

---

## 7. 分类图形设计（重点模块）

### 7.1 导航

#### `bk.nav.bills` 账单

- **形状**：长票据轮廓 + 底部锯齿可选简化为直边（保证 16px 清晰）+ 内部 2 条水平流水线；
- **未选中**：线性 1.75，`textPrimary`；
- **选中**：票据体填充 `primary`（或 `primaryContainer` + 线性 `primary` 双色），流水线挖空/反白；
- **辨识**：与系统「列表」区分——保留票据上下缘轮廓。

#### `bk.nav.reports` 报表

- **形状**：三根柱高度差 + 底部基线；
- **未选中**：线性柱框或线性柱体；
- **选中**：柱体填充 `primary`；
- **辨识**：与日历、饼图轮廓差异明显；不与账单混淆。

#### `bk.act.entry` 记账（中央）

- **形状**：**正圆轮廓** + 中心等臂「+」（D3）；
- **规格**：圆描边 1.75；加号臂长约 8/24，臂粗 1.75，端点 round；
- **容器**：主操作可用 primary 着色玻璃或主按钮形态，**图标本体保持克制**，不做票据复合；
- **禁**：票据+加号、加粗实心圆+白加号（除非主按钮背景已为 primary 实色，则本体用 `onPrimary`）。

### 7.2 账单

| ID | 含义 | 绘制要点 |
|---|---|---|
| `bk.bill.list` | 流水列表 | 票据 + 3 条线，比 Tab 稍密，列表头部用 |
| `bk.bill.transfer` | 转账 | 水平双向箭头；与收入上箭头/支出下箭头区分 |
| `bk.bill.expense` | 支出方向 | 箭头向下（仅指示，不染红） |
| `bk.bill.income` | 收入方向 | 箭头向上（仅指示，不染绿） |
| `bk.bill.empty` | 空态主形 | **仅** 票据线性主形（D4：无星标、无装饰层） |
| `bk.bill.filter` | 筛选 | 漏斗或三线渐窄，与系统筛选习惯一致 |

**辨识度处理：**

1. 同族票据轮廓保证「这是账」；
2. 差分只用 1 个特征（线数量 / 箭头方向 / 双向箭头），避免复合符号；
3. 金额红绿与图标解耦。

### 7.3 报表

| ID | 含义 | 绘制要点 |
|---|---|---|
| `bk.rpt.pie` | 分类占比 | 圆 + 1–2 条半径分隔，可缺口 |
| `bk.rpt.bars` | 周期对比 | 与 Tab 报表同构，可略简 |
| `bk.rpt.calendar` | 日历视图 | 周历框 + 顶栏挂环 + 网格点；底部可有一条净额短横 |
| `bk.rpt.period` | 周期切换 | 环形箭头 + 短柱，避免纯时钟 |
| `bk.rpt.hide-amount` | 隐藏金额 | 眼睛 + 斜杠 |
| `bk.rpt.empty` | 空态主形 | **仅** 等高基线上的三根矮柱线性图（无第二层装饰） |

图表图例继续使用 `chartSeriesColorsFromPalette`；图例色块 8×8、圆角 2，不使用 BK-ICON。

### 7.4 状态

| ID | 含义 | 备注 |
|---|---|---|
| `bk.status.sync` | 同步 | 双循环箭头；动画可选，尊重 `prefers-reduced-motion` |
| `bk.status.lock` | 隐私锁 | 盾 + 锁孔 |
| `bk.status.warn` | 预警 | 三角 + 感叹号 |
| `bk.status.ok` | 完成 | 圆 + 对勾 |

### 7.5 空状态（D4）

沿用 `AppEmpty` 布局，仅替换插画位：

- 容器：96×96，`primaryContainer.withValues(alpha: 0.5)` 圆底（与现实现一致）；
- 主图形：44，`palette.primary`，**单层主形**；
- 禁止：叠加元素、渐变光斑、表情化装饰；
- 文案：账单空态 CTA「记一笔」；报表空态指向「先有流水」。

---

## 8. Tab 选中态（D6）

### 8.1 状态模型

| 状态 | 路径 | 颜色 | 说明 |
|---|---|---|---|
| `selected=false` | outline | `textPrimary` | 1.75 线性 |
| `selected=true` | **fill 或 duo** | `primary` | 二选一，全 Tab 栏必须一致 |

**推荐默认：fill 单色**（路径闭合处填充 `primary`，内部细节用 destination-out 或双 path 挖空）。若选用 duo：

- 底：`primaryContainer` 圆角方/圆容器（可由 GlassIcon tint 承担）；
- 前：线性或实心 `primary`。

### 8.2 API

```dart
GlassIcon(
  icon: BkIcons.billsData, // 或 CustomPaint 包装
  tint: selected,
  // 内部 BkPainter(selected: selected, color: ...)
)
```

- 选中变化动画 200ms，曲线 `GlassMotion.curve`；
- 减弱动态：100ms 淡入淡出。

### 8.3 实现（CustomPainter）

- 每个图标一个 `Path` 常量或轻量 Painter；
- `shouldRepaint` 当 `selected` / `color` 变化；
- 不使用 `Icons.*` 作为正式路径（过渡映射除外）。

---

## 9. 工程落地

### 9.1 目录建议

```
app/lib/shared/icons/
  bk_icon.dart          # BkIcon Widget
  bk_icons.dart         # 名称常量
  painters/
    bk_nav_bills_painter.dart
    bk_nav_reports_painter.dart
    bk_act_entry_painter.dart
    ...
docs/34-GraphicSystemDesignSpecifications.md  # 本文件
tool/check_bk_icons.dart                      # 裸 Icons 扫描（扩展）
```

设计源 SVG 可放 `design/icons/bk/`（不进 App 包），由人工或脚本转为 Path。

### 9.2 与开发对接

| 项 | 约定 |
|---|---|
| 唯一出口 | `BkIcon` / `BkIcons` + 既有 `GlassIcon` |
| 颜色 | 仅 `ThemePalette` / `AppColors` |
| 版本 | `bk-icons` semver：栅格/描边变更 = major；新增 = minor；路径微调 = patch |
| 提交 | 图标目录原子提交；PR 附 golden diff |
| 门禁 | `flutter analyze`；golden；对比度；裸 `Icons.` 扫描 |

### 9.3 迁移步骤

| Phase | 内容 | 优先级 | 预估 |
|---|---|---|---|
| 0 | 命名、BkIcon 骨架、Painter 生成约定、Golden 模板 | P0 | 0.5 周 |
| 1 | 首页：bills / reports / entry（含选中态） | P0 | 0.5 周 |
| 2 | 账单链路：列表、转账、操作、空态 | P0 | 1 周 |
| 3 | 报表链路：双视图、周期、隐藏金额、空态 | P0 | 1 周 |
| 4 | 状态图标 + CI 扫描收敛 | P1 | 0.5 周 |
| 5 | 分类库 60+ 同风格迁移 | P2 | 2 周 |

### 9.4 兼容

- 过渡期保留 `materialFallback` 映射，缺失时回退并 `debugPrint`；
- 分类 `iconName` 契约不变。

---

## 10. 验收标准（可量化）

| ID | 标准 | 验证 |
|---|---|---|
| AC-01 | 首页 Tab/记账均走 `bk.nav.*` / `bk.act.entry`，正式路径无 `Icons.receipt_long_outlined` / `bar_chart_outlined` | 扫描 + 走查 |
| AC-02 | 功能图标 100% 经 GlassIcon 容器；描边 1.75±0.05 | 设计走查 + 代码 |
| AC-03 | 图标颜色全部来自 ThemePalette 槽位，业务层无裸 hex | 静态扫描 |
| AC-04 | 浅/深（及至少 2 个预设）下核心图标对比度 ≥ 3:1 | 脚本 |
| AC-05 | **内部 5 人 × 10 轮**，20px 与 16px 下账单/报表/记账辨识 ≥ 90% | 盲测记录 |
| AC-06 | Tab 选中/未选中双态正确，切换 200ms，减弱动态 100ms | Widget 测试 + 走查 |
| AC-07 | 空态无二层装饰，账单/报表空态均有文案与 CTA 策略 | 走查 |
| AC-08 | Golden：浅/深 × 账单页 × 报表页 diff 为零（抗锯齿级除外） | `flutter test --update-goldens` 策略 |
| AC-09 | 实现为 CustomPainter，无 flutter_svg 运行时依赖 | pubspec + 代码 |
| AC-10 | 中央记账为圆内加号，非复合票据符号 | 设计稿 + 走查 |

---

## 11. 图标清单（首期最小集）

| ID | 模块 | 优先级 |
|---|---|---|
| bk.nav.bills | 底栏 | P0 |
| bk.nav.reports | 底栏 | P0 |
| bk.act.entry | 底栏中央 | P0 |
| bk.bill.list | 账单 | P0 |
| bk.bill.transfer | 账单 | P0 |
| bk.bill.empty | 账单空态 | P0 |
| bk.bill.filter | 账单 | P1 |
| bk.rpt.pie | 报表 | P0 |
| bk.rpt.bars | 报表 | P0 |
| bk.rpt.calendar | 报表 | P0 |
| bk.rpt.hide-amount | 报表 | P0 |
| bk.rpt.empty | 报表空态 | P0 |
| bk.rpt.period | 报表 | P1 |
| bk.status.sync | 全局 | P1 |
| bk.status.lock | 全局 | P1 |
| bk.status.warn | 全局 | P1 |
| bk.status.ok | 全局 | P2 |

---

## 12. 风险与对策

| 风险 | 对策 |
|---|---|
| Tab 图标变更影响用户习惯 | 随版本说明一帧；可灰度 |
| Painter 手写路径工作量 | 先最小集 17 枚；分类库脚本化 |
| 多主题下选中态可读性差 | 选中用 primary 实色，弱预设上做对比度抽检 |
| 禁止 Icons 后过渡期断裂 | 白名单 + fallback 一个迭代后移除 |

---

## 13. 修订记录

| 版本 | 日期 | 说明 |
|---|---|---|
| 1.0 | 2026-08 | 首版；锁定 D1–D8 决策，可进入 Phase 0 |
