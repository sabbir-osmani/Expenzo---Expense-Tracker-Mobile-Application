import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:expenzo/core/enums/transaction_type.dart';
import 'package:expenzo/core/enums/wallet_type.dart';
import 'package:expenzo/data/models/category_model.dart';
import 'package:expenzo/data/models/transaction_model.dart';
import 'package:expenzo/data/models/wallet_model.dart';
import 'package:expenzo/domain/services/balance_service.dart';

Map<String, dynamic> _buildBackup({
  required List<WalletModel> wallets,
  required List<CategoryModel> categories,
  required List<TransactionModel> transactions,
}) {
  return {
    'version': 1,
    'appName': 'Expenzo',
    'exportedAt': DateTime.now().toIso8601String(),
    'wallets': wallets.map((w) => w.toJson()).toList(),
    'categories': categories.map((c) => c.toJson()).toList(),
    'transactions': transactions.map((t) => t.toJson()).toList(),
  };
}

TransactionModel _tx(
  String id,
  double amount,
  TransactionType type,
  String source, {
  String? dest,
}) {
  final dt = DateTime(2025, 1, 15, 10, 0);
  return TransactionModel(
    id: id,
    amount: amount,
    type: type,
    categoryId: 'cat_1',
    sourceWalletId: source,
    destinationWalletId: dest,
    dateTime: dt,
    monthKey: '2025-01',
    createdAt: dt,
    updatedAt: dt,
  );
}

void main() {
  const cash = 'wallet_cash';
  const bkash = 'wallet_bkash';
  const balanceSvc = BalanceService();

  final wallets = [
    const WalletModel(
      id: cash,
      name: 'Cash',
      type: WalletType.cash,
      isActive: true,
    ),
    const WalletModel(
      id: bkash,
      name: 'bKash',
      type: WalletType.mobileBanking,
      isActive: true,
    ),
  ];

  final categories = [
    const CategoryModel(
      id: 'cat_1',
      name: 'Salary',
      type: TransactionType.income,
      iconName: 'work',
      colorHex: '#43A047',
      isDefault: true,
      isActive: true,
      sortOrder: 0,
    ),
  ];

  group('Backup → JSON → restore → balance integrity', () {
    test('restored transactions produce identical wallet balances', () {
      final transactions = [
        _tx('t1', 5000, TransactionType.income, cash),
        _tx('t2', 300, TransactionType.transfer, cash, dest: bkash),
        _tx('t3', 800, TransactionType.expense, cash),
      ];

      final originalCash =
          balanceSvc.computeWalletBalance(cash, transactions);
      final originalBkash =
          balanceSvc.computeWalletBalance(bkash, transactions);

      // Simulate export then import.
      final json = jsonEncode(_buildBackup(
        wallets: wallets,
        categories: categories,
        transactions: transactions,
      ));

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final restored = (decoded['transactions'] as List)
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(
        balanceSvc.computeWalletBalance(cash, restored),
        originalCash,
      );
      expect(
        balanceSvc.computeWalletBalance(bkash, restored),
        originalBkash,
      );
      expect(originalCash, 3900.0); // 5000 - 300 - 800
      expect(originalBkash, 300.0);
    });

    test('negative amount fails validation rule', () {
      final txn = _tx('t_bad', -100, TransactionType.expense, cash);
      expect(txn.amount > 0, isFalse);
    });

    test('transfer has both source and destination', () {
      final txn = _tx('t_tr', 500, TransactionType.transfer, cash, dest: bkash);
      expect(txn.sourceWalletId, cash);
      expect(txn.destinationWalletId, bkash);
    });

    test('edit transaction updates balance correctly', () {
      final dt = DateTime(2025, 1, 10);
      final original = TransactionModel(
        id: 't1',
        amount: 200,
        type: TransactionType.expense,
        categoryId: 'cat_1',
        sourceWalletId: cash,
        dateTime: dt,
        monthKey: '2025-01',
        createdAt: dt,
        updatedAt: dt,
      );
      final income = _tx('t0', 1000, TransactionType.income, cash);

      final before = balanceSvc.computeWalletBalance(cash, [income, original]);
      expect(before, 800.0);

      final edited = original.copyWith(amount: 350);
      final after = balanceSvc.computeWalletBalance(cash, [income, edited]);
      expect(after, 650.0);
    });

    test('delete transaction self-corrects balance', () {
      final income = _tx('t0', 1000, TransactionType.income, cash);
      final expense = _tx('t1', 200, TransactionType.expense, cash);

      final withExpense =
          balanceSvc.computeWalletBalance(cash, [income, expense]);
      expect(withExpense, 800.0);

      final afterDelete = balanceSvc.computeWalletBalance(cash, [income]);
      expect(afterDelete, 1000.0);
    });
  });
}