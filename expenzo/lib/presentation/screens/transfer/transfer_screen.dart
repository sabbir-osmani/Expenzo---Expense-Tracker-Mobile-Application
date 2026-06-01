import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/wallet_constants.dart';
import '../../../core/enums/transaction_type.dart';
import '../../../core/extensions/datetime_ext.dart';
import '../../../core/extensions/double_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/balance_service_ext.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/common/expenzo_app_bar.dart';
import '../transaction/widgets/amount_calculator.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  static const _uuid = Uuid();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  // Only 2 directions: Cash → bKash, bKash → Cash.
  // false = Cash → bKash, true = bKash → Cash.
  bool _bkashToCash = false;

  double _amount = 0;
  bool _isSaving = false;

  String get _fromId => _bkashToCash
      ? WalletConstants.bkashWalletId
      : WalletConstants.cashWalletId;

  String get _toId => _bkashToCash
      ? WalletConstants.cashWalletId
      : WalletConstants.bkashWalletId;

  String get _fromName => _bkashToCash ? 'bKash' : 'Cash';
  String get _toName => _bkashToCash ? 'Cash' : 'bKash';

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _walletColor(String id) {
    switch (id) {
      case WalletConstants.cashWalletId:
        return AppColors.cashWallet;
      case WalletConstants.bkashWalletId:
        return AppColors.bkashWallet;
      default:
        return AppColors.primary;
    }
  }

  IconData _walletIcon(String id) {
    switch (id) {
      case WalletConstants.cashWalletId:
        return Icons.payments_outlined;
      case WalletConstants.bkashWalletId:
        return Icons.phone_android_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save(Map<String, double> balanceMap) async {
    if (_amount <= 0) {
      _snack('Enter an amount.');
      return;
    }

    final available = balanceMap[_fromId] ?? 0.0;

    if (_amount > available) {
      _snack(
        'Insufficient balance in $_fromName.\nAvailable: ${available.toCurrency}',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Resolve category — transfer doesn't need a user-facing category.
      final allCats = ref.read(allCategoriesProvider);
      final categoryId = allCats
              .where((c) =>
                  c.id == 'cat_transfer_internal' ||
                  c.type == TransactionType.transfer)
              .map((c) => c.id)
              .firstOrNull ??
          allCats
              .where((c) => c.type == TransactionType.expense)
              .map((c) => c.id)
              .firstOrNull ??
          'cat_expense_other';

      final now = DateTime.now();
      final title = _titleController.text.trim().isEmpty
          ? '$_fromName → $_toName'
          : _titleController.text.trim();

      final txn = TransactionModel(
        id: _uuid.v4(),
        title: title,
        amount: _amount.rounded,
        type: TransactionType.transfer,
        categoryId: categoryId,
        sourceWalletId: _fromId,
        destinationWalletId: _toId,
        dateTime: now,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        monthKey: now.monthKey,
        createdAt: now,
        updatedAt: now,
      );

      await ref.read(transactionNotifierProvider.notifier).add(txn);

      if (mounted) _showSuccess(available);
    } catch (e) {
      if (mounted) _snack('Transfer failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : null,
    ));
  }

  void _showSuccess(double availableBefore) {
    final remaining = availableBefore - _amount;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.income),
            SizedBox(width: 8),
            Text('Transfer Done'),
          ],
        ),
        content: Text(
          '${_amount.toCurrency} transferred from $_fromName to $_toName.\n\n'
          '$_fromName remaining: ${remaining.toCurrency}',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final balanceMap = ref.watch(walletBalanceMapProvider);
    final fromBalance = balanceMap[_fromId] ?? 0.0;
    final toBalance = balanceMap[_toId] ?? 0.0;
    final afterTransfer = fromBalance - _amount;
    final isOverdrawn = _amount > 0 && _amount > fromBalance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ExpenzoAppBar(title: 'Transfer', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── 1. Live wallet balances ────────────────────────────────────
          _buildBalanceOverview(balanceMap),
          const SizedBox(height: 20),

          // ── 2. Direction toggle ────────────────────────────────────────
          _buildDirectionToggle(),
          const SizedBox(height: 20),

          // ── 3. Amount input ────────────────────────────────────────────
          _buildAmountField(fromBalance, isOverdrawn),
          const SizedBox(height: 16),

          // ── 4. After-transfer preview ──────────────────────────────────
          if (_amount > 0) ...[
            _buildPreview(fromBalance, toBalance, afterTransfer, isOverdrawn),
            const SizedBox(height: 16),
          ],

          // ── 5. Title ───────────────────────────────────────────────────
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              prefixIcon: Icon(Icons.title_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),

          // ── 6. Note ────────────────────────────────────────────────────
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
              alignLabelWithHint: true,
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 100),
        ],
      ),
      bottomNavigationBar: _buildConfirmBar(balanceMap, isOverdrawn),
    );
  }

  // ── Balance overview ───────────────────────────────────────────────────────

  Widget _buildBalanceOverview(Map<String, double> balanceMap) {
    final wallets = [
      (WalletConstants.cashWalletId, 'Cash'),
      (WalletConstants.bkashWalletId, 'bKash'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Balances', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: wallets.map((w) {
              final id = w.$1;
              final name = w.$2;
              final balance = balanceMap[id] ?? 0.0;
              final color = _walletColor(id);
              final isFrom = id == _fromId;
              final isTo = id == _toId;

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    color: isFrom
                        ? AppColors.expenseLight
                        : AppColors.incomeLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFrom
                          ? AppColors.expense.withValues(alpha: 0.4)
                          : AppColors.income.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(_walletIcon(id), color: color, size: 24),
                      const SizedBox(height: 6),
                      Text(name,
                          style: AppTextStyles.labelMedium
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          balance.toCurrency,
                          style: AppTextStyles.amountSmall.copyWith(color: color),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isFrom
                              ? AppColors.expense.withValues(alpha: 0.15)
                              : AppColors.income.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isFrom ? 'FROM' : 'TO',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isFrom ? AppColors.expense : AppColors.income,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Direction toggle ───────────────────────────────────────────────────────

  Widget _buildDirectionToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transfer Direction', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              // Cash → bKash
              Expanded(
                child: _DirectionButton(
                  fromName: 'Cash',
                  toName: 'bKash',
                  fromColor: AppColors.cashWallet,
                  toColor: AppColors.bkashWallet,
                  fromIcon: Icons.payments_outlined,
                  toIcon: Icons.phone_android_outlined,
                  isSelected: !_bkashToCash,
                  onTap: () {
                    if (_bkashToCash) setState(() => _bkashToCash = false);
                  },
                ),
              ),
              const SizedBox(width: 10),
              // bKash → Cash
              Expanded(
                child: _DirectionButton(
                  fromName: 'bKash',
                  toName: 'Cash',
                  fromColor: AppColors.bkashWallet,
                  toColor: AppColors.cashWallet,
                  fromIcon: Icons.phone_android_outlined,
                  toIcon: Icons.payments_outlined,
                  isSelected: _bkashToCash,
                  onTap: () {
                    if (!_bkashToCash) setState(() => _bkashToCash = true);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Amount field ───────────────────────────────────────────────────────────

  Widget _buildAmountField(double fromBalance, bool isOverdrawn) {
    return GestureDetector(
      onTap: () async {
        final result =
            await AmountCalculator.show(context, initialValue: _amount);
        if (result != null && mounted) setState(() => _amount = result);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOverdrawn
                ? AppColors.error
                : _amount > 0
                    ? AppColors.transfer
                    : AppColors.border,
            width: _amount > 0 ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _amount > 0
                          ? _amount.toCurrency
                          : 'Tap to enter amount',
                      style: _amount > 0
                          ? AppTextStyles.amountLarge.copyWith(
                              color: isOverdrawn
                                  ? AppColors.error
                                  : AppColors.transfer)
                          : AppTextStyles.bodyLarge
                              .copyWith(color: AppColors.textTertiary),
                    ),
                  ),
                  if (isOverdrawn) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Exceeds $_fromName balance (${fromBalance.toCurrency})',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.calculate_outlined,
              color: isOverdrawn ? AppColors.error : AppColors.primary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // ── After-transfer preview ─────────────────────────────────────────────────

  Widget _buildPreview(double fromBalance, double toBalance,
      double afterTransfer, bool isOverdrawn) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOverdrawn ? AppColors.expenseLight : AppColors.incomeLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdrawn
              ? AppColors.error.withValues(alpha: 0.4)
              : AppColors.income.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_fromName after transfer:',
                  style: AppTextStyles.bodySmall),
              Text(
                isOverdrawn ? 'Insufficient' : afterTransfer.toCurrency,
                style: AppTextStyles.titleMedium.copyWith(
                    color:
                        isOverdrawn ? AppColors.error : AppColors.expense),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_toName after transfer:',
                  style: AppTextStyles.bodySmall),
              Text(
                (toBalance + _amount).toCurrency,
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.income),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Confirm bar ────────────────────────────────────────────────────────────

  Widget _buildConfirmBar(Map<String, double> balanceMap, bool isOverdrawn) {
    final canTransfer = _amount > 0 && !isOverdrawn;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (_isSaving || !canTransfer)
              ? null
              : () => _save(balanceMap),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isOverdrawn ? AppColors.error : AppColors.transfer,
            disabledBackgroundColor:
                AppColors.transfer.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  _amount <= 0
                      ? 'Enter Amount'
                      : isOverdrawn
                          ? 'Insufficient Balance'
                          : 'Transfer ${_amount.toCurrency}',
                  style: AppTextStyles.titleLarge
                      .copyWith(color: Colors.white),
                ),
        ),
      ),
    );
  }
}

// ── Direction button ──────────────────────────────────────────────────────────

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.fromName,
    required this.toName,
    required this.fromColor,
    required this.toColor,
    required this.fromIcon,
    required this.toIcon,
    required this.isSelected,
    required this.onTap,
  });

  final String fromName;
  final String toName;
  final Color fromColor;
  final Color toColor;
  final IconData fromIcon;
  final IconData toIcon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.transfer.withValues(alpha: 0.08)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.transfer : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(fromIcon, color: fromColor, size: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: isSelected
                        ? AppColors.transfer
                        : AppColors.textTertiary,
                  ),
                ),
                Icon(toIcon, color: toColor, size: 20),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$fromName → $toName',
              style: AppTextStyles.labelMedium.copyWith(
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}