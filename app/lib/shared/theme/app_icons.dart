import 'package:flutter/material.dart';

/// 功能模块（底部导航主 Tab；BK-DOC-28 需求6：分类入口下沉设置后
/// 收敛为两模块，记账入口为底栏中央动作按钮而非 Tab）
enum AppModule {
  bills('账单'),
  reports('报表');

  const AppModule(this.label);
  final String label;
}

/// 功能模块图标（固定 outlined 变体；图标风格选择已随外观简化移除，
/// Spec §2.3 / BK-DOC-26——`IconPack` 配置面整体收敛）
IconData moduleIcon(AppModule module) => switch (module) {
      AppModule.bills => Icons.receipt_long_outlined,
      AppModule.reports => Icons.bar_chart_outlined,
    };
