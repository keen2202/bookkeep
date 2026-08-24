# 20 - 玻璃拟态全链路 Spec 规格说明（Glassmorphism v3）

| 项目 | 内容 |
| --- | --- |
| 文档编号 | BK-DOC-20 |
| 版本 | v1.1（2026-08-24 评审修订） |
| 日期 | 2026-08-24 |
| 状态 | 待评审 → 实施中 |
| 设计依据 | `docs/19-玻璃拟态全链路设计文档.md` v1.1（章节号 § 对应其内文） |
| 任务拆解 | `docs/21-玻璃拟态全链路任务分解.md`（BK-GLS-000~020） |
| 适用范围 | `app/`（Flutter SDK ≥3.19，Riverpod 2.6）；`server/` 不涉及 |

**v1.1 修订摘要**：§2.1 深色描边改为实值（0.16–0.24）并新增 §2.4 参数推导与对比度验算；§2.3 画质档填充补偿表；§3 GlassPanel 实现细则（Clip.hardEdge、banding 防线、ForegroundDecoration 成本论证）；§4.4 光斑软化分档与漂移澄清；§4.6 背景图模式专项；§4.7 ContrastGuard 对比度联动算法；§5 图表 innerSheen；§9 AC-06 性能测量方法细化；§10 Golden 覆盖策略扩展；新增附录 A 变更影响文件清单。

---

## 1. 总体架构

### 1.1 分层与新增文件

```
features/*（15 个业务模块：只消费 GlassPanel / Token / 组件，禁止自绘玻璃）
shared/widgets/
  ├─ app_card.dart        AppCard → 内部改用 GlassPanel（API 兼容）
  ├─ app_button.dart      新增 glass 变体 + hover/focus 态
  └─ app_text_field.dart  focus 光晕包装
shared/theme/glass/                          ← 新增子目录
  ├─ glass_layers.dart     GlassTier 枚举 + GlassSpec + resolveGlassSpec()
  ├─ glass_panel.dart      GlassPanel（L1–L4 通用玻璃容器）
  ├─ glass_quality.dart    GlassQuality 三档 + provider + 持久化
  └─ ambient_motion.dart   AmbientMotionController + AmbientRouteObserver
shared/theme/background/
  └─ ambient_gradient.dart 改造：4 光斑 + 分档软化 + 动效接入（文件名不变）
shared/theme/
  ├─ tokens.dart           AppGlass 重写为层级函数消费端
  ├─ theme_presets.dart    ambient 扩为 4 色；T5/T7/T8 提亮；glass 系字段派生化
  ├─ contrast_guard.dart   ContrastGuard（对比度联动，新增）
  └─ app_theme.dart        组装器接入层级函数；组件主题玻璃化
tool/check_glass_consistency.sh               ← 一致性门禁脚本（新增）
```

### 1.2 关键决策

| # | 决策点 | 结论 | 理由 |
| --- | --- | --- | --- |
| D1 | 分层实现方式 | `GlassPanel` 单组件承载 L1–L4，内部按 tier + quality 决定是否包 `BackdropFilter` | 一个出口保证一致性；降级只改一处 |
| D2 | L1 列表性能 | 列表行级元素 fill-only；整卡容器在「高保真」档才启用 σ10 | 长列表滚动零回归（v2 §10 决策延续） |
| D3 | inset 高光映射 | CSS `inset box-shadow` → ForegroundDecoration 顶部 LinearGradient + solidLine 降级 flag | Flutter 无 inset shadow 原生物；渐变可 golden 化；色带风险有单点降级开关 |
| D4 | 动效驱动 | 单 `AmbientMotionController` + RepaintBoundary 内 CustomPainter 重绘光斑；RouteObserver 发脉冲 | 不重建 Widget 树；成本锁死在背景层 |
| D5 | 玻璃 Token 演进 | `ThemePalette.glassBorder/glassFill/glassFillStrong` 字段保留为派生值，新代码一律走 `resolveGlassSpec()` | 存量零破坏，增量收敛有唯一入口 |
| D6 | 画质档默认值 | 默认「标准」档 | 兼顾主流机型流畅度与视觉上限 |
| D7 | 持久化 | 复用 app_meta 键值 + settings_repository 注入链路，不建表 | 与主题/背景设置同构 |
| D8 | 参数冻结流程 | 全部视觉常量先经 BK-GLS-000 原型小样实测（含 banding 探针、描边 A/B、ContrastGuard 系数校准），回填本 Spec 后冻结 | 评审意见 #1/#2：避免纸面参数直接进实施 |

---

## 2. 玻璃层级规格（glass_layers.dart）

### 2.1 层级参数总表

