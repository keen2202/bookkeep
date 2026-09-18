import 'dart:ui';

/// 分类库 seed `iconName` 的 BK 线性 Path 源（BK-IC-050 / 34 §1.3·§11 P2）。
///
/// 设计原则：
/// - 保留 DB seed `iconName` 字符串契约，不新增/修改 seed 字段；
/// - 每条 Path 使用 24×24 栅格、stroke 1.75、round cap/join 的线性语言；
/// - 命令字符串在首次使用时编译为 `Path` 并缓存，热路径无 `Path()` 分配；
/// - 非 SVG 运行时：仅使用 Flutter [Path] 指令，不引入图片/SVG 资源。
///
/// 指令：`M/L` 2 参、`Q` 4 参、`C` 6 参、`O cx cy r`、
/// `R x y w h r`（圆角矩形）、`Z` 闭合。
class BkCategoryPaths {
  BkCategoryPaths._();

  /// seed `iconName` → 复用相同路径的语义别名（与 Material 源一致）
  static const Map<String, String> aliases = <String, String>{
    'auto_stories': 'menu_book',
    'donate': 'volunteer_activism',
    'local_mall': 'shopping_bag',
    'tag': 'sell',
    'tram': 'train',
  };

  static const Map<String, String> commands = <String, String>{
    'account_balance':
        'M 3 9 L 12 4 L 21 9 M 5 9 L 5 17 M 9 9 L 9 17 M 15 9 L 15 17 M 19 9 L 19 17 M 3 20 L 21 20',
    'apartment':
        'M 5 20 L 5 4 L 13 4 L 13 20 M 15 20 L 15 9 L 20 9 L 20 20 M 3 20 L 21 20 M 8 7 L 10 7 M 8 10 L 10 10 M 8 13 L 10 13 M 8 16 L 10 16 M 17 12 L 18 12 M 17 15 L 18 15',
    'attractions':
        'O 12 13 7 M 12 6 L 12 20 M 5 13 L 19 13 M 7 8 L 17 18 M 17 8 L 7 18 M 8 21 L 16 21',
    'bathtub':
        'M 3 12 L 21 12 Q 21 19 12 19 Q 3 19 3 12 Z M 6 12 Q 6 5 8 4 Q 10 4 10 6 M 6 19 L 6 21 M 18 19 L 18 21 M 9 12 L 9 9',
    'bed':
        'M 3 20 L 3 8 L 5 8 L 5 15 L 21 15 L 21 20 M 5 11 Q 8 11 8 13 L 5 13 M 11 13 L 21 13',
    'bolt': 'M 13 3 L 6 13 L 11 13 L 10 21 L 17 11 L 12 11 Z',
    'cake':
        'M 4 13 L 20 13 L 20 20 L 4 20 Z M 4 16 L 20 16 M 8 13 L 8 9 M 8 6 O 8 6 1 M 12 13 L 12 9 M 12 6 O 12 6 1 M 16 13 L 16 9 M 16 6 O 16 6 1',
    'call':
        'M 5 4 L 9 4 L 11 9 L 8 11 Q 10 15 13 17 L 15 14 L 20 16 L 20 20 Q 15 21 10 17 Q 5 13 4 6 Z',
    'camera_alt': 'R 3 7 18 13 2 M 8 7 L 9 4 L 15 4 L 16 7 O 12 13 4',
    'card_giftcard':
        'R 3 6 18 13 2 M 3 10 L 21 10 M 7 6 L 7 19 M 12 6 Q 12 3 15 3 Q 17 3 17 5 Q 17 6 15 6 Z',
    'cast_for_education':
        'R 3 5 18 12 2 O 12 8.5 1.5 M 8 12 Q 12 9 16 12 M 3 17 L 21 17 M 10 20 L 14 20',
    'category': 'R 4 4 6 6 1 R 14 4 6 6 1 R 4 14 6 6 1 R 14 14 6 6 1',
    'celebration':
        'M 3 21 L 10 7 L 17 14 Z M 10 7 Q 14 3 18 5 M 14 9 L 20 6 M 15 12 L 21 12 M 13 14 L 16 20 M 12 4 L 12 2 M 17 8 L 19 6',
    'chair':
        'M 8 4 L 8 12 L 16 12 L 16 4 M 6 12 L 18 12 L 19 20 M 6 12 L 5 20 M 12 12 L 12 17',
    'chat':
        'M 4 5 L 20 5 L 20 16 L 13 16 L 9 20 L 9 16 L 4 16 Z M 8 10 L 16 10 M 8 13 L 13 13',
    'checkroom':
        'M 12 5 Q 12 3 10.5 3 Q 9 3 9 5 L 12 5 M 12 5 L 20 12 L 4 12 L 12 5 M 4 12 L 4 20 L 20 20 L 20 12',
    'cleaning_services':
        'R 8 8 7 13 1 M 11 4 L 15 4 L 15 8 L 11 8 Z M 8 12 L 15 12 M 12 8 L 12 4 M 15 6 L 18 3 M 18 5 L 21 5 M 19 7 L 21 9',
    'cookie': 'O 12 12 8 O 9 9 0.7 O 15 10 0.7 O 10 15 0.7 O 15 15 0.7',
    'credit_card':
        'R 3 6 18 12 2 M 3 10 L 21 10 M 6 14 L 10 14 M 14 14 L 18 14',
    'currency_exchange': 'M 4 8 L 16 8 L 13 5 M 20 16 L 8 16 L 11 19',
    'delivery_dining':
        'O 6 18 2 O 18 18 2 M 8 18 L 15 18 M 9 15 L 15 12 L 20 12 M 16 12 L 16 9 L 19 9 M 12 18 Q 13 13 18 13',
    'devices_other':
        'R 3 6 12 9 1 M 3 15 L 15 15 M 7 18 L 11 18 M 17 6 L 21 6 L 21 18 L 17 18 Z M 19 9 L 19 14',
    'dinner_dining':
        'M 4 17 L 20 17 M 6 17 Q 6 9 12 7 Q 18 9 18 17 M 11 6 L 13 6 M 12 6 L 12 4 O 12 3 0.7',
    'directions_bus':
        'R 4 4 16 14 2 M 4 9 L 20 9 M 8 5 L 8 8 M 16 5 L 16 8 M 9 12 L 15 12 O 7.5 19 1.5 O 16.5 19 1.5',
    'directions_car':
        'M 4 14 L 5 9 L 8 6 L 16 6 L 19 9 L 20 14 Z M 8 9 L 16 9 M 7 14 L 7 17 M 17 14 L 17 17 O 7 17 1.5 O 17 17 1.5 M 4 14 L 20 14',
    'directions_subway':
        'R 6 3 12 14 2 M 6 8 L 18 8 M 9 4 L 9 7 M 15 4 L 15 7 M 9 13 L 15 13 M 7 17 L 9 20 M 17 17 L 15 20 M 8 20 L 16 20',
    'edit': 'M 4 20 L 5 15 L 16 4 L 20 8 L 9 19 Z M 15 5 L 19 9 M 4 20 L 8 19',
    'email': 'R 3 6 18 12 2 M 3 7 L 12 13 L 21 7 M 3 18 L 9 13 M 21 18 L 15 13',
    'face_retouching_natural':
        'O 11 13 7 O 8.5 11 1 O 13.5 11 1 M 8 16 Q 11 19 14 16 M 19 3 L 19 7 M 17 5 L 21 5',
    'fastfood':
        'M 5 13 Q 12 8 19 13 L 19 15 L 5 15 Z M 5 17 L 19 17 M 6 20 L 18 20 M 9 4 L 9 10 M 12 3 L 12 10 M 15 4 L 15 10 M 7 3 L 8 10 M 16 3 L 17 10',
    'favorite':
        'M 12 20 Q 4 14 4 9 Q 4 5 8 5 Q 10 5 12 7 Q 14 5 16 5 Q 20 5 20 9 Q 20 14 12 20 Z',
    'fitness_center':
        'M 4 12 L 20 12 M 6 9 L 6 15 M 8 7 L 8 17 M 16 7 L 16 17 M 18 9 L 18 15',
    'flight':
        'M 12 3 L 13.2 8.5 L 20 13 L 20 14.5 L 13.2 12 L 13.2 17 L 15.5 18.6 L 15.5 20 L 12 18.6 L 8.5 20 L 8.5 18.6 L 10.8 17 L 10.8 12 L 4 14.5 L 4 13 L 10.8 8.5 Z',
    'free_breakfast':
        'M 5 10 L 16 10 L 15 16 Q 11 19 6 16 Z M 16 11 Q 20 11 18 15 M 8 4 Q 7 6 8 8 M 12 4 Q 11 6 12 8 M 4 21 L 20 21',
    'handshake':
        'M 3 12 L 7 8 L 11 11 L 15 7 L 21 13 M 7 8 L 12 13 M 11 11 L 16 16 Q 18 18 20 16 L 21 15 M 5 15 L 8 18 M 9 17 L 12 20',
    'handyman':
        'M 9 4 Q 4 4 4 9 Q 4 13 8 13 L 10 11 L 10 14 L 12 14 L 12 11 L 14 13 Q 18 13 18 9 Q 18 5 14 5 L 12 7 L 12 4 Z',
    'health_and_safety':
        'M 12 3 L 20 6 L 20 12 Q 20 19 12 22 Q 4 19 4 12 L 4 6 Z M 12 9 L 12 16 M 8.5 12.5 L 15.5 12.5',
    'hiking':
        'O 15 5 2 M 13 8 L 9 12 L 12 15 L 10 21 M 13 8 L 17 11 L 19 16 M 9 12 L 5 11 L 3 8 M 15 9 L 20 5',
    'home':
        'M 4 12 L 12 4 L 20 12 M 6 10 L 6 20 L 18 20 L 18 10 M 10 20 L 10 14 L 14 14 L 14 20',
    'home_work':
        'M 4 20 L 4 9 L 10 9 L 10 20 M 10 13 L 20 13 L 20 20 M 6 12 L 8 12 M 6 15 L 8 15 M 13 16 L 17 16 M 13 18 L 17 18 M 3 20 L 21 20',
    'house':
        'M 4 11 L 12 4 L 20 11 M 6 10 L 6 20 L 18 20 L 18 10 M 9 20 L 9 15 L 11 15 L 11 20 M 14 13 L 16 13 M 14 16 L 16 16',
    'icecream': 'M 8 11 L 16 11 L 12 21 Z O 9 8 3 O 15 8 3',
    'kitchen':
        'R 5 11 14 8 1 M 5 14 L 19 14 M 8 11 Q 8 6 12 6 Q 16 6 16 11 M 3 13 L 5 13 M 19 13 L 21 13 M 12 6 L 12 4',
    'label': 'M 4 10 L 10 4 L 20 4 L 20 14 L 14 20 Z O 16 8 1.5',
    'local_bar':
        'M 5 5 L 19 5 L 12 13 Z M 12 13 L 12 19 M 8 19 L 16 19 M 8 9 L 12 13',
    'local_cafe':
        'M 5 9 L 16 9 L 15 16 Q 11 19 6 16 Z M 16 10 Q 20 11 18 15 M 8 4 L 8 7 M 12 4 L 12 7',
    'local_gas_station':
        'M 5 20 L 5 6 Q 5 4 7 4 L 12 4 Q 14 4 14 6 L 14 20 Z M 7 8 L 12 8 M 16 10 L 19 10 Q 20 10 20 11 L 20 18 Q 20 20 18 20 Q 16 20 16 18 L 16 14 M 14 20 L 4 20',
    'local_grocery_store':
        'M 4 9 L 20 9 L 18 19 L 6 19 Z M 8 9 Q 8 4 12 4 Q 16 4 16 9 M 10 13 L 10.5 13.5 M 14 13 L 14.5 13.5',
    'local_hospital': 'R 5 4 14 16 2 M 12 7 L 12 17 M 8.5 12 L 15.5 12',
    'local_parking':
        'O 12 12 9 M 9 17 L 9 7 L 13 7 Q 16 7 16 10 Q 16 13 13 13 L 9 13',
    'local_shipping':
        'R 3 7 11 9 1 M 14 10 L 17 10 L 21 13 L 21 16 L 3 16 O 7 19 1.5 O 17 19 1.5 M 14 10 L 14 16 M 6 9 L 10 9 M 6 12 L 10 12',
    'local_taxi':
        'M 4 14 L 5 10 L 8 7 L 16 7 L 19 10 L 20 14 Z M 10 4 L 14 4 M 4 14 L 20 14 M 8 10 L 16 10 M 7 14 L 7 17 M 17 14 L 17 17 O 7 17 1.5 O 17 17 1.5',
    'lunch_dining':
        'M 4 10 Q 12 4 20 10 L 20 12 L 4 12 Z M 4 14 L 20 14 M 6 17 L 18 17 M 7 19 L 17 19',
    'medical_services':
        'R 4 8 16 12 2 M 9 8 L 9 5 L 15 5 L 15 8 M 12 11 L 12 17 M 9 14 L 15 14',
    'medication':
        'R 7 8 10 12 2 M 9 8 L 9 6 L 15 6 L 15 8 M 9 12 L 15 12 M 12 12 L 12 18',
    'menu_book':
        'M 12 6 Q 8 4 4 5 L 4 18 Q 8 17 12 19 Q 16 17 20 18 L 20 5 Q 16 4 12 6 Z M 12 6 L 12 19',
    'monitor_heart':
        'R 3 5 18 12 2 M 3 11 L 8 11 L 10 8 L 13 15 L 15 11 L 21 11 M 10 20 L 14 20 M 12 17 L 12 20',
    'more_horiz': 'O 6 12 1.2 O 12 12 1.2 O 18 12 1.2',
    'movie':
        'R 3 5 18 14 2 M 3 9 L 21 9 M 7 5 L 11 9 M 13 5 L 17 9 M 8 14 L 8 16 M 16 14 L 16 16 M 4 19 L 20 19',
    'music_note':
        'M 10 18 Q 10 21 8 21 Q 6 21 6 19 Q 6 17 8 17 Q 9 17 10 18 L 10 5 L 18 3 L 18 15 Q 18 18 16 18 Q 14 18 14 16 Q 14 14 16 14 Q 17 14 18 15',
    'network_cell':
        'M 4 20 L 4 16 M 9 20 L 9 12 M 14 20 L 14 8 M 19 20 L 19 4 O 5 20 0.6 O 10 20 0.6 O 15 20 0.6 O 20 20 0.6',
    'paid': 'O 12 12 9 M 7.5 12 L 10.5 15 L 16.5 9',
    'payments':
        'R 3 7 16 9 1 M 5 5 L 21 5 L 21 15 M 6 10 L 15 10 M 6 12.5 L 12 12.5',
    'pedal_bike':
        'O 6 16 3 O 18 16 3 M 6 16 L 10 10 L 15 10 L 18 16 M 10 10 L 8 16 M 15 10 L 12 7 M 11 7 L 14 7',
    'percent': 'M 6 18 L 18 6 O 7 7 2 O 17 17 2',
    'pets':
        'O 8 9 2 O 15 9 2 O 5 13 2 O 18 13 2 M 8.5 17 Q 12 21 15.5 17 Q 14 15 12 16 Q 10 15 8.5 17 Z',
    'phone_iphone': 'R 7 3 10 18 2 M 10 5 L 14 5 M 10 18 L 14 18 O 12 19 0.7',
    'pool':
        'M 4 15 Q 7 13 10 15 Q 13 17 16 15 Q 18 14 20 15 M 4 19 Q 7 17 10 19 Q 13 21 16 19 Q 18 18 20 19 M 8 8 L 10 5 L 14 7 L 16 4 M 10 5 Q 13 3 16 4',
    'ramen_dining':
        'M 4 11 L 20 11 Q 19 19 12 19 Q 5 19 4 11 Z M 8 4 L 18 10 M 10 3 L 20 9 M 9 14 Q 12 16 15 14',
    'receipt_long':
        'M 5 3 L 19 3 L 19 21 L 5 21 Z M 8 7 L 16 7 M 8 11 L 16 11 M 8 15 L 13 15',
    'redeem':
        'R 4 9 16 11 1 M 3 6 L 21 6 L 21 9 L 3 9 Z M 12 6 L 12 20 M 8 6 Q 5 6 5 4 Q 5 2 7 2 Q 10 2 12 6 M 16 6 Q 19 6 19 4 Q 19 2 17 2 Q 14 2 12 6',
    'request_quote':
        'M 6 3 L 18 3 L 18 21 L 15 19 L 12 21 L 9 19 L 6 21 Z M 9 8 L 15 8 M 9 12 L 15 12 M 9 16 L 13 16',
    'restaurant':
        'M 8 4 L 8 20 M 6 4 L 6 9 Q 8 11 10 9 M 10 4 L 10 9 M 16 4 L 16 20 M 16 4 Q 19 6 19 9 Q 19 12 16 13 L 16 20',
    'savings':
        'M 4 13 Q 4 8 9 7 L 16 7 Q 20 7 20 12 Q 20 16 16 17 L 6 17 Q 4 16 4 13 M 8 7 L 9 4 L 14 4 L 15 7 M 17 11 L 17.5 11.5 M 10 17 L 9 20 M 15 17 L 16 20 M 20 12 L 22 13',
    'school':
        'M 3 9 L 12 5 L 21 9 L 12 13 Z M 6 11 L 6 16 Q 12 20 18 16 L 18 11 M 12 13 L 12 16 M 20 9 L 20 14',
    'science':
        'M 10 3 L 10 9 L 5 19 Q 4 21 6 21 L 18 21 Q 20 21 19 19 L 14 9 L 14 3 M 8 3 L 16 3 M 8 14 L 16 14 M 12 14 L 12 21',
    'sell': 'M 3 11 L 11 3 L 21 3 L 21 13 L 13 21 Z O 17 7 1.5',
    'set_meal':
        'O 12 13 8 M 5 13 Q 9 9 13 13 Q 9 17 5 13 Z M 13 13 L 16 10 M 16 10 L 18 11 M 16 10 L 17 8 M 18 13 L 20 13',
    'shield': 'M 12 3 L 20 6 L 20 12 Q 20 19 12 22 Q 4 19 4 12 L 4 6 Z',
    'shopping_bag':
        'M 5 8 L 19 8 L 18 20 L 6 20 Z M 9 8 Q 9 4 12 4 Q 15 4 15 8 M 9 12 L 9.5 12.5 M 15 12 L 15.5 12.5',
    'shopping_cart':
        'M 3 6 L 6 6 L 9 15 L 18 15 M 6 6 L 8 12 L 18 12 L 20 7 L 6 7 O 7 19 1.5 O 17 19 1.5',
    'show_chart': 'M 3 18 L 9 12 L 13 15 L 21 6 M 16 6 L 21 6 L 21 11',
    'sports_esports':
        'R 3 8 18 9 4 M 7 11 L 10 11 M 8.5 9.5 L 8.5 12.5 O 16 10.5 1 O 18 13 1',
    'sports_soccer':
        'O 12 12 9 M 12 3 L 12 21 M 4 8 Q 12 12 20 8 M 4 16 Q 12 12 20 16',
    'store':
        'M 4 9 L 20 9 L 19 20 L 5 20 Z M 4 9 L 6 5 L 18 5 L 20 9 M 8 13 L 11 13 L 11 20 M 13 13 L 16 13 L 16 17',
    'storefront':
        'M 4 10 L 5 5 L 19 5 L 20 10 Q 18.5 12 17 10 Q 15.5 12 14 10 Q 12.5 12 11 10 Q 9.5 12 8 10 Q 6.5 12 4 10 Z M 6 11 L 6 20 L 18 20 L 18 11 M 9 15 L 12 15 L 12 20 M 14 15 L 16 15',
    'train':
        'R 5 3 14 15 2 M 5 8 L 19 8 M 9 4 L 9 7 M 15 4 L 15 7 M 8 12 L 16 12 M 7 18 L 5 21 M 17 18 L 19 21 M 9 21 L 15 21',
    'trending_up': 'M 3 17 L 10 10 L 14 14 L 21 7 M 15 7 L 21 7 L 21 13',
    'two_wheeler':
        'O 7 18 2 O 18 18 2 M 9 18 L 16 18 M 10 15 L 15 12 L 20 12 M 16 12 L 16 8 M 14 8 L 18 8 M 13 18 Q 14 14 18 14',
    'vaccination':
        'M 4 20 L 9 15 M 7 13 L 11 17 M 9 14 L 17 6 M 15 4 L 20 9 M 13 6 L 18 11 M 17 4 L 20 7 M 16 10 L 14 12',
    'videogame_asset':
        'R 4 8 16 9 4 M 8 11 L 12 11 M 10 9 L 10 13 O 17 11 1 O 19 13 1 M 9 17 L 15 17',
    'volunteer_activism':
        'M 12 13 Q 8 9 8 6 Q 8 4 10 4 Q 11 4 12 6 Q 13 4 14 4 Q 16 4 16 6 Q 16 9 12 13 Z M 3 14 Q 6 12 9 14 L 12 16 L 15 14 Q 18 12 21 14 M 3 14 L 3 20 L 21 20 L 21 14',
    'wifi':
        'M 4 11 Q 12 4 20 11 M 7 14 Q 12 9 17 14 M 10 17 Q 12 15 14 17 O 12 20 0.6',
  };

