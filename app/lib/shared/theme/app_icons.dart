import '../icons/bk_icons.dart';

/// 功能模块（底部导航主 Tab；BK-DOC-28 需求6：分类入口下沉设置后
/// 收敛为两模块，记账入口为底栏中央动作按钮而非 Tab）
enum AppModule {
  bills('账单'),
  reports('报表');

  const AppModule(this.label);
  final String label;
}

/// 功能模块 BK-ICON 设计 ID（BK-IC-011 / AC-01）。
///
/// 正式路径不再返回 Material `Icons.*`；底栏经 `BkGlassIcon` 渲染。
String moduleBkIcon(AppModule module) => switch (module) {
      AppModule.bills => BkIcons.bills,
      AppModule.reports => BkIcons.reports,
    };
