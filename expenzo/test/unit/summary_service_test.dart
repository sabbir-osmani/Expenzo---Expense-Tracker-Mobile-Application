import 'package:flutter_test/flutter_test.dart';
import 'package:expenzo/core/enums/transaction_type.dart';
import 'package:expenzo/core/enums/wallet_type.dart';
import 'package:expenzo/core/constants/wallet_constants.dart';
import 'package:expenzo/data/models/transaction_model.dart';
import 'package:expenzo/data/models/wallet_model.dart';
import 'package:expenzo/domain/services/balance_service.dart';
import 'package:expenzo/domain/services/summary_service.dart';

TransactionModel _tx({
  required String id,
  required double amount,
  required TransactionType type,
  required String sourceWalletId,
  String? destinationWalletId,
  required String monthKey,
}) {
  final year = int.parse(monthKey.split('-')[0]);
  final month = int.parse(monthKey.split('-')[1]);
  final dt = DateTime(year, month, 15, 10, 0);
  return TransactionModel(
    id: id,
    amount: amount,
    type: type,
    categoryId: 'cat_test',
    sourceWalletId: sourceWalletId,
    destinationWalletId: destinationWalletId,
    dateTime: dt,
    monthKey: monthKey,
    createdAt: dt,
    updatedAt: dt,
  );
}

void main() {
  final balanceSvc = const BalanceService();
  final summarySvc = SummaryService(balanceSvc);

  const cash = WalletConstants.cashWalletId;
  const bkash = WalletConstants.bkashWalletId;

  final wallets = [
    const WalletModel(id: cash, name: 'Cash', type: WalletType.cash, isActive: true),
    const WalletModel(id: bkash, name: 'bKash', type: WalletType.mobileBanking, isActive: true),
  ];

  group('SummaryService — monthly totals', () {
    test('correctly totals income and expense for selected month', () {
      final jan = '2025-01';
      final monthStart = DateTime(2025, 1, 1);

      final allTxns = [
        _tx(id: '1', amount: 5000, type: TransactionType.income, sourceWalletId: cash, monthKey: jan),
        _tx(id: '2', amount: 1000, type: TransactionType.expense, sourceWalletId: cash, monthKey: jan),
        _tx(id: '3', amount: 500, type: TransactionType.expense, sourceWalletId: cash, monthKey: jan),
      ];

      final summary = summarySvc.buildMonthlySummary(
        monthKey: jan,
        allTransactions: allTxns,
        monthTransactions: allTxns,
        wallets: wallets,
        monthStart: monthStart,
      );

      expect(summary.totalIncome, 5000.0);
      expect(summary.totalExpense, 1500.0);
      expect(summary.netChange, 3500.0);
    });

    test('opening balance is zero for first-ever month', () {
      final jan = '2025-01';
      final monthStart = DateTime(2025, 1, 1);

      final allTxns = [
        _tx(id: '1', amount: 1000, type: TransactionType.income, sourceWalletId: cash, monthKey: jan),
      ];

      final summary = summarySvc.buildMonthlySummary(
        monthKey: jan,
        allTransactions: allTxns,
        monthTransactions: allTxns,
        wallets: wallets,
        monthStart: monthStart,
      );

      expect(summary.openingBalance, 0.0);
    });

    test('opening balance of february includes january carry-over', () {
      final jan = '2025-01';
      final feb = '2025-02';
      final febStart = DateTime(2025, 2, 1);

      final allTxns = [
        _tx(id: '1', amount: 5000, type: TransactionType.income, sourceWalletId: cash, monthKey: jan),
        _tx(id: '2', amount: 1000, type: TransactionType.expense, sourceWalletId: cash, monthKey: jan),
        _tx(id: '3', amount: 500, type: TransactionType.income, sourceWalletId: cash, monthKey: feb),
      ];

      final febTxns = allTxns.where((t) => t.monthKey == feb).toList();

      final summary = summarySvc.buildMonthlySummary(
        monthKey: feb,
        allTransactions: allTxns,
        monthTransactions: febTxns,
        wallets: wallets,
        monthStart: febStart,
      );

      // January net was 4000, so February opening should be 4000.
      expect(summary.openingBalance, 4000.0);
    });
  });

  group('SummaryService — category breakdown', () {
    test('returns sorted breakdown by total descending', () {

      // Use multiple expense transactions with different categories.
      final rawTxns = [
        TransactionModel(
          id: '1', amount: 500, type: TransactionType.expense,
          categoryId: 'food', sourceWalletId: cash,
          dateTime: DateTime(2025, 1, 10), monthKey: '2025-01',
          createdAt: DateTime(2025, 1, 10), updatedAt: DateTime(2025, 1, 10),
        ),
        TransactionModel(
          id: '2', amount: 200, type: TransactionType.expense,
          categoryId: 'transport', sourceWalletId: cash,
          dateTime: DateTime(2025, 1, 12), monthKey: '2025-01',
          createdAt: DateTime(2025, 1, 12), updatedAt: DateTime(2025, 1, 12),
        ),
        TransactionModel(
          id: '3', amount: 300, type: TransactionType.expense,
          categoryId: 'food', sourceWalletId: cash,
          dateTime: DateTime(2025, 1, 14), monthKey: '2025-01',
          createdAt: DateTime(2025, 1, 14), updatedAt: DateTime(2025, 1, 14),
        ),
      ];

      final names = {'food': 'Food', 'transport': 'Transport'};
      final colors = {'food': '#E53935', 'transport': '#1E88E5'};

      final breakdown = summarySvc.buildCategoryBreakdown(
        rawTxns,
        names,
        colors,
        filterType: TransactionType.expense,
      );

      expect(breakdown.length, 2);
      expect(breakdown.first.categoryId, 'food'); // highest total
      expect(breakdown.first.total, 800.0);
      expect(breakdown[1].categoryId, 'transport');
    });

    test('returns empty list when no transactions match filter type', () {
      final txns = [
        TransactionModel(
          id: '1', amount: 500, type: TransactionType.income,
          categoryId: 'salary', sourceWalletId: cash,
          dateTime: DateTime(2025, 1, 10), monthKey: '2025-01',
          createdAt: DateTime(2025, 1, 10), updatedAt: DateTime(2025, 1, 10),
        ),
      ];

      final breakdown = summarySvc.buildCategoryBreakdown(
        txns, {}, {},
        filterType: TransactionType.expense,
      );

      expect(breakdown, isEmpty);
    });
  });
}