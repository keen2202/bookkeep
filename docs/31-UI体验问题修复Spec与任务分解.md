# 31-UI体验问题修复（第二轮）Spec 与任务分解

| 项 | 内容 |
| --- | --- |
| 文档编号 | BK-DOC-31 |
| 版本 | v1.0（已实施并验证） |
| 日期 | 2026-09-10 |
| 范围 | Flutter App（`app/`）4 项 UI/UX 问题的修复：收支趋势按日汇总、周期记账去 ✔、分类选中光晕收敛、App 图标圆圈居中 |
| 关联文档 | 28-交互与导航优化Spec（需求7 选中态去 ✔、需求9 收支趋势）、29-交互与导航优化任务分解、30-UI体验问题修复Spec（T07 备查项）、19-玻璃拟态全链路设计文档 |
| 代码基线 | 本文「现状」均基于当前仓库源码逐行核对，附文件与行号 |

---

## 0. 代码基线核对结论（前置事实）

| # | 核对项 | 结论 |
| --- | --- | --- |
| 1 | 收支趋势粒度 | `reports_page.dart` 的「收支趋势」区块仅在**年**粒度渲染（`yearlyTrendProvider` → 12 个月桶，副标题「{年}年 · 按月汇总」）；`BucketGranularity` 只有 `week`/`month` 两值，月粒度无趋势区块（旧 AC9-1） |
| 2 | 周期记账 ✔ | `recurring_page.dart` 规则编辑弹层使用裸 `SegmentedButton<String>`/`SegmentedButton<RecurringFrequency>`（M3 默认 `showSelectedIcon: true`）与裸 `ChoiceChip`（默认 `showCheckmark: true`），选中态均渲染 ✔。BK-DOC-30 T07 已将该处登记为「备查、后续按 AC7-4 统一收敛」 |
| 3 | 分类选中光晕 | 记账页分类弹窗 `CategoryPicker` 的选中态由 `GlassSelection` 四层叠加承载，层② 光晕为 `GlassSelectionTokens.glowAlpha 0.25 / glowBlur 20`；chip 高度约 30px、`Wrap` 间距 8px，blur 20（外溢约 10px）在小控件上明显发散、糊住相邻分类 |
| 4 | App 图标圆圈位置 | `tool/generate_app_icons.py` 按设计稿原样落位生成：主图预览内环形硬币外接框中心 `(0.5000, 0.4631)`，比画布几何中心**上移 3.69%**（1024 栅格 ≈ 37.8px），iOS/Android 全部图标沿用该偏移 |

---

# 第一部分 Spec（需求规格）

## UI-01 收支趋势增加按日汇总统计

**现状描述**
报表 → 图表视图的「收支趋势」折线图只在统计期为**年**时出现，固定按 12 个月汇总。统计期收敛到某个月（时间滚轮选到月）后趋势区块整体消失，无法观察当月逐日走势。

**预期行为**
- 统计粒度决定趋势粒度：**年 → 按月汇总**（12 桶，行为不变）；**月 → 按日汇总**（当月 28/29/30/31 桶）；**日 → 不渲染趋势区块**（单日无走势可言）。
- 月粒度趋势的副标题为「{年}年{月}月 · 按日汇总」；区块位置、容器（G2 `GlassPanel`）、折线样式、图例点击显隐、脱敏（`hideAmounts`）与 y 轴刻度策略与年粒度完全一致。
- 按日汇总的取数口径与其余区块一致：账本过滤 + 记账汇率快照优先、缺失回退汇率表；**无流水的日期补 0 点**（折线不断档），全月零流水时走「暂无数据」空态。
- x 轴标签为「D日」（如 1日/5日…），窄屏自动跳标（相邻标签间距 ≥ 34px），28~31 个桶时约每 4 天标一次，不互相重叠。
- 触摸 tooltip 时间文案为「YYYY年M月D日」。

**影响范围**
- 数据层：`app/lib/data/repositories/reports_repository.dart`（`BucketGranularity` 增加 `day`，`periodBuckets` 增加 `%Y-%m-%d` 分桶）
- 展示层：`app/lib/features/reports/reports_page.dart`（`dailyTrendProvider` + `dailyTrendBuckets` 补零）、`app/lib/features/reports/charts/report_charts.dart`（日桶轴标签、跳标步长、tooltip 文案）

