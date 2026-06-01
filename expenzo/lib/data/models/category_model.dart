import 'package:equatable/equatable.dart';
import '../../core/enums/transaction_type.dart';

class CategoryModel extends Equatable {
  const CategoryModel({
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

  // ── DB mapping ─────────────────────────────────────────────────────────────

  static const String tableName = 'categories';

  static const String colId = 'id';
  static const String colName = 'name';
  static const String colType = 'type';
  static const String colIconName = 'icon_name';
  static const String colColorHex = 'color_hex';
  static const String colIsDefault = 'is_default';
  static const String colIsActive = 'is_active';
  static const String colSortOrder = 'sort_order';

  static const String createTableSql = '''
    CREATE TABLE $tableName (
      $colId TEXT PRIMARY KEY,
      $colName TEXT NOT NULL,
      $colType TEXT NOT NULL,
      $colIconName TEXT NOT NULL,
      $colColorHex TEXT NOT NULL,
      $colIsDefault INTEGER NOT NULL DEFAULT 0,
      $colIsActive INTEGER NOT NULL DEFAULT 1,
      $colSortOrder INTEGER NOT NULL DEFAULT 0
    )
  ''';

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map[colId] as String,
      name: map[colName] as String,
      type: TransactionType.fromString(map[colType] as String),
      iconName: map[colIconName] as String,
      colorHex: map[colColorHex] as String,
      isDefault: (map[colIsDefault] as int) == 1,
      isActive: (map[colIsActive] as int) == 1,
      sortOrder: map[colSortOrder] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      colId: id,
      colName: name,
      colType: type.dbValue,
      colIconName: iconName,
      colColorHex: colorHex,
      colIsDefault: isDefault ? 1 : 0,
      colIsActive: isActive ? 1 : 0,
      colSortOrder: sortOrder,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory CategoryModel.fromJson(Map<String, dynamic> json) =>
      CategoryModel.fromMap(json);

  CategoryModel copyWith({
    String? id,
    String? name,
    TransactionType? type,
    String? iconName,
    String? colorHex,
    bool? isDefault,
    bool? isActive,
    int? sortOrder,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [
        id, name, type, iconName, colorHex, isDefault, isActive, sortOrder,
      ];
}