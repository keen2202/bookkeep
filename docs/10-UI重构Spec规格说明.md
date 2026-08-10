# 10 - UI 重构 Spec 规格说明（主题系统 / 组件库 / 智能背景）

| 项目 | 内容 |
| --- | --- |
| 文档编号 | BK-DOC-10 |
| 版本 | v1.0 |
| 日期 | 2026-08-09 |
| 状态 | 待评审 |
| 设计依据 | `docs/09-UI设计文档-主题与视觉体系.md` |
| 任务拆解 | `docs/11-UI重构任务分解.md` |
| 适用范围 | `app/`（Flutter SDK `^3.12.0`，Riverpod 2.6，Drift） |

---

## 1. 总体架构

### 1.1 分层

```
┌────────────────────────────────────────────────┐
│ features/*（15 个业务模块，只消费 Token/组件）   │
├────────────────────────────────────────────────┤
│ shared/widgets/  组件库（AppButton/AppCard/…）   │
├────────────────────────────────────────────────┤
│ shared/theme/    主题系统                        │
│   ├─ tokens.dart        设计 Token（间距/圆角/   │
│   │                     阴影/字阶）              │
│   ├─ theme_presets.dart 8 套预制主题数据         │
│   ├─ app_theme.dart     ThemeData 组装（改造）   │
│   ├─ theme_settings.dart 设置模型 + Provider     │
│   │                     （扩展现有）             │
│   └─ background/        背景图子系统             │
│        ├─ background_service.dart  存取/解码     │
│        ├─ luminance.dart           亮度/遮罩算法 │
│        └─ app_background.dart      三层背景部件  │
├────────────────────────────────────────────────┤
│ 持久化：app_meta 键值（沿用现有 ThemeSettings    │
│ 注入链路，main() 启动时读入）                    │
└────────────────────────────────────────────────┘
```

### 1.2 关键决策

| # | 决策点 | 结论 | 理由 |
| --- | --- | --- | --- |
| D1 | 主题体系基座 | 保留 `ColorScheme.fromSeed` 不再用于预制主题；预制主题改为**完整 ThemeData 数据类**直出 | fromSeed 只能换主色，无法表达 8 套主题的完整配色体系 |
| D2 | 主题模型 | 新增 `AppThemePreset`（不可变数据类）+ `AppThemeExtension`（承载设计文档全部 Token） | M3 ColorScheme 装不下 border/divider/surfaceVariant 语义，用 ThemeExtension 扩展 |
| D3 | 自定义色 | 保留现有"种子色自定义"能力，作为第 9 种"自定义主题"与 8 套预制并存 | 不破坏既有用户偏好 |
| D4 | 状态管理 | 沿用 `themeSettingsProvider`（StateProvider）扩展字段；背景相关拆出 `backgroundSettingsProvider` | 全项目 Riverpod 统一；背景解码为异步操作，独立 provider 避免阻塞主题切换 |
| D5 | 持久化 | app_meta 键值新增 `theme_preset_id`、`bg_image_path`、`bg_overlay_mode`、`bg_overlay_alpha`、`bg_blur`；旧 `seed_color`/`theme_mode` 键保留兼容 | 沿用 main() 启动注入机制，无迁移脚本 |
| D6 | 图片依赖 | 新增 `image_picker: ^1.x`；图片解码/采样用 Flutter 内置 `dart:ui` `instantiateImageCodec`，不引第三方图像库 | 控制包体积（APK 体积是历史痛点，见审查报告 v0.2.1） |
| D7 | 图标风格 | IconPack 保持不变，随主题设置页并入"外观"分组 | 现有机制成熟，零改造成本 |

---

## 2. 数据模型

### 2.1 ThemePreset（预制主题，静态常量）

