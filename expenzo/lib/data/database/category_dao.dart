import 'package:sqflite/sqflite.dart';
import '../models/category_model.dart';

class CategoryDao {
  const CategoryDao(this._db);

  final Database _db;

  Future<void> insert(CategoryModel category) async {
    await _db.insert(
      CategoryModel.tableName,
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(CategoryModel category) async {
    await _db.update(
      CategoryModel.tableName,
      category.toMap(),
      where: '${CategoryModel.colId} = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> delete(String id) async {
    await _db.delete(
      CategoryModel.tableName,
      where: '${CategoryModel.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAll() async {
    await _db.delete(CategoryModel.tableName);
  }

  Future<void> insertBatch(List<CategoryModel> categories) async {
    final batch = _db.batch();
    for (final c in categories) {
      batch.insert(
        CategoryModel.tableName,
        c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<CategoryModel?> getById(String id) async {
    final maps = await _db.query(
      CategoryModel.tableName,
      where: '${CategoryModel.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CategoryModel.fromMap(maps.first);
  }

  Future<List<CategoryModel>> getAll() async {
    final maps = await _db.query(
      CategoryModel.tableName,
      orderBy:
          '${CategoryModel.colType} ASC, ${CategoryModel.colSortOrder} ASC',
    );
    return maps.map(CategoryModel.fromMap).toList();
  }

  Future<List<CategoryModel>> getByType(String type) async {
    final maps = await _db.query(
      CategoryModel.tableName,
      where: '${CategoryModel.colType} = ? AND ${CategoryModel.colIsActive} = 1',
      whereArgs: [type],
      orderBy: '${CategoryModel.colSortOrder} ASC',
    );
    return maps.map(CategoryModel.fromMap).toList();
  }

  Future<bool> existsByName(String name, {String? excludeId}) async {
    final conditions = ['LOWER(${CategoryModel.colName}) = LOWER(?)'];
    final args = <dynamic>[name.trim()];
    if (excludeId != null) {
      conditions.add('${CategoryModel.colId} != ?');
      args.add(excludeId);
    }
    final result = await _db.query(
      CategoryModel.tableName,
      where: conditions.join(' AND '),
      whereArgs: args,
      limit: 1,
    );
    return result.isNotEmpty;
  }
}