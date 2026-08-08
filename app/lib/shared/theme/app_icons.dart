import 'package:flutter/material.dart';

import 'theme_settings.dart';

/// 功能模块（底部导航五 Tab）
enum AppModule {
  bills('账单'),
  categories('分类'),
  recurring('周期记账'),
  reports('报表'),
  calendar('日历');

  const AppModule(this.label);
  final String label;
}

/// 应用图标（应用标识，随图标风格替换）
IconData appIcon(IconPack pack) => switch (pack) {
      IconPack.outlined => Icons.account_balance_wallet_outlined,
      IconPack.filled => Icons.account_balance_wallet,
      IconPack.rounded => Icons.account_balance_wallet_rounded,
      IconPack.sharp => Icons.account_balance_wallet_sharp,
    };

/// 功能模块图标（随图标风格替换；含各变体，选中态同源）
IconData moduleIcon(AppModule module, IconPack pack) => switch (module) {
      AppModule.bills => switch (pack) {
          IconPack.outlined => Icons.receipt_long_outlined,
          IconPack.filled => Icons.receipt_long,
          IconPack.rounded => Icons.receipt_long_rounded,
          IconPack.sharp => Icons.receipt_long_sharp,
        },
      AppModule.categories => switch (pack) {
          IconPack.outlined => Icons.category_outlined,
          IconPack.filled => Icons.category,
          IconPack.rounded => Icons.category_rounded,
          IconPack.sharp => Icons.category_sharp,
        },
      AppModule.recurring => switch (pack) {
          IconPack.outlined => Icons.repeat_outlined,
          IconPack.filled => Icons.repeat,
          IconPack.rounded => Icons.repeat_rounded,
          IconPack.sharp => Icons.repeat_sharp,
        },
      AppModule.reports => switch (pack) {
          IconPack.outlined => Icons.bar_chart_outlined,
          IconPack.filled => Icons.bar_chart,
          IconPack.rounded => Icons.bar_chart_rounded,
          IconPack.sharp => Icons.bar_chart_sharp,
        },
      AppModule.calendar => switch (pack) {
          IconPack.outlined => Icons.calendar_month_outlined,
          IconPack.filled => Icons.calendar_month,
          IconPack.rounded => Icons.calendar_month_rounded,
          IconPack.sharp => Icons.calendar_month_sharp,
        },
    };
