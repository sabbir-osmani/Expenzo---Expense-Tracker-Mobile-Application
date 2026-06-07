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
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/common/confirmation_dialog.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/expenzo_app_bar.dart';
import '../../widgets/forms/wallet_picker.dart';
import '../history/widgets/transaction_tile.dart';
import '../transaction/widgets/amount_calculator.dart';

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(walletBalanceMapProvider);
    final all = ref.watch(allTransactionsProvider);

    final savingsBalance = balances[WalletConstants.savingsWalletId] ?? 0.0;
    final cashBalance = balances[WalletConstants.cashWalletId] ?? 0.0;
    final bkashBalance = balances[WalletConstants.bkashWalletId] ?? 0.0;

    final savingsTxns = all
        .where((t) =>
            t.sourceWalletId == WalletConstants.savingsWalletId ||
            t.destinationWalletId == WalletConstants.savingsWalletId)
        .take(50)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ExpenzoAppBar(title: 'Savings', showBack: true),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── Savings balance card ─────────────────────────────────
                _SavingsHeader(balance: savingsBalance),
                const SizedBox(height: 16),

                // ── Available source balances ────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SourceBalancesRow(
                    cashBalance: cashBalance,
                    bkashBalance: bkashBalance,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Deposit / Withdraw actions ───────────────────────────
                _ActionRow(
                  savingsBalance: savingsBalance,
                  cashBalance: cashBalance,
                  bkashBalance: bkashBalance,
                  onDeposit: () => _showOperationSheet(
                    context, ref,
                    isDeposit: true,
                    savingsBalance: savingsBalance,
                  ),
                  onWithdraw: () => _showOperationSheet(
                    context, ref,
                    isDeposit: false,
                    savingsBalance: savingsBalance,
                  ),
                ),
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Savings History',
                        style: AppTextStyles.titleLarge),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          if (savingsTxns.isEmpty)
            const SliverFillRemaining(
              child: EmptyState(
                message: 'No savings transactions yet',
                subtitle: 'Tap Deposit to start saving',
                icon: Icons.account_balance_outlined,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final t = savingsTxns[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TransactionTile(
                        transaction: t,
                        swipeEnabled: true,
                        onEdit: () =>
                            context.push('/edit-transaction/${t.id}'),
                        onDelete: () async {
                          final confirmed = await ConfirmationDialog.show(
                            context,
                            title: 'Delete Transaction',
                            message: 'This will update your savings balance.',
                          );
                          if (confirmed) {
                            ref
                                .read(transactionNotifierProvider.notifier)
                                .delete(t.id);
                          }
                        },
                      ),
                    );
                  },
                  childCount: savingsTxns.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showOperationSheet(
    BuildContext context,
    WidgetRef ref, {
    required bool isDeposit,
    required double savingsBalance,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SavingsOperationSheet(
        isDeposit: isDeposit,
        savingsBalance: savingsBalance,
      ),
    );
  }
}

// ── Savings balance header ────────────────────────────────────────────────────

