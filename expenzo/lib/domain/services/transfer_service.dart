import 'package:uuid/uuid.dart';
import '../../core/enums/transaction_type.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/extensions/datetime_ext.dart';
import '../../data/models/transaction_model.dart';

class TransferService {
  const TransferService();

  static const _uuid = Uuid();

  /// Creates a validated transfer [TransactionModel].
  ///
  /// A transfer is a single DB record that:
  /// - debits [sourceWalletId]
  /// - credits [destinationWalletId]
  ///
  /// This guarantees atomic balance changes with no duplication.
  TransactionModel createTransfer({
    required double amount,
    required String sourceWalletId,
    required String destinationWalletId,
    required DateTime dateTime,
    required TransactionType type,
    required String categoryId,
    String? title,
    String? note,
  }) {
    _validateTransfer(
      amount: amount,
      sourceWalletId: sourceWalletId,
      destinationWalletId: destinationWalletId,
      type: type,
    );

    final now = DateTime.now();
    return TransactionModel(
      id: _uuid.v4(),
      title: title,
      amount: double.parse(amount.toStringAsFixed(2)),
      type: type,
      categoryId: categoryId,
      sourceWalletId: sourceWalletId,
      destinationWalletId: destinationWalletId,
      dateTime: dateTime,
      note: note,
      monthKey: dateTime.monthKey,
      createdAt: now,
      updatedAt: now,
    );
  }

  void _validateTransfer({
    required double amount,
    required String sourceWalletId,
    required String destinationWalletId,
    required TransactionType type,
  }) {
    if (amount <= 0) {
      throw const InvalidTransferException('Transfer amount must be positive.');
    }
    if (sourceWalletId == destinationWalletId) {
      throw const InvalidTransferException(
        'Source and destination wallets must be different.',
      );
    }
    if (!type.isTransfer) {
      throw InvalidTransferException(
        'Invalid type for transfer: ${type.name}',
      );
    }
  }
}