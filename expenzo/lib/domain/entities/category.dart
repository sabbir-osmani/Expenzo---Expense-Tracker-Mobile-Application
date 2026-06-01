import 'package:equatable/equatable.dart';
import '../../core/enums/transaction_type.dart';
import '../../data/models/category_model.dart';

class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.iconName,
    required this.colorHex,
    required this.isDefault,
    required this.isActive,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final TransactionType type;
  final String iconName;
  final String colorHex;
  final bool isDefault;
  final bool isActive;
  final int sortOrder;

  factory Category.fromModel(CategoryModel m) {
    return Category(
      id: m.id,
      name: m.name,
      type: m.type,
      iconName: m.iconName,
      colorHex: m.colorHex,
      isDefault: m.isDefault,
      isActive: m.isActive,
      sortOrder: m.sortOrder,
    );
  }

  CategoryModel toModel() {
    return CategoryModel(
      id: id,
      name: name,
      type: type,
      iconName: iconName,
      colorHex: colorHex,
      isDefault: isDefault,
      isActive: isActive,
      sortOrder: sortOrder,
    );
  }

  /// Returns a safe fallback category for deleted/missing categories.
  static Category get unknown => const Category(
        id: 'unknown',
        name: 'Unknown',
        type: TransactionType.expense,
        iconName: 'help_outline',
        colorHex: '#9E9E9E',
        isDefault: false,
        isActive: false,
        sortOrder: 9999,
      );

  @override
  List<Object?> get props =>
      [id, name, type, iconName, colorHex, isDefault, isActive, sortOrder];
}