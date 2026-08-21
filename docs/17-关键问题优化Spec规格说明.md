# 17 - 关键问题优化 Spec 规格说明（UI 图标重构 / 背景热重载与层级 / 快速记账退出）

| 项目 | 内容 |
| --- | --- |
| 文档编号 | BK-DOC-17 |
| 版本 | v1.0 |
| 日期 | 2026-08-17 |
| 状态 | 实施中 |
| 关联文档 | `docs/09-UI设计文档-主题与视觉体系.md`、`docs/10-UI重构Spec规格说明.md`、`docs/15-UI重构审核改进Spec规格说明.md` |
| 任务拆解 | `docs/18-关键问题优化任务分解.md` |
| 适用范围 | `app/`（Flutter，Riverpod 2.6） |

---

## 1. 背景与目标

本 Spec 针对当前三个关键体验问题制定统一优化方案：

1. **UI 图标体系缺少现代统一风格**：现有图标为原生 Material Icon 直出，缺乏轻盈、通透的视觉层级，需引入玻璃拟态（Glassmorphism）设计语言。
2. **自定义背景图存在“必须重启才生效/遮挡交互”的隐患**：同路径覆盖选图时 Flutter ImageCache 可能复用旧图；背景层若命中测试参与可能影响 TabBar、FAB 等点击。
3. **快速记账（秒开模式）退出入口缺失**：秒开模式将记账页作为根路由，用户无法离开，造成“必须先记一笔”的强制体验。

目标：以统一 Token + 可复用组件落地玻璃拟态图标；实现背景图会话内即时热重载与安全层级；为快速记账提供明确、无阻断的退出路径。

---

## 2. UI 图标重构（Glassmorphism）

### 2.1 设计目标

- 视觉轻盈、通透，与现代 App 设计趋势一致。
- 全应用关键图标统一使用同一套玻璃容器，避免图标风格碎片化。
- 在浅色/深色主题、8 套预制主题及自定义主题下均保持可辨识度和对比度。
- 性能可控：小图标可关闭 BackdropFilter，仅保留填充、描边和阴影。

### 2.2 统一图标规范

| Token | 浅色主题 | 深色主题 | 说明 |
| --- | --- | --- | --- |
| 填充色 | `Color(0x33FFFFFF)`（白 20%） | `Color(0x1AFFFFFF)`（白 10%） | 通透玻璃底 |
| 描边色 | `Color(0x80FFFFFF)`（白 50%） | `Color(0x40FFFFFF)`（白 25%） | 高光玻璃边 |
| 描边宽 | 1px | 1px | 统一 |
| 圆角 | 12px | 12px | 与卡片 `AppRadius.md` 对齐 |
| 背景模糊 | 10px | 10px | 容器内 BackdropFilter，可关闭 |
| 阴影 | y=2, blur=10, 8% 黑 | 同左 | 轻盈悬浮 |
| 图标字号 | 20–22（常规） | 同左 | 由使用场景决定 |

实现位置：

- `app/lib/shared/theme/tokens.dart`：新增 `AppGlass` 玻璃拟态 Token 常量。
- `app/lib/shared/theme/glass_icon.dart`：新增 `GlassIcon`（图标容器）与 `GlassIconButton`（图标按钮）。

### 2.3 组件更新范围

| 组件 | 更新内容 |
| --- | --- |
| 底部导航 `NavigationBar` | 五个 Tab 图标改用 `GlassIcon` 包裹 |
| 记一笔 FAB | 加号图标改用 `GlassIcon` |
| 主界面设置入口 | 改用 `GlassIconButton` |
| 账本切换器 `BookSwitcher` | 账本图标使用 `GlassIcon`（轻量，关闭模糊） |
| 外观页图标风格预览 | 预览项改用 `GlassIcon` 展示玻璃效果 |
| 快速记账退出按钮 | 关闭图标使用轻量玻璃样式（关闭模糊，保证文字按钮清晰） |

后续迭代可将列表图标、分类图标、空态插画逐步迁移至同一组件；本次先完成全局关键入口的统一。

---

## 3. 自定义背景图交互修复

### 3.1 热重载/即时预览

**根因**：

- 背景图固定写入 `background/bg.png`，多次选图覆盖同一路径。
- `Image.file` 使用的 `FileImage` 以“路径 + scale”作为缓存 Key；同路径覆盖后，Flutter ImageCache 可能继续命中旧图。
- 单纯更新 Riverpod 状态不会改变 `ImageProvider` 的相等性，因此界面可能不刷新，需重启清空缓存后才显示新图。

**方案**：

1. 新增 `backgroundRevisionProvider`（`StateProvider<int>`），每次成功选图并落盘后自增。
2. `BackgroundController._precacheImage` 先执行 `FileImage(file).evict()` 清除旧缓存，再预热新图。
3. 新增 `RevisionFileImage`（带 revision 的 `FileImage` 子类），`AppBackground` 与外观页预览改用该 Provider，并将 `imageRevision` 同时绑定到 `ValueKey`；revision 变化时 Provider 不等同，强制重新解码。
4. 保留既有 `backgroundImageFileProvider` / `backgroundLuminanceProvider` 的响应式链路：`_persist` 更新设置后，文件解析与亮度采样自动重跑。

**效果**：用户选图后无需重启，主界面背景与外观页预览均立即刷新。

