import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/category_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/common/confirmation_dialog.dart';
import '../../widgets/common/expenzo_app_bar.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _lastMessage;
  bool _lastSuccess = true;

  Future<void> _exportBackup() async {
    setState(() { _isExporting = true; _lastMessage = null; });
    try {
      final svc = ref.read(backupServiceProvider);
      await svc.exportBackup();
      _setMessage('Backup exported successfully.', success: true);
    } on AppException catch (e) {
      _setMessage(e.message, success: false);
    } catch (e) {
      _setMessage('Export failed: ${e.toString()}', success: false);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importBackup() async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Restore Backup',
      message:
          'This will replace ALL current data with the backup. This cannot be undone.',
      confirmLabel: 'Restore',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );
    if (!confirmed) return;

    // Pick file.
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } catch (_) {
      _setMessage('Could not open file picker.', success: false);
      return;
    }

    if (result == null || result.files.single.path == null) return;

    setState(() { _isImporting = true; _lastMessage = null; });
    try {
      final svc = ref.read(backupServiceProvider);
      await svc.importBackup(result.files.single.path!);

      // Reload all providers.
      await Future.wait([
        ref.read(transactionNotifierProvider.notifier).reload(),
        ref.read(categoryNotifierProvider.notifier).reload(),
        ref.read(walletNotifierProvider.notifier).reload(),
      ]);

      _setMessage('Data restored successfully.', success: true);
    } on UnsupportedBackupVersionException catch (e) {
      _setMessage(e.message, success: false);
    } on CorruptedBackupException catch (e) {
      _setMessage('Corrupted backup: ${e.message}', success: false);
    } on BackupImportException catch (e) {
      _setMessage(e.message, success: false);
    } catch (e) {
      _setMessage('Restore failed: ${e.toString()}', success: false);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _setMessage(String msg, {required bool success}) {
    if (mounted) setState(() { _lastMessage = msg; _lastSuccess = success; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ExpenzoAppBar(title: 'Backup & Restore', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_lastMessage != null) ...[
            _StatusBanner(message: _lastMessage!, success: _lastSuccess),
            const SizedBox(height: 16),
          ],
          _InfoCard(),
          const SizedBox(height: 24),
          _ActionCard(
            icon: Icons.upload_outlined,
            title: 'Export Backup',
            description:
                'Save all your transactions, categories, and wallets to a JSON file. '
                'Share it to cloud storage or keep it locally.',
            buttonLabel: 'Export Now',
            buttonColor: AppColors.primary,
            isLoading: _isExporting,
            onTap: _exportBackup,
          ),
          const SizedBox(height: 16),
          _ActionCard(
            icon: Icons.download_outlined,
            title: 'Restore Backup',
            description:
                'Import a previously exported JSON file. '
                'All existing data will be replaced.',
            buttonLabel: 'Choose File & Restore',
            buttonColor: AppColors.savings,
            isLoading: _isImporting,
            onTap: _importBackup,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.expenseLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined,
                    color: AppColors.expense, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Restoring replaces all data. Export first if you want to keep your current data.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.expense),
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

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.transferLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.transfer, size: 20),
              const SizedBox(width: 8),
              Text('About Backups',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.transfer)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Backups are stored as JSON files\n'
            '• Export before reinstalling the app\n'
            '• Backups include all transactions, categories, and wallets\n'
            '• Store backups in Google Drive for safekeeping',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.transfer, height: 1.7),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.buttonColor,
    required this.isLoading,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final Color buttonColor;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: buttonColor, size: 24),
              const SizedBox(width: 10),
              Text(title,
                  style: AppTextStyles.titleLarge.copyWith(color: buttonColor)),
            ],
          ),
          const SizedBox(height: 8),
          Text(description,
              style: AppTextStyles.bodySmall.copyWith(height: 1.5)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onTap,
              style: ElevatedButton.styleFrom(backgroundColor: buttonColor),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.success});
  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: success ? AppColors.incomeLight : AppColors.expenseLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.error_outline,
            color: success ? AppColors.income : AppColors.expense,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: success ? AppColors.income : AppColors.expense,
              ),
            ),
          ),
        ],
      ),
    );
  }
}