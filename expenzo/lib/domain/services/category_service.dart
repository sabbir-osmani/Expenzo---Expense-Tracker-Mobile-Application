import 'package:uuid/uuid.dart';
import '../../core/enums/transaction_type.dart';
import '../../core/errors/app_exceptions.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository.dart';

class CategoryService {
  const CategoryService(this._repository);

  final CategoryRepository _repository;
  static const _uuid = Uuid();

  Future<List<CategoryModel>> getAllCategories() =>
      _repository.getAll();

  Future<List<CategoryModel>> getCategoriesByType(TransactionType type) =>
      _repository.getByType(type.dbValue);

  Future<CategoryModel> addCategory({
    required String name,
    required TransactionType type,
    required String iconName,
    required String colorHex,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationException('Category name cannot be empty.');
    }

    final exists = await _repository.existsByName(trimmedName);
    if (exists) {
      throw DuplicateCategoryException(trimmedName);
    }

    final existing = await _repository.getByType(type.dbValue);
    final sortOrder = existing.length;

    final category = CategoryModel(
      id: 'cat_custom_${_uuid.v4().replaceAll('-', '').substring(0, 12)}',
      name: trimmedName,
      type: type,
      iconName: iconName,
      colorHex: colorHex,
      isDefault: false,
      isActive: true,
      sortOrder: sortOrder,
    );

    await _repository.add(category);
    return category;
  }

  Future<CategoryModel> editCategory({
    required String id,
    required String name,
    required String iconName,
    required String colorHex,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationException('Category name cannot be empty.');
    }

    final existing = await _repository.getById(id);
    if (existing == null) {
      throw const ValidationException('Category not found.');
    }

    final nameExists =
        await _repository.existsByName(trimmedName, excludeId: id);
    if (nameExists) {
      throw DuplicateCategoryException(trimmedName);
    }

    final updated = existing.copyWith(
      name: trimmedName,
      iconName: iconName,
      colorHex: colorHex,
    );

    await _repository.update(updated);
    return updated;
  }

  Future<void> deleteCategory(String id) async {
    final category = await _repository.getById(id);
    if (category == null) return;

    if (category.isDefault) {
      throw const ProtectedCategoryException();
    }

    // Transactions referencing this category will display 'Unknown'
    // via the soft-reference fallback in Category.unknown.
    await _repository.delete(id);
  }

  Future<void> toggleCategoryActive(String id) async {
    final category = await _repository.getById(id);
    if (category == null) return;
    await _repository.update(
      category.copyWith(isActive: !category.isActive),
    );
  }
}