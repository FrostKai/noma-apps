import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noma/core/database/app_database.dart';
import 'package:noma/features/category/data/category_repository.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CategoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'default category can be edited and deleted without deleting transactions',
    () async {
      final now = DateTime(2026, 8, 28).millisecondsSinceEpoch;
      final categoryId = await repo.addCategory(
        CategoriesCompanion.insert(
          name: 'Kategori Lama',
          type: 'expense',
          isDefault: const Value(true),
          createdAt: now,
        ),
      );

      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              type: 'expense',
              amount: 25000,
              category: 'Kategori Lama',
              source: 'manual',
              transactionDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      final category = await (db.select(
        db.categories,
      )..where((t) => t.id.equals(categoryId))).getSingle();
      final updated = await repo.updateCategory(
        category.copyWith(name: 'Kategori Baru'),
        previousName: category.name,
      );
      expect(updated, isTrue);

      final renamedTransaction = await db.select(db.transactions).getSingle();
      expect(renamedTransaction.category, 'Kategori Baru');

      final deleted = await repo.deleteCategory(categoryId);
      expect(deleted, 1);
      expect(await db.select(db.categories).get(), isNot(contains(category)));
      expect(await db.select(db.transactions).get(), hasLength(1));
    },
  );
}
