import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

abstract class ICategoryRepository {
  Stream<List<Category>> watchAllCategories();
  Future<int> addCategory(CategoriesCompanion category);
  Future<bool> updateCategory(Category category);
  Future<int> deleteCategory(int id);
}

class CategoryRepository implements ICategoryRepository {
  final AppDatabase _db;

  CategoryRepository(this._db);

  @override
  Stream<List<Category>> watchAllCategories() {
    return (_db.select(_db.categories)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  @override
  Future<int> addCategory(CategoriesCompanion category) {
    return _db.into(_db.categories).insert(category);
  }

  @override
  Future<bool> updateCategory(Category category) {
    return _db.update(_db.categories).replace(category);
  }

  @override
  Future<int> deleteCategory(int id) {
    return (_db.delete(_db.categories)
          ..where((t) => t.id.equals(id) & t.isDefault.equals(false)))
        .go();
  }
}
