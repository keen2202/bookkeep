import 'package:drift/drift.dart';

import '../../core/constants/constants.dart';
import '../local/database.dart';

/// ISO 4217 常用币种（code: [name, symbol]）；主币种 CNY 汇率 1.0
const currencySeed = <String, List<String>>{
  'CNY': ['人民币', '¥'], 'USD': ['美元', r'$'], 'EUR': ['欧元', '€'],
  'JPY': ['日元', '¥'], 'GBP': ['英镑', '£'], 'HKD': ['港币', r'HK$'],
  'TWD': ['新台币', r'NT$'], 'KRW': ['韩元', '₩'], 'SGD': ['新加坡元', r'S$'],
  'AUD': ['澳元', r'A$'], 'CAD': ['加元', r'C$'], 'NZD': ['新西兰元', r'NZ$'],
  'CHF': ['瑞士法郎', 'CHF'], 'SEK': ['瑞典克朗', 'kr'], 'NOK': ['挪威克朗', 'kr'],
  'DKK': ['丹麦克朗', 'kr'], 'THB': ['泰铢', '฿'], 'MYR': ['马来西亚林吉特', 'RM'],
  'IDR': ['印尼盾', 'Rp'], 'PHP': ['菲律宾比索', '₱'], 'VND': ['越南盾', '₫'],
  'INR': ['印度卢比', '₹'], 'PKR': ['巴基斯坦卢比', '₨'], 'BDT': ['孟加拉塔卡', '৳'],
  'LKR': ['斯里兰卡卢比', 'Rs'], 'MMK': ['缅甸元', 'K'], 'KHR': ['柬埔寨瑞尔', '៛'],
  'LAK': ['老挝基普', '₭'], 'NPR': ['尼泊尔卢比', 'Rs'], 'MOP': ['澳门元', r'MOP$'],
  'RUB': ['俄罗斯卢布', '₽'], 'UAH': ['乌克兰格里夫纳', '₴'], 'BYN': ['白俄罗斯卢布', 'Br'],
  'PLN': ['波兰兹罗提', 'zł'], 'CZK': ['捷克克朗', 'Kč'], 'HUF': ['匈牙利福林', 'Ft'],
  'RON': ['罗马尼亚列伊', 'lei'], 'BGN': ['保加利亚列弗', 'лв'], 'RSD': ['塞尔维亚第纳尔', 'дин'],
  'HRK': ['克罗地亚库纳', 'kn'], 'TRY': ['土耳其里拉', '₺'], 'ILS': ['以色列新谢克尔', '₪'],
  'AED': ['阿联酋迪拉姆', 'د.إ'], 'SAR': ['沙特里亚尔', '﷼'], 'QAR': ['卡塔尔里亚尔', '﷼'],
  'KWD': ['科威特第纳尔', 'د.ك'], 'BHD': ['巴林第纳尔', 'د.ب'], 'OMR': ['阿曼里亚尔', '﷼'],
  'JOD': ['约旦第纳尔', 'د.ا'], 'LBP': ['黎巴嫩镑', 'ل.ل'], 'IQD': ['伊拉克第纳尔', 'ع.د'],
  'IRR': ['伊朗里亚尔', '﷼'], 'AFN': ['阿富汗尼', '؋'], 'EGP': ['埃及镑', 'E£'],
  'MAD': ['摩洛哥迪拉姆', 'د.م.'], 'DZD': ['阿尔及利亚第纳尔', 'دج'], 'TND': ['突尼斯第纳尔', 'د.ت'],
  'LYD': ['利比亚第纳尔', 'ل.د'], 'NGN': ['尼日利亚奈拉', '₦'], 'GHS': ['加纳塞地', '₵'],
  'KES': ['肯尼亚先令', 'KSh'], 'ETB': ['埃塞俄比亚比尔', 'Br'], 'TZS': ['坦桑尼亚先令', 'TSh'],
  'UGX': ['乌干达先令', 'USh'], 'ZAR': ['南非兰特', 'R'], 'BRL': ['巴西雷亚尔', r'R$'],
  'ARS': ['阿根廷比索', r'$'], 'CLP': ['智利比索', r'$'], 'PEN': ['秘鲁索尔', 'S/'],
  'COP': ['哥伦比亚比索', r'$'], 'MXN': ['墨西哥比索', r'$'], 'UYU': ['乌拉圭比索', r'$U'],
  'VES': ['委内瑞拉玻利瓦尔', 'Bs'], 'CUP': ['古巴比索', r'$'], 'GTQ': ['危地马拉格查尔', 'Q'],
  'HNL': ['洪都拉斯伦皮拉', 'L'], 'NIO': ['尼加拉瓜科多巴', r'C$'], 'CRC': ['哥斯达黎加科朗', '₡'],
  'PAB': ['巴拿马巴波亚', 'B/.'], 'DOP': ['多米尼加比索', r'RD$'], 'JMD': ['牙买加元', r'J$'],
  'TTD': ['特立尼达和多巴哥元', r'TT$'], 'BBD': ['巴巴多斯元', r'Bds$'], 'BSD': ['巴哈马元', r'$'],
  'BZD': ['伯利兹元', r'BZ$'], 'XCD': ['东加勒比元', r'EC$'], 'HTG': ['海地古德', 'G'],
  'PYG': ['巴拉圭瓜拉尼', '₲'], 'BOB': ['玻利维亚诺', 'Bs'], 'AWG': ['阿鲁巴弗罗林', 'ƒ'],
  'CUC': ['古巴可兑换比索', r'CUC$'], 'GYD': ['圭亚那元', r'G$'], 'SRD': ['苏里南元', r'$'],
  'ALL': ['阿尔巴尼亚列克', 'L'], 'AMD': ['亚美尼亚德拉姆', '֏'], 'AZN': ['阿塞拜疆马纳特', '₼'],
  'GEL': ['格鲁吉亚拉里', '₾'], 'KZT': ['哈萨克斯坦坚戈', '₸'], 'KGS': ['吉尔吉斯斯坦索姆', 'сом'],
  'TJS': ['塔吉克斯坦索莫尼', 'ЅМ'], 'TMT': ['土库曼斯坦马纳特', 'm'], 'UZS': ['乌兹别克斯坦苏姆', 'сўм'],
  'MNT': ['蒙古图格里克', '₮'], 'FJD': ['斐济元', r'FJ$'], 'PGK': ['巴布亚新几内亚基那', 'K'],
  'SBD': ['所罗门群岛元', r'SI$'], 'WST': ['萨摩亚塔拉', r'WS$'], 'TOP': ['汤加潘加', r'T$'],
  'VUV': ['瓦努阿图瓦图', 'VT'], 'BND': ['文莱元', r'B$'], 'MVR': ['马尔代夫拉菲亚', 'Rf'],
  'KMF': ['科摩罗法郎', 'CF'], 'MGA': ['马达加斯加阿里亚里', 'Ar'], 'MUR': ['毛里求斯卢比', '₨'],
  'SCR': ['塞舌尔卢比', '₨'], 'SYP': ['叙利亚镑', '£S'], 'YER': ['也门里亚尔', '﷼'],
  'BAM': ['波黑可兑换马克', 'KM'], 'MKD': ['北马其顿第纳尔', 'ден'], 'MDL': ['摩尔多瓦列伊', 'L'],
  'XAF': ['中非法郎', 'FCFA'], 'XOF': ['西非法郎', 'CFA'], 'XPF': ['太平洋法郎', '₣'],
  'ANG': ['荷属安的列斯盾', 'ƒ'], 'CDF': ['刚果法郎', 'FC'], 'RWF': ['卢旺达法郎', 'FRw'],
  'BIF': ['布隆迪法郎', 'FBu'], 'DJF': ['吉布提法郎', 'Fdj'], 'ERN': ['厄立特里亚纳克法', 'Nfk'],
  'GMD': ['冈比亚达拉西', 'D'], 'GNF': ['几内亚法郎', 'FG'], 'LRD': ['利比里亚元', r'$'],
  'MWK': ['马拉维克瓦查', 'MK'], 'MZN': ['莫桑比克梅蒂卡尔', 'MT'], 'NAD': ['纳米比亚元', r'$'],
  'SLL': ['塞拉利昂利昂', 'Le'], 'SOS': ['索马里先令', 'Sh'], 'SSP': ['南苏丹镑', '£'],
  'SDG': ['苏丹镑', '£SD'], 'SZL': ['斯威士兰里兰吉尼', 'E'], 'ZMW': ['赞比亚克瓦查', 'ZK'],
  'ZWL': ['津巴布韦元', r'$'], 'BWP': ['博茨瓦纳普拉', 'P'], 'LSL': ['莱索托洛蒂', 'L'],
  'MRU': ['毛里塔尼亚乌吉亚', 'UM'], 'STN': ['圣多美多布拉', 'Db'], 'CVE': ['佛得角埃斯库多', 'Esc'],
  'AOA': ['安哥拉宽扎', 'Kz'], 'FKP': ['福克兰镑', '£'], 'GIP': ['直布罗陀镑', '£'],
  'SHP': ['圣赫勒拿镑', '£'], 'IMP': ['马恩岛镑', '£'], 'JEP': ['泽西镑', '£'],
  'GGP': ['根西镑', '£'], 'KYD': ['开曼元', r'CI$'], 'BMD': ['百慕大元', r'$'],
};