**验收标准（可测试）**
1. `dailyTrendBuckets(year, month, sparse)`：空桶 → 空列表；部分日期 → 固定当月天数、缺失日补 0、label `YYYY-MM-DD` 升序；闰年 2 月 29 桶；跨月/跨年桶被忽略。
2. `periodBuckets(granularity: day)`：同一天多笔合并，日标签 `YYYY-MM-DD`，窗口外流水不计。
3. `periodAxisLabels` 将 `YYYY-MM-DD` 渲染为「D日」，不影响既有日/周/月/年标签规则；`axisLabelInterval` 在 320px 宽下对 28~31 桶返回 4、对 12 个月桶返回 2（与既有行为一致）。
4. Widget：年粒度仍为「{年}年 · 按月汇总」；月粒度出现「{年}年{月}月 · 按日汇总」且折线点数 = 当月天数，选中日的点金额正确、其余日为 0；日粒度不出现趋势区块。

---

## UI-02 取消周期记账中的「✔」选中效果

**现状描述**
周期记账规则编辑弹层（`RuleEditSheet`）中，支出/收入分段、频率分段、锚点选项（月初/月中/月末/自定义日期，周频率为周一~周日）选中时均在文字前渲染 ✔。

**预期行为**
- 支出/收入、频率两处分段控件改用全项目收敛出口 `AppSegmentedButton`（`showSelectedIcon: false` + primary 前景 + primary α0.12 底突显）。
- 锚点选项改用新增收敛出口 `AppChoiceChip`（`showCheckmark: false` + primary 前景 + 加粗），选中语义仍由 `selected` 承载，颜色不是唯一通道。
- 选中/联动逻辑（周频率按 `anchorDay` 判定、切频率重置锚点、自定义日期默认 15）与保存流程完全不变。

**影响范围**
- 新增：`app/lib/shared/widgets/app_choice_chip.dart`
- 改动：`app/lib/features/recurring/recurring_page.dart`

**验收标准（可测试）**
1. 规则编辑弹层内不存在 `Icons.check`；两处分段控件的 `showSelectedIcon` 均为 false；全部锚点 chip 的 `showCheckmark` 均为 false。
2. 切换频率到「周」后 7 个锚点 chip 同样无 ✔；选中 chip 的文字色为 `palette.primary`。
3. 既有 golden（`golden_tabs_test` 周期记账页）不因本次改动变化（列表页不含分段控件与 chip）。

---

## UI-03 记账页分类选中效果：光晕收敛

**现状描述**
记账页分类弹窗的选中光晕 blur 20、α0.25，在高度约 30px 的 chip 与紧凑的父分类行上外溢约 10px，选中项周围形成发散光斑，相邻分类被糊住。

**预期行为**
- `GlassSelection` 增加**可选**光晕覆盖参数 `glowAlpha` / `glowBlur`，默认值保持 FG-SEL 既有语义（0.25 / 20），其余使用方（底部导航、玻璃表格、样板间）零变化。
- 新增紧凑档 Token `GlassSelectionTokens.compactGlowAlpha = 0.30` / `compactGlowBlur = 8`；分类弹窗的父分类行与二级 chip 均改用该档：光晕外溢收敛到约 4px，不再向相邻分类发散，层①③④（玻璃增亮 / primary 渐变叠加 / 双描边）保持不变。
- 选中辨识度不降：文字与图标仍着 `palette.primary`，外缘仍为 1px primary α0.6。

**影响范围**
- `app/lib/shared/theme/glass_tokens.dart`（新增 compact 档 Token）
- `app/lib/shared/widgets/glass_selection.dart`（可选参数）
- `app/lib/shared/widgets/category_picker.dart`（传紧凑档）

**验收标准（可测试）**
1. 分类弹窗选中态投射的光晕 `blurRadius == 8`、颜色 = `palette.primary` α0.30、`spreadRadius == 0`；未选中态不投射光晕。
2. `compactGlowBlur < glowBlur`（收敛关系可断言）；`GlassSelection` 默认档（不传参）仍为 20 / 0.25。
3. 点选二级分类的回调与选中预填行为不变。

---

## UI-04 App 图标圆圈图案居中

**现状描述**
`tool/generate_app_icons.py` 保留设计稿的视觉重心校正：主图预览内环形硬币外接框中心为 `(0.5000, 0.4631)`，即比画布几何中心上移 3.69%。生成的 iOS 1024 图标中白色前景外接框为 `x 276–747 / y 238–709`，中心 `(511.5, 473.5)`，画布中心为 `(511.5, 511.5)`——圆圈明显偏上。