```dart
enum GlassTier { panel, dock, overlay, floating } // L1..L4
```

**基础档（high）取值：**

| Tier | 语义 | 填充 α（浅·白基） | 填充 α（深·surface 基） | blur σ | 描边白 α（浅） | 描边白 α（深） | 高光 α_top（浅/深） | 阴影缩放 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| panel (L1) | 卡片/图表容器/分组容器 | 0.55 | 0.66 | 10 | 0.20 | **0.16** | 0.25 / 0.10 | ×1.0 |
| dock (L2) | 底部导航栏/吸顶栏/FAB 区 | 0.65 | 0.72 | 16 | 0.22 | **0.18** | 0.28 / 0.11 | ×1.2 |
| overlay (L3) | 弹窗/底部弹层/下拉菜单 | 0.75 | 0.80 | 28 | 0.25 | **0.20** | 0.30 / 0.12 | ×1.5 |
| floating (L4) | SnackBar/Toast/Tooltip | 0.85 | 0.86 | 36 | 0.30 | **0.24** | 0.33 / 0.13 | ×1.8 |

规则：

- 深色主题填充色 = `palette.surface`（带主题色温）× 表内 α，非纯黑；
- 描边宽度恒 **1**（逻辑像素），颜色恒白色系；浅色 L1 = `Color(0x33FFFFFF)` 即需求给定基准 rgba(255,255,255,0.2)；
- 三参数（σ / 填充α / 描边α）随层级严格单调递增——单元测试锁定；
- **描边可见性下限**：任一层「描边合成色 vs 内侧填充合成色」的 WCAG 相对亮度对比度 ≥ **1.5:1**（装饰性线条内部规范，非文字 AA），单元测试锁定（§2.4 给出验算示例）。

### 2.2 解析函数

```dart
class GlassSpec {
  final Color fill;            // 已按 brightness/quality/imageMode 解析的填充色
  final double sigmaX, sigmaY; // quality 归零规则见 §2.3
  final Color borderColor;     // 白 × 层 alpha × 明暗系数（深色用 §2.1 实值）
  final Gradient topHighlight; // ForegroundDecoration 用
  final List<BoxShadow> shadows;
}

GlassSpec resolveGlassSpec({
  required GlassTier tier,
  required Brightness brightness,
  required ThemePalette palette,
  required GlassQuality quality,
  bool imageBackgroundMode = false, // §4.6 L1 加厚
})
```

### 2.3 画质三档（glass_quality.dart）

| GlassQuality | σ 行为 | 填充补偿（叠加于 §2.1 基础值） | 环境光 |
| --- | --- | --- | --- |
| `high` | 全部层级真实磨砂，σ 按表 | 无补偿 | 正常 |
| `standard`（默认） | L1/L2 σ=0（fill-only），L3/L4 真实按表 | 浅色 L1 +0.06 / L2 +0.03；深色 L1 +0.04 / L2 +0.02 | 正常（光斑软化曲线生效，§4.4） |
| `saver` | 仅 L3/L4 且 σ×0.6 | 浅色 +0.08/+0.06/+0.02/+0.02；深色 +0.08/+0.06/+0.02/+0.02（L1→L4） | 强制静止 |

持久化键 `glass_quality`（string：`high|standard|saver`），缺失默认 `standard`。
背景图模式下 L1 追加 +0.06（上限 0.80），见 §4.6。

### 2.4 参数推导逻辑与验算（评审意见 #2 回应）

**推导原则**：σ 与描边 α 以「物理隐喻」外推——模糊半径随深度近似线性（10→36），描边亮度跟随「离观察者越近受光越足」；填充 α 由可读性反推（每层的最差文字场景经 ContrastGuard 校验后取最小可行值的向上取整档）。表格值为规范源（canonical），公式仅用于解释单调性与新层扩展：

```
sigma(t)        ≈ 10 · 1.8^t                     (t=0..3 → 10,18,32.4… 取整至 10/16/28/36)
borderAlphaLight(t) = 0.20 + 0.033t             (0.20/0.23→0.22/0.27→0.25/0.30 规范化)
darkFactor      = 实测标定，非固定系数（见下）
```

**深色描边实值标定过程**（回应「×0.6 可能过弱」）：以 T5 石墨·夜（提亮后 bg `#13171C`、surface `#1A1E24`）、standard 档 L1 为 worst case：

