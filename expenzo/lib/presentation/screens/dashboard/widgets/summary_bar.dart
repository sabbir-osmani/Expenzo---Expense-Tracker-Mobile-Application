import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/double_ext.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../providers/summary_provider.dart';

class SummaryBar extends ConsumerWidget {
  const SummaryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthlySummaryProvider);
    final income = summary?.totalIncome ?? 0;
    final expense = summary?.totalExpense ?? 0;
    final net = income - expense;

    return GestureDetector(
      onTap: () => context.push('/monthly-summary'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: _SummaryItem(
                label: 'Income',
                amount: income,
                color: AppColors.income,
                icon: Icons.arrow_downward,
              ),
            ),
            Container(width: 1, height: 40, color: AppColors.border),
            Expanded(
              child: _SummaryItem(
                label: 'Expense',
                amount: expense,
                color: AppColors.expense,
                icon: Icons.arrow_upward,
              ),
            ),
            Container(width: 1, height: 40, color: AppColors.border),
            Expanded(
              child: _SummaryItem(
                label: 'Net',
                amount: net.abs(),
                color: net >= 0 ? AppColors.income : AppColors.expense,
                icon: net >= 0 ? Icons.trending_up : Icons.trending_down,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        // FittedBox prevents overflow for large numbers.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount.toCurrency,
              style: AppTextStyles.amountSmall
                  .copyWith(color: AppColors.textPrimary),
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}