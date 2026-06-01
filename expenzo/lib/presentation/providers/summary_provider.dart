import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/transaction_type.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/entities/wallet_summary.dart';
import '../../domain/services/summary_service.dart';
import 'category_provider.dart';
import 'core_providers.dart';
import 'navigation_provider.dart';
import 'transaction_provider.dart';
import 'wallet_provider.dart';

// ── Monthly summary ────────────────────────────────────────────────────────

final monthlySummaryProvider = Provider<MonthlySummary?>((ref) {
  final selectedMonth = ref.watch(selectedMonthProvider);
  final allTransactions = ref.watch(allTransactionsProvider);
  final monthTransactions = ref.watch(monthTransactionsProvider);
  final wallets = ref.watch(activeWalletsProvider);
  final summaryService = ref.watch(summaryServiceProvider);

  if (allTransactions.isEmpty && monthTransactions.isEmpty) {
    return null;
  }

  final monthKey =
      '${selectedMonth.year.toString().padLeft(4, '0')}-'
      '${selectedMonth.month.toString().padLeft(2, '0')}';

  return summaryService.buildMonthlySummary(
    monthKey: monthKey,
    allTransactions: allTransactions,
    monthTransactions: monthTransactions,
    wallets: wallets,
    monthStart: selectedMonth,
  );
});

// ── Category breakdowns ────────────────────────────────────────────────────

final expenseBreakdownProvider = Provider<List<CategoryBreakdown>>((ref) {
  final monthTransactions = ref.watch(monthTransactionsProvider);
  final categoryMap = ref.watch(categoryMapProvider);
  final summaryService = ref.watch(summaryServiceProvider);

  final names = <String, String>{
    for (final e in categoryMap.entries) e.key: e.value.name,
  };
  final colors = <String, String>{
    for (final e in categoryMap.entries) e.key: e.value.colorHex,
  };

  return summaryService.buildCategoryBreakdown(
    monthTransactions,
    names,
    colors,
    filterType: TransactionType.expense,
  );
});

final incomeBreakdownProvider = Provider<List<CategoryBreakdown>>((ref) {
  final monthTransactions = ref.watch(monthTransactionsProvider);
  final categoryMap = ref.watch(categoryMapProvider);
  final summaryService = ref.watch(summaryServiceProvider);

  final names = <String, String>{
    for (final e in categoryMap.entries) e.key: e.value.name,
  };
  final colors = <String, String>{
    for (final e in categoryMap.entries) e.key: e.value.colorHex,
  };

  return summaryService.buildCategoryBreakdown(
    monthTransactions,
    names,
    colors,
    filterType: TransactionType.income,
  );
});

// ── Trend data (last 6 months) ─────────────────────────────────────────────

final trendDataProvider = Provider<List<MonthlyTotals>>((ref) {
  final allTransactions = ref.watch(allTransactionsProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  final summaryService = ref.watch(summaryServiceProvider);

  final monthKeys = <String>[];
  for (int i = 5; i >= 0; i--) {
    final dt = DateTime(selectedMonth.year, selectedMonth.month - i, 1);
    final key =
        '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}';
    monthKeys.add(key);
  }

  // Explicitly typed to avoid Map<String, List<dynamic>> inference error
  final byMonth = <String, List<TransactionModel>>{
    for (final key in monthKeys)
      key: allTransactions.where((t) => t.monthKey == key).toList(),
  };

  return summaryService.buildMonthlyTrendData(byMonth, monthKeys);
});