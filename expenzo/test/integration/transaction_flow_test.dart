import 'package:flutter_test/flutter_test.dart';

import 'package:expenzo/core/enums/transaction_type.dart';
import 'package:expenzo/core/constants/wallet_constants.dart';
import 'package:expenzo/data/models/transaction_model.dart';
import 'package:expenzo/domain/services/balance_service.dart';
import 'package:expenzo/domain/services/transfer_service.dart';

void main() {
  const balanceSvc = BalanceService();
  const transferSvc = TransferService();
  const cash = WalletConstants.cashWalletId;
  const bkash = WalletConstants.bkashWalletId;

  TransactionModel income(String id, double amount) {
    final dt = DateTime(2025, 1, 10);
    return TransactionModel(
      id: id,
      amount: amount,
      type: TransactionType.income,
      categoryId: 'cat_income',
      sourceWalletId: cash,
      dateTime: dt,
      monthKey: '2025-01',
      createdAt: dt,
      updatedAt: dt,
    );
  }

  group('Transaction flow — add / edit / delete', () {
    test('add income then expense — net is correct', () {
      final txns = [
        income('t1', 5000),
        income('t2', 1000),
      ];
      final dt = DateTime(2025, 1, 12);
      final expense = TransactionModel(
        id: 't3',
        amount: 2000,
        type: TransactionType.expense,
        categoryId: 'cat_expense',
        sourceWalletId: cash,
        dateTime: dt,
        monthKey: '2025-01',
        createdAt: dt,
        updatedAt: dt,
      );

      final all = [...txns, expense];
      expect(balanceSvc.computeWalletBalance(cash, all), 4000.0);
      expect(balanceSvc.totalIncome(all), 6000.0);
      expect(balanceSvc.totalExpense(all), 2000.0);
    });

    test('transfer flow — both wallets update atomically', () {
      final startIncome = income('t0', 3000);
      final transfer = transferSvc.createTransfer(
        amount: 1000,
        sourceWalletId: cash,
        destinationWalletId: bkash,
        dateTime: DateTime(2025, 1, 15),
        type: TransactionType.transfer,
        categoryId: 'cat_transfer',
      );

      final all = [startIncome, transfer];
      expect(balanceSvc.computeWalletBalance(cash, all), 2000.0);
      expect(balanceSvc.computeWalletBalance(bkash, all), 1000.0);
      // Net money in system unchanged.
      final cashBal = balanceSvc.computeWalletBalance(cash, all);
      final bkashBal = balanceSvc.computeWalletBalance(bkash, all);
      expect(cashBal + bkashBal, 3000.0);
    });

    test('delete single transaction recalculates correctly', () {
      final txns = [
        income('t1', 5000),
        income('t2', 2000),
      ];
      expect(balanceSvc.computeWalletBalance(cash, txns), 7000.0);

      final afterDelete = txns.where((t) => t.id != 't2').toList();
      expect(balanceSvc.computeWalletBalance(cash, afterDelete), 5000.0);
    });
  });
}