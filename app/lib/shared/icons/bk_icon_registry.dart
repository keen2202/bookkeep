import 'package:flutter/material.dart';

import 'bk_category_icons.dart';
import 'bk_icons.dart';
import 'painters/bk_act_entry_painter.dart';
import 'painters/bk_bill_empty_painter.dart';
import 'painters/bk_bill_filter_painter.dart';
import 'painters/bk_bill_list_painter.dart';
import 'painters/bk_bill_transfer_painter.dart';
import 'painters/bk_category_painter.dart';
import 'painters/bk_nav_bills_painter.dart';
import 'painters/bk_nav_reports_painter.dart';
import 'painters/bk_rpt_bars_painter.dart';
import 'painters/bk_rpt_calendar_painter.dart';
import 'painters/bk_rpt_empty_painter.dart';
import 'painters/bk_rpt_hide_amount_painter.dart';
import 'painters/bk_rpt_period_painter.dart';
import 'painters/bk_rpt_pie_painter.dart';
import 'painters/bk_status_lock_painter.dart';
import 'painters/bk_status_ok_painter.dart';
import 'painters/bk_status_sync_painter.dart';
import 'painters/bk_status_warn_painter.dart';

/// name → Painter 工厂（BK-DOC-35 §4.3；BK-IC-001）。
typedef BkIconPainterFactory = CustomPainter Function({
  required Color color,
  required bool selected,
  double? selectedT,
});

/// BK-ICON 注册表：设计 ID → CustomPainter。
///
/// 未知 ID 策略（35 假设 A3 / §4.5）：
/// - debug：assert 失败，暴露漏注册；
/// - release：回退 `Icons.category`（[materialFallback] 仅覆盖未迁移 ID；
///   Phase 4（BK-IC-044）后正式路径不得依赖 fallback）。
abstract final class BkIconRegistry {
  static final Map<String, BkIconPainterFactory> _factories =
      <String, BkIconPainterFactory>{};

  /// 注册单个图标（图标模块初始化时调用）
  static void register(String name, BkIconPainterFactory factory) {
    _factories[name] = factory;
  }

  /// 是否已注册
  static bool isRegistered(String name) => _factories.containsKey(name);

  /// 已注册 ID 集合（测试/扫描用）
  static Set<String> get registeredNames => _factories.keys.toSet();

  /// 解析 Painter；未注册时 debug assert，release 返回 null
  static CustomPainter? resolve(
    String name, {
    required Color color,
    required bool selected,
    double? selectedT,
  }) {
    final factory = _factories[name];
    if (factory == null) {
      assert(false, 'BkIcon 未注册: $name（请在 bk_icon_registry 注册）');
      return null;
    }
    return factory(
      color: color,
      selected: selected,
      selectedT: selectedT,
    );
  }

  /// 过渡期 Material 回退（34 §9.4；A3：仅未迁移 ID）
  static IconData? materialFallback(String name) => _fallbacks[name];

  static const Map<String, IconData> _fallbacks = <String, IconData>{
    // 首期已迁移 ID 无 fallback；分类库（P2）迁移前可在此临时映射
  };

  /// 首次使用时惰性注册首期图标（避免重复 map 写入）
  static bool _bootstrapped = false;

  /// 确保首期最小集已注册（幂等）
  static void ensureInitialized() {
    if (_bootstrapped) return;
    _bootstrapped = true;
    _registerFirstWave();
    _registerCategoryLibrary();
  }

  static void _registerFirstWave() {
    register(
      BkIcons.bills,
      ({required color, required selected, selectedT}) =>
          BkNavBillsPainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.reports,
      ({required color, required selected, selectedT}) =>
          BkNavReportsPainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.entry,
      ({required color, required selected, selectedT}) =>
          BkActEntryPainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.billList,
      ({required color, required selected, selectedT}) =>
          BkBillListPainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.billTransfer,
      ({required color, required selected, selectedT}) =>
          BkBillTransferPainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.billEmpty,
      ({required color, required selected, selectedT}) =>
          BkBillEmptyPainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.billFilter,
      ({required color, required selected, selectedT}) =>
          BkBillFilterPainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.rptPie,
      ({required color, required selected, selectedT}) =>
          BkRptPiePainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.rptBars,
      ({required color, required selected, selectedT}) =>
          BkRptBarsPainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.rptCalendar,
      ({required color, required selected, selectedT}) =>
          BkRptCalendarPainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.rptHideAmount,
      ({required color, required selected, selectedT}) =>
          BkRptHideAmountPainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.rptEmpty,
      ({required color, required selected, selectedT}) =>
          BkRptEmptyPainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.rptPeriod,
      ({required color, required selected, selectedT}) =>
          BkRptPeriodPainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.statusSync,
      ({required color, required selected, selectedT}) =>
          BkStatusSyncPainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.statusLock,
      ({required color, required selected, selectedT}) =>
          BkStatusLockPainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.statusWarn,
      ({required color, required selected, selectedT}) =>
          BkStatusWarnPainter(color: color, selected: selected, selectedT: selectedT),
    );
    register(
      BkIcons.statusOk,
      ({required color, required selected, selectedT}) =>
          BkStatusOkPainter(color: color, selected: selected, selectedT: selectedT),
    );
  }

  /// 分类库（P2；BK-IC-050）：保留 seed `iconName` 契约，全部映射为
  /// `bk.cat.<iconName>` 通用 Painter；未知名称统一回退 `bk.cat.category`。
  static void _registerCategoryLibrary() {
    for (final iconName in BkCategoryCatalog.names) {
      register(
        BkCategoryCatalog.id(iconName),
        ({required color, required selected, selectedT}) => BkCategoryPainter(
          iconName: iconName,
          color: color,
          selected: selected,
          selectedT: selectedT,
        ),
      );
    }
  }
}
