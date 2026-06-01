import 'package:flutter_test/flutter_test.dart';
import 'package:expenzo/core/enums/transaction_type.dart';
import 'package:expenzo/core/errors/app_exceptions.dart';
import 'package:expenzo/core/constants/wallet_constants.dart';
import 'package:expenzo/domain/services/transfer_service.dart';

void main() {
  final svc = const TransferService();
  const cash = WalletConstants.cashWalletId;
  const bkash = WalletConstants.bkashWalletId;

  group('TransferService — validation', () {
    test('throws InvalidTransferException when amount is zero', () {
      expect(
        () => svc.createTransfer(
          amount: 0,
          sourceWalletId: cash,
          destinationWalletId: bkash,
          dateTime: DateTime.now(),
          type: TransactionType.transfer,
          categoryId: 'cat_transfer',
        ),
        throwsA(isA<InvalidTransferException>()),
      );
    });

    test('throws InvalidTransferException when amount is negative', () {
      expect(
        () => svc.createTransfer(
          amount: -100,
          sourceWalletId: cash,
          destinationWalletId: bkash,
          dateTime: DateTime.now(),
          type: TransactionType.transfer,
          categoryId: 'cat_transfer',
        ),
        throwsA(isA<InvalidTransferException>()),
      );
    });

    test('throws InvalidTransferException when source equals destination', () {
      expect(
        () => svc.createTransfer(
          amount: 500,
          sourceWalletId: cash,
          destinationWalletId: cash,
          dateTime: DateTime.now(),
          type: TransactionType.transfer,
          categoryId: 'cat_transfer',
        ),
        throwsA(isA<InvalidTransferException>()),
      );
    });

    test('throws InvalidTransferException for wrong type', () {
      expect(
        () => svc.createTransfer(
          amount: 500,
          sourceWalletId: cash,
          destinationWalletId: bkash,
          dateTime: DateTime.now(),
          type: TransactionType.expense, // not a transfer type
          categoryId: 'cat_transfer',
        ),
        throwsA(isA<InvalidTransferException>()),
      );
    });
  });

  group('TransferService — valid creation', () {
    test('creates single transaction record', () {
      final txn = svc.createTransfer(
        amount: 500,
        sourceWalletId: cash,
        destinationWalletId: bkash,
        dateTime: DateTime(2025, 1, 15),
        type: TransactionType.transfer,
        categoryId: 'cat_transfer',
      );

      expect(txn.amount, 500.0);
      expect(txn.sourceWalletId, cash);
      expect(txn.destinationWalletId, bkash);
      expect(txn.type, TransactionType.transfer);
      expect(txn.id, isNotEmpty);
    });

    test('monthKey matches dateTime', () {
      final dt = DateTime(2025, 6, 20);
      final txn = svc.createTransfer(
        amount: 100,
        sourceWalletId: cash,
        destinationWalletId: bkash,
        dateTime: dt,
        type: TransactionType.transfer,
        categoryId: 'cat_transfer',
      );
      expect(txn.monthKey, '2025-06');
    });

    test('savings type is also valid', () {
      final txn = svc.createTransfer(
        amount: 200,
        sourceWalletId: cash,
        destinationWalletId: WalletConstants.savingsWalletId,
        dateTime: DateTime.now(),
        type: TransactionType.savings,
        categoryId: 'cat_savings',
      );
      expect(txn.type, TransactionType.savings);
    });

    test('amount is rounded to 2 decimal places', () {
      final txn = svc.createTransfer(
        amount: 100.999,
        sourceWalletId: cash,
        destinationWalletId: bkash,
        dateTime: DateTime.now(),
        type: TransactionType.transfer,
        categoryId: 'cat_transfer',
      );
      expect(txn.amount, 101.0); // rounded
    });
  });
}