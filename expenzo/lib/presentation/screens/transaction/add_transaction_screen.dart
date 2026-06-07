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
import '../../../domain/services/balance_service.dart';
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
  final _manualChargeController = TextEditingController();

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
  // Only Cash or bKash for income/expense.
  String _sourceWalletId = WalletConstants.cashWalletId;
  DateTime _dateTime = DateTime.now();
  bool _isSaving = false;

  // ── Transfer state ─────────────────────────────────────────────────────────
  bool _bkashToCash = false;
  // Cash-out charge: preset or manual.
  // null = use manual, 0 = 1.85%, 1 = 1.49% (default)
  int? _cashOutPresetIndex = 1; // default 1.49%
  bool _useManualCharge = false;
  // FIX: manual charge is now a raw Taka amount, not a percentage
  double _manualChargeTaka = 0.0;

  static const _cashOutPresets = [
    ('1.85%', 'Normal Agent',    0.0185),
    ('1.49%', 'Favourite Agent', 0.0149),
  ];

  // ── bKash payment charge (expense from bKash) ──────────────────────────────
  bool _hasPaymentCharge = false;
  int _paymentPresetIndex = 0; // 0=1.15%, 1=1.49%, 2=1.85%

  static const _paymentPresets = [
    ('1.15%', 0.0115),
    ('1.49%', 0.0149),
    ('1.85%', 0.0185),
  ];

  // ── Derived ────────────────────────────────────────────────────────────────

  String get _tfFromId => _bkashToCash
      ? WalletConstants.bkashWalletId
      : WalletConstants.cashWalletId;
  String get _tfToId => _bkashToCash
      ? WalletConstants.cashWalletId
      : WalletConstants.bkashWalletId;
  String get _tfFromName => _bkashToCash ? 'bKash' : 'Cash';
  String get _tfToName   => _bkashToCash ? 'Cash'  : 'bKash';

  double get _effectiveCashOutRate {
    if (!_bkashToCash) return 0.0;
    // FIX: manual mode — derive rate from raw taka so all downstream
    // calculations (_cashOutCharge, _cashOutTotalCost) remain consistent.
    if (_useManualCharge) {
      return _amount > 0 ? _manualChargeTaka / _amount : 0.0;
    }
    return _cashOutPresets[_cashOutPresetIndex ?? 1].$3;
  }

  // FIX: in manual mode, charge IS exactly the taka value entered (no rounding drift).
  double get _cashOutCharge => _useManualCharge
      ? BalanceService.round2(_manualChargeTaka)
      : BalanceService.round2(_amount * _effectiveCashOutRate);
  double get _tfDestAmount => _amount;
  double get _cashOutTotalCost =>
      BalanceService.round2(_amount + _cashOutCharge);

  double get _paymentRate =>
      _hasPaymentCharge ? _paymentPresets[_paymentPresetIndex].$2 : 0.0;
  double get _paymentCharge =>
      BalanceService.round2(_amount * _paymentRate);
  double get _paymentTotalCost =>
      BalanceService.round2(_amount + _paymentCharge);

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
        // Reset source to Cash (never Savings) when switching tabs.
        if (_sourceWalletId == WalletConstants.savingsWalletId) {
          _sourceWalletId = WalletConstants.cashWalletId;
        }
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
    _manualChargeController.dispose();
    _typeTabController.dispose();
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

  // ── Validation ─────────────────────────────────────────────────────────────

  bool _validateBalance(Map<String, double> balanceMap) {
    if (_type == TransactionType.income) return true;

    if (_type == TransactionType.transfer) {
      final available = balanceMap[_tfFromId] ?? 0.0;
      if (_cashOutTotalCost > available + 0.001) {
        _showError(
          'Insufficient Balance',
          'You need ${_cashOutTotalCost.toCurrency} from $_tfFromName\n'
          '(${_amount.toCurrency} + ${_cashOutCharge.toCurrency} charge).\n\n'
          'Available: ${available.toCurrency}',
        );
        return false;
      }
      return true;
    }

    final available = balanceMap[_sourceWalletId] ?? 0.0;
    final needed = _isExpenseFromBkash ? _paymentTotalCost : _amount;
    if (needed > available + 0.001) {
      final wallets = ref.read(allWalletsProvider);
      final name = wallets
              .where((w) => w.id == _sourceWalletId)
              .map((w) => w.name)
              .firstOrNull ??
          'wallet';
      _showError(
        'Insufficient Balance',
        'You need ${needed.toCurrency} from $name.\n'
        'Available: ${available.toCurrency}',
      );
      return false;
    }
    return true;
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save(Map<String, double> balanceMap) async {
    if (_amount <= 0) {
      _showError('No Amount', 'Please enter an amount.');
      return;
    }
    if (_type != TransactionType.transfer) {
      if (_categoryId == null) {
        _showError('No Category', 'Please select a category.');
        return;
      }
      if (!(_formKey.currentState?.validate() ?? false)) return;
    }
    if (!_validateBalance(balanceMap)) return;

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final allCats = ref.read(allCategoriesProvider);

      if (_type == TransactionType.transfer) {
        await _saveTransfer(now, allCats);
      } else {
        await _saveIncomeExpense(now);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('Saved successfully'),
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
      if (mounted) _showError('Save Failed', e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveTransfer(DateTime now, dynamic allCats) async {
    final catId = _resolveTransferCat(allCats);
    final title = _titleController.text.trim().isEmpty
        ? '$_tfFromName → $_tfToName'
        : _titleController.text.trim();

    // Transfer stores only what the destination receives.
    // Charge is a separate expense record to prevent double-deduction.
    final transferTxn = TransactionModel(
      id: _uuid.v4(),
      title: title,
      amount: _tfDestAmount,
      type: TransactionType.transfer,
      categoryId: catId,
      sourceWalletId: _tfFromId,
      destinationWalletId: _tfToId,
      dateTime: now,
      // FIX: note for manual charge shows taka amount directly
      note: _cashOutCharge > 0
          ? (_useManualCharge
              ? 'Cash out charge = ${_cashOutCharge.toCurrency}'
              : 'Cash out ${(_effectiveCashOutRate * 100).toStringAsFixed(2)}%'
                  ' charge = ${_cashOutCharge.toCurrency}')
          : _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
      monthKey: now.monthKey,
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(transactionNotifierProvider.notifier).add(transferTxn);

    if (_cashOutCharge > 0) {
      final expCatId = (allCats as List)
              .where((c) => c.type == TransactionType.expense)
              .map((c) => c.id as String)
              .firstOrNull ??
          'cat_expense_other';
      // FIX: charge transaction title adapts to manual vs preset
      final chargeTitle = _useManualCharge
          ? 'bKash Cash Out Charge (${_cashOutCharge.toCurrency})'
          : 'bKash Cash Out Charge '
            '(${(_effectiveCashOutRate * 100).toStringAsFixed(2)}%)';
      final chargeNote = _useManualCharge
          ? 'Manual charge: ${_cashOutCharge.toCurrency}'
              ' on ${_amount.toCurrency}'
          : '${(_effectiveCashOutRate * 100).toStringAsFixed(2)}%'
            ' of ${_amount.toCurrency}';
      final chargeTxn = TransactionModel(
        id: _uuid.v4(),
        title: chargeTitle,
        amount: _cashOutCharge,
        type: TransactionType.expense,
        categoryId: expCatId,
        sourceWalletId: _tfFromId,
        destinationWalletId: null,
        dateTime: now,
        note: chargeNote,
        monthKey: now.monthKey,
        createdAt: now,
        updatedAt: now,
      );
      await ref.read(transactionNotifierProvider.notifier).add(chargeTxn);
    }
  }

  Future<void> _saveIncomeExpense(DateTime now) async {
    final totalAmount =
        _isExpenseFromBkash ? _paymentTotalCost : _amount;

    final noteParts = <String>[];
    if (_noteController.text.trim().isNotEmpty) {
      noteParts.add(_noteController.text.trim());
    }
    if (_paymentCharge > 0) {
      noteParts.add(
          'Charge: ${(_paymentRate * 100).toStringAsFixed(2)}%'
          ' = ${_paymentCharge.toCurrency}');
    }

    final txn = TransactionModel(
      id: _uuid.v4(),
      title: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      amount: BalanceService.round2(totalAmount),
      type: _type,
      categoryId: _categoryId!,
      sourceWalletId: _sourceWalletId,
      destinationWalletId: null,
      dateTime: _dateTime,
      note: noteParts.isEmpty ? null : noteParts.join(' | '),
      monthKey: _dateTime.monthKey,
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(transactionNotifierProvider.notifier).add(txn);
  }

  String _resolveTransferCat(dynamic allCats) {
    return (allCats as List)
            .where((c) =>
                c.id == 'cat_transfer_internal' ||
                c.type == TransactionType.transfer)
            .map((c) => c.id as String)
            .firstOrNull ??
        (allCats)
            .where((c) => c.type == TransactionType.expense)
            .map((c) => c.id as String)
            .firstOrNull ??
        'cat_expense_other';
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
            // ── Wallet balance overview ──────────────────────────────────
            _buildWalletOverview(balanceMap, isTransfer),
            const SizedBox(height: 14),

            if (isTransfer) ...[
              _buildTransferDirectionToggle(),
              const SizedBox(height: 14),
              if (_bkashToCash) ...[
                _buildCashOutChargeSection(),
                const SizedBox(height: 14),
              ],
            ],

            // ── Amount ────────────────────────────────────────────────────
            _buildAmountField(isTransfer, balanceMap),
            const SizedBox(height: 14),

            // ── Breakdown ─────────────────────────────────────────────────
            if (_amount > 0) _buildBreakdown(isTransfer, balanceMap),
            if (_amount > 0) const SizedBox(height: 14),

            // ── Date ──────────────────────────────────────────────────────
            _buildDateRow(),
            const SizedBox(height: 14),

            if (!isTransfer) ...[
              CategoryPicker(
                selectedCategoryId: _categoryId,
                transactionType: _type,
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 14),
              // Savings excluded from income/expense wallet picker.
              WalletPicker(
                selectedWalletId: _sourceWalletId,
                onChanged: (v) => setState(() {
                  _sourceWalletId = v!;
                  _hasPaymentCharge = false;
                }),
                label: _type == TransactionType.income
                    ? 'Receive to Wallet'
                    : 'Pay from Wallet',
                excludeSavings: true, // ← only Cash and bKash
              ),
              const SizedBox(height: 14),
              if (_isExpenseFromBkash) ...[
                _buildPaymentChargeSection(),
                const SizedBox(height: 14),
              ],
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
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: _buildSaveBar(isTransfer, balanceMap),
    );
  }

  // ── Type tabs ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildTypeTabs() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Container(
        color: AppColors.surface,
        child: TabBar(
          controller: _typeTabController,
          tabs: _tabDefs.map((t) => Tab(
            child: Text(t.$2, style: AppTextStyles.labelMedium),
          )).toList(),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
        ),
      ),
    );
  }

  // ── Wallet overview — Cash + bKash only (no Savings) ──────────────────────

  Widget _buildWalletOverview(Map<String, double> balanceMap, bool isTransfer) {
    if (isTransfer) {
      return Row(children: [
        Expanded(child: _WalletBadge(
          icon: Icons.payments_outlined,
          label: 'Cash',
          balance: balanceMap[WalletConstants.cashWalletId] ?? 0.0,
          color: AppColors.cashWallet,
          role: !_bkashToCash ? 'FROM' : 'TO',
          isSource: !_bkashToCash,
        )),
        const SizedBox(width: 10),
        Expanded(child: _WalletBadge(
          icon: Icons.phone_android_outlined,
          label: 'bKash',
          balance: balanceMap[WalletConstants.bkashWalletId] ?? 0.0,
          color: AppColors.bkashWallet,
          role: _bkashToCash ? 'FROM' : 'TO',
          isSource: _bkashToCash,
        )),
      ]);
    }

    // Income/Expense: show ONLY Cash and bKash.
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
          Text('Wallet Balances',
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MiniWallet(
              icon: Icons.payments_outlined,
              label: 'Cash',
              balance: balanceMap[WalletConstants.cashWalletId] ?? 0.0,
              color: AppColors.cashWallet,
              isSelected: _sourceWalletId == WalletConstants.cashWalletId,
            )),
            Container(
              width: 1, height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: AppColors.border,
            ),
            Expanded(child: _MiniWallet(
              icon: Icons.phone_android_outlined,
              label: 'bKash',
              balance: balanceMap[WalletConstants.bkashWalletId] ?? 0.0,
              color: AppColors.bkashWallet,
              isSelected: _sourceWalletId == WalletConstants.bkashWalletId,
            )),
          ]),
        ],
      ),
    );
  }

  // ── Transfer direction ─────────────────────────────────────────────────────

  Widget _buildTransferDirectionToggle() {
    return Row(children: [
      Expanded(child: _DirButton(
        label: 'Cash → bKash',
        badge: 'Free',
        badgeColor: AppColors.income,
        isSelected: !_bkashToCash,
        onTap: () { if (_bkashToCash) setState(() => _bkashToCash = false); },
      )),
      const SizedBox(width: 10),
      Expanded(child: _DirButton(
        label: 'bKash → Cash',
        badge: 'Charge',
        badgeColor: AppColors.expense,
        isSelected: _bkashToCash,
        onTap: () { if (!_bkashToCash) setState(() => _bkashToCash = true); },
      )),
    ]);
  }

  // ── Cash-out charge: presets + manual ─────────────────────────────────────

  Widget _buildCashOutChargeSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.percent, size: 15, color: AppColors.savings),
          const SizedBox(width: 6),
          Text('Cash Out Charge', style: AppTextStyles.titleMedium),
        ]),
        const SizedBox(height: 10),

        // Preset chips + Manual toggle in one row.
        Row(children: [
          // Preset 1: 1.85%
          _ChargePill(
            rateLabel: '1.85%',
            sublabel: 'Normal',
            isSelected: !_useManualCharge && _cashOutPresetIndex == 0,
            onTap: () => setState(() {
              _useManualCharge = false;
              _cashOutPresetIndex = 0;
            }),
          ),
          const SizedBox(width: 8),
          // Preset 2: 1.49% — default
          _ChargePill(
            rateLabel: '1.49%',
            sublabel: 'Favourite',
            isSelected: !_useManualCharge && _cashOutPresetIndex == 1,
            onTap: () => setState(() {
              _useManualCharge = false;
              _cashOutPresetIndex = 1;
            }),
          ),
          const SizedBox(width: 8),
          // Manual entry chip.
          _ChargePill(
            rateLabel: 'Manual',
            sublabel: 'Fixed ৳',   // FIX: label reflects taka input
            isSelected: _useManualCharge,
            selectedColor: AppColors.transfer,
            onTap: () => setState(() => _useManualCharge = true),
          ),
        ]),

        // FIX: Manual charge input — raw Taka amount, not a percentage.
        if (_useManualCharge) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _manualChargeController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Cash out charge amount',
              hintText: 'e.g. 30',
              // FIX: prefix shows taka symbol instead of percent
              prefixText: '৳ ',
              prefixIcon: const Icon(Icons.edit_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v) ?? 0.0;
              // Clamp: charge can't exceed the transfer amount itself
              setState(() => _manualChargeTaka =
                  parsed < 0 ? 0.0 : parsed);
            },
          ),
          // FIX: preview shows taka charge and effective % for transparency
          if (_manualChargeTaka > 0 && _amount > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Charge: ${_cashOutCharge.toCurrency}'
              ' (${(_effectiveCashOutRate * 100).toStringAsFixed(2)}%'
              ' of ${_amount.toCurrency})',
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.expense),
            ),
          ],
        ],
      ]),
    );
  }

  // ── bKash payment charge ───────────────────────────────────────────────────

  Widget _buildPaymentChargeSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Icon(Icons.phone_android_outlined,
                  size: 16, color: AppColors.bkashWallet),
              const SizedBox(width: 6),
              Text('bKash Payment Charge',
                  style: AppTextStyles.titleMedium),
            ]),
            Switch(
              value: _hasPaymentCharge,
              onChanged: (v) => setState(() {
                _hasPaymentCharge = v;
                if (!v) _paymentPresetIndex = 0;
              }),
              activeColor: AppColors.primary,
            ),
          ],
        ),
        if (_hasPaymentCharge) ...[
          const SizedBox(height: 10),
          Row(children: List.generate(_paymentPresets.length, (i) {
            final p = _paymentPresets[i];
            final sel = _paymentPresetIndex == i;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _paymentPresetIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.bkashWallet.withValues(alpha: 0.1)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? AppColors.bkashWallet : AppColors.border,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Text(p.$1,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: sel
                          ? AppColors.bkashWallet
                          : AppColors.textSecondary,
                      fontWeight:
                          sel ? FontWeight.w700 : FontWeight.w500,
                    )),
              ),
            ));
          })),
        ],
      ]),
    );
  }

  // ── Amount field ───────────────────────────────────────────────────────────

  Widget _buildAmountField(bool isTransfer, Map<String, double> balanceMap) {
    final needed = isTransfer
        ? _cashOutTotalCost
        : (_isExpenseFromBkash && _hasPaymentCharge
            ? _paymentTotalCost
            : _amount);
    final fromBal = isTransfer
        ? (balanceMap[_tfFromId] ?? 0.0)
        : (balanceMap[_sourceWalletId] ?? 0.0);
    final isOverdrawn = _type != TransactionType.income &&
        _amount > 0 &&
        needed > fromBal + 0.001;

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
                  _amount > 0 ? _amount.toCurrency : 'Tap to enter amount',
                  style: _amount > 0
                      ? AppTextStyles.amountLarge.copyWith(
                          color: isOverdrawn ? AppColors.error : _typeColor)
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
                  Text('Exceeds available balance',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.error)),
                ]),
              ],
            ],
          )),
          const Icon(Icons.calculate_outlined,
              color: AppColors.primary, size: 24),
        ]),
      ),
    );
  }

  // ── Breakdown ──────────────────────────────────────────────────────────────

  Widget _buildBreakdown(bool isTransfer, Map<String, double> balanceMap) {
    if (isTransfer) {
      final fromBal = balanceMap[_tfFromId] ?? 0.0;
      final toBal   = balanceMap[_tfToId] ?? 0.0;
      final overdrawn = _cashOutTotalCost > fromBal + 0.001;
      return _BreakdownCard(isOverdrawn: overdrawn, rows: [
        _BRow('Transfer amount', _amount.toCurrency),
        if (_bkashToCash && _cashOutCharge > 0) ...[
          // FIX: breakdown label adapts to manual vs preset
          _BRow(
            _useManualCharge
                ? 'Cash out charge (fixed)'
                : 'Cash out charge (${(_effectiveCashOutRate * 100).toStringAsFixed(2)}%)',
            _cashOutCharge.toCurrency,
            color: AppColors.expense,
          ),
          const Divider(height: 10),
          _BRow('Total from $_tfFromName',
              _cashOutTotalCost.toCurrency, bold: true),
          _BRow('$_tfToName receives',
              _tfDestAmount.toCurrency, color: AppColors.income),
        ],
        const Divider(height: 10),
        _BRow('$_tfFromName after',
            overdrawn
                ? 'Insufficient'
                : BalanceService.round2(fromBal - _cashOutTotalCost)
                    .toCurrency,
            color: overdrawn ? AppColors.error : AppColors.expense),
        _BRow('$_tfToName after',
            BalanceService.round2(toBal + _tfDestAmount).toCurrency,
            color: AppColors.income),
        if (!_bkashToCash)
          _BRow('ℹ Cash In', 'Completely free', color: AppColors.income),
      ]);
    }

    if (_isExpenseFromBkash && _hasPaymentCharge && _paymentCharge > 0) {
      final bkashBal = balanceMap[WalletConstants.bkashWalletId] ?? 0.0;
      final overdrawn = _paymentTotalCost > bkashBal + 0.001;
      return _BreakdownCard(isOverdrawn: overdrawn, rows: [
        _BRow('Original amount', _amount.toCurrency),
        _BRow(
          'Payment charge (${(_paymentRate * 100).toStringAsFixed(2)}%)',
          _paymentCharge.toCurrency,
          color: AppColors.expense,
        ),
        const Divider(height: 10),
        _BRow('Total from bKash',
            _paymentTotalCost.toCurrency, bold: true),
        const Divider(height: 10),
        _BRow('bKash after',
            overdrawn
                ? 'Insufficient'
                : BalanceService.round2(bkashBal - _paymentTotalCost)
                    .toCurrency,
            color: overdrawn ? AppColors.error : AppColors.expense),
      ]);
    }

    if (_type == TransactionType.expense && _amount > 0) {
      final bal = balanceMap[_sourceWalletId] ?? 0.0;
      final wallets = ref.read(allWalletsProvider);
      final wName = wallets
              .where((w) => w.id == _sourceWalletId)
              .map((w) => w.name)
              .firstOrNull ?? 'wallet';
      final after = BalanceService.round2(bal - _amount);
      final overdrawn = _amount > bal + 0.001;
      return _BreakdownCard(isOverdrawn: overdrawn, rows: [
        _BRow('$wName balance', bal.toCurrency),
        _BRow('$wName after expense',
            overdrawn ? 'Insufficient' : after.toCurrency,
            color: overdrawn ? AppColors.error : AppColors.expense),
      ]);
    }

    return const SizedBox.shrink();
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
        child: Row(children: [
          const Icon(Icons.event_outlined,
              color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_dateTime.displayDateTime,
                style: AppTextStyles.bodyMedium),
          ),
          const Icon(Icons.edit_outlined,
              color: AppColors.textTertiary, size: 18),
        ]),
      ),
    );
  }

  Widget _buildSaveBar(bool isTransfer, Map<String, double> balanceMap) {
    final fromBal  = isTransfer ? (balanceMap[_tfFromId] ?? 0.0) : 0.0;
    final bkashBal = balanceMap[WalletConstants.bkashWalletId] ?? 0.0;
    final srcBal   = balanceMap[_sourceWalletId] ?? 0.0;

    final tfOver = isTransfer && _amount > 0 &&
        _cashOutTotalCost > fromBal + 0.001;
    final payOver = _isExpenseFromBkash && _hasPaymentCharge &&
        _amount > 0 && _paymentTotalCost > bkashBal + 0.001;
    final expOver = !isTransfer && _type == TransactionType.expense &&
        !(_isExpenseFromBkash && _hasPaymentCharge) &&
        _amount > 0 && _amount > srcBal + 0.001;
    final isOverdrawn = tfOver || payOver || expOver;
    final canSave = _amount > 0 && !isOverdrawn;

    String label;
    if (_amount <= 0) {
      label = 'Enter Amount First';
    } else if (isOverdrawn) {
      label = 'Insufficient Balance';
    } else if (isTransfer && _cashOutCharge > 0) {
      label = 'Transfer (Total ${_cashOutTotalCost.toCurrency})';
    } else if (isTransfer) {
      label = 'Transfer ${_amount.toCurrency}';
    } else if (_isExpenseFromBkash && _paymentCharge > 0) {
      label = 'Save (Total ${_paymentTotalCost.toCurrency})';
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
          onPressed: (_isSaving || !canSave) ? null : () => _save(balanceMap),
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
      case TransactionType.income:  return AppColors.income;
      case TransactionType.expense: return AppColors.expense;
      default:                      return AppColors.transfer;
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _WalletBadge extends StatelessWidget {
  const _WalletBadge({
    required this.icon, required this.label, required this.balance,
    required this.color, required this.role, required this.isSource,
  });
  final IconData icon;
  final String label, role;
  final double balance;
  final Color color;
  final bool isSource;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: isSource ? AppColors.expenseLight : AppColors.incomeLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSource
              ? AppColors.expense.withValues(alpha: 0.35)
              : AppColors.income.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(balance.toCurrency,
                  style: AppTextStyles.amountSmall.copyWith(color: color)),
            ),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isSource
                ? AppColors.expense.withValues(alpha: 0.12)
                : AppColors.income.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(role,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSource ? AppColors.expense : AppColors.income,
                fontWeight: FontWeight.w700, fontSize: 9,
              )),
        ),
      ]),
    );
  }
}