1. 填充合成色 = surface(0.70) over background(0.30) → `#181C22`，相对亮度 L_fill ≈ **0.0114**；
2. 若按旧方案 ×0.6 得描边 α=0.12：合成色 `#34373C`，L≈0.0380，对比度 (0.088)/(0.0614) ≈ **1.44:1 < 1.5 下限 → 否决**；
3. 取 α=0.16：合成通道 R=255×0.16+24×0.84≈61 → `#3D4045`，L_border≈0.0509，对比度 ≈ **1.64:1 ✓**；
4. 依此法逐层标定得 0.16/0.18/0.20/0.24（更高层因填充更亮，同 α 对比度略降，故阶梯上移）。

> 以上为线性 RGB 合成 + WCAG 相对亮度公式的手工验算记录；BK-GLS-000 在真机复核，若实测观感偏弱允许 L1 上调至 0.18（仍需过 1.5:1 测试与走查）。浅色主题白描边在近白填充上增量有限属预期行为——轮廓定义由阴影+顶部高光+光斑边缘色差承担，A/B 小样不过关时启用 `borderBoost`（浅色 L1 0.20→0.32）备选参数。

---

## 3. GlassPanel 组件（glass_panel.dart）

```dart
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.tier = GlassTier.panel,
    this.borderRadius,                 // 默认 AppRadius.mdAll（L3 弹层传 lg）
    this.onTap,
    this.padding,
    this.colorOverride,
    this.blurOverride,
    this.innerSheen = false,           // 图表容器专用底部微反光（§5.4）
  });
}
```

### 3.1 行为规格

1. 渲染顺序：`ClipRRect → BackdropFilter(σ) → Container(fill+border+shadows) → ForegroundDecoration(topHighlight[, innerSheen]) → child`；
2. σ=0 时跳过 ClipRRect+BackdropFilter 直接渲染（standard 档 L1/L2 主路径，零 saveLayer）；
3. `onTap != null` 按压态：填充叠加 scrim α0.04（150ms）；hover 态（MouseRegion）：描边 α+0.08、高光 +0.05（120ms easeOut）；
4. 阴影按 §2.1 缩放系数生成。

### 3.2 实现细则与陷阱（评审意见 #8 回应）

- **BackdropFilter 必须双保险裁剪**：`BackdropFilter(clipBehavior: Clip.hardEdge)` + 外层 `ClipRRect(borderRadius)`。原因：BackdropFilter 的采样默认不裁剪（`Clip.none`），圆角矩形外侧会溢出模糊光晕（Flutter 已知渲染问题）；hardEdge 保证矩形边界不溢出，圆角由 ClipRRect 承担（BackdropFilter 自身 clipBehavior 不支持圆角形状）。二者缺一不可，widget 测试断言节点结构；
- **术语约定**：表内 σ 为 `ui.ImageFilter.blur(sigmaX/sigmaY)` 直取值；CSS `blur(r)` 近似对应 sigma r/2，仅供跨团队沟通换算，不做渲染承诺；
- **ForegroundDecoration 开销评估**：仅新增一次带 shader 的 drawRect，无 saveLayer、无独立图层；视口面板 ≤8 时净增 <0.1ms。列表行不使用 GlassPanel，无批量叠加路径；
- **色带防线**：渐变 stop 间隔 ≥0.15；同一区域半透明渐变层数 ≤2；Impeller 后端自带梯度抖动；样板间设「色带探针」展项（纯黑底放大高光条）；真机可见色带时置 `glassHighlightStyle=solidLine`（1px α_top 实线 + 1px 半强线替代渐变），实现为 `resolveGlassSpec` 内单点分支。

---

## 4. 环境光动效（ambient_motion.dart + ambient_gradient.dart 改造）

### 4.1 数据模型

- 光斑数：4（补齐第 4 色，预设变更见 §6.2）；blob 参数 `(color, anchorAlignment, baseSizeW, baseSizeH, orbitPhase)`；orbit 椭圆半轴 = 尺寸 × (0.06, 0.04)。

### 4.2 控制器

```dart
class AmbientMotionController {
  /// Ticker 驱动，周期 36s/blob（相位错开 90°）
  /// 位置 = anchor + orbit · sin/cos(2π·phase + phaseOffset)
  void pulse({required Offset direction});   // push/pop：+3% 位移，600ms easeOutCubic 回弹
  void breathe();                            // Tab 切换：强度 ×0.5→1.0，500ms
  void pause();  void resume();
}
```

- 触发源：`AmbientRouteObserver extends NavigatorObserver`（didPush/didPop → pulse）；Tab 切换由 shell 回调 breathe()；秒开入口同样挂 observer；
- 渲染：AnimatedBuilder → `_AmbientPainter`（CustomPainter），仅重绘 L0 RepaintBoundary；
- 关闭条件（任一即静止于初始相位）：`disableAnimations`、quality==saver、设置关动效、App 后台、锁定态、背景图模式（脉冲部分见 §4.6）。

