import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/wallet_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/wallet_model.dart';
import '../../providers/wallet_provider.dart';

class WalletPicker extends ConsumerWidget {
  const WalletPicker({
    super.key,
    required this.selectedWalletId,
    required this.onChanged,
    this.label = 'Wallet',
    this.excludeWalletId,
    this.excludeSavings = false,
  });

  final String? selectedWalletId;
  final ValueChanged<String?> onChanged;
  final String label;
  final String? excludeWalletId;
  /// When true, Savings wallet is never shown. Used for income/expense pickers.
  final bool excludeSavings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(activeWalletsProvider);

    final available = wallets.where((w) {
      if (excludeWalletId != null && w.id == excludeWalletId) return false;
      if (excludeSavings && w.id == WalletConstants.savingsWalletId) {
        return false;
      }
      return true;
    }).toList();

    // If selected wallet is now excluded, reset to first available.
    final effectiveSelected = available.any((w) => w.id == selectedWalletId)
        ? selectedWalletId
        : (available.isNotEmpty ? available.first.id : null);

    // If we need to auto-correct the selection, notify parent after build.
    if (effectiveSelected != selectedWalletId && effectiveSelected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onChanged(effectiveSelected);
      });
    }

    return DropdownButtonFormField<String>(
      value: effectiveSelected,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
      ),
      items: available.map((wallet) {
        return DropdownMenuItem(
          value: wallet.id,
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _walletColor(wallet),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(wallet.name, style: AppTextStyles.bodyMedium),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Please select a wallet' : null,
    );
  }

  Color _walletColor(WalletModel wallet) {
    switch (wallet.id) {
      case WalletConstants.cashWalletId:
        return AppColors.cashWallet;
      case WalletConstants.bkashWalletId:
        return AppColors.bkashWallet;
      case WalletConstants.savingsWalletId:
        return AppColors.savingsWallet;
      default:
        return AppColors.primary;
    }
  }
}