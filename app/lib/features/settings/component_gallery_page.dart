import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/theme/chart_colors.dart';
import '../../shared/theme/theme_presets.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/app_amount_text.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_empty.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/app_snack.dart';
import '../../shared/widgets/app_text_field.dart';

/// 组件 Gallery 样板间（BK-UI-008，设计文档 §6.3）：
/// 全组件 × 8 主题切换预览，供设计走查（不影响全局主题设置）。
class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  AppThemePreset _preset = kThemePresetsV2.first;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTheme(_preset),
      child: Builder(
        builder: (themedContext) => Scaffold(
          appBar: AppBar(title: const Text('组件样板间')),
          body: ListView(
            padding: AppSpacing.pagePadding,
            children: [
              // 8 主题切换
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final p in kThemePresetsV2)
                    ChoiceChip(
                      label: Text(p.name),
                      selected: _preset.id == p.id,
                      onSelected: (_) => setState(() => _preset = p),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Section(
                title: 'AppButton 按钮',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton.primary(onPressed: () {}, child: const Text('主按钮')),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton.secondary(onPressed: () {}, child: const Text('次按钮')),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton.danger(onPressed: () {}, child: const Text('危险按钮')),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton.text(onPressed: () {}, child: const Text('文字按钮')),
                    const SizedBox(height: AppSpacing.sm),
                    const AppButton.primary(loading: true, child: Text('加载中')),
                    const SizedBox(height: AppSpacing.sm),
                    const AppButton.primary(onPressed: null, child: Text('禁用态')),
                  ],
                ),
              ),
              _Section(
                title: 'AppCard 卡片',
                child: Column(
                  children: [
                    AppCard(
                      child: Text('静态卡片', style: themedContext.text.bodyLarge),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      onTap: () {},
                      child: Row(
                        children: [
                          Icon(Icons.touch_app_outlined,
                              color: themedContext.palette.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Text('可点卡片（水波纹 + 按压 4%）',
                              style: themedContext.text.bodyLarge),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _Section(
                title: 'AppTextField 输入框',
                child: const Column(
                  children: [
                    AppTextField(label: '标准输入框', hint: '请输入内容'),
                    SizedBox(height: AppSpacing.sm),
                    AppTextField(label: '错误态', error: '输入不合法，请重新输入'),
                  ],
                ),
              ),
              _Section(
                title: 'AppAmountText 金额',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppAmountText.minor(123456, large: true),
                    const SizedBox(height: AppSpacing.sm),
                    AppAmountText.minor(-8899),
                    AppAmountText.minor(8899),
                    const AppAmountText('¥0.00'),
                  ],
                ),
              ),
              _Section(
                title: 'AppSheet / AppDialog / AppSnack',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AppButton.secondary(
                      onPressed: () => showAppSheet<void>(
                        themedContext,
                        title: '底部弹层',
                        child: Text('拖拽柄 32×4、圆角 lg、背板 scrim 54%、下滑关闭。',
                            style: themedContext.text.bodyLarge),
                      ),
                      child: const Text('底部弹层'),
                    ),
                    AppButton.secondary(
                      onPressed: () => showAppConfirm(
                        themedContext,
                        title: '普通对话框',
                        content: '标题 title + 内容 body + 按钮区右对齐。',
                      ),
                      child: const Text('对话框'),
                    ),
                    AppButton.secondary(
                      onPressed: () => showAppConfirm(
                        themedContext,
                        title: '危险确认',
                        content: '危险操作确认键为 danger 样式。',
                        danger: true,
                        confirmText: '删除',
                      ),
                      child: const Text('危险对话框'),
                    ),
                    AppButton.secondary(
                      onPressed: () => AppSnack.success(themedContext, '操作成功'),
                      child: const Text('成功提示'),
                    ),
                    AppButton.secondary(
                      onPressed: () => AppSnack.error(themedContext, '操作失败'),
                      child: const Text('失败提示'),
                    ),
                    AppButton.secondary(
                      onPressed: () => AppSnack.info(themedContext, '中性信息'),
                      child: const Text('信息提示'),
                    ),
                  ],
                ),
              ),
              _Section(
                title: 'AppEmpty 空态',
                child: AppCard(
                  child: SizedBox(
                    height: 260,
                    child: AppEmpty(
                      icon: Icons.receipt_long_outlined,
                      title: '暂无账单',
                      message: '点击右下角 + 记一笔',
                      actionLabel: '记一笔',
                      onAction: () {},
                    ),
                  ),
                ),
              ),
              _Section(
                title: '图表序列色（palette 派生）',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final c in chartSeriesColors(themedContext))
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: AppRadius.smAll,
                          border: Border.all(color: themedContext.palette.border),
                        ),
                      ),
                  ],
                ),
              ),
              _Section(
                title: '字阶（七级）',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('displayAmount 34 大数字 ¥1,234.56',
                        style: themedContext.tokens.displayAmountStyle),
                    Text('headline 22 页面主标题',
                        style: themedContext.text.headlineSmall),
                    Text('title 17 卡片标题/列表主文案',
                        style: themedContext.text.titleLarge),
                    Text('body 15 正文内容', style: themedContext.text.bodyLarge),
                    Text('bodySmall 13 辅助说明',
                        style: themedContext.text.bodyMedium),
                    Text('caption 12 时间戳/标签',
                        style: themedContext.text.bodySmall),
                    Text('amount 17 等宽金额 ¥8,888.00',
                        style: themedContext.tokens.amountStyle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
