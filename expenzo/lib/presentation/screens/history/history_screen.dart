import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          const SizedBox(height: 8),
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
    final monthTransactions = ref.watch(monthTransactionsProvider);
    final filtered = _applyFilters(monthTransactions);

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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final t = filtered[i];
        final showDate = i == 0 ||
            filtered[i - 1].dateTime.day != t.dateTime.day ||
            filtered[i - 1].dateTime.month != t.dateTime.month;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDate) _DateHeader(dateTime: t.dateTime),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TransactionTile(
                transaction: t,
                swipeEnabled: true,
                onEdit: () => context.push('/edit-transaction/${t.id}'),
                onDelete: () => _deleteTransaction(t.id),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTransaction(String id) async {
    await ref.read(transactionNotifierProvider.notifier).delete(id);
  }

  List<TransactionModel> _applyFilters(List<TransactionModel> transactions) {
    var result = transactions;

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
    if (result != null) {
      setState(() => _filter = result);
    }
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.dateTime});
  final DateTime dateTime;

  @override
  Widget build(BuildContext context) {
    // Format: "Today", "Yesterday", or date string.
    final now = DateTime.now();
    final isToday = dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day;

    String label;
    if (isToday) {
      label = 'Today';
    } else if (isYesterday) {
      label = 'Yesterday';
    } else {
      label = dateTime.displayDate;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 0, 8),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

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

// Extension for display date — added locally to avoid import dependency.
extension _DateExt on DateTime {
  String get displayDate {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '$day ${months[month]} $year';
  }
}