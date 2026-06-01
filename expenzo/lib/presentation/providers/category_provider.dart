import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/transaction_type.dart';
import '../../data/models/category_model.dart';
import 'core_providers.dart';

// ── Notifier ───────────────────────────────────────────────────────────────

class CategoryNotifier extends AsyncNotifier<List<CategoryModel>> {
  @override
  Future<List<CategoryModel>> build() {
    return ref.read(categoryRepositoryProvider).getAll();
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> addCategory(CategoryModel category) async {
    await ref.read(categoryRepositoryProvider).add(category);
    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, category]);
  }

  Future<void> updateCategory(CategoryModel category) async {
    await ref.read(categoryRepositoryProvider).update(category);
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((c) => c.id == category.id);
    if (idx == -1) { ref.invalidateSelf(); return; }
    final updated = [...current];
    updated[idx] = category;
    state = AsyncData(updated);
  }

  Future<void> deleteCategory(String id) async {
    await ref.read(categoryRepositoryProvider).delete(id);
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((c) => c.id != id).toList());
  }
}

final categoryNotifierProvider =
    AsyncNotifierProvider<CategoryNotifier, List<CategoryModel>>(
  CategoryNotifier.new,
);

// ── Derived ────────────────────────────────────────────────────────────────

final allCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  return ref
      .watch(categoryNotifierProvider)
      .maybeWhen(data: (list) => list, orElse: () => const []);
});

final categoriesByTypeProvider =
    Provider.family<List<CategoryModel>, TransactionType>((ref, type) {
  final all = ref.watch(allCategoriesProvider);
  return all
      .where((c) => c.type == type && c.isActive)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

/// Quick O(1) lookup map: id → CategoryModel.
final categoryMapProvider = Provider<Map<String, CategoryModel>>((ref) {
  final all = ref.watch(allCategoriesProvider);
  return {for (final c in all) c.id: c};
});