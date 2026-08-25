import 'package:drift/drift.dart';

// Conditional import: use native.dart on Android/iOS/Desktop, web.dart on web
import 'connection/unsupported.dart'
    if (dart.library.ffi) 'connection/native.dart'
    if (dart.library.js_interop) 'connection/web.dart';

part 'app_database.g.dart';

// ============================================================
// DRIFT TABLES DEFINITION
// ============================================================

@DataClassName('Transaction')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // 'income' | 'expense'
  RealColumn get amount => real()();
  TextColumn get category => text()();
  TextColumn get description => text().nullable()();
  TextColumn get source => text()(); // 'manual' | 'ai_text' | 'receipt_scan'
  TextColumn get paymentMethod =>
      text().nullable()(); // 'Tunai' | 'Gopay' | 'OVO' | dll
  TextColumn get receiptImagePath => text().nullable()();
  IntColumn get transactionDate => integer()(); // Timestamp in ms
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

@DataClassName('TransactionItem')
class TransactionItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId =>
      integer().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  RealColumn get unitPrice => real().nullable()();
  RealColumn get totalPrice => real()();
  IntColumn get createdAt => integer()();
}

@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()(); // Hex string e.g. '#10B981'
  TextColumn get type => text()(); // 'income' | 'expense' | 'both'
  BoolColumn get isDefault => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
}

@DataClassName('ChatMessage')
class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get role => text()(); // 'user' | 'assistant'
  TextColumn get content => text()();
  IntColumn get createdAt => integer()();
}

@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

// ============================================================
// DRIFT DATABASE SETUP & SEEDING
// ============================================================

@DriftDatabase(
  tables: [
    Transactions,
    TransactionItems,
    Categories,
    ChatMessages,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createPerformanceIndexes();
      await _seedDefaultCategories();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(transactionItems);
      }
      if (from < 3) {
        await _createPerformanceIndexes();
      }
    },
  );

  Future<void> _createPerformanceIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_date_id '
      'ON transactions(transaction_date DESC, id DESC);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_type_date '
      'ON transactions(type, transaction_date);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_category_date '
      'ON transactions(category, transaction_date);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transaction_items_transaction_id '
      'ON transaction_items(transaction_id);',
    );
  }

  Future<void> _seedDefaultCategories() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final defaultCategories = [
      // Expense Categories
      CategoriesCompanion.insert(
        name: 'Makanan & Minuman',
        icon: const Value('fastfood'),
        color: const Value('#F43F5E'),
        type: 'expense',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        name: 'Belanja Harian',
        icon: const Value('shopping_bag'),
        color: const Value('#06B6D4'),
        type: 'expense',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        name: 'Transportasi',
        icon: const Value('directions_car'),
        color: const Value('#3B82F6'),
        type: 'expense',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        name: 'Tagihan & Utilitas',
        icon: const Value('receipt_long'),
        color: const Value('#F59E0B'),
        type: 'expense',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        name: 'Hiburan',
        icon: const Value('sports_esports'),
        color: const Value('#8B5CF6'),
        type: 'expense',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        name: 'Kesehatan',
        icon: const Value('medical_services'),
        color: const Value('#EC4899'),
        type: 'expense',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        name: 'Pendidikan',
        icon: const Value('school'),
        color: const Value('#6366F1'),
        type: 'expense',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        name: 'Fashion & Kecantikan',
        icon: const Value('checkroom'),
        color: const Value('#14B8A6'),
        type: 'expense',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        name: 'Rumah Tangga',
        icon: const Value('home'),
        color: const Value('#64748B'),
        type: 'expense',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        name: 'Pengeluaran Lainnya',
        icon: const Value('more_horiz'),
        color: const Value('#94A3B8'),
        type: 'expense',
        isDefault: const Value(true),
        createdAt: now,
      ),

      // Income Categories
      CategoriesCompanion.insert(
        name: 'Gaji',
        icon: const Value('payments'),
        color: const Value('#10B981'),
        type: 'income',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        name: 'Bonus & THR',
        icon: const Value('card_giftcard'),
        color: const Value('#059669'),
        type: 'income',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        name: 'Investasi',
        icon: const Value('trending_up'),
        color: const Value('#3B82F6'),
        type: 'income',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        name: 'Usaha & Freelance',
        icon: const Value('work'),
        color: const Value('#8B5CF6'),
        type: 'income',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        name: 'Pemasukan Lainnya',
        icon: const Value('attach_money'),
        color: const Value('#10B981'),
        type: 'income',
        isDefault: const Value(true),
        createdAt: now,
      ),
    ];

    for (final category in defaultCategories) {
      await into(categories).insert(category, mode: InsertMode.insertOrIgnore);
    }
  }
}
