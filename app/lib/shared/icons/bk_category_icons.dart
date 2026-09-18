import 'bk_icons.dart';

/// 分类 seed `iconName` → BK-ICON 设计 ID 目录（BK-IC-050）。
///
/// 保留既有 `iconName` 字符串契约；本文件只负责名称到 `bk.cat.*`
/// 设计 ID 的稳定映射，不读取/写入 DB seed。未知名称回退通用 `category`。
abstract final class BkCategoryCatalog {
  BkCategoryCatalog._();

  /// 全部分组/seed 支持名称（覆盖 `categoryIconGroups`，另含历史 iconName）
  static const List<String> names = <String>[
    'account_balance',
    'apartment',
    'attractions',
    'auto_stories',
    'bathtub',
    'bed',
    'bolt',
    'cake',
    'call',
    'camera_alt',
    'card_giftcard',
    'cast_for_education',
    'category',
    'celebration',
    'chair',
    'chat',
    'checkroom',
    'cleaning_services',
    'cookie',
    'credit_card',
    'currency_exchange',
    'delivery_dining',
    'devices_other',
    'dinner_dining',
    'directions_bus',
    'directions_car',
    'directions_subway',
    'donate',
    'edit',
    'email',
    'face_retouching_natural',
    'fastfood',
    'favorite',
    'fitness_center',
    'flight',
    'free_breakfast',
    'handshake',
    'handyman',
    'health_and_safety',
    'hiking',
    'home',
    'home_work',
    'house',
    'icecream',
    'kitchen',
    'label',
    'local_bar',
    'local_cafe',
    'local_gas_station',
    'local_grocery_store',
    'local_hospital',
    'local_mall',
    'local_parking',
    'local_shipping',
    'local_taxi',
    'lunch_dining',
    'medical_services',
    'medication',
    'menu_book',
    'monitor_heart',
    'more_horiz',
    'movie',
    'music_note',
    'network_cell',
    'paid',
    'payments',
    'pedal_bike',
    'percent',
    'pets',
    'phone_iphone',
    'pool',
    'ramen_dining',
    'receipt_long',
    'redeem',
    'request_quote',
    'restaurant',
    'savings',
    'school',
    'science',
    'sell',
    'set_meal',
    'shield',
    'shopping_bag',
    'shopping_cart',
    'show_chart',
    'sports_esports',
    'sports_soccer',
    'store',
    'storefront',
    'tag',
    'train',
    'tram',
    'trending_up',
    'two_wheeler',
    'vaccination',
    'videogame_asset',
    'volunteer_activism',
    'wifi',
  ];

  static final Set<String> _nameSet = names.toSet();

  /// 未知名称的通用图标名（`bk.cat.category`）
  static const String fallbackIconName = 'category';

  /// 未知名称的 BK-ICON 设计 ID
  static const String fallbackId = BkIcons.catFallback;

  static bool contains(String iconName) => _nameSet.contains(iconName);

  /// seed `iconName` → `bk.cat.<iconName>`；未知名称回退 [fallbackId]。
  static String id(String iconName) {
    final supported = contains(iconName) ? iconName : fallbackIconName;
    return '${BkIcons.catPrefix}$supported';
  }
}