/// 币种仓库（Spec §4.5 / BK-T-014）：seed 安装（幂等）+ 汇率读写
class CurrencyRepository {
  CurrencyRepository(this.db);
  final AppDatabase db;

  static const seedMetaKey = 'currency_seed_version';

  /// 安装内置币种（幂等：仅当版本变化时插入缺失项；主币种 CNY 汇率 1.0）
  Future<int> installSeeds() async {
    final rows = await (db.select(db.appMeta)..where((t) => t.key.equals(seedMetaKey))).get();
    if (rows.isNotEmpty && rows.single.value == '1') return 0;

    final now = DateTime.now().toUtc();
    var inserted = 0;
    await db.transaction(() async {
      for (final entry in currencySeed.entries) {
        final existing = await (db.select(db.currencies)
              ..where((t) => t.code.equals(entry.key)))
            .get();
        if (existing.isNotEmpty) continue;
        await db.into(db.currencies).insert(CurrenciesCompanion.insert(
              code: entry.key,
              name: entry.value[0],
              symbol: Value(entry.value.length > 1 ? entry.value[1] : ''),
              rateScaled: entry.key == 'CNY' ? kRateScale : 100000, // 默认 0.1 占位
              updatedAt: now,
            ));
        inserted++;
      }
      await db.into(db.appMeta).insert(
            AppMetaCompanion.insert(key: seedMetaKey, value: '1'),
            onConflict: DoUpdate((_) => const AppMetaCompanion(value: Value('1'))),
          );
    });
    return inserted;
  }

  /// 汇率（相对主币种，kRateScale 刻度）；未配置时回退默认 1:1
  Future<int> rateScaled(String code) async {
    if (code == 'CNY') return kRateScale;
    final row = await (db.select(db.currencies)..where((t) => t.code.equals(code)))
        .getSingleOrNull();
    return row?.rateScaled ?? kRateScale;
  }

  Future<void> setManualRate(String code, double rate) async {
    await db.into(db.currencies).insert(
          CurrenciesCompanion.insert(
            code: code,
            name: code,
            rateScaled: (rate * kRateScale).round(),
            isManual: const Value(true),
            updatedAt: DateTime.now().toUtc(),
          ),
          onConflict: DoUpdate((_) => CurrenciesCompanion(
                rateScaled: Value((rate * kRateScale).round()),
                isManual: const Value(true),
                updatedAt: Value(DateTime.now().toUtc()),
              )),
        );
  }

  Future<List<Currency>> listCurrencies() => db.select(db.currencies).get();
}
