import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/common/confirmation_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Settings', style: AppTextStyles.headlineSmall),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader(label: 'Data'),
          _SettingsTile(
            icon: Icons.backup_outlined,
            title: 'Backup & Restore',
            subtitle: 'Export or import your data',
            onTap: () => context.push('/settings/backup'),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.category_outlined,
            title: 'Manage Categories',
            subtitle: 'Add, edit, or delete categories',
            onTap: () => context.push('/settings/categories'),
          ),
          const SizedBox(height: 24),

          _SectionHeader(label: 'Wallets'),
          _SettingsTile(
            icon: Icons.payments_outlined,
            title: 'Cash',
            subtitle: 'Physical cash wallet',
            trailing: _dot(AppColors.cashWallet),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.phone_android_outlined,
            title: 'bKash',
            subtitle: 'Mobile banking wallet',
            trailing: _dot(AppColors.bkashWallet),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.account_balance_outlined,
            title: 'Savings',
            subtitle: 'Long-term savings wallet',
            trailing: _dot(AppColors.savingsWallet),
          ),
          const SizedBox(height: 24),

          // ── Danger zone ─────────────────────────────────────────────────
          _SectionHeader(label: 'Danger Zone'),
          _SettingsTile(
            icon: Icons.delete_forever_outlined,
            title: 'Clear All Data',
            subtitle: 'Permanently delete all transactions',
            onTap: () => _confirmClearData(context, ref),
            isDestructive: true,
          ),
          const SizedBox(height: 24),

          _SectionHeader(label: 'About'),
          _SettingsTile(
            icon: Icons.info_outline,
            title: AppConstants.appName,
            subtitle: 'Version ${AppConstants.appVersion}',
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Future<void> _confirmClearData(
      BuildContext context, WidgetRef ref) async {
    final step1 = await ConfirmationDialog.show(
      context,
      title: 'Clear All Data',
      message: 'This will permanently delete ALL transactions.\n\n'
          'Wallet balances will reset to ৳ 0.00.\n'
          'Categories and wallet names are preserved.\n\n'
          'Export a backup first if you need your data.',
      confirmLabel: 'Proceed',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );
    if (!step1 || !context.mounted) return;

    // Second confirmation — no accidental taps.
    final step2 = await ConfirmationDialog.show(
      context,
      title: 'Are you absolutely sure?',
      message:
          'All transaction history will be permanently erased. This cannot be undone.',
      confirmLabel: 'Yes, Delete Everything',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );
    if (!step2 || !context.mounted) return;

    await ref.read(transactionNotifierProvider.notifier).clearAll();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared.')),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final iconColor = isDestructive ? AppColors.error : AppColors.primary;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDestructive
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            color: isDestructive ? AppColors.error : AppColors.textPrimary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle!, style: AppTextStyles.bodySmall)
            : null,
        trailing: onTap != null
            ? Icon(Icons.chevron_right,
                color: isDestructive
                    ? AppColors.error
                    : AppColors.textTertiary)
            : trailing,
        onTap: onTap,
      ),
    );
  }
}