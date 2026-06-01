import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/transaction_type.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/extensions/string_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/icon_utils.dart';
import '../../../core/utils/validator.dart';
import '../../../data/models/category_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common/confirmation_dialog.dart';
import '../../widgets/common/expenzo_app_bar.dart';

class ManageCategoriesScreen extends ConsumerStatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  ConsumerState<ManageCategoriesScreen> createState() =>
      _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState
    extends ConsumerState<ManageCategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  TransactionType get _currentType {
    switch (_tabController.index) {
      case 0:
        return TransactionType.income;
      case 1:
        return TransactionType.expense;
      default:
        return TransactionType.savings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ExpenzoAppBar(
        title: 'Categories',
        showBack: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Income'),
              Tab(text: 'Expense'),
              Tab(text: 'Savings'),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textTertiary,
            indicatorColor: AppColors.primary,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSheet(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabController,
        children: TransactionType.values
            .where((t) => t != TransactionType.transfer)
            .map((type) => _CategoryList(
                  type: type,
                  onEdit: (cat) => _showAddEditSheet(context, cat),
                  onDelete: (cat) => _deleteCategory(context, cat),
                  onToggle: (cat) => _toggleCategory(cat),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _showAddEditSheet(
      BuildContext context, CategoryModel? existing) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditCategorySheet(
        existing: existing,
        defaultType: _currentType,
      ),
    );
    if (result == true) {
      ref.read(categoryNotifierProvider.notifier).reload();
    }
  }

  Future<void> _deleteCategory(
    BuildContext context, CategoryModel cat) async {
  // Capture messenger BEFORE any await to satisfy use_build_context_synchronously
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await ConfirmationDialog.show(
    context,
    title: 'Delete Category',
    message:
        'Deleting "${cat.name}" will not delete existing transactions. '
        'They will show as "Unknown" category.',
  );
  if (!confirmed) return;

  try {
    await ref.read(categoryServiceProvider).deleteCategory(cat.id);
    ref.read(categoryNotifierProvider.notifier).reload();
  } on ProtectedCategoryException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Delete failed: $e')),
    );
  }
}

  Future<void> _toggleCategory(CategoryModel cat) async {
    await ref.read(categoryServiceProvider).toggleCategoryActive(cat.id);
    ref.read(categoryNotifierProvider.notifier).reload();
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({
    required this.type,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });
  final TransactionType type;
  final ValueChanged<CategoryModel> onEdit;
  final ValueChanged<CategoryModel> onDelete;
  final ValueChanged<CategoryModel> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allCategoriesProvider);
    final cats = all.where((c) => c.type == type).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (cats.isEmpty) {
      return const Center(child: Text('No categories yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: cats.length,
      itemBuilder: (context, i) {
        final cat = cats[i];
        final color = Color(cat.colorHex.colorValue);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(IconUtils.fromName(cat.iconName), color: color, size: 20),
            ),
            title: Text(
              cat.name,
              style: AppTextStyles.titleMedium.copyWith(
                color: cat.isActive
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ),
            subtitle: cat.isDefault
                ? Text('Default',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.primary))
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: cat.isActive,
                  onChanged: (_) => onToggle(cat),
                  activeColor: AppColors.primary,
                ),
                if (!cat.isDefault) ...[
                  IconButton(
                    onPressed: () => onEdit(cat),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppColors.textSecondary,
                  ),
                  IconButton(
                    onPressed: () => onDelete(cat),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppColors.expense,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddEditCategorySheet extends ConsumerStatefulWidget {
  const _AddEditCategorySheet({
    this.existing,
    required this.defaultType,
  });
  final CategoryModel? existing;
  final TransactionType defaultType;

  @override
  ConsumerState<_AddEditCategorySheet> createState() =>
      _AddEditCategorySheetState();
}

class _AddEditCategorySheetState
    extends ConsumerState<_AddEditCategorySheet> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedIcon = 'category';
  String _selectedColor = '#5C6BC0';
  bool _isSaving = false;

  static const _colorOptions = [
    '#43A047', '#E53935', '#1E88E5', '#FB8C00', '#8E24AA',
    '#00ACC1', '#F4511E', '#6D4C41', '#546E7A', '#5C6BC0',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _selectedIcon = widget.existing!.iconName;
      _selectedColor = widget.existing!.colorHex;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    try {
      final svc = ref.read(categoryServiceProvider);
      if (widget.existing == null) {
        await svc.addCategory(
          name: _nameController.text.trim(),
          type: widget.defaultType,
          iconName: _selectedIcon,
          colorHex: _selectedColor,
        );
      } else {
        await svc.editCategory(
          id: widget.existing!.id,
          name: _nameController.text.trim(),
          iconName: _selectedIcon,
          colorHex: _selectedColor,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on DuplicateCategoryException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingNames = ref
        .read(allCategoriesProvider)
        .where((c) => widget.existing == null || c.id != widget.existing!.id)
        .map((c) => c.name)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'Add Category' : 'Edit Category',
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Category Name'),
                validator: (v) =>
                    AppValidator.categoryName(v, existing: existingNames),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              Text('Color', style: AppTextStyles.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colorOptions.map((hex) {
                  final isSelected = _selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(hex.colorValue),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: AppColors.textPrimary, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Icon', style: AppTextStyles.labelMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: IconUtils.availableIcons.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final iconName = IconUtils.availableIcons[i];
                    final isSelected = _selectedIcon == iconName;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = iconName),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(_selectedColor.colorValue)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? null
                              : Border.all(color: AppColors.border),
                        ),
                        child: Icon(
                          IconUtils.fromName(iconName),
                          size: 20,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(widget.existing == null ? 'Add Category' : 'Update'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}