```dart
/// shared/theme/theme_presets.dart
class ThemePalette {
  const ThemePalette({
    required this.primary, required this.onPrimary,
    required this.primaryContainer, required this.secondary,
    required this.background, required this.surface,
    required this.surfaceVariant, required this.scrim,
    required this.textPrimary, required this.textSecondary,
    required this.textDisabled, required this.border,
    required this.divider,
  });
  final Color primary, onPrimary, primaryContainer, secondary;
  final Color background, surface, surfaceVariant, scrim;
  final Color textPrimary, textSecondary, textDisabled;
  final Color border, divider;
}

class AppThemePreset {
  const AppThemePreset({
    required this.id,          // 't1'..'t8'
    required this.name,        // '青碧·晨' 等
    required this.brightness,
    required this.styleTag,    // 品牌/清爽/优雅/温暖/中性/科技/自然/个性
    required this.palette,     // 设计文档 §4 全量值
  });
  final String id, name, styleTag;
  final Brightness brightness;
  final ThemePalette palette;
}

const kThemePresetsV2 = <AppThemePreset>[ /* T1..T8 */ ];
```

### 2.2 ThemeSettings（扩展，向后兼容）

```dart
class ThemeSettings {
  const ThemeSettings({
    this.presetId = 't1',        // 新增：预制主题 id；'custom' 表示种子色自定义
    required this.seedColor,     // 保留：自定义模式生效
    required this.mode,          // 保留：仅 custom 模式下生效
    this.iconPack = IconPack.outlined,
  });
  final String presetId;
  final Color seedColor;
  final ThemeMode mode;
  final IconPack iconPack;
}
```

兼容规则：升级后若无 `theme_preset_id` 键，按旧 `seed_color` 落为 `presetId='custom'`，行为与旧版一致。

### 2.3 BackgroundSettings

```dart
class BackgroundSettings {
  const BackgroundSettings({
    this.enabled = false,
    this.imagePath,                       // 应用文档目录内相对路径
    this.overlayMode = OverlayMode.auto,  // auto 智能 / manual 手动
    this.manualAlpha = 0.70,              // 手动模式遮罩透明度
    this.blurEnabled = true,
  });
  final bool enabled;
  final String? imagePath;
  final OverlayMode overlayMode;
  final double manualAlpha;   // 0.0 ~ 0.92
  final bool blurEnabled;
}
```

---

## 3. 主题切换接口（对外 API）

### 3.1 ThemeController

```dart
/// shared/theme/theme_settings.dart（扩展）
final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeSettings>(ThemeController.new);

class ThemeController extends Notifier<ThemeSettings> {
  /// 切换到预制主题（'t1'..'t8'），立即全树热重建并持久化
  Future<void> applyPreset(String presetId);
  /// 切换到自定义种子色模式（保留旧能力）
  Future<void> applyCustomSeed(Color seed, ThemeMode mode);
  /// 切换图标包
  Future<void> setIconPack(IconPack pack);
}
```

### 3.2 BackgroundController

```dart
final backgroundControllerProvider =
    AsyncNotifierProvider<BackgroundController, BackgroundSettings>(
        BackgroundController.new);

class BackgroundController extends AsyncNotifier<BackgroundSettings> {
  /// 从相册选图 → 压缩拷贝到文档目录 → 采样亮度 → 应用
  Future<PickResult> pickAndApply();
  /// 重新采样当前图片亮度（主题明暗切换后遮罩重算）
  Future<void> refreshOverlay();
  Future<void> setOverlayMode(OverlayMode mode, {double? manualAlpha});
  Future<void> setBlur(bool enabled);
  Future<void> clear();   // 恢复纯色背景，删除本地图片文件
}
```

### 3.3 消费侧接口

```dart
// 主题 Token（全应用唯一取色入口）
extension AppThemeX on BuildContext {
  ThemePalette get palette;   // 当前主题完整调色板
  AppColors get appColors;    // 语义色（现有，保留）
  TextTheme get text;         // 全局字阶
}

// 背景部件（页面脚手架最底层）
class AppBackground extends StatelessWidget {
  const AppBackground({required this.child});
  // 内部：Image(背景图) → 遮罩 Container(α) → BackdropFilter(blur) → child
}
```

`MaterialApp.builder` 或主 Scaffold 包一层 `AppBackground`，二级页复用同一背景（跨页视觉连续）。

---

## 4. ThemeData 组装规格

`buildTheme()` 改造为：

```dart
ThemeData buildTheme(AppThemePreset preset, {Color? customSeed, ThemeMode? customMode})
```