### 3.2 图层范围与交互修复

**根因/风险**：背景图、遮罩、模糊层若参与命中测试，可能在部分场景拦截点击，导致 TabBar、FAB、按钮无法响应。

**方案**：

1. `AppBackground` 使用“外层 Stack + 内容层置顶”的结构：
   - 背景图/遮罩/模糊统一放入 `IgnorePointer` 背景层，视觉存在但不参与命中测试；
   - 内容层 `Positioned.fill(child: child)` 位于最上层，正常接收点击。
2. 保持背景覆盖全屏的视觉连续性（不做容器裁剪），通过层级与命中隔离解决遮挡。
3. 背景层内部仍使用 `RepaintBoundary` 与 `cacheWidth`，性能策略不变。

**效果**：启用自定义背景后，底部导航、FAB、AppBar、页面按钮均可正常点击。

---

## 4. 快速记账模式退出逻辑完善

### 4.1 根因

原实现中“秒开模式”将 `QuickEntrySheet` 直接作为 `MaterialApp.home` 根路由，没有返回主界面的路由，也没有显式退出入口，用户只能完成记账后离开。

### 4.2 方案

1. **架构调整**：`main.dart` 不再为秒开模式单独创建根 MaterialApp，统一启动 `BookkeepApp`；`BookkeepApp` 新增 `startInQuickEntry` 参数，首帧后通过 `navigatorKey` 将 `QuickEntrySheet` push 到主界面之上。
2. **退出入口**：`QuickEntrySheet` AppBar 右上角新增明确的“退出”按钮（图标 + 文案）。
3. **行为约束**：
   - 点击退出直接 `Navigator.pop()`，不要求完成记账；
   - 若在异常/测试环境作为根路由，使用 `maybePop()` 兜底，不阻断流程；
   - 是否保存由用户决定，退出不产生流水、不弹强制确认。
4. **可选提示**：本次未强制增加未记账确认弹窗，避免阻断；后续可在退出前追加轻提示（需产品确认）。

### 4.3 效果

- 秒开启动后，用户可随时点击“退出”回到主界面。
- 秒开设置仍保留，下次冷启动仍可直达记账页；若用户希望关闭该模式，可到设置页关闭“秒开模式”。

---

## 5. 涉及文件清单

| 文件 | 改动 |
| --- | --- |
| `app/lib/shared/theme/tokens.dart` | 新增 `AppGlass` Token |
| `app/lib/shared/theme/glass_icon.dart` | 新增 `GlassIcon` / `GlassIconButton` |
| `app/lib/app.dart` | 玻璃图标接入、`BookkeepApp.startInQuickEntry`、秒开自动 push |
| `app/lib/features/books/book_switcher.dart` | 账本切换图标玻璃化 |
| `app/lib/main.dart` | 移除秒开独立 MaterialApp 分支，统一启动 `BookkeepApp` |
| `app/lib/features/quick_entry/quick_entry_sheet.dart` | 新增退出按钮与 `_exit()` |
| `app/lib/shared/theme/background/background_controller.dart` | 新增 `backgroundRevisionProvider`、缓存 evict、revision 自增 |
| `app/lib/shared/theme/background/app_background.dart` | 热重载 Key + 背景层 IgnorePointer/层级隔离 |
| `app/lib/features/settings/appearance_page.dart` | 预览热重载 Key + 图标预览玻璃化 |
| `app/test/widget/app_background_test.dart` | 适配背景层嵌套后的遮罩断言，并保留交互回归 |
| `app/test/widget/quick_entry_sheet_test.dart` | 新增快速记账退出入口断言 |

---

## 6. 验收标准

### 6.1 UI 图标

- [ ] `AppGlass` Token 存在且数值符合 2.2 表格。
- [ ] 底部导航、FAB、设置入口、账本切换器、外观页图标预览均使用 `GlassIcon` / `GlassIconButton`。
- [ ] 浅色/深色主题下图标可辨识，无对比度回归。
- [ ] `flutter analyze` 0 issues；`dart run tool/check_ui_tokens.dart` 0 违规。

### 6.2 背景图

- [ ] 选择新背景图后，主界面与外观页预览无需重启立即更新。
- [ ] 同一路径连续选图，不会显示旧缓存图。
- [ ] 启用背景后，TabBar、FAB、AppBar 按钮、页面按钮均可点击。
- [ ] 无背景图时零开销分支保持。

### 6.3 快速记账退出

- [ ] 秒开模式启动后，快速记账页右上角显示“退出”。
- [ ] 点击“退出”立即回到主界面，不保存流水、不强制完成记账。
- [ ] 从 FAB/日历进入的快速记账页也可通过“退出”返回。
- [ ] 保存成功流程不受影响。

---

## 7. 风险与后续

| 风险 | 应对 |
| --- | --- |
| 玻璃图标使用 BackdropFilter 可能增加绘制成本 | 小图标/低端机可设 `blur: false`；后续按真机 profiling 决定是否全局关闭 |
| Golden 基线变化 | 按 0.5% 容差审查后 `--update-goldens` 重建 |
| 秒开自动 push 与隐私锁/背景叠加 | 沿用统一 `appShellBuilder`，无新增嵌套 MaterialApp |
| 背景图热重载依赖 revision | 重启后从磁盘读取最新文件，天然一致 |