**预期行为**
- 生成脚本以**环形硬币（外接框面积最大的路径）**为基准做几何居中：计算其外接框中心与画布中心的差值，整体平移全部前景路径（环内折线与圆点随之移动，相对关系不变），再输出 Android/iOS 资源。
- 平移后校验：渲染 1024 蒙版，前景外接框中心与画布中心偏差 ≤ 0.5%（约 5px），偏差超限直接抛错，防止回归。
- 图形语义、比例、品牌色、圆角率、自适应图标安全区均不变；Android 自适应前景（108dp 矢量）同步居中。

**影响范围**
- `tool/generate_app_icons.py`（新增 `center_ring` / `verify_ring_centering`）
- 重新生成：Android `mipmap-*/ic_launcher(.png/_round.png)`、`drawable/ic_launcher_foreground.xml`；iOS `AppIcon.appiconset` 全部尺寸

**验收标准（可测试）**
1. 脚本输出「平移 dx=+0.00% dy=+3.69%；实测中心 (0.5000, 0.4995)」，校验通过。
2. 重新生成的 1024 图标白色前景外接框为 `x 276–747 / y 276–747`，中心 `(511.5, 511.5)`，与画布中心重合；外接框尺寸仍为 472×472（比例不变）。
3. 新旧图标形状一致性：旧图整体下移 38px 后与新高斯二值蒙版 IoU = 0.9957（差值来自抗锯齿），确认仅平移、未变形。
4. Android 自适应前景 pathData 的环心由 `(54, 50.016)` 变为 `(54, 54)`。

---

# 第二部分 任务分解

## T01 数据层：`periodBuckets` 增加日粒度

- **模块**：`app/lib/data/repositories/reports_repository.dart`
- **优先级**：P0　**Status**：done

**Checklist**
- [x] `BucketGranularity` 增加 `day`，并补文档注释说明三种桶的 label 格式
- [x] `periodBuckets` 的 `strftime` 格式改为 `switch`：day `%Y-%m-%d` / week `%G-W%V` / month `%Y-%m`
- [x] 日桶原样返回 label（解析与补零交给展示层纯函数）
- [x] 新增单测：同日多笔合并、窗口外流水排除、日标签升序

**验证方式**：`flutter test test/unit/data/repositories/reports_repository_test.dart`

---

## T02 展示层：月粒度收支趋势按日汇总

- **模块**：`app/lib/features/reports/reports_page.dart`
- **优先级**：P0　**Status**：done
- **Dependencies**：blockedBy = T01；blocks = T03

**Checklist**
- [x] 新增 `dailyTrendProvider`（family `({int year, int month})`，watch `ledgerVersionProvider` + 汇率表，调用日粒度 `periodBuckets`）
- [x] 新增纯函数 `dailyTrendBuckets(year, month, sparse)`：按当月天数补零、全零走空态
- [x] `_chartsBody` 的趋势取数改为按粒度分支：年 → `yearlyTrendProvider`；月 → `dailyTrendProvider`；日 → 不取数
- [x] 副标题随粒度切换（按月汇总 / 按日汇总），重试回调 invalidate 对应 provider
- [x] 新增单测 `daily_trend_test.dart`（空态 / 补零 / 闰年 / 跨月 / 未来月）

**验证方式**：`flutter test test/unit/features/reports/daily_trend_test.dart`

---

## T03 图表：日桶轴标签与跳标步长

- **模块**：`app/lib/features/reports/charts/report_charts.dart`
- **优先级**：P0　**Status**：done
- **Dependencies**：blockedBy = T02

**Checklist**
- [x] `periodAxisLabels` 新增 `YYYY-MM-DD` 日桶规则（主标签「D日」），不影响既有四种格式
- [x] 新增 `axisLabelInterval(chartWidth, count)`：相邻标签间距 ≥ 34px 的整数跳标；12 个月桶仍为 2（既有观感不变）、28~31 日桶为 4
- [x] `TrendLineChart` tooltip 时间文案支持「YYYY年M月D日」
- [x] 新增单测：日桶标签、跳标步长（含 12 桶回归与单桶兜底）

**验证方式**：`flutter test test/unit/features/reports/report_charts_test.dart`

---

## T04 周期记账去 ✔

- **模块**：`app/lib/shared/widgets/app_choice_chip.dart`（新增）、`app/lib/features/recurring/recurring_page.dart`
- **优先级**：P1　**Status**：done
- **Dependencies**：blockedBy = 无；blocks = 无

