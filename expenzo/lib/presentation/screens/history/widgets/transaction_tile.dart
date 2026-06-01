import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../core/enums/transaction_type.dart';
import '../../../../core/extensions/datetime_ext.dart';
import '../../../../core/extensions/double_ext.dart';
import '../../../../core/extensions/string_ext.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../../domain/entities/category.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../widgets/common/confirmation_dialog.dart';

class TransactionTile extends ConsumerWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
    this.swipeEnabled = true,
  });

  final TransactionModel transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool swipeEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryMap = ref.watch(categoryMapProvider);
    final wallets = ref.watch(allWalletsProvider);

    final category = categoryMap[transaction.categoryId] != null
        ? Category.fromModel(categoryMap[transaction.categoryId]!)
        : Category.unknown;

    final sourceWallet = wallets
        .where((w) => w.id == transaction.sourceWalletId)
        .map((w) => w.name)
        .firstOrNull;

    final destWallet = transaction.destinationWalletId != null
        ? wallets
            .where((w) => w.id == transaction.destinationWalletId)
            .map((w) => w.name)
            .firstOrNull
        : null;

    final tile = GestureDetector(
      onTap: () => _showDetails(context, ref, category, sourceWallet, destWallet),
      child: _buildTileContent(context, category, sourceWallet, destWallet),
    );

    if (!swipeEnabled) return tile;

    return Slidable(
      key: ValueKey(transaction.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.45,
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: Icons.edit_outlined,
            label: 'Edit',
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
          SlidableAction(
            onPressed: (_) => _confirmDelete(context),
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => _showDetails(context, ref, category, sourceWallet, destWallet),
        child: _buildTileContent(context, category, sourceWallet, destWallet),
      ),
    );
  }

  Widget _buildTileContent(
    BuildContext context,
    Category category,
    String? sourceWallet,
    String? destWallet,
  ) {
    final isTransfer = transaction.type == TransactionType.transfer;
    final isSavings = transaction.type == TransactionType.savings;
    final isIncome = transaction.type == TransactionType.income;

    Color amountColor;
    if (isTransfer) {
      amountColor = AppColors.transfer;
    } else if (isSavings) {
      amountColor = AppColors.savings;
    } else if (isIncome) {
      amountColor = AppColors.income;
    } else {
      amountColor = AppColors.expense;
    }

    final amountPrefix =
        isIncome ? '+' : (isTransfer || isSavings) ? '' : '-';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Color(category.colorHex.colorValue).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            IconUtils.fromName(category.iconName),
            color: Color(category.colorHex.colorValue),
            size: 22,
          ),
        ),
        title: Text(
          transaction.title?.isNotEmpty == true
              ? transaction.title!
              : category.name,
          style: AppTextStyles.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              _walletLabel(sourceWallet, destWallet, isTransfer, isSavings),
              style: AppTextStyles.bodySmall,
            ),
            Text(
              transaction.dateTime.displayDateTime,
              style: AppTextStyles.labelSmall,
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$amountPrefix${transaction.amount.toCurrency}',
              style: AppTextStyles.amountSmall.copyWith(color: amountColor),
            ),
            const SizedBox(height: 2),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: amountColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                transaction.type.label,
                style: AppTextStyles.labelSmall.copyWith(color: amountColor),
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  String _walletLabel(
    String? source,
    String? dest,
    bool isTransfer,
    bool isSavings,
  ) {
    if ((isTransfer || isSavings) && source != null && dest != null) {
      return '$source → $dest';
    }
    return source ?? '';
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Transaction',
      message:
          'This transaction will be permanently deleted and your balance will update.',
    );
    if (confirmed) onDelete();
  }

  void _showDetails(
    BuildContext context,
    WidgetRef ref,
    Category category,
    String? sourceWallet,
    String? destWallet,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionDetailSheet(
        transaction: transaction,
        category: category,
        sourceWallet: sourceWallet,
        destWallet: destWallet,
        onEdit: () {
          Navigator.of(context).pop();
          onEdit();
        },
        onDelete: () async {
          Navigator.of(context).pop();
          final confirmed = await ConfirmationDialog.show(
            context,
            title: 'Delete Transaction',
            message:
                'This transaction will be permanently deleted and your balance will update.',
          );
          if (confirmed) onDelete();
        },
      ),
    );
  }
}

// ── Detail sheet ────────────────────────────────────────────────────────────

class _TransactionDetailSheet extends StatelessWidget {
  const _TransactionDetailSheet({
    required this.transaction,
    required this.category,
    required this.sourceWallet,
    required this.destWallet,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionModel transaction;
  final Category category;
  final String? sourceWallet;
  final String? destWallet;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isTransfer = transaction.type == TransactionType.transfer;
    final isSavings = transaction.type == TransactionType.savings;
    final isIncome = transaction.type == TransactionType.income;

    Color typeColor;
    if (isTransfer) {
      typeColor = AppColors.transfer;
    } else if (isSavings) {
      typeColor = AppColors.savings;
    } else if (isIncome) {
      typeColor = AppColors.income;
    } else {
      typeColor = AppColors.expense;
    }

    final amountPrefix =
        isIncome ? '+' : (isTransfer || isSavings) ? '' : '-';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(category.colorHex.colorValue)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  IconUtils.fromName(category.iconName),
                  color: Color(category.colorHex.colorValue),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title?.isNotEmpty == true
                          ? transaction.title!
                          : category.name,
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        transaction.type.label,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: typeColor),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$amountPrefix${transaction.amount.toCurrency}',
                style: AppTextStyles.amountLarge.copyWith(color: typeColor),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _DetailRow(
            icon: Icons.category_outlined,
            label: 'Category',
            value: category.name,
          ),
          if (isTransfer || isSavings) ...[
            _DetailRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'From',
              value: sourceWallet ?? '—',
            ),
            _DetailRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'To',
              value: destWallet ?? '—',
            ),
          ] else
            _DetailRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Wallet',
              value: sourceWallet ?? '—',
            ),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date & Time',
            value: transaction.dateTime.displayDateTime,
          ),
          if (transaction.note?.isNotEmpty == true)
            _DetailRow(
              icon: Icons.notes_outlined,
              label: 'Note',
              value: transaction.note!,
            ),

          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
    );
  }
}