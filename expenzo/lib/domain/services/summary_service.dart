import 'package:equatable/equatable.dart';
import '../../core/enums/transaction_type.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/wallet_model.dart';
import '../entities/wallet_summary.dart';
import 'balance_service.dart';

class SummaryService {
  const SummaryService(this._balanceService);

  final BalanceService _balanceService;

  MonthlySummary buildMonthlySummary({
    required String monthKey,
    required List<TransactionModel> allTransactions,
    required List<TransactionModel> monthTransactions,
    required List<WalletModel> wallets,
    required DateTime monthStart,
  }) {
    final walletSummaries = wallets
        .where((w) => w.isActive)
        .map(
          (w) => _balanceService.buildWalletSummaryForMonth(
            w.id,
            w.name,
            allTransactions,
            monthTransactions,
            monthStart,
          ),
        )
        .toList();

    final totalIncome = _balanceService.totalIncome(monthTransactions);
    final totalExpense = _balanceService.totalExpense(monthTransactions);
    final totalSavings = _balanceService.totalSavings(monthTransactions);
    final totalTransferred = _balanceService.totalTransfer(monthTransactions);

    final openingBalance = wallets
        .where((w) => w.isActive)
        .fold<double>(
          0.0,
          (sum, w) => sum +
              _balanceService.computeWalletBalanceUpTo(
                w.id,
                allTransactions,
                monthStart.subtract(const Duration(milliseconds: 1)),
              ),
        );

    final closingBalance = double.parse(
      (openingBalance + totalIncome - totalExpense).toStringAsFixed(2),
    );

    return MonthlySummary(
      monthKey: monthKey,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      totalSavings: totalSavings,
      totalTransferred: totalTransferred,
      openingBalance: double.parse(openingBalance.toStringAsFixed(2)),
      closingBalance: closingBalance,
      walletSummaries: walletSummaries,
    );
  }

  List<CategoryBreakdown> buildCategoryBreakdown(
    List<TransactionModel> transactions,
    Map<String, String> categoryNames,
    Map<String, String> categoryColors, {
    TransactionType filterType = TransactionType.expense,
  }) {
    final filtered = transactions.where((t) => t.type == filterType).toList();
    if (filtered.isEmpty) return [];

    final totals = <String, double>{};
    final counts = <String, int>{};

    for (final t in filtered) {
      totals[t.categoryId] = (totals[t.categoryId] ?? 0) + t.amount;
      counts[t.categoryId] = (counts[t.categoryId] ?? 0) + 1;
    }

    final grandTotal = totals.values.fold(0.0, (a, b) => a + b);
    if (grandTotal == 0) return [];

    final breakdowns = totals.entries.map((entry) {
      final categoryId = entry.key;
      return CategoryBreakdown(
        categoryId: categoryId,
        categoryName: categoryNames[categoryId] ?? 'Unknown',
        colorHex: categoryColors[categoryId] ?? '#9E9E9E',
        total: double.parse(entry.value.toStringAsFixed(2)),
        percentage: double.parse(
          ((entry.value / grandTotal) * 100).toStringAsFixed(1),
        ),
        transactionCount: counts[categoryId] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return breakdowns;
  }

  List<MonthlyTotals> buildMonthlyTrendData(
    Map<String, List<TransactionModel>> transactionsByMonth,
    List<String> monthKeys,
  ) {
    return monthKeys.map((key) {
      final txns = transactionsByMonth[key] ?? [];
      return MonthlyTotals(
        monthKey: key,
        income: _balanceService.totalIncome(txns),
        expense: _balanceService.totalExpense(txns),
        savings: _balanceService.totalSavings(txns),
      );
    }).toList();
  }
}

class MonthlyTotals extends Equatable {
  const MonthlyTotals({
    required this.monthKey,
    required this.income,
    required this.expense,
    required this.savings,
  });

  final String monthKey;
  final double income;
  final double expense;
  final double savings;

  double get net => income - expense;

  @override
  List<Object?> get props => [monthKey, income, expense, savings];
}