组装规则：
1. `ColorScheme`：从 `preset.palette` 显式构造（primary/onPrimary/secondary/surface/error 等映射），不再 fromSeed；`presetId='custom'` 时退回旧 fromSeed 路径。
2. `extensions`：注册 `AppColors`（语义色浅/深锁定）+ 新增 `AppTokens`（palette/spacing/radius）。
3. `textTheme`：按设计文档 §3.2 七级字阶生成；`amount`/`displayAmount` 经 `AppTokens.amountStyle` 暴露（含 `FontFeature.tabularFigures`）。
4. 组件主题内建：AppBarTheme（透明 + overlay 明暗）、CardTheme（圆角 12 + 边框/阴影按明暗分流）、NavigationBarTheme、BottomSheetThemeData（圆角 20 + scrim 54%）、SnackBarThemeData（floating，沿用）、InputDecorationTheme（填充 surfaceVariant + 聚焦 2px primary）、DialogThemeData。
5. 主题切换动画：`AnimatedTheme(duration: 250ms)` 包 MaterialApp.theme。

---

## 5. 智能遮罩算法规格

### 5.1 亮度采样

```
decode: ui.instantiateImageCodec(bytes, targetWidth: 32, targetHeight: 32)
pixels: rgba8888
for each pixel:
  c' = c / 255
  linear = c' <= 0.03928 ? c'/12.92 : ((c'+0.055)/1.055)^2.4   // sRGB 线性化
L = mean(0.2126·Rl + 0.7152·Gl + 0.0722·Bl)   ∈ [0, 1]
```

### 5.2 遮罩透明度映射

分段锚点（α 随主题明暗取列值，锚点间**线性插值**）：

| L | 0.00 | 0.15 | 0.35 | 0.55 | 0.75 | 1.00 |
| --- | --- | --- | --- | --- | --- | --- |
| α（浅色主题） | 0.50 | 0.55 | 0.60 | 0.72 | 0.82 | 0.86 |
| α（深色主题） | 0.48 | 0.52 | 0.58 | 0.68 | 0.78 | 0.82 |

### 5.3 对比度校验闭环

```
effLum = L·(1-α) + lum(theme.background)·α          // 遮罩后有效亮度（近似）
ratio  = contrast(theme.palette.textPrimary, colorOf(effLum))
while ratio < 4.5 and α < 0.92: α += 0.05
```

- `contrast()` 按 WCAG 2.x 相对亮度公式实现，单元测试覆盖 8 主题 × 5 档亮度 = 40 用例。
- 手动模式不强制校验，但滑杆下方给出实时对比度评级提示（优/良/差）。
- 状态栏图标明暗：`effLum > 0.5 ? dark icons : light icons`。

### 5.4 图片处理管线

1. `image_picker` 选图（Android 13+ 走 PhotoPicker，无需存储权限；iOS `NSPhotoLibraryUsageDescription`）。
2. 压缩：最长边 1920px、JPEG 质量 85，写入 `getApplicationDocumentsDirectory()/background/bg.jpg`（固定文件名，替换即覆盖）。
3. 采样亮度（isolate 外即可，32×32 解码 < 16ms）。
4. 持久化 BackgroundSettings；旧文件 `clear()` 时删除。
5. 缓存：`AppBackground` 用 `Image.file` + `cacheWidth` 限制，避免每次重建解码。

---

## 6. 组件库规格（shared/widgets/）

| 组件 | 文件 | 关键属性 | 替换范围 |
| --- | --- | --- | --- |
| AppButton | `app_button.dart` | variant(primary/secondary/text/danger)、loading、block | 全项目 ElevatedButton/TextButton/OutlinedButton |
| AppCard | `app_card.dart` | onTap、padded | 各业务卡片（account_card、budget_summary_card 等先包一层） |
| AppTextField | `app_text_field.dart` | label、error、prefix | 各编辑 sheet 输入框 |
| AppSheet | `app_sheet.dart` | title、scrollable | showModalBottomSheet 全量收敛（quick_entry_sheet、settings sheet 等） |
| AppDialog | `app_dialog.dart` | danger 支持 | AlertDialog 全量收敛 |
| AppSnack | `app_snack.dart` | success/error/info 静态方法 | ScaffoldMessenger 调用点 |
| AppEmpty | `app_empty.dart` | icon、title、action | 账单/报表/日历空态 |
| AppAmountText | `app_amount_text.dart` | 等宽数字、收支自动着色 | 全部金额展示位 |

