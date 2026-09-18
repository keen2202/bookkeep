import '../icons/bk_category_icons.dart';

/// 分类 seed `iconName` → BK-ICON 设计 ID 映射（P2；BK-IC-050）。
///
/// 保留 DB seed / 业务层 `iconName` 字符串契约，只更换底层绘制；
/// 兼容原 [categoryIcon] 调用名，返回可直接交给 `BkIcon` 的
/// `bk.cat.<iconName>` 设计 ID。未知名称回退 `bk.cat.category`。
String categoryIcon(String iconName) => BkCategoryCatalog.id(iconName);

/// 语义化别名（与 `moduleBkIcon` 对称）。
String categoryBkIcon(String iconName) => categoryIcon(iconName);

/// 分类图标库（分类新建/编辑图标选择器，BK-DOC-26 需求7）：
/// 按消费场景语义分组，组名 → 图标名列表；全部名称在 [BkCategoryCatalog] 中
/// 定义，并由 `bk.cat.*` Painter 渲染。
const categoryIconGroups = <(String, List<String>)>[
  (
    '餐饮',
    [
      'restaurant', 'free_breakfast', 'lunch_dining', 'dinner_dining',
      'delivery_dining', 'local_cafe', 'fastfood', 'ramen_dining',
      'set_meal', 'cookie', 'icecream', 'cake', 'local_bar',
    ]
  ),
  (
    '交通',
    [
      'directions_bus', 'directions_subway', 'directions_car', 'local_taxi',
      'pedal_bike', 'two_wheeler', 'train', 'tram', 'flight',
      'local_gas_station', 'local_parking', 'local_shipping',
    ]
  ),
  (
    '购物',
    [
      'shopping_cart', 'shopping_bag', 'local_mall', 'local_grocery_store',
      'store', 'storefront', 'checkroom', 'face_retouching_natural',
      'devices_other',
    ]
  ),
  (
    '居家',
    [
      'home', 'house', 'home_work', 'apartment', 'bolt', 'wifi',
      'kitchen', 'cleaning_services', 'bathtub', 'bed', 'chair',
      'handyman', 'pets',
    ]
  ),
  (
    '娱乐',
    [
      'movie', 'sports_esports', 'videogame_asset', 'music_note',
      'camera_alt', 'hiking', 'fitness_center', 'sports_soccer', 'pool',
      'attractions',
    ]
  ),
  (
    '医疗',
    [
      'medical_services', 'local_hospital', 'medication', 'vaccination',
      'monitor_heart', 'health_and_safety',
    ]
  ),
  (
    '教育',
    ['school', 'menu_book', 'auto_stories', 'cast_for_education', 'science']
  ),
  (
    '人情',
    [
      'card_giftcard', 'redeem', 'celebration', 'volunteer_activism',
      'handshake', 'favorite',
    ]
  ),
  (
    '通讯',
    ['phone_iphone', 'call', 'network_cell', 'email', 'chat']
  ),
  (
    '金融',
    [
      'account_balance', 'credit_card', 'payments', 'savings', 'paid',
      'show_chart', 'trending_up', 'percent', 'currency_exchange',
      'request_quote', 'receipt_long', 'shield', 'sell',
    ]
  ),
  ('其他', ['tag', 'category', 'label', 'edit', 'more_horiz']),
];
