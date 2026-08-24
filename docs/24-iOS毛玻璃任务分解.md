# 24 - iOS 毛玻璃任务分解（FGDS v1.0 · 实施计划）

| 项目 | 内容 |
| --- | --- |
| 文档编号 | BK-DOC-24 |
| 版本 | v1.0 |
| 日期 | 2026-08-24 |
| 状态 | 待评审 |
| 关联文档 | `docs/22-iOS毛玻璃设计文档.md`（设计理念）、`docs/23-iOS毛玻璃Spec规格说明.md`（唯一参数源） |
| 取代关系 | 完全取代 `docs/21-玻璃拟态全链路任务分解.md` 及全部前序玻璃实施计划 |
| 任务编号约定 | BK-FG-xxx；阶段：P0 基础设施 → P1 核心组件 → P2 复合组件 → P3 页面接入 → P4 验收清理 |

**总原则**：所有数值只允许来自 Spec（23 文档）；每完成一个任务必须同步通过其关联 AC；旧玻璃系统（`ambient` Mesh、`glassFill*` 派生等）在 P0 内一次性拆除，不做渐进兼容。

---

## P0 基础设施（拆除旧系统 + 建立唯一参数源）

| ID | 任务 | 主要改动位置 | 对应 Spec | 验收标准 | 依赖 |
| --- | --- | --- | --- | --- | --- |
| BK-FG-001 | 建立玻璃 Token 体系：新建 `glass_tokens.dart`，定义 §2/§3 全部 Token（G1–G5 的 blur/fill/border/highlight/shadow/radius，主题色深浅双值，文字四档，动效常量）；`ThemePalette` 接入双模式分流 | `app/lib/shared/theme/glass_tokens.dart`（新建）、`theme_presets.dart` | §1/§2/§3/§5/§6 | Token 单文件可读全量参数；编译通过 | — |
| BK-FG-002 | 背景系统重构：`AppBackground` 改为纯色 `#F2F2F7` / `#000000`（+ 可选同系微渐变）；**删除** `ambient` Mesh 渐变、光斑绘制、漂移动画及相关 Token；8 套预设主题背景统一收敛 | `theme_presets.dart`、`AppBackground` 所在文件 | §2.2、§8 | AC-02：扫描无 `ambient`/RadialGradient 光斑残留 | BK-FG-001 |
| BK-FG-003 | 新建基础容器 `GlassPanel`：按 `GlassLevel.g1–g5` 渲染 BackdropFilter + 填充 + 双层描边 + 顶部内高光 + 环境投影；支持禁用模糊降级（低性能时 fill α +0.10 补偿） | `app/lib/shared/widgets/glass_panel.dart`（新建） | §3 | 五层渲染与参数表逐项一致；嵌套升档规则生效 | BK-FG-001 |
| BK-FG-004 | 拆除旧玻璃实现：移除 `glassFill/glassFillStrong/glassBorder` 派生字段、`resolveGlassSpec()`、旧 `AppGlass` 装饰方法及全部调用点；`ContrastGuard` 由静态验算替代 | `theme_presets.dart`、`app_card.dart` 等引用点 | §8 | AC-08：编译无残留引用 | BK-FG-001、003 |

**P0 出口条件**：应用可编译运行，背景为纯净双色，旧玻璃代码零残留（AC-02、AC-08 预检通过）。

---

## P1 核心组件

| ID | 任务 | 主要改动位置 | 对应 Spec | 验收标准 | 依赖 |
| --- | --- | --- | --- | --- | --- |
| BK-FG-010 | 图标容器 `GlassIcon`：28/36/44 三档，squircle 近似圆角（×0.28），G1 材质，1.5px 线性图标，可选主题色 tint 变体；替换全应用功能性图标底座 | `app/lib/shared/widgets/glass_icon.dart`（新建）、各 feature 图标调用点 | §4.1 | 容器三件套（填充/双层描边/内高光）齐全；tint 变体参数正确 | P0 |
| BK-FG-011 | 按钮系统重构：`AppButton` 改玻璃材质，实现默认/hover/pressed/focus/disabled 五态参数矩阵（含 blur 20→24→16→8 变化、scale 0.98、内阴影）；主按钮改主题色着色玻璃 | `app/lib/shared/widgets/app_button.dart` | §4.4 | 五态参数逐项符合矩阵；主按钮非实色 | P0 |
| BK-FG-012 | 卡片与面板：`AppCard` 基于 `GlassPanel` G2 重建；嵌套升档规则；可点卡片复用 pressed 反馈 | `app/lib/shared/widgets/app_card.dart` | §4.5 | 卡片三件套 + 环境投影；嵌套不叠加 BackdropFilter | BK-FG-003 |
| BK-FG-013 | 选中态组件 `GlassSelection`：实现 FG-SEL 四层叠加（增亮/光晕/透明叠加层/高光描边），200ms 同步过渡，供列表项、Tab、导航项、表格行复用 | `app/lib/shared/widgets/glass_selection.dart`（新建） | §4.2 | AC-07：四层齐备、无实色填充 | P0 |

---

## P2 复合组件