收敛清单（硬编码色/字号整改点，来自现状走查）：

| 文件 | 位置 | 整改 |
| --- | --- | --- |
| color_picker_dialog.dart | 128-160 | 遮罩/棋盘格色 → palette |
| theme_settings_page.dart | 145 | 预览底色 → palette |
| report_charts.dart | 55 | 图表序列色 → palette/语义色派生 |
| calendar_page.dart | 208/216 | 日历选中/今日标记 → palette |
| category_edit_sheet.dart | 140 | 图标底色 → palette |
| amount_keyboard.dart 等 6 处 | fontSize 裸值 | → TextTheme/AppAmountText |

---

## 7. 设置页改造（外观分组）

`features/settings/theme_settings_page.dart` 重构为"外观"页：

```
外观
├─ 主题方案：8 套预制卡片网格（2列，色板缩略预览 + 名称 + 风格标签）
│           + 第 9 格"自定义"（进入现有选色器流程）
├─ 图标风格：线性/实心/圆角/直角（现有，迁移保留）
└─ 个性背景：
   ├─ 开关：使用背景图片
   ├─ 更换图片 / 恢复默认
   ├─ 遮罩：智能 / 手动（滑杆 + 实时预览 + 对比度评级）
   └─ 背景模糊：开关
```

---

## 8. 非功能规格

| 项 | 指标 |
| --- | --- |
| 主题切换 | 全树重建 ≤ 100ms（无图片解码参与）；过场动画 250ms |
| 背景应用 | 选图到生效 ≤ 800ms（含压缩拷贝与采样） |
| 包体积增量 | ≤ 300KB（image_picker 原生部分 + Dart 代码；不引图像库） |
| 内存 | 背景图解码缓存 ≤ 屏幕物理分辨率 ×4B |
| 兼容 | Flutter `^3.12.0`；minSdk/ targetSdk 不变；Android PhotoPicker / iOS 相册权限文案 |
| 隐私 | 背景图仅存本地文档目录；备份/同步范围明确排除（备份范围历史遗漏问题见审查报告，勿扩大） |

## 9. 测试规格

| 层 | 用例 |
| --- | --- |
| 单元 | luminance 采样（纯色图极值/渐变图）、α 映射插值连续性、对比度闭环收敛性（40 用例）、ThemeSettings/BackgroundSettings 序列化与旧键兼容迁移 |
| Widget | ThemeController 切换后 Consumer 重建；AppBackground 三层结构存在性；AppButton loading 防重入 |
| Golden | 8 主题 × 主页面 + 账单卡片 + 设置外观页 = ≥ 24 张基线图；容差 0.5% |
| 集成 | 选图→应用→杀进程重启→背景与遮罩恢复；手动/智能模式互切 |
| 静态 | 自定义 lint/脚本：features/ 下禁止 `Color(0x` 与 `fontSize:`（白名单除外），CI 卡点 |

## 10. 风险与回退

| 风险 | 等级 | 缓解 |
| --- | --- | --- |
| 8 主题全量直出色板与 M3 组件默认映射冲突（如 NavigationBar 指示色） | 中 | 组件主题全部显式构造，禁用 fromSeed 隐式派生；Golden 测试兜底 |
| image_picker 在部分国产 ROM 相册兼容问题 | 中 | 降级 SAF/文件选择；PickResult 携带失败原因，UI 提示 |
| 背景图导致低端机滚动掉帧 | 低 | cacheWidth 限解码尺寸 + 模糊可关；RepaintBoundary 隔离背景层 |
| 旧用户升级后主题跳变 | 低 | 兼容规则落 'custom' 模式，观感与旧版一致 |
| 回退 | — | 主题/背景均为纯前端偏好键值，回退即恢复默认 ThemeSettings，无数据迁移 |

---

*任务拆解、波次依赖与排期见 `docs/11-UI重构任务分解.md`。*
