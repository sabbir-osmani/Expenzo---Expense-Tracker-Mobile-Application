import 'package:flutter/material.dart';

class IconUtils {
  IconUtils._();

  static IconData fromName(String name) {
    return _map[name] ?? Icons.label_outline;
  }

  static const Map<String, IconData> _map = {
    'school': Icons.school,
    'work': Icons.work,
    'emoji_events': Icons.emoji_events,
    'account_balance_wallet': Icons.account_balance_wallet,
    'laptop': Icons.laptop,
    'card_giftcard': Icons.card_giftcard,
    'add_circle': Icons.add_circle,
    'menu_book': Icons.menu_book,
    'account_balance': Icons.account_balance,
    'medication': Icons.medication,
    'local_hospital': Icons.local_hospital,
    'family_restroom': Icons.family_restroom,
    'favorite': Icons.favorite,
    'people': Icons.people,
    'restaurant': Icons.restaurant,
    'fastfood': Icons.fastfood,
    'directions_bus': Icons.directions_bus,
    'directions_car': Icons.directions_car,
    'person': Icons.person,
    'more_horiz': Icons.more_horiz,
    'savings': Icons.savings,
    'money_off': Icons.money_off,
    'shield': Icons.shield,
    'help_outline': Icons.help_outline,
    'category': Icons.category,
    'attach_money': Icons.attach_money,
    'shopping_bag': Icons.shopping_bag,
    'local_grocery_store': Icons.local_grocery_store,
    'phone_android': Icons.phone_android,
    'electric_bolt': Icons.electric_bolt,
    'home': Icons.home,
    'fitness_center': Icons.fitness_center,
    'sports_esports': Icons.sports_esports,
    'flight': Icons.flight,
    'hotel': Icons.hotel,
    'local_cafe': Icons.local_cafe,
    'celebration': Icons.celebration,
    'pets': Icons.pets,
    'child_care': Icons.child_care,
    'subscriptions': Icons.subscriptions,
    'build': Icons.build,
    'star': Icons.star,
    'trending_up': Icons.trending_up,
    // Transfer internal icon.
    'swap_horiz': Icons.swap_horiz,
    'account_balance_outlined': Icons.account_balance,
  };

  /// Available icons for the category icon picker (user-facing only).
  static const List<String> availableIcons = [
    'category', 'attach_money', 'work', 'school', 'laptop',
    'shopping_bag', 'local_grocery_store', 'restaurant', 'fastfood',
    'local_cafe', 'directions_bus', 'directions_car', 'flight',
    'hotel', 'home', 'electric_bolt', 'phone_android', 'medication',
    'local_hospital', 'fitness_center', 'sports_esports', 'celebration',
    'pets', 'child_care', 'family_restroom', 'favorite', 'people',
    'person', 'card_giftcard', 'emoji_events', 'savings', 'account_balance',
    'account_balance_wallet', 'money_off', 'shield', 'subscriptions',
    'build', 'star', 'trending_up', 'menu_book', 'more_horiz',
  ];
}