### 4.3 设置项与持久化

| 键 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `ambient_motion_enabled` | bool | true | 总开关 |
| `ambient_intensity` | string(`soft|standard|rich`) | standard | 光斑强度系数 0.60/0.85/1.10 |
| `ambient_nav_pulse` | bool | true | 页面切换脉冲（环境光渐变模式） |

### 4.4 分档软化曲线（评审意见 #2/#3 回应）

| 画质档 | blob 衰减 stops（alpha × 强度系数 I） | 目的 |
| --- | --- | --- |
| high | `[0.95I @0, 0 @1]` 两段急衰减 | L1 有真实磨砂，blob 保持「聚光」 |
| standard | `[0.95I @0, 0.45I @0.55, 0 @1]` 三段缓衰减 | 「把模糊烘焙进渐变」，fill-only 下无硬边 |
| saver | 同 high | 静止画面，无需软化 |

**漂移 × 模糊不适问题澄清**：环境光路径没有独立模糊 pass（软化内建于渐变），漂移只是软渐变整体平移，不存在模糊半径变化；图像路径 8px 模糊作用于静态图且 σ 恒定，遮罩呼吸默认关 → 均无呼吸式胀缩感。

强度设置乘算 blob alpha；后备手段：若 BK-GLS-000 判定标准档 L1 边缘仍生硬，光斑数 4→5（更小更密重叠羽化）。

### 4.5 ContrastGuard 对比度联动（contrast_guard.dart，评审意见 #4 回应）

```dart
/// 最坏情况卡片底色：
///   blobUnderCard = composite(background, brightestBlob × (0.95 × intensity × 0.85))
///   cardWorst     = composite(blobUnderCard, glassFill)
/// 判定：contrast(textPrimary, cardWorst) ≥ 4.5（正文）/ ≥ 3.0（displayAmount 大金额）
/// 不满足：intensity 逐级钳制 rich→standard→soft；仍不满足再对当前场景 fill +0.05（运行时，不写盘）
class ContrastGuard {
  static AmbientIntensity effectiveIntensity({required ThemePalette palette, required AmbientIntensity requested});
  static double extraFillAlpha({...}); // 钳制后的兜底增量
}
```

- 系数 0.85（光斑中心透过玻璃的残余可见度）为经验值，BK-GLS-000 实测校准后冻结；
- 用户感知：外观页强度选项旁显示「已自动限制强度以保持对比度」徽标（clamp 生效时）；
- 锁定态金额脱敏优先级最高，不受本机制影响；
- 测试锁定：8 预设 × {soft, standard, rich} × 浅深两态共 48 组合达标（单元测试）；新增预设/强度档必须先过此门。

### 4.6 背景图模式专项（imageBackgroundMode=true）

| 项 | 行为 |
| --- | --- |
| 光斑 Mesh | 隐藏（图即光环境，v2 既定） |
| pulse/breathe | 默认关闭；用户可在设置手动开启（开启时作用于遮罩明度 ±2% 微呼吸） |
| L1 填充 | 在画质档补偿之上再 +0.06，上限 0.80 |
| 描边/高光/σ 体系 | 不变（跨模式语言一致） |
| 可读性 | 智能遮罩闭环沿用 `luminance.dart`；关闭模糊时闭环自动提高遮罩 alpha |

### 4.8 背景纯色禁令

全部预设与 custom 派生路径：background ≠ 纯黑/纯白且相对亮度 ∈ (0.01, 0.99)；T5/T7/T8 提亮见 §6.2。单元测试锁定。

---

## 5. 组件主题玻璃化（app_theme.dart 组装器）

### 5.1 ThemeData 变更清单

| 组件主题 | v3 规格 |
| --- | --- |
| `cardTheme` | color: `resolveGlassSpec(panel).fill`；side: L1 描边；clip antiAlias |
| `navigationBarTheme` | backgroundColor: L2 fill；未选中 label/icon textSecondary |
| `bottomSheetTheme` | backgroundColor: L3 fill；modalBarrier scrim α0.54 不变 |
| `dialogTheme` | backgroundColor: L3 fill |
| `snackBarTheme` | backgroundColor: L4 fill |
| `inputDecorationTheme` | fillColor 浅 `0x1FFFFFFF` / 深 `0x0FFFFFFF`；focusedBorder primary 2px；focus 光晕由 AppTextField 外层 AnimatedContainer 提供（primary α0.18 blur12，180ms） |
| `dropdownMenuTheme`/`menuTheme` | 容器 L3 fill + 描边；elevation 0（阴影归 GlassPanel） |
| `checkboxTheme`/`switchTheme` | 未选侧 L1 fill + 描边；选中侧语义色实心不变 |
| `chipTheme` | 未选 L1 fill；选中 primaryContainer α0.70 |
| `sliderTheme` | inactive divider α0.5 / active primary；拇指白芯 1px 描边 |
| `iconTheme` | 默认 outline pack（沿用 IconPack 机制确认默认值） |

