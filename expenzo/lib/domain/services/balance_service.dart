import '../../core/enums/transaction_type.dart';
import '../../data/models/transaction_model.dart';
import '../entities/wallet_summary.dart';

class BalanceService {
  const BalanceService();

  // ── Core ──────────────────────────────────────────────────────────────────

  double computeWalletBalance(
    String walletId,
    List<TransactionModel> transactions,
  ) {
    double balance = 0.0;
    for (final t in transactions) {
      balance += _contribution(walletId, t);
    }
    return double.parse(balance.toStringAsFixed(2));
  }

  double computeWalletBalanceUpTo(
    String walletId,
    List<TransactionModel> transactions,
    DateTime upTo,
  ) {
    double balance = 0.0;
    for (final t in transactions) {
      if (!t.dateTime.isAfter(upTo)) {
        balance += _contribution(walletId, t);
      }
    }
    return double.parse(balance.toStringAsFixed(2));
  }

  // ── Balance validation ────────────────────────────────────────────────────

  /// Returns the spendable balance for [walletId].
  /// Pass [excludeTransactionId] when editing an existing transaction so the
  /// original debit is not double-counted.
  double availableBalance({
    required String walletId,
    required List<TransactionModel> allTransactions,
    String? excludeTransactionId,
  }) {
    final txns = excludeTransactionId != null
        ? allTransactions.where((t) => t.id != excludeTransactionId).toList()
        : allTransactions;
    return computeWalletBalance(walletId, txns);
  }

  /// Returns true if [walletId] can afford [amount].
  bool canAfford({
    required String walletId,
    required double amount,
    required List<TransactionModel> allTransactions,
    String? excludeTransactionId,
  }) {
    return availableBalance(
          walletId: walletId,
          allTransactions: allTransactions,
          excludeTransactionId: excludeTransactionId,
        ) >=
        amount;
  }

  // ── Contribution ──────────────────────────────────────────────────────────

  double _contribution(String walletId, TransactionModel t) {
    switch (t.type) {
      case TransactionType.income:
        return t.sourceWalletId == walletId ? t.amount : 0.0;
      case TransactionType.expense:
        return t.sourceWalletId == walletId ? -t.amount : 0.0;
      case TransactionType.transfer:
      case TransactionType.savings:
        double c = 0.0;
        if (t.sourceWalletId == walletId) c -= t.amount;
        if (t.destinationWalletId == walletId) c += t.amount;
        return c;
    }
  }

  // ── Monthly wallet summary ────────────────────────────────────────────────

  WalletSummary buildWalletSummaryForMonth(
    String walletId,
    String walletName,
    List<TransactionModel> allTransactions,
    List<TransactionModel> monthTransactions,
    DateTime monthStart,
  ) {
    final openingBalance = computeWalletBalanceUpTo(
      walletId,
      allTransactions,
      monthStart.subtract(const Duration(milliseconds: 1)),
    );

    double inflow = 0.0;
    double outflow = 0.0;

    for (final t in monthTransactions) {
      final c = _contribution(walletId, t);
      if (c > 0) {
        inflow += c;
      } else {
        outflow += c.abs();
      }
    }

    return WalletSummary(
      walletId: walletId,
      walletName: walletName,
      balance: double.parse((openingBalance + inflow - outflow).toStringAsFixed(2)),
      totalInflow: double.parse(inflow.toStringAsFixed(2)),
      totalOutflow: double.parse(outflow.toStringAsFixed(2)),
    );
  }

  // ── Aggregates ─────────────────────────────────────────────────────────────

  double totalIncome(List<TransactionModel> transactions) =>
      _sum(transactions.where((t) => t.type == TransactionType.income));

  double totalExpense(List<TransactionModel> transactions) =>
      _sum(transactions.where((t) => t.type == TransactionType.expense));

  double totalSavings(List<TransactionModel> transactions) =>
      _sum(transactions.where((t) => t.type == TransactionType.savings));

  double totalTransfer(List<TransactionModel> transactions) =>
      _sum(transactions.where((t) => t.type == TransactionType.transfer));

  double netForMonth(List<TransactionModel> transactions) =>
      double.parse((totalIncome(transactions) - totalExpense(transactions))
          .toStringAsFixed(2));

  double _sum(Iterable<TransactionModel> transactions) =>
      double.parse(transactions
          .fold(0.0, (s, t) => s + t.amount)
          .toStringAsFixed(2));
}