| ID | 任务 | 主要改动位置 | 对应 Spec | 验收标准 | 依赖 |
| --- | --- | --- | --- | --- | --- |
| BK-FG-020 | 表格组件 `GlassTable`：G2 容器 + G3 表头 + 斑马纹（奇 0.45/0.10、偶 0.30/0.06，纯透明度、零 BackdropFilter）+ 行 hover + 行选中接 `GlassSelection` + 0.5px 内缩分隔线 | `app/lib/shared/widgets/glass_table.dart`（新建）、`features/reports`、`features/bills` 列表 | §4.3 | 斑马纹仅透明度区分；行级零 BackdropFilter（AC-06） | BK-FG-003、013 |
| BK-FG-021 | 导航与吸附层：吸顶 AppBar / 底部导航栏改 G3；滚动联动分隔线渐显；底部导航图标用 28 档 `GlassIcon`，选中项接 `GlassSelection` | 导航壳层（`app.dart` 及路由壳）、`app/lib/shared/widgets/` | §4.6 | 滚动时内容被实时柔化；分隔线行为符合 iOS 惯例 | BK-FG-003、010、013 |
| BK-FG-022 | 浮层与提示：`AppDialog`/`AppSheet` 改 G4 + scrim 遮罩；`AppSnack`/Toast 改 G5 胶囊；FAB 改 G5 着色玻璃；下拉与 `category_picker` 改 G4 | `app_dialog.dart`、`app_sheet.dart`、`app_snack.dart`、`category_picker.dart` | §4.7 | 各组件参数对档；遮罩 α0.32 | BK-FG-003 |
| BK-FG-023 | 输入框：`AppTextField` 改 G2 降档填充（0.45/0.10），聚焦环、错误环、禁用态 | `app_text_field.dart` | §4.8 | 三态参数符合规格 | P0 |

---

## P3 页面接入与双模式联调

| ID | 任务 | 范围 | 对应 Spec | 验收标准 | 依赖 |
| --- | --- | --- | --- | --- | --- |
| BK-FG-030 | 页面接入：全部 feature 页面（`bills` 记账流水、`quick_entry` 快速记账、`reports` 报表、`budgets`、`accounts`、`categories`、`calendar`、`recurring`、`settings`、`books`、`sync`、`backup`、`currency`、`auth_lock`、`auto_capture`）改用新组件，清除页面级私有样式与散写数值 | `app/lib/features/**` | §4 全量 | 页面无私有 blur/fill 字面量（AC-01 预检） | P1、P2 |
| BK-FG-031 | 深/浅双模式联调：逐页核验两模式下的层次、对比度、光晕可见性；主题切换 200ms 过渡无闪变 | 全应用 | §7、§9（设计文档） | AC-04：双模式截图走查通过 | BK-FG-030 |
| BK-FG-032 | 主题预设收敛：8 套预设主题差异收敛为「主题色 + 背景明暗」，玻璃参数全预设统一，不再各持一套玻璃 Token | `theme_presets.dart` | §2/§3 | 任一预设下玻璃参数一致 | BK-FG-031 |

---

## P4 验收与清理

| ID | 任务 | 产出 | 对应 Spec | 验收标准 | 依赖 |
| --- | --- | --- | --- | --- | --- |
| BK-FG-040 | 参数一致性扫描脚本：扫描 `BackdropFilter` σ ∈ {12,20,28,36,44}、fill/border/shadow 字面量、行级 BackdropFilter、`ambient` 残留 | `tool/` 下扫描脚本（接入现有检查流程） | §9 AC-01/02/06/08 | 扫描全绿 | P3 |
| BK-FG-041 | 对比度自动化验算：按 §7.1 合成底色公式复算全部层级 × 文字档组合，输出验算报告 | 验算脚本 + 报告 | §7.1、AC-03 | 全部 ≥ 4.5:1（大文字 3:1） | BK-FG-040 |
| BK-FG-042 | 性能采样：目标设备滚动帧率 ≥ 55fps，同屏 BackdropFilter ≤ 20 | 性能记录 | AC-06 | 达标 | BK-FG-040 |
| BK-FG-043 | 验收报告与文档归档：输出验收报告；docs 19/20/21 头部标注「已废弃，由 22/23/24 取代」 | `docs/25-iOS毛玻璃验收报告.md`（新建）、旧文档标注 | §9 全量 | AC-01~08 全绿 | BK-FG-040~042 |

---

## 里程碑

| 里程碑 | 内容 | 出口条件 |
| --- | --- | --- |
| M1 纯净基底 | P0 完成 | 旧玻璃零残留，纯净背景上线（AC-02/08 预检） |
| M2 组件就绪 | P1 + P2 完成 | 8 类组件全部玻璃化，五态/四层可演示 |
| M3 全量接入 | P3 完成 | 全页面双模式走查通过（AC-04/05 预检） |
| M4 验收交付 | P4 完成 | AC-01~08 全绿，验收报告归档 |

## 风险与对策

| 风险 | 对策 |
| --- | --- |
| 大量 BackdropFilter 导致低端机掉帧 | Spec §4.3 行级禁模糊；同屏 ≤20 硬上限；`GlassPanel` 内置降级开关（fill α +0.10 补偿） |
| 纯黑背景下投影不可见、层次变弱 | 深色模式描边 alpha 已上调（§3 表）；层次主要依赖 fill α 与内高光，不依赖投影 |
| 页面改造遗漏散写数值 | AC-01 扫描脚本作为合并门禁，不达标不入主干 |
| 选中态光晕在浅色背景上过弱 | 光晕 alpha 0.25 + 外缘主题色描边 0.30 双保险（§4.2），走查时单独核验 |