### 5.2 AppButton.glass 变体

```
AppButton(variant: AppButtonVariant.glass)
├─ 背景：L2 spec.fill + BackdropFilter（仅 high 档）+ topHighlight
├─ 主操作着色：primary α0.90（onPrimary 前景）
├─ hover：描边 α+0.08 / 高光 +0.05（120ms）
├─ focus：primary 2px ring + primary α0.18 blur8 外晕（150ms）
└─ press：scale 0.96 + 填充 scrim +0.08（150ms，复用 v2 Listener+AnimatedScale）
```

既有四变体保留并升级：primary → 品牌色玻璃、secondary → 中性玻璃、danger → expense α0.90 玻璃、text 不变。

### 5.3 图标

`GlassIcon` 填充/描边改读 `resolveGlassSpec(panel)`（旧常量保留兼容）；导航未选中线性图标 textSecondary，选中项允许实心 + primary。

### 5.4 图表容器（评审意见 #5 回应）

- 报表三图 / 现金流趋势图 / 预算进度条容器统一 `GlassPanel(tier: panel, innerSheen: true)`；
- `innerSheen`：容器底部 4% 白自下而上微渐变（玻璃厚度反光），单 drawRect，任何画质档恒开——这是标准档图表玻璃感的三支柱之一（另两柱：§4.4 软化光斑 + §2.3 填充补偿）；
- 网格线 `palette.divider` α0.5（刻度清晰度不受档位影响）；柱/折线下方语义色 α0.12→0 渐变（「光透过图表」主承载）；
- 分类色序列由 `chart_colors.dart` 从 `palette.ambient + semantic` 派生（锁定测试防漂移）。

---

## 6. 主题预设变更（theme_presets.dart）

### 6.1 结构性变更

`ThemePalette.ambient` 约定扩为 4 元素；`glassFill/glassFillStrong/glassBorder` 字段保留但 getter 化派生值（兼容旧调用）。

### 6.2 取值变更表

| 预设 | 变更 | 新值 |
| --- | --- | --- |
| T5 石墨·夜 | background 提亮 | `#0F1215 → #13171C` |
| T5 石墨·夜 | ambient 补第 4 色 | `#3E4A57`（青灰） |
| T6 深海·蓝 | ambient 补第 4 色 | `#1B6E8C` |
| T7 墨竹·绿 | background `#0C1210 → #101713`；ambient 补 `#2E6E34` | — |
| T8 绛紫·夜 | background `#110C1B → #171126`；ambient 补 `#6E2A8C` | — |
| T1–T4 浅色 | ambient 各补第 4 色（右上锚位同族浅色） | BK-GLS-004 checklist 定值 |
| 全部 | glass 系字段退役为 §2 函数派生值 | — |

约束：所有改动后 `textPrimary/background` 对比度 ≥ WCAG AA（既有锁定测试扩展到新值）。

---

## 7. 外观页个性化 UI（appearance_page.dart）

新增两组设置（控件本身已玻璃化）：

```
玻璃质感
├─ 画质            [高保真 | 标准 | 省电]   （即时生效）
└─ 说明文案         「省电模式将关闭环境光动效并降低弹层模糊」

环境光
├─ 动态漂移         Switch（默认开；disableAnimations 时禁用置灰）
├─ 光斑强度         [含蓄 | 标准 | 浓郁] （旁注：「已自动限制强度以保持对比度」徽标当 clamp 生效）
└─ 页面切换位移      Switch（默认开；背景图模式下默认关并可手开）
```

样板间（component_gallery_page.dart）新增展区：①玻璃层级（L1–L4 同屏+参数标注）；②交互状态矩阵（hover/focus/press）；③环境光演示（脉冲触发/暂停）；④色带探针（黑底放大高光条）。

---

## 8. 一致性门禁

### 8.1 唯一出口规则

feature 层违规判定（code review + CI grep 双重把关）：

- 自建 `BackdropFilter`（唯一合法处：`shared/theme/glass/glass_panel.dart`、`shared/theme/glass_icon.dart`、`shared/theme/background/app_background.dart`）;
- 直接引用 `AppGlass.fillLight/fillDark/borderLight/borderDark`（改用 `resolveGlassSpec`）；
- 卡片类自绘 `BoxDecoration` 含白色系 `Border.all`。

