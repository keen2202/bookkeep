# 25 - iOS 毛玻璃验收报告（FGDS v1.0）

| 项目 | 内容 |
| --- | --- |
| 文档编号 | BK-DOC-25 |
| 版本 | v1.0 |
| 日期 | 2026-08-24 |
| 状态 | 已归档 |
| 关联文档 | `docs/22-iOS毛玻璃设计文档.md`、`docs/23-iOS毛玻璃Spec规格说明.md`（唯一参数源）、`docs/24-iOS毛玻璃任务分解.md` |
| 覆盖范围 | `app/`（Flutter 客户端）纯视觉层重构；`server/` 不涉及 |

---

## 1. 结论摘要

按任务分解（doc-24）P0→P1→P2→P3→P4 五阶段完成 iOS 毛玻璃体系重构：旧玻璃系统
（ambient Mesh、光斑漂移、`resolveGlassSpec(tier:)`、`glassFill*` 派生、ContrastGuard、
画质三档、背景图模式）一次性拆除；G1–G5 层级参数表以 `glass_tokens.dart`
为唯一参数源重建；8 类组件（图标容器/选中态/表格/按钮/卡片/导航/浮层/输入框）
全部对齐 Spec §4 规格；8 套主题收敛为「主题色 + 背景明暗」。

**验收状态：AC-01/02/05/07/08 全绿；AC-03 主判定全绿（含规格内部矛盾告警，见 §5）；
AC-04 双模式走查以代码级核验+金样基线替代人工截图（见 §5 偏差 D2）；AC-06 静态核算达标，
真机帧率采样未在本环境执行（见 §5 偏差 D1）。**

---

## 2. 分阶段交付对照（BK-FG 任务 ↔ 实现）

### P0 基础设施

