import 'package:flutter/material.dart';

/// 功能模块（底部导航主 Tab；BK-DOC-26：周期记账下沉设置、日历并入报表后
/// 收敛为三模块）
enum AppModule {
  bills('账单'),
  categories('分类'),
  reports('报表');

  const AppModule(this.label);
  final String label;
}

/// 功能模块图标（固定 outlined 变体；图标风格选择已随外观简化移除，
/// Spec §2.3 / BK-DOC-26——`IconPack` 配置面整体收敛）
IconData moduleIcon(AppModule module) => switch (module) {
      AppModule.bills => Icons.receipt_long_outlined,
      AppModule.categories => Icons.category_outlined,
      AppModule.reports => Icons.bar_chart_outlined,
    };