### 8.2 门禁命令（CI 可执行）

```bash
grep -rn "BackdropFilter(" app/lib --include="*.dart" \
  | grep -v "shared/theme/glass/\|shared/theme/glass_icon.dart\|shared/theme/background/"
# 输出非空 → fail
grep -rn "AppGlass\.fill\|AppGlass\.border" app/lib/features --include="*.dart"
# 输出非空 → fail
```

### 8.3 迁移走查清单

存量散点（预估 ≤12 处）：`account_card`、`budget_progress_bar`、`budget_summary_card`、`calendar_page` 日格、`amount_keyboard` 键帽、`pin_pad`、`book_switcher`、`bill_detail_sheet` 等，逐处收敛到 GlassPanel/Token；完整文件清单见附录 A，任务 BK-GLS-010 逐项打钩。

---

## 9. 验收标准（逐条对应用户四大需求）

### AC-01 通透层次体系

- [ ] L1–L4 参数落地且 σ/填充α/描边α 三参数随层级单调递增（`glass_layers_test`）；
- [ ] 样板间同屏展示四层差异，BK-GLS-000 后人工走查通过（截图归档 `docs/report/gls-v3/`）；
- [ ] 导航栏滚动内容穿透呈现真实磨砂（dock 层，标准档及以上）。

### AC-02 光影边界细节

- [ ] 所有玻璃表面描边宽度 == 1，颜色 == 白 α 按 §2.1 表（浅 L1=0x33FFFFFF 基准）；
- [ ] 深色描边逐层实值 0.16–0.24，且每层「描边 vs 填充」合成对比度 ≥1.5:1（单元测试含 §2.4 验算用例）；
- [ ] L1–L4 全部具备顶部高光渐变（浅/深基准 0.25/0.10）；色带探针走查通过或已切 solidLine 并记录；
- [ ] 旧 `0x99FFFFFF/0x38FFFFFF` 漂移描边清零（grep 无残留）。

### AC-03 动态色彩融合

- [ ] 8 预设 + custom 派生 background 相对亮度 ∈ (0.01, 0.99)，无一为纯黑/纯白（单元测试）；
- [ ] 环境光 36s 周期漂移正确（fake clock：blob 中心偏移 > 0）；
- [ ] push/pop 触发 +3% 位移脉冲、600ms 回归（RouteObserver 单元测试）；
- [ ] `disableAnimations` / saver / 应用后台 / 锁定态 四条件任一成立即完全静止（测试覆盖）；
- [ ] ContrastGuard：48 组合（8 预设 × 3 强度 × 浅深）对比度全部达标，钳制顺序与徽标提示正确；
- [ ] 背景图模式：Mesh 隐藏、脉冲默认关、L1 加厚生效（widget 测试）。

### AC-04 全组件玻璃化

- [ ] 按钮（glass 变体）、输入框、下拉菜单、复选框、开关、滑杆、Chip 全部玻璃规格（样板间 golden）;
- [ ] hover/focus/press 三态过渡 120–180ms（widget 测试断言 decoration 变化与 Duration）;
- [ ] 图表容器包 GlassPanel(innerSheen)；图表配色 palette 派生（锁定测试）；标准档下网格线 α0.5 清晰；
- [ ] 图标默认线性 pack + GlassIcon 承载（导航/AppBar/FAB 走查）。

### AC-05 一致性与质量门禁

- [ ] §8.2 两条 grep 门禁输出为空；
- [ ] `flutter analyze` 0 issues；`make test` 全绿（存量 242+ 不回退）；
- [ ] 新增专项测试 ≥ 25 例（token 数学与对比度 8 / GlassPanel 行为 6 / 组件三态 6 / 动效降级与 ContrastGuard 5+）。

### AC-06 性能预算与测量方法（评审意见 #3/#6 回应）

- [ ] **设备基线**：中端 Android（骁龙 695/765 档，Pixel 6a / Redmi Note 12 级别）为主测机；旗舰机上限参照；结果注明具体型号与 OS 版本；
- [ ] **工具**：`flutter run --profile` + DevTools Performance 手动复核；自动化 `flutter drive` + integration_test Timeline 采集 frame build/raster p95 与丢帧率，落盘 `docs/report/gls-v3/perf.json`；
- [ ] **场景与判定**：①报表页 10k 条首帧 <500ms；②账单 200 条快速 fling ×10 平均帧构建时间 vs v2 基线 ≤+5%；③五 Tab 连续切换 ×10 无卡顿丢帧突增；④样板间静置 60s 背景动画 raster 帧均 ≤2ms；
- [ ] **监控**：nightly workflow perf job 记录不设门禁；连续两版回归 >10% 升级为门禁。

