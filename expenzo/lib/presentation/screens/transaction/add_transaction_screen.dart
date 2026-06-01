import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/wallet_constants.dart';
import '../../../core/enums/transaction_type.dart';
import '../../../core/extensions/datetime_ext.dart';
import '../../../core/extensions/double_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validator.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/balance_service_ext.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/common/expenzo_app_bar.dart';
import '../../widgets/forms/category_picker.dart';
import '../../widgets/forms/wallet_picker.dart';
import 'widgets/amount_calculator.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  static const _tabDefs = [
    (TransactionType.income,   'Income',   AppColors.income),
    (TransactionType.expense,  'Expense',  AppColors.expense),
    (TransactionType.transfer, 'Transfer', AppColors.transfer),
  ];

  late TabController _typeTabController;
  static const _uuid = Uuid();

  TransactionType _type = TransactionType.expense;
  double _amount = 0;
  String? _categoryId;
  String _sourceWalletId = WalletConstants.cashWalletId;
  DateTime _dateTime = DateTime.now();
  bool _isSaving = false;

  // Transfer state.
  bool _bkashToCash = false;
  int _chargePresetIndex = 0;

  // bKash payment charge state (for expense paid from bKash).
  bool _hasPaymentCharge = false;
  double _paymentChargeRate = 0.0; // user-entered percentage
  final _chargeRateController = TextEditingController();

  String get _transferFromId => _bkashToCash
      ? WalletConstants.bkashWalletId
      : WalletConstants.cashWalletId;
  String get _transferToId => _bkashToCash
      ? WalletConstants.cashWalletId
      : WalletConstants.bkashWalletId;
  String get _transferFromName => _bkashToCash ? 'bKash' : 'Cash';
  String get _transferToName => _bkashToCash ? 'Cash' : 'bKash';

  static const _cashOutPresets = [
    ('Normal Agent', 0.0185),
    ('Favourite Agent', 0.0149),
  ];

  double get _cashOutChargeRate =>
      _bkashToCash ? _cashOutPresets[_chargePresetIndex].$2 : 0.0;
  double get _cashOutCharge =>
      double.parse((_amount * _cashOutChargeRate).toStringAsFixed(2));
  double get _cashOutTotal =>
      double.parse((_amount + _cashOutCharge).toStringAsFixed(2));

  // Payment charge (for bKash expense).
  double get _paymentCharge =>
      _hasPaymentCharge && _paymentChargeRate > 0
          ? double.parse((_amount * _paymentChargeRate / 100).toStringAsFixed(2))
          : 0.0;
  double get _paymentTotal =>
      double.parse((_amount + _paymentCharge).toStringAsFixed(2));

  bool get _isExpenseFromBkash =>
      _type == TransactionType.expense &&
      _sourceWalletId == WalletConstants.bkashWalletId;

  @override
  void initState() {
    super.initState();
    _typeTabController =
        TabController(length: _tabDefs.length, vsync: this, initialIndex: 1);
    _typeTabController.addListener(() {
      if (_typeTabController.indexIsChanging) return;
      setState(() {
        _type = _tabDefs[_typeTabController.index].$1;
        _categoryId = null;
        _amount = 0;
        _hasPaymentCharge = false;
        _chargeRateController.clear();
        _paymentChargeRate = 0;
      });
      if (_type != TransactionType.transfer) _preselectCategory();
    });
    _preselectCategory();
  }

  void _preselectCategory() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _type == TransactionType.transfer) return;
      final cats = ref.read(categoriesByTypeProvider(_type));
      if (cats.isNotEmpty && _categoryId == null) {
        setState(() => _categoryId = cats.first.id);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _chargeRateController.dispose();
    _typeTabController.dispose();
    super.dispose();
  }

  // ── Validation & error dialog ──────────────────────────────────────────────

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.titleLarge),
        ]),
        content: Text(message, style: AppTextStyles.bodyMedium
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

  bool _validateBalance() {
    if (_type == TransactionType.income) return true;

    final allTxns = ref.read(allTransactionsProvider);
    final balanceSvc = ref.read(balanceServiceProvider);

    final walletId = _type == TransactionType.transfer
        ? _transferFromId
        : _sourceWalletId;

    final available = balanceSvc.availableBalance(
      walletId: walletId,
      allTransactions: allTxns,
    );

    // For transfers, check total including charge.
    final needed = _type == TransactionType.transfer
        ? _cashOutTotal
        : (_isExpenseFromBkash ? _paymentTotal : _amount);

    if (needed > available) {
      final wallets = ref.read(allWalletsProvider);
      final name = wallets
              .where((w) => w.id == walletId)
              .map((w) => w.name)
              .firstOrNull ?? 'wallet';
      _showErrorDialog(
        'Insufficient Balance',
        'You need ${needed.toCurrency} from $name.\n'
        'Available: ${available.toCurrency}',
      );
      return false;
    }
    return true;
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_amount <= 0) {
      _showErrorDialog('No Amount', 'Please enter an amount before saving.');
      return;
    }
    if (_type != TransactionType.transfer) {
      if (_categoryId == null) {
        _showErrorDialog('No Category', 'Please select a category.');
        return;
      }
      if (!(_formKey.currentState?.validate() ?? false)) return;
    }
    if (!_validateBalance()) return;

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final allCats = ref.read(allCategoriesProvider);

      if (_type == TransactionType.transfer) {
        final categoryId = allCats
                .where((c) =>
                    c.id == 'cat_transfer_internal' ||
                    c.type == TransactionType.transfer)
                .map((c) => c.id)
                .firstOrNull ??
            allCats.where((c) => c.type == TransactionType.expense)
                .map((c) => c.id).firstOrNull ??
            'cat_expense_other';

        final title = _titleController.text.trim().isEmpty
            ? '$_transferFromName → $_transferToName'
            : _titleController.text.trim();

        final txn = TransactionModel(
          id: _uuid.v4(),
          title: title,
          amount: _cashOutTotal,
          type: TransactionType.transfer,
          categoryId: categoryId,
          sourceWalletId: _transferFromId,
          destinationWalletId: _transferToId,
          dateTime: _dateTime,
          note: _buildTransferNote(),
          monthKey: _dateTime.monthKey,
          createdAt: now,
          updatedAt: now,
        );
        await ref.read(transactionNotifierProvider.notifier).add(txn);

        // Separate charge expense record.
        if (_cashOutCharge > 0) {
          final chargeCat = allCats
              .where((c) => c.type == TransactionType.expense)
              .map((c) => c.id).firstOrNull ?? 'cat_expense_other';
          final chargeTxn = TransactionModel(
            id: _uuid.v4(),
            title: 'bKash Cash Out Charge',
            amount: _cashOutCharge,
            type: TransactionType.expense,
            categoryId: chargeCat,
            sourceWalletId: _transferFromId,
            destinationWalletId: null,
            dateTime: _dateTime,
            note: '${(_cashOutChargeRate * 100).toStringAsFixed(2)}% of ${_amount.toCurrency}',
            monthKey: _dateTime.monthKey,
            createdAt: now,
            updatedAt: now,
          );
          await ref.read(transactionNotifierProvider.notifier).add(chargeTxn);
        }
      } else {
        // Income or Expense (with optional payment charge).
        final totalAmount = _isExpenseFromBkash ? _paymentTotal : _amount;
        final txn = TransactionModel(
          id: _uuid.v4(),
          title: _titleController.text.trim().isEmpty
              ? null
              : _titleController.text.trim(),
          amount: totalAmount,
          type: _type,
          categoryId: _categoryId!,
          sourceWalletId: _sourceWalletId,
          destinationWalletId: null,
          dateTime: _dateTime,
          note: _buildExpenseNote(),
          monthKey: _dateTime.monthKey,
          createdAt: now,
          updatedAt: now,
        );
        await ref.read(transactionNotifierProvider.notifier).add(txn);
      }

      if (mounted) {
        context.pop();
        // Show success as a brief banner instead of snackbar to avoid UX disruption.
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(_type == TransactionType.transfer
                  ? 'Transfer saved'
                  : 'Transaction saved'),
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
      if (mounted) _showErrorDialog('Save Failed', e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _buildTransferNote() {
    final parts = <String>[];
    if (_noteController.text.trim().isNotEmpty) {
      parts.add(_noteController.text.trim());
    }
    if (_cashOutCharge > 0) {
      parts.add('Charge: ${(_cashOutChargeRate * 100).toStringAsFixed(2)}%'
          ' = ${_cashOutCharge.toCurrency}');
    }
    return parts.isEmpty ? null : parts.join(' | ');
  }

  String? _buildExpenseNote() {
    final parts = <String>[];
    if (_noteController.text.trim().isNotEmpty) {
      parts.add(_noteController.text.trim());
    }
    if (_paymentCharge > 0) {
      parts.add('Payment charge: $_paymentChargeRate%'
          ' = ${_paymentCharge.toCurrency}');
    }
    return parts.isEmpty ? null : parts.join(' | ');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isTransfer = _type == TransactionType.transfer;
    final balanceMap = ref.watch(walletBalanceMapProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ExpenzoAppBar(
        title: 'Add Transaction',
        showBack: true,
        bottom: _buildTypeTabs(),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (isTransfer) ...[
              _buildTransferBalanceOverview(balanceMap),
              const SizedBox(height: 14),
              _buildTransferDirectionToggle(),
              const SizedBox(height: 14),
              if (_bkashToCash) ...[
                _buildCashOutChargeSelector(),
                const SizedBox(height: 14),
              ],
            ],
            _buildAmountSection(isTransfer, balanceMap),
            const SizedBox(height: 14),
            if (isTransfer && _amount > 0) ...[
              _buildTransferBreakdown(balanceMap),
              const SizedBox(height: 14),
            ],
            _buildDateRow(),
            const SizedBox(height: 14),
            if (!isTransfer) ...[
              CategoryPicker(
                selectedCategoryId: _categoryId,
                transactionType: _type,
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 14),
              WalletPicker(
                selectedWalletId: _sourceWalletId,
                onChanged: (v) => setState(() {
                  _sourceWalletId = v!;
                  _hasPaymentCharge = false;
                  _chargeRateController.clear();
                  _paymentChargeRate = 0;
                }),
                label: _type == TransactionType.income
                    ? 'Receive to Wallet'
                    : 'Pay from Wallet',
              ),
              const SizedBox(height: 14),
              if (_isExpenseFromBkash) _buildPaymentChargeSection(balanceMap),
              if (_isExpenseFromBkash) const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                prefixIcon: Icon(Icons.title_outlined),
              ),
              validator: AppValidator.title,
              textCapitalization: TextCapitalization.sentences,
              maxLength: AppConstants.maxTitleLength,
            ),
            const SizedBox(height: 14),
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
      bottomNavigationBar: _buildSaveBar(isTransfer, balanceMap),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildTypeTabs() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Container(
        color: AppColors.surface,
        child: TabBar(
          controller: _typeTabController,
          tabs: _tabDefs
              .map((t) => Tab(child: Text(t.$2, style: AppTextStyles.labelMedium)))
              .toList(),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
        ),
      ),
    );
  }

  // ── Transfer sub-widgets ───────────────────────────────────────────────────

  Widget _buildTransferBalanceOverview(Map<String, double> balanceMap) {
    return Row(
      children: [
        Expanded(child: _BalanceCard(
          icon: Icons.payments_outlined,
          label: 'Cash',
          balance: balanceMap[WalletConstants.cashWalletId] ?? 0.0,
          color: AppColors.cashWallet,
          isFrom: !_bkashToCash,
        )),
        const SizedBox(width: 10),
        Expanded(child: _BalanceCard(
          icon: Icons.phone_android_outlined,
          label: 'bKash',
          balance: balanceMap[WalletConstants.bkashWalletId] ?? 0.0,
          color: AppColors.bkashWallet,
          isFrom: _bkashToCash,
        )),
      ],
    );
  }

  Widget _buildTransferDirectionToggle() {
    return Row(
      children: [
        Expanded(child: _DirectionButton(
          fromName: 'Cash', toName: 'bKash',
          badge: 'Free', badgeColor: AppColors.income,
          isSelected: !_bkashToCash,
          onTap: () { if (_bkashToCash) setState(() => _bkashToCash = false); },
        )),
        const SizedBox(width: 10),
        Expanded(child: _DirectionButton(
          fromName: 'bKash', toName: 'Cash',
          badge: 'Charge', badgeColor: AppColors.expense,
          isSelected: _bkashToCash,
          onTap: () { if (!_bkashToCash) setState(() => _bkashToCash = true); },
        )),
      ],
    );
  }

  Widget _buildCashOutChargeSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.percent, size: 15, color: AppColors.savings),
            const SizedBox(width: 6),
            Text('Cash Out Charge', style: AppTextStyles.titleMedium),
          ]),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_cashOutPresets.length, (i) {
              final p = _cashOutPresets[i];
              final sel = _chargePresetIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _chargePresetIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
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
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${(p.$2 * 100).toStringAsFixed(2)}%',
                          style: AppTextStyles.amountSmall.copyWith(
                            color: sel ? AppColors.savings : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          )),
                      Text(p.$1,
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textSecondary)),
                    ]),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferBreakdown(Map<String, double> balanceMap) {
    final fromBal = balanceMap[_transferFromId] ?? 0.0;
    final toBal = balanceMap[_transferToId] ?? 0.0;
    final isOverdrawn = _cashOutTotal > fromBal;

    return _BreakdownCard(
      isOverdrawn: isOverdrawn,
      children: [
        _BRow('Transfer amount', _amount.toCurrency),
        if (_bkashToCash && _cashOutCharge > 0) ...[
          _BRow('Cash out charge (${(_cashOutChargeRate * 100).toStringAsFixed(2)}%)',
              _cashOutCharge.toCurrency, color: AppColors.expense),
          const Divider(height: 12),
          _BRow('Total deducted from $_transferFromName',
              _cashOutTotal.toCurrency, bold: true),
        ],
        const Divider(height: 12),
        _BRow('$_transferFromName after',
            isOverdrawn ? 'Not enough' : (fromBal - _cashOutTotal).toCurrency,
            color: isOverdrawn ? AppColors.error : AppColors.expense),
        _BRow('$_transferToName after', (toBal + _amount).toCurrency,
            color: AppColors.income),
        if (!_bkashToCash)
          _BRow('ℹ Cash In', 'Completely free', color: AppColors.income),
      ],
    );
  }

  // ── Payment charge section (bKash expense) ────────────────────────────────

  Widget _buildPaymentChargeSection(Map<String, double> balanceMap) {
    final bkashBalance = balanceMap[WalletConstants.bkashWalletId] ?? 0.0;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.phone_android_outlined,
                    size: 16, color: AppColors.bkashWallet),
                const SizedBox(width: 6),
                Text('bKash Payment Charge', style: AppTextStyles.titleMedium),
              ]),
              Switch(
                value: _hasPaymentCharge,
                onChanged: (v) => setState(() {
                  _hasPaymentCharge = v;
                  if (!v) {
                    _chargeRateController.clear();
                    _paymentChargeRate = 0;
                  }
                }),
                activeColor: AppColors.primary,
              ),
            ],
          ),
          if (_hasPaymentCharge) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _chargeRateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Charge rate (%)',
                hintText: 'e.g. 1.15',
                prefixIcon: Icon(Icons.percent_outlined),
                suffixText: '%',
              ),
              onChanged: (v) {
                final parsed = double.tryParse(v) ?? 0.0;
                setState(() => _paymentChargeRate = parsed);
              },
            ),
            if (_amount > 0 && _paymentChargeRate > 0) ...[
              const SizedBox(height: 10),
              _BreakdownCard(
                isOverdrawn: _paymentTotal > bkashBalance,
                children: [
                  _BRow('Amount', _amount.toCurrency),
                  _BRow(
                      'Charge ($_paymentChargeRate%)',
                      _paymentCharge.toCurrency,
                      color: AppColors.expense),
                  const Divider(height: 12),
                  _BRow('Total deducted from bKash',
                      _paymentTotal.toCurrency, bold: true),
                  _BRow(
                    'bKash after payment',
                    _paymentTotal > bkashBalance
                        ? 'Not enough'
                        : (bkashBalance - _paymentTotal).toCurrency,
                    color: _paymentTotal > bkashBalance
                        ? AppColors.error
                        : AppColors.expense,
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Amount section ─────────────────────────────────────────────────────────

  Widget _buildAmountSection(bool isTransfer, Map<String, double> balanceMap) {
    final fromBal = isTransfer
        ? (balanceMap[_transferFromId] ?? 0.0)
        : (balanceMap[_sourceWalletId] ?? 0.0);
    final needed = isTransfer
        ? _cashOutTotal
        : (_isExpenseFromBkash ? _paymentTotal : _amount);
    final isOverdrawn = _type != TransactionType.income &&
        _amount > 0 &&
        needed > fromBal;

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
                    ? _typeColor
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
                      _amount > 0 ? _amount.toCurrency : 'Tap to enter amount',
                      style: _amount > 0
                          ? AppTextStyles.amountLarge.copyWith(
                              color: isOverdrawn
                                  ? AppColors.error
                                  : _typeColor)
                          : AppTextStyles.bodyLarge
                              .copyWith(color: AppColors.textTertiary),
                    ),
                  ),
                  if (isOverdrawn) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 13, color: AppColors.error),
                      const SizedBox(width: 4),
                      Text(
                        'Exceeds available balance',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.error),
                      ),
                    ]),
                  ],
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
        child: Row(
          children: [
            const Icon(Icons.event_outlined,
                color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_dateTime.displayDateTime,
                  style: AppTextStyles.bodyMedium),
            ),
            const Icon(Icons.edit_outlined,
                color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveBar(bool isTransfer, Map<String, double> balanceMap) {
    final fromBal = isTransfer ? (balanceMap[_transferFromId] ?? 0.0) : 0.0;
    final bkashBal = balanceMap[WalletConstants.bkashWalletId] ?? 0.0;
    final isTransferOverdrawn = isTransfer && _amount > 0 && _cashOutTotal > fromBal;
    final isPaymentOverdrawn = _isExpenseFromBkash &&
        _hasPaymentCharge &&
        _amount > 0 &&
        _paymentTotal > bkashBal;
    final isOverdrawn = isTransferOverdrawn || isPaymentOverdrawn;
    final canSave = _amount > 0 && !isOverdrawn;

    String label;
    if (_amount <= 0) {
      label = 'Enter Amount';
    } else if (isOverdrawn) {
      label = 'Insufficient Balance';
    } else if (isTransfer) {
      label = _cashOutTotal > _amount
          ? 'Transfer (Total ${_cashOutTotal.toCurrency})'
          : 'Transfer ${_amount.toCurrency}';
    } else if (_isExpenseFromBkash && _paymentCharge > 0) {
      label = 'Save (Total ${_paymentTotal.toCurrency})';
    } else {
      label = 'Save Transaction';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (_isSaving || !canSave) ? null : _save,
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
              : Text(label,
                  style: AppTextStyles.titleMedium
                      .copyWith(color: Colors.white)),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
      default:
        return AppColors.primary;
    }
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.icon, required this.label,
    required this.balance, required this.color, required this.isFrom,
  });
  final IconData icon;
  final String label;
  final double balance;
  final Color color;
  final bool isFrom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: isFrom ? AppColors.expenseLight : AppColors.incomeLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFrom
              ? AppColors.expense.withValues(alpha: 0.35)
              : AppColors.income.withValues(alpha: 0.35),
        ),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTextStyles.labelSmall
              .copyWith(color: AppColors.textSecondary)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(balance.toCurrency,
                style: AppTextStyles.amountSmall.copyWith(color: color)),
          ),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: isFrom
                ? AppColors.expense.withValues(alpha: 0.12)
                : AppColors.income.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(isFrom ? 'FROM' : 'TO',
              style: AppTextStyles.labelSmall.copyWith(
                color: isFrom ? AppColors.expense : AppColors.income,
                fontWeight: FontWeight.w700, fontSize: 9,
              )),
        ),
      ]),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.fromName, required this.toName,
    required this.badge, required this.badgeColor,
    required this.isSelected, required this.onTap,
  });
  final String fromName, toName, badge;
  final Color badgeColor;
  final bool isSelected;
  final VoidCallback onTap;

  static IconData _icon(String name) => name == 'Cash'
      ? Icons.payments_outlined
      : Icons.phone_android_outlined;
  static Color _color(String name) => name == 'Cash'
      ? AppColors.cashWallet
      : AppColors.bkashWallet;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
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
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_icon(fromName), color: _color(fromName), size: 17),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Icon(Icons.arrow_forward, size: 12,
                  color: isSelected ? AppColors.transfer : AppColors.textTertiary),
            ),
            Icon(_icon(toName), color: _color(toName), size: 17),
          ]),
          const SizedBox(height: 4),
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
        ]),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.isOverdrawn, required this.children});
  final bool isOverdrawn;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverdrawn ? AppColors.expenseLight : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdrawn
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            isOverdrawn ? Icons.warning_amber_outlined : Icons.receipt_long_outlined,
            size: 15,
            color: isOverdrawn ? AppColors.error : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            isOverdrawn ? 'Insufficient Balance' : 'Breakdown',
            style: AppTextStyles.labelMedium.copyWith(
                color: isOverdrawn ? AppColors.error : AppColors.textSecondary),
          ),
        ]),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }
}

class _BRow extends StatelessWidget {
  const _BRow(this.label, this.value, {this.bold = false, this.color});
  final String label, value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary))),
          const SizedBox(width: 8),
          Text(value,
              style: bold
                  ? AppTextStyles.titleMedium.copyWith(color: color)
                  : AppTextStyles.bodyMedium.copyWith(
                      color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}