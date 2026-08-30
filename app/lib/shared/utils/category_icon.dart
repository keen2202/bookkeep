import 'package:flutter/material.dart';

/// seed 中使用的图标名 → IconData 映射（矢量映射表，避免图片资源，BK-P0-003）
const _icons = <String, IconData>{
  // 餐饮
  'restaurant': Icons.restaurant,
  'free_breakfast': Icons.free_breakfast,
  'lunch_dining': Icons.lunch_dining,
  'dinner_dining': Icons.dinner_dining,
  'delivery_dining': Icons.delivery_dining,
  'local_cafe': Icons.local_cafe,
  'cookie': Icons.cookie,
  'fastfood': Icons.fastfood,
  'ramen_dining': Icons.ramen_dining,
  'set_meal': Icons.set_meal,
  'icecream': Icons.icecream,
  'cake': Icons.cake,
  'local_bar': Icons.local_bar,
  // 交通
  'directions_bus': Icons.directions_bus,
  'directions_subway': Icons.directions_subway,
  'directions_car': Icons.directions_car,
  'local_taxi': Icons.local_taxi,
  'local_gas_station': Icons.local_gas_station,
  'local_parking': Icons.local_parking,
  'flight': Icons.flight,
  'pedal_bike': Icons.pedal_bike,
  'train': Icons.train,
  'tram': Icons.tram,
  'two_wheeler': Icons.two_wheeler,
  'local_shipping': Icons.local_shipping,
  // 购物
  'local_grocery_store': Icons.local_grocery_store,
  'shopping_cart': Icons.shopping_cart,
  'shopping_bag': Icons.shopping_bag,
  'local_mall': Icons.local_mall,
  'store': Icons.store,
  'checkroom': Icons.checkroom,
  'face_retouching_natural': Icons.face_retouching_natural,
  'devices_other': Icons.devices_other,
  // 居家
  'chair': Icons.chair,
  'storefront': Icons.storefront,
  'pets': Icons.pets,
  'home': Icons.home,
  'house': Icons.house,
  'home_work': Icons.home_work,
  'apartment': Icons.apartment,
  'bolt': Icons.bolt,
  'wifi': Icons.wifi,
  'handyman': Icons.handyman,
  'kitchen': Icons.kitchen,
  'cleaning_services': Icons.cleaning_services,
  'bathtub': Icons.bathtub,
  'bed': Icons.bed,
  // 娱乐
  'sports_esports': Icons.sports_esports,
  'movie': Icons.movie,
  'videogame_asset': Icons.videogame_asset,
  'hiking': Icons.hiking,
  'fitness_center': Icons.fitness_center,
  'attractions': Icons.attractions,
  'sports_soccer': Icons.sports_soccer,
  'music_note': Icons.music_note,
  'camera_alt': Icons.camera_alt,
  'pool': Icons.pool,
  // 医疗
  'medical_services': Icons.medical_services,
  'local_hospital': Icons.local_hospital,
  'medication': Icons.medication,
  'monitor_heart': Icons.monitor_heart,
  'health_and_safety': Icons.health_and_safety,
  'vaccination': Icons.vaccination,
  // 教育
  'school': Icons.school,
  'cast_for_education': Icons.cast_for_education,
  'menu_book': Icons.menu_book,
  'auto_stories': Icons.auto_stories,
  'science': Icons.science,
  // 人情
  'favorite': Icons.favorite,
  'card_giftcard': Icons.card_giftcard,
  'redeem': Icons.redeem,
  'celebration': Icons.celebration,
  'volunteer_activism': Icons.volunteer_activism,
  'handshake': Icons.handshake,
  // 通讯
  'phone_iphone': Icons.phone_iphone,
  'call': Icons.call,
  'network_cell': Icons.network_cell,
  'email': Icons.email,
  'chat': Icons.chat,
  // 金融
  'account_balance': Icons.account_balance,
  'show_chart': Icons.show_chart,
  'shield': Icons.shield,
  'receipt_long': Icons.receipt_long,
  'request_quote': Icons.request_quote,
  'payments': Icons.payments,
  'trending_up': Icons.trending_up,
  'percent': Icons.percent,
  'savings': Icons.savings,
  'sell': Icons.sell,
  'currency_exchange': Icons.currency_exchange,
  'credit_card': Icons.credit_card,
  'paid': Icons.paid,
  // 其他
  'edit': Icons.edit,
  'more_horiz': Icons.more_horiz,
  'category': Icons.category,
  'label': Icons.label,
  'donate': Icons.volunteer_activism,
  'tag': Icons.sell,
};

IconData categoryIcon(String iconName) => _icons[iconName] ?? Icons.category;

/// 分类图标库（分类新建/编辑图标选择器，BK-DOC-26 需求7）：
/// 按消费场景语义分组，组名 → 图标名列表；全部名称在 [_icons] 中有定义。
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