---

## 10. 测试方案

| 层 | 文件 | 要点 |
| --- | --- | --- |
| 单元 | `test/unit/shared/theme/glass_layers_test.dart` | 层级单调性、画质档解析与补偿、描边基准与 1.5:1 下限、solidLine 分支 |
| 单元 | `test/unit/features/theme/app_theme_test.dart`（扩展） | 纯色禁令、ambient 4 色、对比度锁定、派生 token |
| 单元 | `test/unit/shared/theme/ambient_motion_test.dart` | fake clock 漂移、pulse/breathe、pause/resume、disableAnimations |
| 单元 | `test/unit/shared/theme/contrast_guard_test.dart` | 48 组合达标矩阵、钳制顺序、extraFillAlpha 兜底 |
| Widget | `test/widget/shared/glass_panel_test.dart` | σ 分支节点结构（ClipRRect+BackdropFilter hardEdge）、hover/focus/press、innerSheen |
| Widget | `test/widget/shared/app_button_glass_test.dart` | glass 变体三态、focus ring、loading 互斥 |
| Golden | `test/golden/golden_ui_test.dart`（扩展）+ `golden_tabs_test.dart` | **覆盖策略（评审意见 #5 回应）**：断言面 = 五 Tab + 样板间全展区 ×{T1, T6} + 样板间(T1) × 自定义背景图 fixture；**全部以 standard 档渲染**（BackdropFilter 不进入 golden 断言范围）；high/saver 分支由 widget 测试断言 σ 节点有无与 alpha 值；fixture 为入库的多色渐变探针图 `app/test/fixtures/bg_probe.png`（BK-GLS-017 一次性生成提交） |
| 性能 | integration_test Timeline 场景集（AC-06 四场景） | nightly 记录，阈值判定见 AC-06 |

CI 影响：无新增常驻 job；golden 更新在本波次一次性提交；nightly 追加 perf job。

---

## 11. 风险与回滚

| 风险 | 缓解 | 回滚 |
| --- | --- | --- |
| 多设备 BackdropFilter 性能不可控 | 默认 standard 已规避 L1/L2 磨砂；AC-06 实测；saver 兜底 | 设置切 saver 等效关闭绝大部分模糊 |
| 顶部高光真机色带 | §3.2 四重防线；BK-GLS-000 探针提前暴露 | `glassHighlightStyle=solidLine` 单点 flag |
| 深色描边可见度不足 | §2.4 实值标定 + 1.5:1 测试 + 小样 A/B | L1 上调 0.18 或 borderBoost |
| 标准档 L1 观感不够磨砂 | §4.4 三段软化 + 填充补偿 | 后备第 5 光斑；极端情况默认档切 saver 并公告 |
| golden 大面积失效 | 波次内集中刷新一次 | git revert golden 目录 |
| 动画耗电 | 后台/锁定暂停 + 总开关 | 设置关闭动效 |
| 存量 API 兼容 | ThemePalette 字段派生化；AppCard 签名不变 | — |

---

## 附录 A：变更影响文件清单（评审意见 #6/#7 回应）

### A.1 新增文件（N）

| 文件 | 内容 |
| --- | --- |
| `app/lib/shared/theme/glass/glass_layers.dart` | Tier 枚举、GlassSpec、resolveGlassSpec、solidLine 分支 |
| `app/lib/shared/theme/glass/glass_panel.dart` | GlassPanel 组件 |
| `app/lib/shared/theme/glass/glass_quality.dart` | 三档枚举、provider、app_meta 持久化 |
| `app/lib/shared/theme/glass/ambient_motion.dart` | 控制器 + AmbientRouteObserver |
| `app/lib/shared/theme/contrast_guard.dart` | 对比度联动计算器 |
| `tool/check_glass_consistency.sh` | CI 门禁脚本（Spec §8.2 两条命令封装） |
| `app/test/unit/shared/theme/glass_layers_test.dart` | 层级/画质/描边下限测试 |
| `app/test/unit/shared/theme/ambient_motion_test.dart` | 动效与降级测试 |
| `app/test/unit/shared/theme/contrast_guard_test.dart` | 48 组合矩阵测试 |
| `app/test/widget/shared/glass_panel_test.dart` | 面板行为测试 |
| `app/test/widget/shared/app_button_glass_test.dart` | 按钮三态测试 |
| `app/test/fixtures/bg_probe.png` | golden 背景图 fixture（多色渐变探针图，一次性生成入库） |

### A.2 改造文件（M）

