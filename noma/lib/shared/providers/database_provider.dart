import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';

/// AppDatabase Singleton Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Stream Provider for Categories
final categoriesStreamProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.categories)
        ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]))
      .watch();
});

/// Stream Provider for Expense Categories Only
final expenseCategoriesStreamProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.categories)
        ..where((t) => t.type.isIn(['expense', 'both']))
        ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]))
      .watch();
});

/// Stream Provider for Income Categories Only
final incomeCategoriesStreamProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.categories)
        ..where((t) => t.type.isIn(['income', 'both']))
        ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]))
      .watch();
});
