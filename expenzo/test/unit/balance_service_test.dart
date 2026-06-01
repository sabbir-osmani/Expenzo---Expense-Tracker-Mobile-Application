import 'package:flutter_test/flutter_test.dart';
import 'package:expenzo/core/enums/transaction_type.dart';
import 'package:expenzo/core/constants/wallet_constants.dart';
import 'package:expenzo/data/models/transaction_model.dart';
import 'package:expenzo/domain/services/balance_service.dart';

TransactionModel _tx({
  required String id,
  required double amount,
  required TransactionType type,
  required String sourceWalletId,
  String? destinationWalletId,
  DateTime? dateTime,
}) {
  final dt = dateTime ?? DateTime(2025, 1, 15, 10, 0);
  return TransactionModel(
    id: id,
    amount: amount,
    type: type,
    categoryId: 'cat_test',
    sourceWalletId: sourceWalletId,
    destinationWalletId: destinationWalletId,
    dateTime: dt,
    monthKey: '2025-01',
    createdAt: dt,
    updatedAt: dt,
  );
}

void main() {
  final svc = const BalanceService();
  const cash = WalletConstants.cashWalletId;
  const bkash = WalletConstants.bkashWalletId;
  const savings = WalletConstants.savingsWalletId;

  group('BalanceService — income', () {
    test('income credits source wallet', () {
      final txns = [_tx(id: '1', amount: 500, type: TransactionType.income, sourceWalletId: cash)];
      expect(svc.computeWalletBalance(cash, txns), 500.0);
    });

    test('income does not affect other wallets', () {
      final txns = [_tx(id: '1', amount: 500, type: TransactionType.income, sourceWalletId: cash)];
      expect(svc.computeWalletBalance(bkash, txns), 0.0);
    });
  });

  group('BalanceService — expense', () {
    test('expense debits source wallet', () {
      final txns = [
        _tx(id: '1', amount: 1000, type: TransactionType.income, sourceWalletId: cash),
        _tx(id: '2', amount: 200, type: TransactionType.expense, sourceWalletId: cash),
      ];
      expect(svc.computeWalletBalance(cash, txns), 800.0);
    });

    test('expense does not affect other wallets', () {
      final txns = [_tx(id: '1', amount: 200, type: TransactionType.expense, sourceWalletId: cash)];
      expect(svc.computeWalletBalance(bkash, txns), 0.0);
    });
  });

  group('BalanceService — transfer', () {
    test('transfer debits source and credits destination', () {
      final txns = [
        _tx(id: '1', amount: 1000, type: TransactionType.income, sourceWalletId: cash),
        _tx(id: '2', amount: 300, type: TransactionType.transfer,
            sourceWalletId: cash, destinationWalletId: bkash),
      ];
      expect(svc.computeWalletBalance(cash, txns), 700.0);
      expect(svc.computeWalletBalance(bkash, txns), 300.0);
    });

    test('transfer single record — no duplication', () {
      final txns = [
        _tx(id: '1', amount: 500, type: TransactionType.transfer,
            sourceWalletId: cash, destinationWalletId: bkash),
      ];
      // Net across all wallets should be zero (money moved, not created).
      final cashBal = svc.computeWalletBalance(cash, txns);
      final bkashBal = svc.computeWalletBalance(bkash, txns);
      expect(cashBal + bkashBal, 0.0);
    });

    test('reverse transfer restores balances', () {
      final txns = [
        _tx(id: '1', amount: 1000, type: TransactionType.income, sourceWalletId: cash),
        _tx(id: '2', amount: 400, type: TransactionType.transfer,
            sourceWalletId: cash, destinationWalletId: bkash),
        _tx(id: '3', amount: 400, type: TransactionType.transfer,
            sourceWalletId: bkash, destinationWalletId: cash),
      ];
      expect(svc.computeWalletBalance(cash, txns), 1000.0);
      expect(svc.computeWalletBalance(bkash, txns), 0.0);
    });
  });

  group('BalanceService — savings', () {
    test('savings transfer debits source and credits savings', () {
      final txns = [
        _tx(id: '1', amount: 2000, type: TransactionType.income, sourceWalletId: cash),
        _tx(id: '2', amount: 500, type: TransactionType.savings,
            sourceWalletId: cash, destinationWalletId: savings),
      ];
      expect(svc.computeWalletBalance(cash, txns), 1500.0);
      expect(svc.computeWalletBalance(savings, txns), 500.0);
    });
  });

  group('BalanceService — delete correction', () {
    test('deleting income transaction reduces balance', () {
      final all = [
        _tx(id: '1', amount: 1000, type: TransactionType.income, sourceWalletId: cash),
        _tx(id: '2', amount: 500, type: TransactionType.income, sourceWalletId: cash),
      ];
      expect(svc.computeWalletBalance(cash, all), 1500.0);

      final afterDelete = all.where((t) => t.id != '2').toList();
      expect(svc.computeWalletBalance(cash, afterDelete), 1000.0);
    });

    test('editing amount recalculates correctly', () {
      var txns = [
        _tx(id: '1', amount: 1000, type: TransactionType.income, sourceWalletId: cash),
        _tx(id: '2', amount: 200, type: TransactionType.expense, sourceWalletId: cash),
      ];
      expect(svc.computeWalletBalance(cash, txns), 800.0);

      // Simulate edit: replace transaction with updated amount.
      txns = [
        txns[0],
        txns[1].copyWith(amount: 350),
      ];
      expect(svc.computeWalletBalance(cash, txns), 650.0);
    });
  });

  group('BalanceService — upTo boundary', () {
    test('computeWalletBalanceUpTo excludes future transactions', () {
      final earlyDate = DateTime(2025, 1, 1);
      final lateDate = DateTime(2025, 1, 31);

      final txns = [
        _tx(id: '1', amount: 1000, type: TransactionType.income,
            sourceWalletId: cash, dateTime: earlyDate),
        _tx(id: '2', amount: 200, type: TransactionType.expense,
            sourceWalletId: cash, dateTime: lateDate),
      ];

      final balanceBeforeExpense = svc.computeWalletBalanceUpTo(
        cash,
        txns,
        DateTime(2025, 1, 15),
      );
      expect(balanceBeforeExpense, 1000.0);
    });
  });

  group('BalanceService — aggregates', () {
    test('totalIncome sums income transactions only', () {
      final txns = [
        _tx(id: '1', amount: 500, type: TransactionType.income, sourceWalletId: cash),
        _tx(id: '2', amount: 100, type: TransactionType.income, sourceWalletId: bkash),
        _tx(id: '3', amount: 200, type: TransactionType.expense, sourceWalletId: cash),
      ];
      expect(svc.totalIncome(txns), 600.0);
    });

    test('totalExpense sums expense transactions only', () {
      final txns = [
        _tx(id: '1', amount: 500, type: TransactionType.income, sourceWalletId: cash),
        _tx(id: '2', amount: 200, type: TransactionType.expense, sourceWalletId: cash),
        _tx(id: '3', amount: 50, type: TransactionType.expense, sourceWalletId: cash),
      ];
      expect(svc.totalExpense(txns), 250.0);
    });

    test('netForMonth returns income minus expense', () {
      final txns = [
        _tx(id: '1', amount: 1000, type: TransactionType.income, sourceWalletId: cash),
        _tx(id: '2', amount: 300, type: TransactionType.expense, sourceWalletId: cash),
      ];
      expect(svc.netForMonth(txns), 700.0);
    });

    test('empty transaction list returns zero for all aggregates', () {
      expect(svc.totalIncome([]), 0.0);
      expect(svc.totalExpense([]), 0.0);
      expect(svc.netForMonth([]), 0.0);
    });
  });
}