| 文件 | 变更要点 | 所属任务 |
| --- | --- | --- |
| `app/lib/shared/theme/tokens.dart` | AppGlass 重写为层级函数消费端；旧常量保留兼容 | GLS-001 |
| `app/lib/shared/widgets/app_card.dart` | 改 GlassPanel 薄封装（签名不变） | GLS-002 |
| `app/lib/shared/theme/theme_presets.dart` | ambient 4 色、T5/T7/T8 提亮、glass 字段派生化 | GLS-004 |
| `app/lib/shared/theme/app_theme.dart` | 组装器接入 resolveGlassSpec；组件主题玻璃化（§5.1） | GLS-005/006 |
| `app/lib/shared/widgets/app_button.dart` | glass 变体 + hover/focus 态 | GLS-006 |
| `app/lib/shared/widgets/app_text_field.dart` | focus 光晕包装 | GLS-006 |
| `app/lib/shared/theme/chart_colors.dart` | ambient+semantic 派生序列 | GLS-007 |
| `app/lib/features/reports/charts/report_charts.dart` | 容器 GlassPanel(innerSheen)+渐变填充 | GLS-007 |
| `app/lib/features/calendar/cashflow_chart.dart` | 同上 | GLS-007 |
| `app/lib/features/budgets/budget_progress_bar.dart` | 同上 | GLS-007 |
| `app/lib/shared/theme/glass_icon.dart` | 读层级函数 | GLS-008 |
| `app/lib/shared/theme/background/ambient_gradient.dart` | 4 光斑 + 分档软化 + 动效绘制 | GLS-009/013 |
| `app/lib/shared/theme/background/app_background.dart` | 动效接线、imageMode 判定透传 | GLS-009/012 |
| `app/lib/app.dart` | navigatorObservers 挂 AmbientRouteObserver；Tab breathe 回调 | GLS-012 |
| `app/lib/main.dart` | 新增设置键启动注入 | GLS-014 |
| `app/lib/data/repositories/settings_repository.dart` | 新增 5 个键读写 | GLS-014 |
| `app/lib/features/settings/appearance_page.dart` | 「玻璃质感」「环境光」设置组 + clamp 徽标 | GLS-014 |
| `app/lib/features/settings/component_gallery_page.dart` | 四个新展区 | GLS-015 |
| `app/lib/features/accounts/account_card.dart` | 散点装饰收敛（§8.3） | GLS-010 |
| `app/lib/features/budgets/budget_summary_card.dart` | 同上 | GLS-010 |
| `app/lib/features/calendar/calendar_page.dart` | 日格装饰收敛 | GLS-010 |
| `app/lib/features/quick_entry/amount_keyboard.dart` | 键帽装饰收敛 | GLS-010 |
| `app/lib/features/auth_lock/pin_pad.dart` | 键帽装饰收敛 | GLS-010 |
| `app/lib/features/books/book_switcher.dart` | 走查收敛 | GLS-010 |
| `app/lib/features/bills/bill_detail_sheet.dart` | 走查收敛 | GLS-010 |
| `app/test/golden/golden_ui_test.dart` | 扩展区面 + fixture 用例 | GLS-017 |
| `app/test/golden/golden_tabs_test.dart` | standard 档渲染声明 + 刷新 | GLS-017 |
| `app/test/unit/features/theme/app_theme_test.dart` | 纯色禁令等扩展 | GLS-004 |
| `.github/workflows/*`（nightly） | perf job 追加 | GLS-018 |

### A.3 明确不改（供 review 对照）

`server/**` 全部、`app/lib/data/` 除 settings_repository 外全部、`domain/`、同步相关 features（sync/books_api 等）、Drift schema。

---

## 附录 B：实施核销记录（2026-08-24，BK-GLS-019）

附录 A 所列文件全部落地：

- **A.1 新增（N）**：12/12 已创建入库。其中 `app/test/fixtures/bg_probe.png` 由
  `test/golden/generate_bg_fixture_test.dart` 生成器产出（多色渐变探针）；
- **A.2 改造（M）**：全部完成。实现口径差异两处——
  ①`BackdropFilter(clipBehavior: Clip.hardEdge)` 在 Flutter 3.44 widget 层
  无此参数，等价采用 `ImageFilterConfig.blur(bounded: true)` + 外层 ClipRRect
  双保险（语义一致，见 spike.md C-2）；②calendar 日格经走查确认为数据可视化
  标记而非玻璃表面，按 §8.3「保留理由」核销；
- **A.3 不改**：与计划一致。

验收判定详见 `docs/report/gls-v3/acceptance.md`（AC-01~05 ✅；AC-06 方法论
就绪、真机实测待执行）。
