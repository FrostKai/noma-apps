import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../data/category_repository.dart';

final categoryRepositoryProvider = Provider<ICategoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryRepository(db);
});

final categoryControllerProvider =
    StateNotifierProvider<CategoryController, AsyncValue<void>>((ref) {
      return CategoryController(ref.watch(categoryRepositoryProvider));
    });

class CategoryController extends StateNotifier<AsyncValue<void>> {
  final ICategoryRepository _repo;

  CategoryController(this._repo) : super(const AsyncData(null));

  Future<bool> addCategory({
    required String name,
    required String type,
    String? icon,
    String? color,
  }) async {
    state = const AsyncLoading();
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final companion = CategoriesCompanion.insert(
        name: name,
        type: type,
        icon: Value(icon),
        color: Value(color),
        isDefault: const Value(false),
        createdAt: now,
      );
      await _repo.addCategory(companion);
      state = const AsyncData(null);
      return true;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    state = const AsyncLoading();
    try {
      await _repo.deleteCategory(id);
      state = const AsyncData(null);
      return true;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<bool> updateCategory({
    required Category category,
    required String name,
    required String type,
  }) async {
    state = const AsyncLoading();
    try {
      final updated = category.copyWith(name: name, type: type);
      final success = await _repo.updateCategory(
        updated,
        previousName: category.name,
      );
      state = const AsyncData(null);
      return success;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return false;
    }
  }
}