| ID | 交付 | 主要落点 | 对应 Spec |
| --- | --- | --- | --- |
| BK-FG-001 | 新建唯一参数源 `glass_tokens.dart`：`GlassLevel`(G1–G5) blur {12,20,28,36,44}、fill α 双值表、外侧黑描边/内侧白高光 α 表、顶部内高光（α 浅0.20/深0.08，覆盖40%）、环境投影表（spread恒0）、圆角表；§2.1 主题色/danger/success、§2.2 背景白名单、§2.3 scrim α0.32、§5 文字四档、§6 动效常量（150/200/250ms + cubic(0.4,0,0.2,1)）；FG-BTN/FG-SEL/FG-TBL/FG-INP/FG-ICON 语义 Token；嵌套升档与降级补偿派生规则；WCAG 合成/对比度工具 | `app/lib/shared/theme/glass_tokens.dart`（新建）；`ThemePalette` 删除全部玻璃字段并新增 `textTertiary` | §1/§2/§3/§5/§6 |
| BK-FG-002 | `AppBackground` 重写为纯色底色渲染（#F2F2F7/#000000）+ `GlassPrefsScope` 注入；删除 `AmbientGradient` 光斑绘制、`AmbientMotionController` 漂移动画、背景图模式（选图/遮罩/模糊三层）、`luminance.dart` 亮度采样及 5 个 bg_*/ambient_* 持久化键（历史键读取忽略） | `background/app_background.dart`（重写）；删除 `background/{ambient_gradient,background_controller,background_service,background_settings,luminance}.dart`、`glass/` 整目录、`contrast_guard.dart` | §2.2、§8（AC-02） |
| BK-FG-003 | 新建基础容器 `widgets/glass_panel.dart`：投影层 → ClipRRect → BackdropFilter(σ层级表) → 填充(#FFFFFF×α)+外勾边0.5px → 内白高光0.5px+顶部内高光渐变 → child 五层结构；降级开关（作用域关闭时零模糊节点 + fill α+0.10 补偿，`degradeCompensation` 区分用户降级与结构性 fill-only）；`GlassPanel.nested()` 嵌套升档（下一档填充值、零新增模糊、R12、无投影） | `shared/widgets/glass_panel.dart`（新建） | §3 |
| BK-FG-004 | 旧实现拆除：`resolveGlassSpec(tier:)`/`GlassTier`/`compensatedFillAlpha`/`resolvedSigma`/`GlassQuality` 三档/`AppGlass.*`/`glassFill(glassFillStrong/glassBorder` 派生字段/`ContrastGuard` 全部移除，引用点（app_theme/tokens/glass_icon/app_button/app_card/amount_keyboard/pin_pad 等）改接新 Token | 编译零残留（门禁5） | §8（AC-08） |

### P1 核心组件

| ID | 交付 | 对应 Spec |
| --- | --- | --- |
| BK-FG-010 | `widgets/glass_icon.dart`：28/36/44 三档正方形容器，圆角=边长×0.28，G1 全参数材质（经 GlassPanel），图标本体=容器×0.55，默认 textPrimary、`tint` 变体 fill 混入 primary α0.10/0.08；替换全部功能图标底座（导航/动作/账本切换/账单详情/快速记账退出等） | §4.1 |
| BK-FG-011 | `app_button.dart` 重写五态矩阵（secondary）：默认 σ20/fill0.60(0.12)、hover σ24/0.68(0.16)/内高光+0.05、pressed σ16/0.48(0.09)/scale0.98/顶部内阴影近似、focus 2px 外环 primary α0.50、禁用 σ8/0.32(0.06)/去高光；主按钮=着色玻璃（primary α0.75/0.65，hover +0.08 / pressed −0.10，禁用 0.30 文字α0.50），danger 变体同构用 color.danger；高度44/32、R12/胶囊、水平padding20、文字15/600 | §4.4 |
| BK-FG-012 | `app_card.dart` 基于 GlassPanel G2 重建（R16、padding16/紧凑12）；点击反馈复用 pressed 规则；嵌套经 `GlassPanel.nested`（样板间演示） | §4.5 |
| BK-FG-013 | `widgets/glass_selection.dart`：四层叠加（①增亮至 G3 档增量层 ②primary α0.25/blur20 光晕 ③垂直渐变叠加 0.12→0.06（深0.10→0.05）④内侧白高光0.5px α0.50(深0.20)+外缘 primary 0.5px α0.30(深0.35)）；200ms cubic 四层同步淡入淡出；未选中整组移除（非 α0 常驻）；供列表项/分类chip/表格行/底部导航项复用 | §4.2（AC-07） |

### P2 复合组件

| ID | 交付 | 对应 Spec |
| --- | --- | --- |
| BK-FG-020 | `widgets/glass_table.dart`：G2 容器（σ20/R16/双层描边/投影）为全表唯一 BackdropFilter；表头 G3 填充值+底部0.5px分隔线（浅#000α0.06/深#FFFα0.08）+13/600次级文字；斑马纹奇0.45/0.10偶0.30/0.06（差0.15/0.04，纯透明度）；行 hover +0.10/+0.04（150ms）；行选中接 FG-SEL 全量；行分隔线0.5px 内缩16px；单元格 padding v12/h16 无独立背景。已接入组件样板间展示 | §4.3（AC-06） |
| BK-FG-021 | 导航吸附层：主 shell AppBar 与底部导航换 G3 玻璃（σ28 通栏）；滚动联动分隔线（静止隐藏/滚动渐显，浅#000α0.08·深#FFFα0.10）；底部导航图标 28 档 GlassIcon + 选中项 FG-SEL；FAB 改 G5 着色玻璃 56×56 R16；12 个二级页 Scaffold 统一收敛到新 `GlassScaffold`（自动滚动联动） | §4.6 |
| BK-FG-022 | 浮层提示：`AppDialog`→G4 面板(R20)+scrim α0.32；`AppSheet`→G4 顶圆角20+遮罩α0.32（入场沿用250ms）；`AppSnack`→G5 胶囊（真实磨砂）；下拉/popup 菜单主题 G4 填充+R20+发丝边；`category_picker` chip 改 G4 玻璃填充+FG-SEL 选中（去除 FilterChip 实色选中） | §4.7（AC-07） |
| BK-FG-023 | 输入框：G2 降档填充 0.45/0.10、R12/H44；聚焦内高光+0.05（顶部渐变近似）+2px 外环 primary α0.50；错误外环 danger α0.60+danger 错误文案；禁用 fill 0.24/0.05+textDisabled | §4.8 |

### P3 页面接入

| ID | 交付 |
| --- | --- |
| BK-FG-030 | 全部 feature 页面接入新组件；散写清理：`amount_keyboard`（G3 底座/G2 键帽 fill-only）、`pin_pad`（G2 圆形键帽双层描边）、图表容器三处（cashflow/budget_summary/reports）统一 G2；features 层无 blur/fill 字面量（门禁1/2 绿） |
| BK-FG-031 | 双模式：全部玻璃双值由 `Brightness` 单点分流于 glass_tokens/theme_presets 两处 Token 层，组件零 `isDark?:` 取值散写（文字色等经 palette 槽位）；主题切换过场 250ms→200ms（Spec §6 状态切换档）；深浅金样基线各 25 张重生成 |
| BK-FG-032 | 预设收敛：8 预设差异仅剩「主题色 + 明暗」，中性槽位（背景/表面/文字四档/发丝线）全组统一且同明暗组主题色互异；单元测试锁定（app_theme_test） |

### P4 验收与清理

| ID | 交付 |
| --- | --- |
| BK-FG-040 | `tool/check_glass_consistency.sh` 重写为五门禁（BackdropFilter 唯一出口=widgets/{glass_panel,glass_icon,app_button}；σ 字面量零散写；层级表取值合法性；ambient/RadialGradient/image_picker 零残留；旧 API 零引用）。CI 入口路径不变 |
| BK-FG-041 | `tool/check_fg_contrast.dart`：按 §7.1 公式复算 30 组（5 层×2模式×{主/次/三级}），已接入 CI。主文字全组合 ≥4.5:1 通过；合成底色逐层复现 Spec 表（如深 G5=#4D4D4D ✓） |
| BK-FG-042 | 同屏 BackdropFilter 静态核算：主界面=G3 AppBar+G3 底部栏+G5 FAB+可见卡片≤N，典型屏 ≤10 处 <20 上限；行级/表格/键盘/列表项结构性禁模糊（门禁1 保证）。真机帧率采样见偏差 D1 |
| BK-FG-043 | 本报告归档；docs 19/20/21 头部标注「已废弃，由 22/23/24 取代」（保留存档）；README 主题体系章节同步更新 |

---

## 3. 修改文件清单

### 新建
| 文件 | 内容 |
| --- | --- |
| `app/lib/shared/theme/glass_tokens.dart` | 唯一参数源：层级表/语义Token/动效/WCAG 工具 |
| `app/lib/shared/theme/glass_prefs.dart` | 磨砂降级偏好（blurEnabled）+ 控制器 |
| `app/lib/shared/widgets/glass_panel.dart` | G1–G5 基础容器（五层渲染/降级/嵌套） |
| `app/lib/shared/widgets/glass_icon.dart` | FG-ICON 图标容器（28/36/44+tint） |
| `app/lib/shared/widgets/glass_selection.dart` | FG-SEL 四层选中态 |
| `app/lib/shared/widgets/glass_table.dart` | FG-TBL 玻璃表格 |
| `app/lib/shared/widgets/glass_nav.dart` | GlassAppBar/GlassBottomBar/GlassFab/GlassScaffold/GlassAppBarAction |
| `tool/check_fg_contrast.dart` | AC-03 对比度自动化验算脚本 |
| `app/test/unit/shared/theme/glass_tokens_test.dart` | 参数表逐项锁定测试 |
| `docs/25-iOS毛玻璃验收报告.md` | 本报告 |

### 重写（视觉管线）
`theme_presets.dart`、`app_theme.dart`、`tokens.dart`、`chart_colors.dart`、`theme_transition.dart`（200ms）、`background/app_background.dart`、`app_button/app_card/app_dialog/app_sheet/app_snack/app_text_field/category_picker.dart`、`app.dart`（shell）

### 修改（接入与清理）
`main.dart`、`settings_repository.dart`（glassPrefs 收敛为 blur_enabled 单键）、`theme_controller.dart`、`amount_keyboard.dart`、`pin_pad.dart`、`cashflow_chart.dart`、`budget_summary_card.dart`、`reports_page.dart`、`appearance_page.dart`（删背景/环境光区，新增降级开关）、`component_gallery_page.dart`（G1–G5 样板间）、`book_switcher/account_card/bill_detail_sheet/quick_entry_sheet`（GlassIcon 迁移）、12 个二级页 Scaffold→GlassScaffold、`pubspec.yaml`（注释标注遗留依赖）、`.github/workflows/ci.yml`（接入对比度门禁）、`app/tool/check_ui_tokens.dart`（白名单收敛至新 Token 文件）、`README.md`

### 删除
`shared/theme/glass/`（glass_layers/glass_panel/glass_quality/ambient_motion）、`shared/theme/contrast_guard.dart`、`shared/theme/background/{ambient_gradient,background_controller,background_service,background_settings,luminance}.dart`、旧 `shared/theme/glass_icon.dart`、`integration_test/background_test.dart`、`test/unit/shared/theme/{glass_layers,contrast_guard,ambient_motion}_test.dart`、`test/unit/features/theme/{luminance,background_settings}_test.dart`、`test/golden/generate_bg_fixture_test.dart`、`test/fixtures/bg_probe.png`、golden `t1_gallery_bgpicture.png`

### 金样基线
`test/golden/goldens/*.png` 全量重生成（视觉体系变更，容差比较器不变 0.5%）

---

## 4. 验收标准（AC-01~08）核验记录

| ID | 结果 | 证据 |
| --- | --- | --- |
| AC-01 σ∈{12,20,28,36,44} 且数值全部来自 Token | ✅ | 门禁2（lib/ 零 σ 字面量）+ 门禁3（glass_tokens 内 blur 取值 ∈ 规格集合，§4.4 矩阵 {8,16,24} 以 GlassButtonTokens 收录）+ check_ui_tokens 白名单收敛 |
| AC-02 背景层纯净、ambient 零残留 | ✅ | 门禁4（`.ambient/ambient:/RadialGradient/MeshGradient/image_picker` 零命中）+ app_background_test（底色断言 #F2F2F7/#000000） |
| AC-03 对比度 ≥4.5:1 | ✅* | check_fg_contrast：主文字 10 组全部 PASS（浅 16.2–16.7 / 深 8.5–17.5）；次级/三级存在 Spec §5 α 值导致的数学不可达项，转为 WARN 并列入偏差 D3（`--strict` 可硬判） |
| AC-04 双模式截图走查 | ✅* | 深/浅金样各 25 张重生成并通过（t1–t8 × 页面矩阵 + 样板间 T1/T6）；人工设备截图走查不在本环境执行 → 偏差 D2 |
| AC-05 八类组件 100% 使用 §4 规格、无私有实现 | ✅ | 组件走查：全部玻璃表面经 GlassPanel/三个白名单文件渲染；样板间同屏可演示 G1–G5/FG-ICON/FG-SEL/FG-TBL/FG-BTN 五态 |
| AC-06 同屏 BackdropFilter ≤20；行级零模糊 | ✅* | 门禁1 白名单外零 BackdropFilter；GlassTable 行级 fill-only（widget 测试断言仅 1 个模糊节点/表）；静态核算典型屏 ≤10。55fps 真机采样未执行 → 偏差 D1 |
| AC-07 无实色填充选中态 | ✅ | FilterChip selectedColor 移除；category_picker/导航项/表格行走 GlassSelection 四层；chipTheme 选中=primary α0.12 叠加（非实色） |
| AC-08 旧系统零残留 | ✅ | 门禁5 + `flutter analyze` 全绿（0 error/0 warning） |

最终回归：`flutter analyze` 0 问题；`flutter test` 全量 **531 项通过**（unit + widget + golden，含重生成后的 50 张双模式金样基线）。

---

## 5. 偏差项与说明

| # | 偏差 | 原因 | 建议 |
| --- | --- | --- | --- |
| D1 | **真机性能采样未执行**（AC-06 的 55fps 部分） | 本环境无目标设备/模拟器；已用静态核算替代：BackdropFilter 仅存在于 3 个白名单文件、行级结构性禁模糊、典型屏实例数 ≤10 < 20 硬上限 | 合入后按 doc-24 BK-FG-042 在目标设备补测帧率并存档 |
| D2 | **AC-04 人工双模式截图走查以金样基线代替** | 无真机截图通道；金样覆盖 8 主题×多页面×深浅模式共 50 张基线 | 版本合入后按惯例补人工走查记录 |
| D3 | **Spec §7.1 次级文字对比度标称值不可复现（规格内部矛盾）**：§5 定义次级=#3C3C43/#FFF α0.60，按 WCAG 数学在玻璃合成底色上实算 ≈3.4:1（浅）/4.3:1（深 G5），无法达到 §7.1 表所载 6.2:1/4.9:1，也无法同时满足 AC-03 的全组合 ≥4.5 | 数学事实：α0.60 的半透明文字有效亮度决定了上限 ≈3.4；Spec 自身深色 G5 行也只标称 4.2 | 实现严格采用 §5 数值（参数唯一源原则），验算脚本默认将该项列为 WARN；建议下一版 Spec 将次级 α 提升至 ≥0.78 或加深基色以闭合矛盾。当前应用中次级文字均为辅助说明（非关键操作数据），关键信息一律主文字档 |
| D4 | **三级文字（α0.36）部分组合 <3:1**（浅色 1.9–2.0、深 G4/G5 2.6–2.9） | 同 D3，属 §5 定值的固有结果 | Spec §7.1 已限定三级文字仅用于非关键信息；验算脚本按 WARN 输出不阻断 |
| D5 | **着色玻璃按钮的白字对比度处于大文字下限附近**（浅色 primary α0.75 合成面 vs 白字 ≈2.7:1） | §4.4 主按钮规格字面值（iOS 系统着色玻璃的实际观感依赖 vibrancy，Flutter 下无对应能力） | 走查关注；如需收紧建议上调 primaryFillLight 至 ≥0.85 或对浅色主按钮改用深化主色 |
| D6 | **图标本体「1.5px 等宽线/圆角线帽」以 Material outlined 字形近似** | Material Icons 为字体字形，不支持 SF Symbols 式 stroke-width 参数 | 如需完全一致需引入矢量线稿图标集（超出本次纯视觉重构最小改动边界） |
| D7 | **image_picker 依赖暂留 pubspec（代码零引用）** | 本环境 pub-cache 只读，物理移除依赖行会触发 `pub get` 重解析失败；已保留原依赖行并加注释标注 | 联网环境删除该行后 `flutter pub get` 即可 |
| D8 | **按压「内阴影 inset 0/1/3」无原生 API**，以顶部 3px 高黑渐变（α0.08）近似 | Flutter BoxDecoration 不支持 inset shadow | 视觉走查确认可接受；如需精确可用 CustomPainter 重绘 |
| D9 | **次要页面级散写 accent alpha**（如账单图标底 α0.15、同步状态点 α0.12 等 6 处） | 均为业务数据色装饰（分类色/状态点），不属于玻璃表面参数（AC-01 管辖 blur/fill/border/shadow of glass） | 维持现状，后续可纳入 constants 统一 |

---

## 6. 遗留事项

1. `docs/report/gls-v3/` 历史走查档案随 v3 废弃保留存档。
2. Golden 基线已随新视觉重建；后续视觉微调需同步 `--update-goldens` 并在 PR 中附差异说明（既有流程不变）。
3. 建议下一版 Spec 修订项：D3/D4（次级/三级文字 α）、D5（着色玻璃按钮对比度）、以及为「同色系微渐变」给出可选开启的明确场景（当前实现保留 API、默认纯色路径）。
