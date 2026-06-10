import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/core_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/wallet_constants.dart';
import '../../../core/enums/transaction_type.dart';
import '../../../core/extensions/datetime_ext.dart';
import '../../../core/extensions/double_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validator.dart';
import '../../../data/models/transaction_model.dart';
import '../../../domain/services/balance_service.dart';
import '../../providers/category_provider.dart';
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

  // ── Error dialog ───────────────────────────────────────────────────────────

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 22),
          const SizedBox(width: 8),
          Flexible(child: Text(title, style: AppTextStyles.titleLarge)),
        ]),
        content: Text(message,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Balance validation (excludes original transaction) ────────────────────

  bool _validateBalance(Map<String, double> balanceMap) {
    if (_type == TransactionType.income) return true;
    if (_original == null) return true;

    final allTxns = ref.read(allTransactionsProvider);
    final balanceSvc = ref.read(balanceServiceProvider);

    String? checkWalletId;
    switch (_type) {
      case TransactionType.expense:
        checkWalletId = _sourceWalletId;
      case TransactionType.transfer:
        checkWalletId = _sourceWalletId;
      case TransactionType.savings:
        // Deposit: check source wallet; Withdrawal: check savings
        final isDeposit =
            _destinationWalletId == WalletConstants.savingsWalletId;
        checkWalletId =
            isDeposit ? _sourceWalletId : WalletConstants.savingsWalletId;
      default:
        return true;
    }

    if (checkWalletId == null) return true;

    // Exclude original so we don't double-count the transaction being edited.
    final available = balanceSvc.availableBalance(
      walletId: checkWalletId,
      allTransactions: allTxns,
      excludeTransactionId: _original!.id,
    );

    if (_amount > available + 0.001) {
      final wallets = ref.read(allWalletsProvider);
      final name = wallets
              .where((w) => w.id == checkWalletId)
              .map((w) => w.name)
              .firstOrNull ??
          'wallet';
      _showError(
        'Insufficient Balance',
        'You need ${_amount.toCurrency} from $name.\n'
        'Available: ${available.toCurrency}',
      );
      return false;
    }
    return true;
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save(Map<String, double> balanceMap) async {
    if (_original == null || _type == null || _sourceWalletId == null) return;
    if (_amount <= 0) {
      _showError('No Amount', 'Please enter an amount.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if ((_type == TransactionType.transfer ||
            _type == TransactionType.savings) &&
        _sourceWalletId == _destinationWalletId) {
      _showError('Invalid Transfer',
          'Source and destination wallets must be different.');
      return;
    }

    if (!_validateBalance(balanceMap)) return;

    setState(() => _isSaving = true);
    try {
      final dt = _dateTime!;
      final updated = _original!.copyWith(
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        amount: BalanceService.round2(_amount),
        categoryId: _categoryId,
        sourceWalletId: _sourceWalletId,
        destinationWalletId: (_type == TransactionType.transfer ||
                _type == TransactionType.savings)
            ? _destinationWalletId
            : null,
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
        context.pop();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('Transaction updated'),
            ]),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ));
      }
    } catch (e) {
      if (mounted) _showError('Update Failed', e.toString());
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

    final balanceMap = ref.watch(walletBalanceMapProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ExpenzoAppBar(
        title: 'Edit Transaction',
        showBack: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Wallet balance overview ──────────────────────────────────
            _buildWalletOverview(balanceMap),
            const SizedBox(height: 14),

            // ── Type badge (read-only) ───────────────────────────────────
            _buildTypeBadge(),
            const SizedBox(height: 14),

            // ── Amount ────────────────────────────────────────────────────
            _buildAmountField(balanceMap),
            const SizedBox(height: 14),

            // ── Date ──────────────────────────────────────────────────────
            _buildDateRow(),
            const SizedBox(height: 14),

            // ── Type-specific wallet & category fields ─────────────────
            _buildTypeSpecificFields(balanceMap),

            // ── Title ─────────────────────────────────────────────────────
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
            const SizedBox(height: 14),

            // ── Note ──────────────────────────────────────────────────────
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
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: _buildSaveBar(balanceMap),
    );
  }

  // ── Wallet balance overview ───────────────────────────────────────────────
  // For all types, show Cash + bKash live balances (excluding original txn).

  Widget _buildWalletOverview(Map<String, double> balanceMap) {
    final allTxns = ref.read(allTransactionsProvider);
    final balanceSvc = ref.read(balanceServiceProvider);

    // Compute balances excluding the original transaction so preview is accurate.
    final cashAvail = balanceSvc.availableBalance(
      walletId: WalletConstants.cashWalletId,
      allTransactions: allTxns,
      excludeTransactionId: _original?.id,
    );
    final bkashAvail = balanceSvc.availableBalance(
      walletId: WalletConstants.bkashWalletId,
      allTransactions: allTxns,
      excludeTransactionId: _original?.id,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available Balances',
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _BalanceTile(
              icon: Icons.payments_outlined,
              label: 'Cash',
              balance: cashAvail,
              color: AppColors.cashWallet,
              isActive: _sourceWalletId == WalletConstants.cashWalletId ||
                  (_type == TransactionType.savings &&
                      _destinationWalletId == WalletConstants.cashWalletId),
            )),
            Container(
              width: 1, height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: AppColors.border,
            ),
            Expanded(child: _BalanceTile(
              icon: Icons.phone_android_outlined,
              label: 'bKash',
              balance: bkashAvail,
              color: AppColors.bkashWallet,
              isActive: _sourceWalletId == WalletConstants.bkashWalletId ||
                  (_type == TransactionType.savings &&
                      _destinationWalletId == WalletConstants.bkashWalletId),
            )),
          ]),
        ],
      ),
    );
  }

  // ── Type badge (read-only) ────────────────────────────────────────────────

  Widget _buildTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _typeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _typeColor.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.label_outline, color: _typeColor, size: 18),
        const SizedBox(width: 8),
        Text(_type?.label ?? '',
            style: AppTextStyles.titleMedium.copyWith(color: _typeColor)),
        const Spacer(),
        Text('type is fixed',
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textTertiary)),
      ]),
    );
  }

  // ── Amount field ───────────────────────────────────────────────────────────

  Widget _buildAmountField(Map<String, double> balanceMap) {
    final allTxns = ref.read(allTransactionsProvider);
    final balanceSvc = ref.read(balanceServiceProvider);

    // Determine check wallet depending on type.
    String? checkWallet;
    if (_type == TransactionType.expense ||
        _type == TransactionType.transfer) {
      checkWallet = _sourceWalletId;
    } else if (_type == TransactionType.savings) {
      checkWallet =
          _destinationWalletId == WalletConstants.savingsWalletId
              ? _sourceWalletId
              : WalletConstants.savingsWalletId;
    }

    final available = checkWallet != null
        ? balanceSvc.availableBalance(
            walletId: checkWallet,
            allTransactions: allTxns,
            excludeTransactionId: _original?.id,
          )
        : double.infinity;

    final isOverdrawn = _type != TransactionType.income &&
        _amount > 0 &&
        available != double.infinity &&
        _amount > available + 0.001;

    return GestureDetector(
      onTap: () async {
        final r =
            await AmountCalculator.show(context, initialValue: _amount);
        if (r != null && mounted) setState(() => _amount = r);
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
                    ? _typeColor
                    : AppColors.border,
            width: _amount > 0 ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _amount > 0 ? _amount.toCurrency : 'Tap to enter',
                  style: _amount > 0
                      ? AppTextStyles.amountLarge.copyWith(
                          color: isOverdrawn ? AppColors.error : _typeColor)
                      : AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textTertiary),
                ),
              ),
              if (isOverdrawn) ...[
                const SizedBox(height: 4),
                Text(
                  'Exceeds available (${available.toCurrency})',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.error),
                ),
              ],
            ],
          )),
          const Icon(Icons.calculate_outlined,
              color: AppColors.primary, size: 24),
        ]),
      ),
    );
  }

  // ── Date row ───────────────────────────────────────────────────────────────

  Widget _buildDateRow() {
    return GestureDetector(
      onTap: _pickDateTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.event_outlined,
              color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_dateTime?.displayDateTime ?? '',
                style: AppTextStyles.bodyMedium),
          ),
          const Icon(Icons.edit_outlined,
              color: AppColors.textTertiary, size: 18),
        ]),
      ),
    );
  }

  // ── Type-specific fields ───────────────────────────────────────────────────

  Widget _buildTypeSpecificFields(Map<String, double> balanceMap) {
    switch (_type) {
      // ── Income ────────────────────────────────────────────────────────────
      case TransactionType.income:
        return Column(children: [
          CategoryPicker(
            selectedCategoryId: _categoryId,
            transactionType: TransactionType.income,
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 14),
          // Receive to wallet — Cash or bKash only (NO savings).
          WalletPicker(
            selectedWalletId: _sourceWalletId,
            onChanged: (v) => setState(() => _sourceWalletId = v),
            label: 'Receive to Wallet',
            excludeSavings: true,
          ),
          const SizedBox(height: 14),
        ]);

      // ── Expense ───────────────────────────────────────────────────────────
      case TransactionType.expense:
        return Column(children: [
          CategoryPicker(
            selectedCategoryId: _categoryId,
            transactionType: TransactionType.expense,
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 14),
          // Pay from wallet — Cash or bKash only (NO savings).
          WalletPicker(
            selectedWalletId: _sourceWalletId,
            onChanged: (v) => setState(() => _sourceWalletId = v),
            label: 'Pay from Wallet',
            excludeSavings: true,
          ),
          const SizedBox(height: 14),
        ]);

      // ── Transfer (Cash ↔ bKash) ───────────────────────────────────────────
      case TransactionType.transfer:
        return Column(children: [
          WalletPicker(
            selectedWalletId: _sourceWalletId,
            onChanged: (v) => setState(() => _sourceWalletId = v),
            label: 'From Wallet',
            excludeWalletId: _destinationWalletId,
            excludeSavings: true,
          ),
          const SizedBox(height: 12),
          WalletPicker(
            selectedWalletId: _destinationWalletId,
            onChanged: (v) => setState(() => _destinationWalletId = v),
            label: 'To Wallet',
            excludeWalletId: _sourceWalletId,
            excludeSavings: true,
          ),
          const SizedBox(height: 14),
        ]);

      // ── Savings ───────────────────────────────────────────────────────────
      case TransactionType.savings:
        return _buildSavingsFields();

      default:
        return const SizedBox(height: 14);
    }
  }

  // ── Savings edit fields ────────────────────────────────────────────────────
  // From wallet = Cash or bKash only.
  // To wallet   = always Savings (locked, shown as label only).

  Widget _buildSavingsFields() {
    final isDeposit =
        _destinationWalletId == WalletConstants.savingsWalletId;

    return Column(children: [
      // From / source wallet — only for deposits.
      if (isDeposit) ...[
        WalletPicker(
          selectedWalletId: _sourceWalletId,
          onChanged: (v) => setState(() => _sourceWalletId = v),
          label: 'From Wallet',
          excludeSavings: true,
        ),
        const SizedBox(height: 12),
        // To wallet: locked to Savings.
        _LockedWalletLabel(
          label: 'To Wallet',
          walletName: 'Savings',
          icon: Icons.account_balance_outlined,
          color: AppColors.savingsWallet,
        ),
      ] else ...[
        // Withdrawal: source = Savings (locked).
        _LockedWalletLabel(
          label: 'From Wallet',
          walletName: 'Savings',
          icon: Icons.account_balance_outlined,
          color: AppColors.savingsWallet,
        ),
        const SizedBox(height: 12),
        // To wallet: Cash or bKash.
        WalletPicker(
          selectedWalletId: _destinationWalletId,
          onChanged: (v) => setState(() => _destinationWalletId = v),
          label: 'To Wallet',
          excludeSavings: true,
        ),
      ],
      const SizedBox(height: 14),
    ]);
  }

  // ── Save bar ───────────────────────────────────────────────────────────────

  Widget _buildSaveBar(Map<String, double> balanceMap) {
    final allTxns = ref.read(allTransactionsProvider);
    final balanceSvc = ref.read(balanceServiceProvider);

    String? checkWallet;
    if (_type == TransactionType.expense ||
        _type == TransactionType.transfer) {
      checkWallet = _sourceWalletId;
    } else if (_type == TransactionType.savings &&
        _destinationWalletId == WalletConstants.savingsWalletId) {
      checkWallet = _sourceWalletId;
    }

    final available = checkWallet != null
        ? balanceSvc.availableBalance(
            walletId: checkWallet,
            allTransactions: allTxns,
            excludeTransactionId: _original?.id,
          )
        : double.infinity;

    final isOverdrawn = _type != TransactionType.income &&
        _amount > 0 &&
        available != double.infinity &&
        _amount > available + 0.001;

    final canSave = _amount > 0 && !isOverdrawn;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (_isSaving || !canSave)
              ? null
              : () => _save(balanceMap),
          style: ElevatedButton.styleFrom(
            backgroundColor: isOverdrawn ? AppColors.error : _typeColor,
            disabledBackgroundColor: _typeColor.withValues(alpha: 0.35),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Text(
                  isOverdrawn
                      ? 'Insufficient Balance'
                      : 'Update Transaction',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: Colors.white)),
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
      _dateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Color get _typeColor {
    switch (_type) {
      case TransactionType.income:  return AppColors.income;
      case TransactionType.expense: return AppColors.expense;
      case TransactionType.transfer:return AppColors.transfer;
      case TransactionType.savings: return AppColors.savings;
      default:                      return AppColors.primary;
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.icon, required this.label, required this.balance,
    required this.color, required this.isActive,
  });
  final IconData icon;
  final String label;
  final double balance;
  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: isActive ? color : AppColors.textTertiary, size: 18),
      const SizedBox(height: 3),
      Text(label, style: AppTextStyles.labelSmall.copyWith(
        color: isActive ? color : AppColors.textSecondary,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
      )),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(balance.toCurrency,
            style: AppTextStyles.amountSmall.copyWith(
              color: isActive ? color : AppColors.textSecondary,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              fontSize: isActive ? 13 : 11,
            )),
      ),
    ]);
  }
}

/// A read-only wallet display — used for the locked "Savings" field.
class _LockedWalletLabel extends StatelessWidget {
  const _LockedWalletLabel({
    required this.label, required this.walletName,
    required this.icon, required this.color,
  });
  final String label, walletName;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label, style: AppTextStyles.bodySmall
            .copyWith(color: AppColors.textSecondary)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(walletName, style: AppTextStyles.bodyMedium
              .copyWith(color: color, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Fixed', style: AppTextStyles.labelSmall
                .copyWith(color: color)),
          ),
        ]),
      ),
    ]);
  }
}