**Checklist**
- [x] 新增 `AppChoiceChip`：`showCheckmark: false` + 选中 primary 前景/加粗（底色与描边沿用 `chipTheme`）
- [x] 支出/收入、频率两处 `SegmentedButton` → `AppSegmentedButton`
- [x] 锚点 `ChoiceChip` → `AppChoiceChip`，选中判定逻辑（周频率 `anchorDay`）原样保留
- [x] 新增 `app_choice_chip_test.dart`（关 ✔ / 选中配色 / 未选中回落 / 回调）
- [x] 新增 `recurring_page_test.dart`（弹层无 ✔、切周频率 7 chip 无 ✔、选中态为 primary）
- [x] golden 基线无需更新（周期记账 golden 为规则列表页）

**验证方式**：`flutter test test/widget/app_choice_chip_test.dart test/widget/recurring_page_test.dart`

---

## T05 分类选中光晕收敛

- **模块**：`app/lib/shared/theme/glass_tokens.dart`、`app/lib/shared/widgets/glass_selection.dart`、`app/lib/shared/widgets/category_picker.dart`
- **优先级**：P1　**Status**：done
- **Dependencies**：blockedBy = 无；blocks = 无

**Checklist**
- [x] `GlassSelectionTokens` 新增 `compactGlowAlpha 0.30` / `compactGlowBlur 8`，默认档 0.25 / 20 不变
- [x] `GlassSelection` 增加可选 `glowAlpha` / `glowBlur`（默认走 Token），层② 取值改走覆盖值
- [x] `CategoryPicker` 的父分类行与二级 chip 传紧凑档，并补注释
- [x] 新增 `category_picker_test.dart`（光晕 = 8 / α0.30、未选中无光晕、回调不变）
- [x] 新增 `shared/glass_selection_test.dart`（默认档 20 / 0.25、覆盖档 8 / 0.30、未选中无光晕）
- [x] `glass_tokens_test.dart` 增补 compact 档断言
- [x] 底部导航 / 玻璃表格 / 样板间未传参 → 行为不变（golden 全绿佐证）

**验证方式**：`flutter test test/widget/category_picker_test.dart test/widget/shared/glass_selection_test.dart test/unit/shared/theme/glass_tokens_test.dart`

---

## T06 App 图标圆圈居中

- **模块**：`tool/generate_app_icons.py` + 全部图标资源
- **优先级**：P1　**Status**：done
- **Dependencies**：blockedBy = 无；blocks = 无

**Checklist**
- [x] 新增 `_path_bounds` / `_path_area` / `center_ring`：按最大外接框路径（环）几何居中，平移全部前景路径
- [x] 新增 `verify_ring_centering`：渲染 1024 蒙版校验中心偏差 ≤ 0.5%，超限抛错
- [x] `main()` 打印平移量与实测中心；文档字符串同步（去掉「保留视觉重心」表述）
- [x] 重新生成 Android（5 档 mipmap × 2 + 自适应矢量）与 iOS（13 种尺寸）
- [x] 复核：1024 图标前景外接框 `x 276–747 / y 276–747`、中心 `(511.5, 511.5)`；新旧蒙版平移 IoU 0.9957

**验证方式**：`python3 tool/generate_app_icons.py`（需 `pymupdf` + `pillow`）+ 上述复核

---

## 全局验证（已完成）

- [x] `flutter analyze`：**No issues found!**
- [x] `flutter test --no-pub`：**602 项全部通过**（含全部 golden，无基线变更）
- [x] `dart run tool/check_ui_tokens.dart`：✓ lib/ 无裸色值/ARGB 字面量/裸字号残留
- [x] `bash tool/check_glass_consistency.sh`：FGDS 一致性门禁全部通过
- [x] `dart tool/check_fg_contrast.dart`：硬性失败 0 组（7 组规格矛盾告警为既有偏差）
- [x] 图标生成脚本自校验通过（环心实测 `(0.5000, 0.4995)`）

## 遗留（不在本次范围）

- `category_edit_sheet.dart`（一级/二级分类）、`appearance_page.dart`（浅色/深色/跟随系统）、`component_gallery_page.dart`（主题切换 chip）仍为裸 `SegmentedButton` / `ChoiceChip`，选中态仍带 ✔。按 BK-DOC-30 T07 的登记，建议后续按 AC7-4 统一收敛到 `AppSegmentedButton` / `AppChoiceChip`（外观页涉及 8 张 golden 基线重建，故未纳入本次）。
