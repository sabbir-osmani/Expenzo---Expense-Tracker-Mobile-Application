import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/enums/transaction_type.dart';
import '../../../core/extensions/datetime_ext.dart';
import '../../../core/extensions/double_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validator.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/balance_service_ext.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/common/expenzo_app_bar.dart';
import '../../widgets/forms/category_picker.dart';
import '../../widgets/forms/wallet_picker.dart';
import 'widgets/amount_calculator.dart';

class EditTransactionScreen extends ConsumerStatefulWidget {
  const EditTransactionScreen({super.key, required this.transactionId});
  final String transactionId;

  @override
  ConsumerState<EditTransactionScreen> createState() =>
      _EditTransactionScreenState();
}

class _EditTransactionScreenState
    extends ConsumerState<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionModel? _original;
  TransactionType? _type;
  double _amount = 0;
  String? _categoryId;
  String? _sourceWalletId;
  String? _destinationWalletId;
  DateTime? _dateTime;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  void _loadTransaction() {
    final all = ref.read(allTransactionsProvider);
    final t = all.where((t) => t.id == widget.transactionId).firstOrNull;
    if (t != null) {
      _original = t;
      _type = t.type;
      _amount = t.amount;
      _categoryId = t.categoryId;
      _sourceWalletId = t.sourceWalletId;
      _destinationWalletId = t.destinationWalletId;
      _dateTime = t.dateTime;
      _titleController.text = t.title ?? '';
      _noteController.text = t.note ?? '';
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ── Balance check excluding original transaction ───────────────────────────

  bool _validateBalance() {
    if (_type == TransactionType.income) return true;

    final allTxns = ref.read(allTransactionsProvider);
    final balanceSvc = ref.read(balanceServiceProvider);
    final originalId = _original!.id;

    String? checkWalletId;
    switch (_type) {
      case TransactionType.expense:
        checkWalletId = _sourceWalletId;
      case TransactionType.transfer:
        checkWalletId = _sourceWalletId;
      case TransactionType.savings:
        // For savings deposit: check source; for withdrawal: check savings.
        final isDeposit =
            _original!.destinationWalletId == 'wallet_savings' ||
                (_sourceWalletId != 'wallet_savings');
        checkWalletId =
            isDeposit ? _sourceWalletId : 'wallet_savings';
      default:
        return true;
    }

    if (checkWalletId == null) return true;

    final available = balanceSvc.availableBalance(
      walletId: checkWalletId,
      allTransactions: allTxns,
      excludeTransactionId: originalId,
    );

    if (_amount > available) {
      final wallets = ref.read(allWalletsProvider);
      final walletName = wallets
          .where((w) => w.id == checkWalletId)
          .map((w) => w.name)
          .firstOrNull ?? 'wallet';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Insufficient balance in $walletName.\n'
          'Available: ${available.toCurrency}',
        ),
        backgroundColor: AppColors.error,
      ));
      return false;
    }
    return true;
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_original == null || _type == null || _sourceWalletId == null) return;
    if (_amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter an amount.')));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_type!.isTransfer && _sourceWalletId == _destinationWalletId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Source and destination wallets must differ.')),
      );
      return;
    }

    if (!_validateBalance()) return;

    setState(() => _isSaving = true);
    try {
      final dt = _dateTime!;
      final updated = _original!.copyWith(
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        amount: _amount.rounded,
        categoryId: _categoryId,
        sourceWalletId: _sourceWalletId,
        destinationWalletId: _type!.isTransfer ? _destinationWalletId : null,
        dateTime: dt,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        monthKey: dt.monthKey,
        updatedAt: DateTime.now(),
      );

      await ref
          .read(transactionNotifierProvider.notifier)
          .editTransaction(updated);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Transaction updated.')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_original == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Transaction')),
        body: const Center(child: Text('Transaction not found.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ExpenzoAppBar(
        title: 'Edit Transaction',
        showBack: true, // ← Back only; top-right update button removed.
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Type badge (read-only).
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.label_outline, color: _typeColor, size: 18),
                  const SizedBox(width: 8),
                  Text(_type!.label,
                      style: AppTextStyles.titleMedium
                          .copyWith(color: _typeColor)),
                  const Spacer(),
                  Text('(type cannot be changed)',
                      style: AppTextStyles.labelSmall),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Amount.
            GestureDetector(
              onTap: () async {
                final result = await AmountCalculator.show(context,
                    initialValue: _amount);
                if (result != null && mounted) {
                  setState(() => _amount = result);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amount', style: AppTextStyles.labelMedium),
                          const SizedBox(height: 4),
                          Text(
                            _amount > 0
                                ? _amount.toCurrency
                                : 'Tap to enter',
                            style: AppTextStyles.amountLarge
                                .copyWith(color: _typeColor),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.calculate_outlined,
                        color: AppColors.primary, size: 24),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date.
            GestureDetector(
              onTap: _pickDateTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_outlined,
                        color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_dateTime?.displayDateTime ?? '',
                          style: AppTextStyles.bodyMedium),
                    ),
                    const Icon(Icons.edit_outlined,
                        color: AppColors.textTertiary, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category — only for income/expense.
            if (_type == TransactionType.income ||
                _type == TransactionType.expense) ...[
              CategoryPicker(
                selectedCategoryId: _categoryId,
                transactionType: _type!,
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 16),
            ],

            // Wallet section.
            if (_type == TransactionType.transfer ||
                _type == TransactionType.savings) ...[
              WalletPicker(
                selectedWalletId: _sourceWalletId,
                onChanged: (v) =>
                    setState(() => _sourceWalletId = v),
                label: 'From Wallet',
                excludeWalletId: _destinationWalletId,
              ),
              const SizedBox(height: 12),
              WalletPicker(
                selectedWalletId: _destinationWalletId,
                onChanged: (v) =>
                    setState(() => _destinationWalletId = v),
                label: 'To Wallet',
                excludeWalletId: _sourceWalletId,
              ),
            ] else
              WalletPicker(
                selectedWalletId: _sourceWalletId,
                onChanged: (v) =>
                    setState(() => _sourceWalletId = v),
                label: _type == TransactionType.income
                    ? 'Receive to Wallet'
                    : 'Pay from Wallet',
              ),

            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                prefixIcon: Icon(Icons.title_outlined),
              ),
              validator: AppValidator.title,
              maxLength: AppConstants.maxTitleLength,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
              validator: AppValidator.note,
              maxLines: 3,
              maxLength: AppConstants.maxNoteLength,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _typeColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text('Update Transaction',
                    style: AppTextStyles.titleLarge
                        .copyWith(color: Colors.white)),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime ?? DateTime.now()),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dateTime = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Color get _typeColor {
    switch (_type) {
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.transfer:
        return AppColors.transfer;
      case TransactionType.savings:
        return AppColors.savings;
      default:
        return AppColors.primary;
    }
  }
}