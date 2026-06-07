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
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/common/expenzo_app_bar.dart';
import '../transaction/widgets/amount_calculator.dart';

// ── Charge preset ─────────────────────────────────────────────────────────────

class _ChargePreset {
  const _ChargePreset(this.label, this.rate);
  final String label;
  final double rate; // 0.0 = free
}

const _cashOutPresets = [
  _ChargePreset('Normal Agent (1.85%)', 0.0185),
  _ChargePreset('Favourite Agent (1.49%)', 0.0149),
];

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  static const _uuid = Uuid();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  bool _bkashToCash = false; // false = Cash→bKash (free), true = bKash→Cash (charge)
  double _amount = 0;
  int _selectedPresetIndex = 0; // only used when _bkashToCash = true
  bool _isSaving = false;

  String get _fromId => _bkashToCash
      ? WalletConstants.bkashWalletId
      : WalletConstants.cashWalletId;
  String get _toId => _bkashToCash
      ? WalletConstants.cashWalletId
      : WalletConstants.bkashWalletId;
  String get _fromName => _bkashToCash ? 'bKash' : 'Cash';
  String get _toName => _bkashToCash ? 'Cash' : 'bKash';

  double get _chargeRate =>
      _bkashToCash ? _cashOutPresets[_selectedPresetIndex].rate : 0.0;
  double get _chargeAmount =>
      double.parse((_amount * _chargeRate).toStringAsFixed(2));
  double get _totalDeducted =>
      double.parse((_amount + _chargeAmount).toStringAsFixed(2));
  double get _received => _amount; // receiver always gets exact amount

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

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

  IconData _walletIcon(String id) => id == WalletConstants.cashWalletId
      ? Icons.payments_outlined
      : Icons.phone_android_outlined;

  Future<void> _save(Map<String, double> balanceMap) async {
    if (_amount <= 0) {
      _showError('Enter an amount.');
      return;
    }
    final available = balanceMap[_fromId] ?? 0.0;
    if (_totalDeducted > available) {
      _showError(
          'Insufficient balance in $_fromName.\n'
          'You need ${_totalDeducted.toCurrency} (amount + charge).\n'
          'Available: ${available.toCurrency}');
      return;
    }

    setState(() => _isSaving = true);
    try {
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
      final isCashOut = _bkashToCash && _chargeAmount > 0;
      final title = _titleController.text.trim().isEmpty
          ? '$_fromName → $_toName${isCashOut ? ' (Cash Out)' : ''}'
          : _titleController.text.trim();

      // Main transfer record — amount is what receiver gets.
      final txn = TransactionModel(
        id: _uuid.v4(),
        title: title,
        // Total deducted from source = amount + charge.
        // We store totalDeducted as the transaction amount so the source
        // wallet is correctly debited by the full amount including charge.
        amount: _totalDeducted,
        type: TransactionType.transfer,
        categoryId: categoryId,
        sourceWalletId: _fromId,
        destinationWalletId: _toId,
        dateTime: now,
        note: _buildNote(),
        monthKey: now.monthKey,
        createdAt: now,
        updatedAt: now,
      );

      await ref.read(transactionNotifierProvider.notifier).add(txn);

      // If there's a charge, record it separately as an expense from source wallet
      // so reports show the true cost.
      if (_chargeAmount > 0) {
        final chargeCategoryId = allCats
                .where((c) => c.type == TransactionType.expense)
                .map((c) => c.id)
                .firstOrNull ??
            'cat_expense_other';
        final chargeTxn = TransactionModel(
          id: _uuid.v4(),
          title: 'bKash Charge (${(_chargeRate * 100).toStringAsFixed(2)}%)',
          amount: _chargeAmount,
          type: TransactionType.expense,
          categoryId: chargeCategoryId,
          sourceWalletId: _fromId,
          destinationWalletId: null,
          dateTime: now,
          note: 'Auto-calculated cash out charge for $_title',
          monthKey: now.monthKey,
          createdAt: now,
          updatedAt: now,
        );
        await ref.read(transactionNotifierProvider.notifier).add(chargeTxn);
      }

      if (mounted) _showSuccess(available);
    } catch (e) {
      if (mounted) _showError('Transfer failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _title => _titleController.text.trim().isEmpty
      ? '$_fromName → $_toName'
      : _titleController.text.trim();

  String? _buildNote() {
    final parts = <String>[];
    if (_noteController.text.trim().isNotEmpty) {
      parts.add(_noteController.text.trim());
    }
    if (_chargeAmount > 0) {
      parts.add(
          'Charge: ${(_chargeRate * 100).toStringAsFixed(2)}% = ${_chargeAmount.toCurrency}');
    }
    return parts.isEmpty ? null : parts.join(' | ');
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error),
            SizedBox(width: 8),
            Text('Cannot Transfer'),
          ],
        ),
        content: Text(msg, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(double availableBefore) {
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReceiptRow('Amount transferred', _amount.toCurrency),
            if (_chargeAmount > 0) ...[
              _ReceiptRow(
                  'bKash charge (${(_chargeRate * 100).toStringAsFixed(2)}%)',
                  _chargeAmount.toCurrency,
                  color: AppColors.expense),
              const Divider(height: 16),
              _ReceiptRow('Total deducted from $_fromName',
                  _totalDeducted.toCurrency,
                  bold: true),
            ],
            const SizedBox(height: 8),
            _ReceiptRow('$_fromName remaining',
                (availableBefore - _totalDeducted).toCurrency),
          ],
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

  @override
  Widget build(BuildContext context) {
    final balanceMap = ref.watch(walletBalanceMapProvider);
    final fromBalance = balanceMap[_fromId] ?? 0.0;
    final toBalance = balanceMap[_toId] ?? 0.0;
    final isOverdrawn = _amount > 0 && _totalDeducted > fromBalance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ExpenzoAppBar(title: 'Transfer', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildBalanceOverview(balanceMap),
          const SizedBox(height: 20),
          _buildDirectionToggle(),
          const SizedBox(height: 20),
          _buildAmountField(fromBalance, isOverdrawn),
          const SizedBox(height: 16),
          if (_bkashToCash) ...[
            _buildChargeSelector(),
            const SizedBox(height: 16),
          ],
          if (_amount > 0) ...[
            _buildBreakdown(fromBalance, toBalance, isOverdrawn),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              prefixIcon: Icon(Icons.title_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
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

  Widget _buildBalanceOverview(Map<String, double> balanceMap) {
    final ids = [
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
            children: ids.map((w) {
              final id = w.$1;
              final name = w.$2;
              final bal = balanceMap[id] ?? 0.0;
              final color = _walletColor(id);
              final isFrom = id == _fromId;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: isFrom ? AppColors.expenseLight : AppColors.incomeLight,
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
                      Icon(_walletIcon(id), color: color, size: 22),
                      const SizedBox(height: 6),
                      Text(name,
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(bal.toCurrency,
                            style: AppTextStyles.amountSmall
                                .copyWith(color: color)),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
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
                            fontSize: 9,
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

  Widget _buildDirectionToggle() {
    return Row(
      children: [
        Expanded(
          child: _DirectionButton(
            fromName: 'Cash',
            toName: 'bKash',
            fromColor: AppColors.cashWallet,
            toColor: AppColors.bkashWallet,
            badge: 'Free',
            badgeColor: AppColors.income,
            isSelected: !_bkashToCash,
            onTap: () { if (_bkashToCash) setState(() => _bkashToCash = false); },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DirectionButton(
            fromName: 'bKash',
            toName: 'Cash',
            fromColor: AppColors.bkashWallet,
            toColor: AppColors.cashWallet,
            badge: 'Charge applies',
            badgeColor: AppColors.expense,
            isSelected: _bkashToCash,
            onTap: () { if (!_bkashToCash) setState(() => _bkashToCash = true); },
          ),
        ),
      ],
    );
  }

  Widget _buildChargeSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.percent, size: 16, color: AppColors.savings),
              const SizedBox(width: 6),
              Text('Cash Out Charge Rate',
                  style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(_cashOutPresets.length, (i) {
              final p = _cashOutPresets[i];
              final sel = _selectedPresetIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPresetIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.savings.withValues(alpha: 0.1)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? AppColors.savings : AppColors.border,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(p.rate * 100).toStringAsFixed(2)}%',
                          style: AppTextStyles.amountSmall.copyWith(
                            color: sel
                                ? AppColors.savings
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          p.label.split('(')[0].trim(),
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField(double fromBalance, bool isOverdrawn) {
    return GestureDetector(
      onTap: () async {
        final result =
            await AmountCalculator.show(context, initialValue: _amount);
        if (result != null && mounted) setState(() => _amount = result);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
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
                  Text('Amount to Transfer', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _amount > 0 ? _amount.toCurrency : 'Tap to enter amount',
                      style: _amount > 0
                          ? AppTextStyles.amountLarge.copyWith(
                              color: isOverdrawn
                                  ? AppColors.error
                                  : AppColors.transfer)
                          : AppTextStyles.bodyLarge
                              .copyWith(color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.calculate_outlined,
                color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdown(
      double fromBalance, double toBalance, bool isOverdrawn) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOverdrawn ? AppColors.expenseLight : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdrawn
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOverdrawn
                    ? Icons.warning_amber_outlined
                    : Icons.receipt_long_outlined,
                size: 16,
                color: isOverdrawn ? AppColors.error : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                isOverdrawn ? 'Insufficient Balance' : 'Transaction Breakdown',
                style: AppTextStyles.titleMedium.copyWith(
                    color: isOverdrawn
                        ? AppColors.error
                        : AppColors.textPrimary),
              ),
            ],
          ),
          const Divider(height: 16),
          _ReceiptRow('Transfer amount', _amount.toCurrency),
          if (_bkashToCash && _chargeAmount > 0) ...[
            _ReceiptRow(
              'bKash charge (${(_chargeRate * 100).toStringAsFixed(2)}%)',
              _chargeAmount.toCurrency,
              color: AppColors.expense,
            ),
            const Divider(height: 12),
            _ReceiptRow(
              'Total deducted from $_fromName',
              _totalDeducted.toCurrency,
              bold: true,
              color: isOverdrawn ? AppColors.error : AppColors.textPrimary,
            ),
          ],
          const Divider(height: 12),
          _ReceiptRow(
            '$_fromName after transfer',
            isOverdrawn
                ? 'Not enough'
                : (fromBalance - _totalDeducted).toCurrency,
            color: isOverdrawn ? AppColors.error : AppColors.expense,
          ),
          _ReceiptRow(
            '$_toName after transfer',
            (toBalance + _amount).toCurrency,
            color: AppColors.income,
          ),
          if (!_bkashToCash) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 14, color: AppColors.income),
                const SizedBox(width: 6),
                Text('Cash In is completely free',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.income)),
              ],
            ),
          ],
        ],
      ),
    );
  }

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
          onPressed: (_isSaving || !canTransfer) ? null : () => _save(balanceMap),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isOverdrawn ? AppColors.error : AppColors.transfer,
            disabledBackgroundColor:
                AppColors.transfer.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Text(
                  _amount <= 0
                      ? 'Enter Amount'
                      : isOverdrawn
                          ? 'Insufficient Balance'
                          : _bkashToCash && _chargeAmount > 0
                              ? 'Transfer (Total: ${_totalDeducted.toCurrency})'
                              : 'Transfer ${_amount.toCurrency}',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: Colors.white),
                ),
        ),
      ),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.fromName, required this.toName,
    required this.fromColor, required this.toColor,
    required this.badge, required this.badgeColor,
    required this.isSelected, required this.onTap,
  });
  final String fromName, toName, badge;
  final Color fromColor, toColor, badgeColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.transfer.withValues(alpha: 0.08)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
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
                Icon(fromName == 'Cash' ? Icons.payments_outlined : Icons.phone_android_outlined,
                    color: fromColor, size: 17),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(Icons.arrow_forward, size: 12,
                      color: isSelected ? AppColors.transfer : AppColors.textTertiary),
                ),
                Icon(toName == 'Cash' ? Icons.payments_outlined : Icons.phone_android_outlined,
                    color: toColor, size: 17),
              ],
            ),
            const SizedBox(height: 5),
            Text('$fromName → $toName',
                style: AppTextStyles.labelMedium.copyWith(
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                )),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(badge,
                  style: AppTextStyles.labelSmall.copyWith(
                      color: badgeColor, fontWeight: FontWeight.w600, fontSize: 9)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(this.label, this.value, {this.bold = false, this.color});
  final String label, value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? AppTextStyles.titleMedium.copyWith(color: color)
        : AppTextStyles.bodyMedium.copyWith(color: color ?? AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label,
              style: bold ? AppTextStyles.titleMedium : AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary))),
          const SizedBox(width: 8),
          Text(value, style: style),
        ],
      ),
    );
  }
}