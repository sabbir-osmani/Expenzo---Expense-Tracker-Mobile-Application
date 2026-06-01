import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../providers/transaction_provider.dart';
import '../../../widgets/common/empty_state.dart';
import '../../history/widgets/transaction_tile.dart';

/// Shows all transactions from today (current calendar day).
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
    }).toList();

    todayTxns.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    if (todayTxns.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyState(
          message: "No transactions today",
          subtitle: 'Tap + to record your first transaction today',
          icon: Icons.receipt_long_outlined,
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          if (i == todayTxns.length) return const SizedBox(height: 80);
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