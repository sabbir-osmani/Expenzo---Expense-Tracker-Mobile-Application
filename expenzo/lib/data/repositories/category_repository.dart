import '../database/category_dao.dart';
import '../models/category_model.dart';

class CategoryRepository {
  const CategoryRepository(this._dao);

  final CategoryDao _dao;

  Future<void> add(CategoryModel category) => _dao.insert(category);

  Future<void> update(CategoryModel category) => _dao.update(category);

  Future<void> delete(String id) => _dao.delete(id);

  Future<void> deleteAll() => _dao.deleteAll();

  Future<CategoryModel?> getById(String id) => _dao.getById(id);

  Future<List<CategoryModel>> getAll() => _dao.getAll();

  Future<List<CategoryModel>> getByType(String type) =>
      _dao.getByType(type);

  Future<bool> existsByName(String name, {String? excludeId}) =>
      _dao.existsByName(name, excludeId: excludeId);

  Future<void> replaceAll(List<CategoryModel> categories) async {
    await _dao.deleteAll();
    if (categories.isNotEmpty) {
      await _dao.insertBatch(categories);
    }
  }
}