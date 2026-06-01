import 'package:flutter_test/flutter_test.dart';
import 'package:expenzo/core/enums/transaction_type.dart';
import 'package:expenzo/core/errors/app_exceptions.dart';
import 'package:expenzo/data/models/category_model.dart';
import 'package:expenzo/data/repositories/category_repository.dart';
import 'package:expenzo/domain/services/category_service.dart';

// ── Manual fake repository (no code generation required) ──────────────────

class _FakeCategoryRepository implements CategoryRepository {
  bool existsByNameResult = false;
  List<CategoryModel> byTypeResult = [];
  CategoryModel? byIdResult;
  CategoryModel? addedCategory;
  CategoryModel? updatedCategory;
  String? deletedId;
  bool addCalled = false;
  bool updateCalled = false;
  bool deleteCalled = false;

  @override
  Future<bool> existsByName(String name, {String? excludeId}) async =>
      existsByNameResult;

  @override
  Future<List<CategoryModel>> getByType(String type) async => byTypeResult;

  @override
  Future<CategoryModel?> getById(String id) async => byIdResult;

  @override
  Future<void> add(CategoryModel category) async {
    addedCategory = category;
    addCalled = true;
  }

  @override
  Future<void> update(CategoryModel category) async {
    updatedCategory = category;
    updateCalled = true;
  }

  @override
  Future<void> delete(String id) async {
    deletedId = id;
    deleteCalled = true;
  }

  @override
  Future<List<CategoryModel>> getAll() async => [];

  @override
  Future<void> deleteAll() async {}

  @override
  Future<void> replaceAll(List<CategoryModel> categories) async {}
}

// ── Helpers ────────────────────────────────────────────────────────────────

CategoryModel _cat({
  String id = 'cat_1',
  String name = 'Food',
  bool isDefault = false,
  bool isActive = true,
}) =>
    CategoryModel(
      id: id,
      name: name,
      type: TransactionType.expense,
      iconName: 'restaurant',
      colorHex: '#E53935',
      isDefault: isDefault,
      isActive: isActive,
      sortOrder: 0,
    );

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late _FakeCategoryRepository fakeRepo;
  late CategoryService svc;

  setUp(() {
    fakeRepo = _FakeCategoryRepository();
    svc = CategoryService(fakeRepo);
  });

  group('CategoryService — add', () {
    test('adds category when name is unique', () async {
      fakeRepo.existsByNameResult = false;
      fakeRepo.byTypeResult = [];

      final cat = await svc.addCategory(
        name: 'Food',
        type: TransactionType.expense,
        iconName: 'restaurant',
        colorHex: '#E53935',
      );

      expect(cat.name, 'Food');
      expect(fakeRepo.addCalled, true);
    });

    test('throws DuplicateCategoryException when name exists', () async {
      fakeRepo.existsByNameResult = true;

      expect(
        () => svc.addCategory(
          name: 'Food',
          type: TransactionType.expense,
          iconName: 'restaurant',
          colorHex: '#E53935',
        ),
        throwsA(isA<DuplicateCategoryException>()),
      );
    });

    test('throws ValidationException when name is empty', () {
      expect(
        () => svc.addCategory(
          name: '   ',
          type: TransactionType.expense,
          iconName: 'restaurant',
          colorHex: '#E53935',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('CategoryService — delete', () {
    test('deletes non-default category', () async {
      fakeRepo.byIdResult = _cat(isDefault: false);

      await svc.deleteCategory('cat_1');

      expect(fakeRepo.deleteCalled, true);
      expect(fakeRepo.deletedId, 'cat_1');
    });

    test('throws ProtectedCategoryException for default category', () async {
      fakeRepo.byIdResult = _cat(isDefault: true);

      expect(
        () => svc.deleteCategory('cat_1'),
        throwsA(isA<ProtectedCategoryException>()),
      );
      expect(fakeRepo.deleteCalled, false);
    });

    test('does nothing when category not found', () async {
      fakeRepo.byIdResult = null;

      await svc.deleteCategory('nonexistent');

      expect(fakeRepo.deleteCalled, false);
    });
  });

  group('CategoryService — edit', () {
    test('updates category with valid name', () async {
      final cat = _cat();
      fakeRepo.byIdResult = cat;
      fakeRepo.existsByNameResult = false;

      final updated = await svc.editCategory(
        id: cat.id,
        name: 'New Name',
        iconName: 'star',
        colorHex: '#43A047',
      );

      expect(updated.name, 'New Name');
      expect(fakeRepo.updateCalled, true);
    });

    test('throws DuplicateCategoryException when new name already exists',
        () async {
      fakeRepo.byIdResult = _cat();
      fakeRepo.existsByNameResult = true;

      expect(
        () => svc.editCategory(
          id: 'cat_1',
          name: 'Duplicate',
          iconName: 'star',
          colorHex: '#43A047',
        ),
        throwsA(isA<DuplicateCategoryException>()),
      );
    });
  });
}