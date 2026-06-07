import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/transaction_type.dart';
import '../../../../core/extensions/double_ext.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../providers/transaction_provider.dart';
import '../../../widgets/common/empty_state.dart';
import '../../history/widgets/transaction_tile.dart';

class TodayTransactionsList extends ConsumerWidget {
  const TodayTransactionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allTransactionsProvider);
    final today = DateTime.now();

    final todayTxns = all.where((t) {
      return t.dateTime.year == today.year &&
          t.dateTime.month == today.month &&
          t.dateTime.day == today.day;
    }).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    if (todayTxns.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyState(
          message: "No transactions today",
          subtitle: 'Tap + to record your first transaction today',
          icon: Icons.receipt_long_outlined,
        ),
      );
    }

    // Calculate today's total expense.
    final todayExpense = todayTxns
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          // First item: today's expense summary bar.
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (todayExpense > 0)
                  _TodayExpenseBanner(totalExpense: todayExpense),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TransactionTile(
                    transaction: todayTxns[0],
                    swipeEnabled: true,
                    onEdit: () => context
                        .push('/edit-transaction/${todayTxns[0].id}'),
                    onDelete: () => ref
                        .read(transactionNotifierProvider.notifier)
                        .delete(todayTxns[0].id),
                  ),
                ),
              ],
            );
          }
          // Last item: bottom spacer for FAB + bottom bar clearance.
          if (i == todayTxns.length) {
            return const SizedBox(height: 120);
          }
          final t = todayTxns[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TransactionTile(
              transaction: t,
              swipeEnabled: true,
              onEdit: () => context.push('/edit-transaction/${t.id}'),
              onDelete: () => ref
                  .read(transactionNotifierProvider.notifier)
                  .delete(t.id),
            ),
          );
        },
        childCount: todayTxns.length + 1,
      ),
    );
  }
}

/// Small banner showing today's total expense below the header.
class _TodayExpenseBanner extends StatelessWidget {
  const _TodayExpenseBanner({required this.totalExpense});
  final double totalExpense;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.expenseLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.expense.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_upward, size: 15, color: AppColors.expense),
          const SizedBox(width: 8),
          Text(
            "Today's total expense:",
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            totalExpense.toCurrency,
            style: AppTextStyles.titleMedium
                .copyWith(color: AppColors.expense),
          ),
        ],
      ),
    );
  }
}