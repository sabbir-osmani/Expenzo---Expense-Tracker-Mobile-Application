import 'package:equatable/equatable.dart';
import '../../core/enums/transaction_type.dart';
import '../../data/models/transaction_model.dart';

/// Domain entity — used in business logic and presentation.
/// Mirrors TransactionModel closely; kept separate to decouple
/// domain logic from database mapping concerns.
class Transaction extends Equatable {
  const Transaction({
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

  factory Transaction.fromModel(TransactionModel m) {
    return Transaction(
      id: m.id,
      title: m.title,
      amount: m.amount,
      type: m.type,
      categoryId: m.categoryId,
      sourceWalletId: m.sourceWalletId,
      destinationWalletId: m.destinationWalletId,
      dateTime: m.dateTime,
      note: m.note,
      monthKey: m.monthKey,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
    );
  }

  TransactionModel toModel() {
    return TransactionModel(
      id: id,
      title: title,
      amount: amount,
      type: type,
      categoryId: categoryId,
      sourceWalletId: sourceWalletId,
      destinationWalletId: destinationWalletId,
      dateTime: dateTime,
      note: note,
      monthKey: monthKey,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id, title, amount, type, categoryId, sourceWalletId,
        destinationWalletId, dateTime, note, monthKey, createdAt, updatedAt,
      ];
}