import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/double_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/summary_provider.dart';
import '../../widgets/common/expenzo_app_bar.dart';
import '../../widgets/common/month_navigator.dart';

class MonthlySummaryScreen extends ConsumerWidget {
  const MonthlySummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(selectedMonthProvider);
    final summary = ref.watch(monthlySummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ExpenzoAppBar(
        title: 'Monthly Summary',
        showBack: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            color: AppColors.surface,
            child: const MonthNavigator(),
          ),
        ),
      ),
      body: summary == null
          ? const Center(child: Text('No data for this month.'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SummaryCard(
                  label: 'Total Income',
                  amount: summary.totalIncome,
                  color: AppColors.income,
                  icon: Icons.arrow_downward,
                ),
                const SizedBox(height: 12),
                _SummaryCard(
                  label: 'Total Expense',
                  amount: summary.totalExpense,
                  color: AppColors.expense,
                  icon: Icons.arrow_upward,
                ),
                const SizedBox(height: 12),
                _SummaryCard(
                  label: 'Net Savings',
                  amount: summary.netChange,
                  color: summary.netChange >= 0
                      ? AppColors.income
                      : AppColors.expense,
                  icon: summary.netChange >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                ),
                const SizedBox(height: 12),
                _SummaryCard(
                  label: 'Savings Deposits',
                  amount: summary.totalSavings,
                  color: AppColors.savings,
                  icon: Icons.savings_outlined,
                ),
                const SizedBox(height: 24),
                Text('Wallet Balances', style: AppTextStyles.titleLarge),
                const SizedBox(height: 12),
                ...summary.walletSummaries.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WalletSummaryRow(
                      name: w.walletName,
                      balance: w.balance,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Opening Balance',
                        value: summary.openingBalance.toCurrency,
                      ),
                      const Divider(height: 20),
                      _DetailRow(
                        label: 'Closing Balance',
                        value: summary.closingBalance.toCurrency,
                        valueColor: summary.closingBalance >=
                                summary.openingBalance
                            ? AppColors.income
                            : AppColors.expense,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: AppTextStyles.titleMedium),
          ),
          Text(
            amount.toCurrency,
            style: AppTextStyles.amountMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _WalletSummaryRow extends StatelessWidget {
  const _WalletSummaryRow({required this.name, required this.balance});
  final String name;
  final double balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: AppTextStyles.bodyMedium)),
          Text(
            balance.toCurrency,
            style: AppTextStyles.amountSmall.copyWith(
              color: balance >= 0 ? AppColors.income : AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium),
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}