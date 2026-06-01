import 'package:equatable/equatable.dart';
import '../../core/enums/wallet_type.dart';

class WalletModel extends Equatable {
  const WalletModel({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
  });

  final String id;
  final String name;
  final WalletType type;
  final bool isActive;

  // ── DB mapping ─────────────────────────────────────────────────────────────

  static const String tableName = 'wallets';

  static const String colId = 'id';
  static const String colName = 'name';
  static const String colType = 'type';
  static const String colIsActive = 'is_active';

  static const String createTableSql = '''
    CREATE TABLE $tableName (
      $colId TEXT PRIMARY KEY,
      $colName TEXT NOT NULL,
      $colType TEXT NOT NULL,
      $colIsActive INTEGER NOT NULL DEFAULT 1
    )
  ''';

  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      id: map[colId] as String,
      name: map[colName] as String,
      type: WalletType.fromString(map[colType] as String),
      isActive: (map[colIsActive] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      colId: id,
      colName: name,
      colType: type.dbValue,
      colIsActive: isActive ? 1 : 0,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory WalletModel.fromJson(Map<String, dynamic> json) =>
      WalletModel.fromMap(json);

  WalletModel copyWith({
    String? id,
    String? name,
    WalletType? type,
    bool? isActive,
  }) {
    return WalletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [id, name, type, isActive];
}