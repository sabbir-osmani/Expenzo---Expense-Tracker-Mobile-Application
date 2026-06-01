import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/transaction_type.dart';
import '../../../core/extensions/string_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/icon_utils.dart';
import '../../../data/models/category_model.dart';
import '../../providers/category_provider.dart';

class CategoryPicker extends ConsumerWidget {
  const CategoryPicker({
    super.key,
    required this.selectedCategoryId,
    required this.transactionType,
    required this.onChanged,
  });

  final String? selectedCategoryId;
  final TransactionType transactionType;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesByTypeProvider(transactionType));

    return DropdownButtonFormField<String>(
      value: _validatedValue(selectedCategoryId, categories),
      decoration: const InputDecoration(
        labelText: 'Category',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: categories.map((cat) => _buildItem(cat)).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Please select a category' : null,
      isExpanded: true,
    );
  }

  String? _validatedValue(
    String? id,
    List<CategoryModel> categories,
  ) {
    if (id == null) return null;
    final found = categories.any((c) => c.id == id);
    return found ? id : null;
  }

  DropdownMenuItem<String> _buildItem(CategoryModel cat) {
    return DropdownMenuItem(
      value: cat.id,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Color(cat.colorHex.colorValue).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              IconUtils.fromName(cat.iconName),
              size: 16,
              color: Color(cat.colorHex.colorValue),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cat.name,
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}