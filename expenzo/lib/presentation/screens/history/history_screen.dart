import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/enums/transaction_type.dart';
import '../../../core/extensions/double_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/month_navigator.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/transaction_tile.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  TransactionFilter _filter = const TransactionFilter();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('History', style: AppTextStyles.headlineSmall),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          _FilterButton(
            isActive: _filter.isActive,
            onTap: () => _showFilterSheet(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _SearchBar(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            child: const MonthNavigator(),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: transactionsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (_) => _buildList(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final monthTxns = ref.watch(monthTransactionsProvider);
    final filtered = _applyFilters(monthTxns);

    if (filtered.isEmpty) {
      return EmptyState(
        message: _filter.isActive || _searchQuery.isNotEmpty
            ? 'No matching transactions'
            : 'No transactions this month',
        subtitle: _filter.isActive || _searchQuery.isNotEmpty
            ? 'Try adjusting your filters'
            : 'Tap + to add a transaction',
        icon: Icons.search_off_outlined,
      );
    }

    // Group transactions by calendar day.
    // Map: "YYYY-MM-DD" → list of transactions that day.
    final grouped = <String, List<TransactionModel>>{};
    for (final t in filtered) {
      final key = '${t.dateTime.year}-'
          '${t.dateTime.month.toString().padLeft(2, '0')}-'
          '${t.dateTime.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(t);
    }
    // Sorted day keys newest first.
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemCount: days.length,
      itemBuilder: (context, dayIndex) {
        final dayKey = days[dayIndex];
        final dayTxns = grouped[dayKey]!;
        // Sort within day newest first.
        dayTxns.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        // Day's total expense.
        final dayExpense = dayTxns
            .where((t) => t.type == TransactionType.expense)
            .fold(0.0, (s, t) => s + t.amount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header with total expense.
            _DayHeader(
              dateTime: dayTxns.first.dateTime,
              totalExpense: dayExpense,
            ),
            ...dayTxns.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TransactionTile(
                transaction: t,
                swipeEnabled: true,
                onEdit: () => context.push('/edit-transaction/${t.id}'),
                onDelete: () => _deleteTransaction(t.id),
              ),
            )),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  Future<void> _deleteTransaction(String id) async {
    await ref.read(transactionNotifierProvider.notifier).delete(id);
  }

  List<TransactionModel> _applyFilters(List<TransactionModel> txns) {
    var result = txns;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((t) =>
              (t.title?.toLowerCase().contains(q) ?? false) ||
              (t.note?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    if (_filter.type != null) {
      result = result.where((t) => t.type == _filter.type).toList();
    }
    if (_filter.categoryId != null) {
      result =
          result.where((t) => t.categoryId == _filter.categoryId).toList();
    }
    if (_filter.walletId != null) {
      result = result
          .where((t) =>
              t.sourceWalletId == _filter.walletId ||
              t.destinationWalletId == _filter.walletId)
          .toList();
    }
    return result;
  }

  void _showFilterSheet(BuildContext context) async {
    final result = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterSheet(currentFilter: _filter),
    );
    if (result != null) setState(() => _filter = result);
  }
}

// ── Day header with expense total ─────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.dateTime,
    required this.totalExpense,
  });
  final DateTime dateTime;
  final double totalExpense;

  String get _label {
    final now = DateTime.now();
    final isToday = dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day;

    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dateTime.day} ${months[dateTime.month]} ${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Only show expense total if there are expenses that day.
          if (totalExpense > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.expenseLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.expense.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_upward,
                      size: 11, color: AppColors.expense),
                  const SizedBox(width: 4),
                  Text(
                    totalExpense.toCurrency,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.expense,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search transactions…',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      textInputAction: TextInputAction.search,
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.isActive, required this.onTap});
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.tune_outlined),
        ),
        if (isActive)
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}