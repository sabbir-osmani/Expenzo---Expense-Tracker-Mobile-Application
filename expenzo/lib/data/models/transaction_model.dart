import 'package:equatable/equatable.dart';
import '../../core/enums/transaction_type.dart';

class TransactionModel extends Equatable {
  const TransactionModel({
    required this.id,
    this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.sourceWalletId,
    this.destinationWalletId,
    required this.dateTime,
    this.note,
    required this.monthKey,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? title;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String sourceWalletId;
  final String? destinationWalletId;
  final DateTime dateTime;
  final String? note;
  final String monthKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── DB mapping ─────────────────────────────────────────────────────────────

  static const String tableName = 'transactions';

  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colAmount = 'amount';
  static const String colType = 'type';
  static const String colCategoryId = 'category_id';
  static const String colSourceWalletId = 'source_wallet_id';
  static const String colDestinationWalletId = 'destination_wallet_id';
  static const String colDateTime = 'date_time';
  static const String colNote = 'note';
  static const String colMonthKey = 'month_key';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  static const String createTableSql = '''
    CREATE TABLE $tableName (
      $colId TEXT PRIMARY KEY,
      $colTitle TEXT,
      $colAmount REAL NOT NULL,
      $colType TEXT NOT NULL,
      $colCategoryId TEXT NOT NULL,
      $colSourceWalletId TEXT NOT NULL,
      $colDestinationWalletId TEXT,
      $colDateTime TEXT NOT NULL,
      $colNote TEXT,
      $colMonthKey TEXT NOT NULL,
      $colCreatedAt TEXT NOT NULL,
      $colUpdatedAt TEXT NOT NULL
    )
  ''';

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map[colId] as String,
      title: map[colTitle] as String?,
      amount: (map[colAmount] as num).toDouble(),
      type: TransactionType.fromString(map[colType] as String),
      categoryId: map[colCategoryId] as String,
      sourceWalletId: map[colSourceWalletId] as String,
      destinationWalletId: map[colDestinationWalletId] as String?,
      dateTime: DateTime.parse(map[colDateTime] as String),
      note: map[colNote] as String?,
      monthKey: map[colMonthKey] as String,
      createdAt: DateTime.parse(map[colCreatedAt] as String),
      updatedAt: DateTime.parse(map[colUpdatedAt] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      colId: id,
      colTitle: title,
      colAmount: amount,
      colType: type.dbValue,
      colCategoryId: categoryId,
      colSourceWalletId: sourceWalletId,
      colDestinationWalletId: destinationWalletId,
      colDateTime: dateTime.toIso8601String(),
      colNote: note,
      colMonthKey: monthKey,
      colCreatedAt: createdAt.toIso8601String(),
      colUpdatedAt: updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      TransactionModel.fromMap(json);

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? sourceWalletId,
    String? destinationWalletId,
    DateTime? dateTime,
    String? note,
    String? monthKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      sourceWalletId: sourceWalletId ?? this.sourceWalletId,
      destinationWalletId: destinationWalletId ?? this.destinationWalletId,
      dateTime: dateTime ?? this.dateTime,
      note: note ?? this.note,
      monthKey: monthKey ?? this.monthKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        amount,
        type,
        categoryId,
        sourceWalletId,
        destinationWalletId,
        dateTime,
        note,
        monthKey,
        createdAt,
        updatedAt,
      ];
}