class _SavingsHeader extends StatelessWidget {
  const _SavingsHeader({required this.balance});
  final double balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.savingsWallet, Color(0xFFF57C00)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.savingsWallet.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.account_balance_outlined,
              color: Colors.white, size: 36),
          const SizedBox(height: 10),
          Text(
            'Total Savings',
            style: AppTextStyles.bodyMedium
                .copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              balance.toCurrency,
              style:
                  AppTextStyles.displayMedium.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Source balances row (Cash + bKash) ────────────────────────────────────────

class _SourceBalancesRow extends StatelessWidget {
  const _SourceBalancesRow({
    required this.cashBalance,
    required this.bkashBalance,
  });
  final double cashBalance;
  final double bkashBalance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Available to Deposit',
            style: AppTextStyles.titleMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SourceCard(
                icon: Icons.payments_outlined,
                label: 'Cash',
                balance: cashBalance,
                color: AppColors.cashWallet,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SourceCard(
                icon: Icons.phone_android_outlined,
                label: 'bKash',
                balance: bkashBalance,
                color: AppColors.bkashWallet,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.label,
    required this.balance,
    required this.color,
  });
  final IconData icon;
  final String label;
  final double balance;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textSecondary)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    balance.toCurrency,
                    style:
                        AppTextStyles.amountSmall.copyWith(color: color),
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

// ── Deposit / Withdraw action row ─────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.savingsBalance,
    required this.cashBalance,
    required this.bkashBalance,
    required this.onDeposit,
    required this.onWithdraw,
  });
  final double savingsBalance;
  final double cashBalance;
  final double bkashBalance;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final canDeposit = cashBalance > 0 || bkashBalance > 0;
    final canWithdraw = savingsBalance > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'Deposit',
              icon: Icons.add_circle_outline,
              color: canDeposit ? AppColors.income : AppColors.textTertiary,
              onTap: canDeposit ? onDeposit : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              label: 'Withdraw',
              icon: Icons.remove_circle_outline,
              color: canWithdraw ? AppColors.expense : AppColors.textTertiary,
              onTap: canWithdraw ? onWithdraw : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: onTap != null ? 0.08 : 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: color.withValues(alpha: onTap != null ? 0.3 : 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 5),
            Text(label,
                style: AppTextStyles.titleMedium.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Deposit / Withdraw bottom sheet ───────────────────────────────────────────

class _SavingsOperationSheet extends ConsumerStatefulWidget {
  const _SavingsOperationSheet({
    required this.isDeposit,
    required this.savingsBalance,
  });
  final bool isDeposit;
  final double savingsBalance;

  @override
  ConsumerState<_SavingsOperationSheet> createState() =>
      _SavingsOperationSheetState();
}

class _SavingsOperationSheetState
    extends ConsumerState<_SavingsOperationSheet> {
  static const _uuid = Uuid();
  String _walletId = WalletConstants.cashWalletId;
  double _amount = 0;
  final _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }


  Future<void> _save() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter an amount.')));
      return;
    }

    // Balance validation.
    final allTxns = ref.read(allTransactionsProvider);
    final balanceSvc = ref.read(balanceServiceProvider);

    final checkWallet = widget.isDeposit
        ? _walletId
        : WalletConstants.savingsWalletId;

    final available = balanceSvc.availableBalance(
      walletId: checkWallet,
      allTransactions: allTxns,
    );

    if (_amount > available) {
      final wallets = ref.read(allWalletsProvider);
      final walletName = wallets
              .where((w) => w.id == checkWallet)
              .map((w) => w.name)
              .firstOrNull ??
          (widget.isDeposit ? 'wallet' : 'Savings');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Insufficient balance in $walletName.\nAvailable: ${available.toCurrency}'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final txn = TransactionModel(
        id: _uuid.v4(),
        amount: _amount.rounded,
        type: TransactionType.savings,
        categoryId: widget.isDeposit
            ? 'cat_savings_deposit'
            : 'cat_savings_withdrawal',
        sourceWalletId: widget.isDeposit
            ? _walletId
            : WalletConstants.savingsWalletId,
        destinationWalletId: widget.isDeposit
            ? WalletConstants.savingsWalletId
            : _walletId,
        dateTime: now,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        monthKey: now.monthKey,
        createdAt: now,
        updatedAt: now,
      );

      await ref.read(transactionNotifierProvider.notifier).add(txn);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isDeposit
              ? 'Deposited ${_amount.toCurrency} to Savings.'
              : 'Withdrew ${_amount.toCurrency} from Savings.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balances = ref.watch(walletBalanceMapProvider);
    final color = widget.isDeposit ? AppColors.income : AppColors.expense;
    final sourceAvailable = widget.isDeposit
        ? (balances[_walletId] ?? 0.0)
        : (balances[WalletConstants.savingsWalletId] ?? 0.0);
    final isOverdrawn = _amount > 0 && _amount > sourceAvailable;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 16),

            Text(
              widget.isDeposit ? 'Deposit to Savings' : 'Withdraw from Savings',
              style: AppTextStyles.headlineSmall.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isDeposit
                  ? 'Available to deposit:'
                  : 'Savings available:',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            Text(
              sourceAvailable.toCurrency,
              style: AppTextStyles.titleMedium.copyWith(color: color),
            ),

            const SizedBox(height: 16),

            // Source wallet picker (only for deposit).
            if (widget.isDeposit) ...[
              WalletPicker(
                selectedWalletId: _walletId,
                onChanged: (v) => setState(() {
                  _walletId = v!;
                  _amount = 0; // reset amount when wallet changes
                }),
                label: 'From Wallet',
                excludeWalletId: WalletConstants.savingsWalletId,
              ),
              const SizedBox(height: 12),
            ],

            // Amount tap field.
            GestureDetector(
              onTap: () async {
                final result = await AmountCalculator.show(context,
                    initialValue: _amount);
                if (result != null && mounted) {
                  setState(() => _amount = result);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOverdrawn
                        ? AppColors.error
                        : _amount > 0
                            ? color
                            : AppColors.border,
                    width: _amount > 0 ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _amount > 0
                                  ? _amount.toCurrency
                                  : 'Tap to enter amount',
                              style: _amount > 0
                                  ? AppTextStyles.amountMedium.copyWith(
                                      color: isOverdrawn
                                          ? AppColors.error
                                          : color)
                                  : AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textTertiary),
                            ),
                          ),
                        ),
                        Icon(Icons.calculate_outlined,
                            color: AppColors.primary, size: 22),
                      ],
                    ),
                    if (isOverdrawn) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Exceeds available (${sourceAvailable.toCurrency})',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSaving || isOverdrawn || _amount <= 0)
                    ? null
                    : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isOverdrawn ? AppColors.error : color,
                  disabledBackgroundColor: color.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _amount <= 0
                            ? 'Enter Amount'
                            : isOverdrawn
                                ? 'Insufficient Balance'
                                : widget.isDeposit
                                    ? 'Deposit ${_amount.toCurrency}'
                                    : 'Withdraw ${_amount.toCurrency}',
                        style: AppTextStyles.titleLarge
                            .copyWith(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}