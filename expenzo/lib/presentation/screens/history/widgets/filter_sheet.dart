import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/enums/transaction_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/wallet_provider.dart';

class TransactionFilter {
  const TransactionFilter({
    this.type,
    this.categoryId,
    this.walletId,
    this.fromDate,
    this.toDate,
  });

  final TransactionType? type;
  final String? categoryId;
  final String? walletId;
  final DateTime? fromDate;
  final DateTime? toDate;

  bool get isActive =>
      type != null ||
      categoryId != null ||
      walletId != null ||
      fromDate != null ||
      toDate != null;

  TransactionFilter copyWith({
    TransactionType? type,
    String? categoryId,
    String? walletId,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearType = false,
    bool clearCategory = false,
    bool clearWallet = false,
  }) {
    return TransactionFilter(
      type: clearType ? null : (type ?? this.type),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      walletId: clearWallet ? null : (walletId ?? this.walletId),
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }
}

class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key, required this.currentFilter});

  final TransactionFilter currentFilter;

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late TransactionFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.currentFilter;
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(allCategoriesProvider);
    final wallets = ref.watch(activeWalletsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filters', style: AppTextStyles.headlineSmall),
                    TextButton(
                      onPressed: () {
                        setState(() => _filter = const TransactionFilter());
                      },
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Type filter.
                    Text('Type', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        _TypeChip(
                          label: 'All',
                          isSelected: _filter.type == null,
                          onTap: () => setState(
                            () => _filter = _filter.copyWith(clearType: true),
                          ),
                        ),
                        ...TransactionType.values.map((t) => _TypeChip(
                              label: t.label,
                              isSelected: _filter.type == t,
                              onTap: () => setState(
                                () => _filter = _filter.copyWith(type: t),
                              ),
                            )),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Wallet filter.
                    Text('Wallet', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        _TypeChip(
                          label: 'All',
                          isSelected: _filter.walletId == null,
                          onTap: () => setState(
                            () => _filter = _filter.copyWith(clearWallet: true),
                          ),
                        ),
                        ...wallets.map((w) => _TypeChip(
                              label: w.name,
                              isSelected: _filter.walletId == w.id,
                              onTap: () => setState(
                                () => _filter = _filter.copyWith(walletId: w.id),
                              ),
                            )),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Category filter.
                    if (categories.isNotEmpty) ...[
                      Text('Category', style: AppTextStyles.titleMedium),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _filter.categoryId,
                        decoration: const InputDecoration(
                          hintText: 'All categories',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Categories'),
                          ),
                          ...categories.map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(
                          () => v == null
                              ? _filter = _filter.copyWith(clearCategory: true)
                              : _filter = _filter.copyWith(categoryId: v),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_filter),
                    child: const Text('Apply Filters'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}