/// BK-ICON 设计 ID → 代码常量（BK-DOC-34 §6 / §11；BK-IC-004）。
///
/// 字符串与设计侧 `bk.<族>.<语义>[.<变体>]` 一一对应，
/// 业务代码只允许引用本类常量，禁止手写字符串字面量。
abstract final class BkIcons {
  // ── nav：底部导航 ──────────────────────────────────────────
  static const String bills = 'bk.nav.bills';
  static const String reports = 'bk.nav.reports';

  // ── act：底栏中央动作 ─────────────────────────────────────
  static const String entry = 'bk.act.entry';

  // ── bill：账单链路 ────────────────────────────────────────
  /// P2 储备：产品决策账单列表/转账图标采用 Material，暂不接生产。
  static const String billList = 'bk.bill.list';
  static const String billTransfer = 'bk.bill.transfer';
  static const String billEmpty = 'bk.bill.empty';
  static const String billFilter = 'bk.bill.filter';

  // ── rpt：报表链路 ─────────────────────────────────────────
  static const String rptPie = 'bk.rpt.pie';
  static const String rptBars = 'bk.rpt.bars';
  static const String rptCalendar = 'bk.rpt.calendar';

  /// P2 储备：产品定义仅由 `amountMaskProvider` 自动脱敏，暂不接手动入口。
  static const String rptHideAmount = 'bk.rpt.hide-amount';
  static const String rptEmpty = 'bk.rpt.empty';
  static const String rptPeriod = 'bk.rpt.period';

  // ── status：状态图形 ──────────────────────────────────────
  static const String statusSync = 'bk.status.sync';
  static const String statusLock = 'bk.status.lock';
  static const String statusWarn = 'bk.status.warn';
  static const String statusOk = 'bk.status.ok';

  /// 首期最小集（34 §11 P0 + P1）；status.ok 虽列 P2，
  /// 但 BK-IC-041 同步 idle 已无 Material 替代，故随本次一并落地。
  static const List<String> firstWave = [
    bills,
    reports,
    entry,
    billEmpty,
    billFilter,
    rptPie,
    rptBars,
    rptCalendar,
    rptEmpty,
    rptPeriod,
    statusSync,
    statusLock,
    statusWarn,
    statusOk,
  ];

  /// nav 族：启用 Tab 选中 fill 双态（34 §8；35 §4.2）
  static const List<String> navFamily = [bills, reports];

  /// 判断 ID 是否属于 nav 族（selected 语义仅对 nav 生效）
  static bool isNav(String name) =>
      name == bills || name == reports;
}