  static final Map<String, Path> _cache = <String, Path>{};

  /// 解析 seed `iconName` 的 Path；未知名称回退到通用 `category`。
  static Path resolve(String iconName) {
    final target = aliases[iconName] ?? iconName;
    final commandsForTarget = commands[target] ?? commands['category']!;
    return _cache.putIfAbsent(target, () => _build(commandsForTarget));
  }

  static Path _build(String source) {
    final path = Path();
    final tokens = source.split(' ');
    var i = 0;
    double number() => double.parse(tokens[i++]);
    while (i < tokens.length) {
      final op = tokens[i++];
      switch (op) {
        case 'M':
          path.moveTo(number(), number());
          break;
        case 'L':
          path.lineTo(number(), number());
          break;
        case 'Q':
          path.quadraticBezierTo(number(), number(), number(), number());
          break;
        case 'C':
          path.cubicTo(
            number(),
            number(),
            number(),
            number(),
            number(),
            number(),
          );
          break;
        case 'O':
          final cx = number();
          final cy = number();
          final r = number();
          path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
          break;
        case 'R':
          final x = number();
          final y = number();
          final w = number();
          final h = number();
          final r = number();
          path.addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, w, h),
              Radius.circular(r),
            ),
          );
          break;
        case 'Z':
          path.close();
          break;
        default:
          throw FormatException('Unknown BkCategoryPaths command: $op');
      }
    }
    return path;
  }
}