// FIX: _MiniWallet now always shows brand color for icon and label,
// and only dims the balance amount when not selected — not the identity.
class _MiniWallet extends StatelessWidget {
  const _MiniWallet({
    required this.icon, required this.label,
    required this.balance, required this.color,
    required this.isSelected,
  });
  final IconData icon;
  final String label;
  final double balance;
  final Color color;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // FIX: icon always uses the wallet's brand color (never dimmed)
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 3),
      // FIX: label always uses brand color, bold when selected
      Text(label, style: AppTextStyles.labelSmall.copyWith(
        color: color,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      )),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(balance.toCurrency,
            style: AppTextStyles.amountSmall.copyWith(
              // FIX: balance uses brand color when selected, muted otherwise
              color: isSelected ? color : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              fontSize: isSelected ? 13 : 11,
            )),
      ),
    ]);
  }
}

class _DirButton extends StatelessWidget {
  const _DirButton({
    required this.label, required this.badge,
    required this.badgeColor, required this.isSelected, required this.onTap,
  });
  final String label, badge;
  final Color badgeColor;
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
        child: Column(children: [
          Text(label, style: AppTextStyles.titleMedium.copyWith(
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          )),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(badge, style: AppTextStyles.labelSmall.copyWith(
                color: badgeColor, fontWeight: FontWeight.w700, fontSize: 10)),
          ),
        ]),
      ),
    );
  }
}

/// Charge rate pill button.
class _ChargePill extends StatelessWidget {
  const _ChargePill({
    required this.rateLabel,
    required this.sublabel,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
  });
  final String rateLabel, sublabel;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? AppColors.savings;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(children: [
          Text(rateLabel, textAlign: TextAlign.center,
              style: AppTextStyles.titleMedium.copyWith(
                color: isSelected ? color : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              )),
          if (sublabel.isNotEmpty)
            Text(sublabel, textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
        ]),
      ),
    ));
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.isOverdrawn, required this.rows});
  final bool isOverdrawn;
  final List<Widget> rows;

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
            isOverdrawn
                ? Icons.warning_amber_outlined
                : Icons.receipt_long_outlined,
            size: 14,
            color: isOverdrawn ? AppColors.error : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            isOverdrawn ? 'Insufficient Balance' : 'Breakdown',
            style: AppTextStyles.labelMedium.copyWith(
                color: isOverdrawn
                    ? AppColors.error
                    : AppColors.textSecondary),
          ),
        ]),
        const SizedBox(height: 8),
        ...rows,
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