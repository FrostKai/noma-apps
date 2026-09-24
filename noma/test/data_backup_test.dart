import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noma/core/database/app_database.dart';
import 'package:noma/core/services/data_backup_service.dart';
import 'package:noma/features/transaction/data/transaction_repository.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  late AppDatabase source;
  late AppDatabase target;
  late Directory temp;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    source = AppDatabase.forTesting(NativeDatabase.memory());
    target = AppDatabase.forTesting(NativeDatabase.memory());
    temp = await Directory.systemTemp.createTemp('noma-backup-test-');
  });

  tearDown(() async {
    await source.close();
    await target.close();
    await temp.delete(recursive: true);
  });

  test(
    'backup restores transactions and items once without private settings or image paths',
    () async {
      final repo = TransactionRepository(source);
      final now = DateTime(2026, 8, 25).millisecondsSinceEpoch;
      await repo.addTransaction(
        TransactionsCompanion.insert(
          type: 'expense',
          amount: 17500,
          category: 'Makanan & Minuman',
          source: 'receipt_scan',
          receiptImagePath: const Value('/private/receipt.jpg'),
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
        items: [
          (name: 'Kopi', quantity: 2, unitPrice: 8750, totalPrice: 17500),
        ],
      );
      await source
          .into(source.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'api_key',
              value: const Value('secret'),
            ),
          );

      final file = await DataBackupService(
        source,
      ).exportToFile(File('${temp.path}/backup.json'));
      final content = await file.readAsString();
      expect(content, isNot(contains('/private/receipt.jpg')));
      expect(content, isNot(contains('secret')));
      final backup = DataBackupService(target);
      final preview = await backup.prepareRestore(file);
      expect(preview.newTransactions, 1);
      expect(preview.skippedTransactions, 0);
      expect((await backup.restore(preview)).added, 1);
      final duplicate = await backup.prepareRestore(file);
      expect(duplicate.newTransactions, 0);
      expect((await backup.restore(duplicate)).skipped, 1);
      final rows = await TransactionRepository(
        target,
      ).getTransactionsPage(limit: 50, offset: 0);
      expect(rows, hasLength(1));
      expect(rows.single.receiptImagePath, isNull);
      expect(
        (await TransactionRepository(
          target,
        ).getTransactionItems(rows.single.id)).single.name,
        'Kopi',
      );
    },
  );

  test('malformed backup is rejected before changing existing data', () async {
    final file = File('${temp.path}/invalid.json');
    await file.writeAsString(
      jsonEncode({
        'format': 'noma-backup',
        'version': 1,
        'categories': [],
        'transactions': [
          {'externalId': 'bad', 'amount': -1},
        ],
      }),
    );
    await expectLater(
      DataBackupService(target).prepareRestore(file),
      throwsA(anything),
    );
    expect(
      await TransactionRepository(
        target,
      ).getTransactionsPage(limit: 50, offset: 0),
      isEmpty,
    );
  });

  test('undo restores the same transaction and receipt items', () async {
    final repo = TransactionRepository(source);
    final now = DateTime(2026, 8, 25).millisecondsSinceEpoch;
    final id = await repo.addTransaction(
      TransactionsCompanion.insert(
        type: 'expense',
        amount: 10000,
        category: 'Makanan',
        source: 'manual',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      ),
      items: [(name: 'Roti', quantity: 1, unitPrice: 10000, totalPrice: 10000)],
    );
    final deleted = await repo.deleteForUndo(id);
    expect(deleted, isNotNull);
    expect(await repo.getTransactionsPage(limit: 50, offset: 0), isEmpty);
    await repo.restoreDeleted(deleted!);
    final rows = await repo.getTransactionsPage(limit: 50, offset: 0);
    expect(rows.single.id, id);
    expect(rows.single.externalId, deleted.transaction.externalId);
    expect((await repo.getTransactionItems(id)).single.name, 'Roti');
  });

  test('restore rolls back all inserts when a later row fails', () async {
    final repo = TransactionRepository(source);
    final now = DateTime(2026, 8, 25).millisecondsSinceEpoch;
    for (final category in ['First', 'Fail']) {
      await repo.addTransaction(
        TransactionsCompanion.insert(
          type: 'expense',
          amount: 10000,
          category: category,
          source: 'manual',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    final file = await DataBackupService(
      source,
    ).exportToFile(File('${temp.path}/rollback.json'));
    final backup = DataBackupService(target);
    final preview = await backup.prepareRestore(file);
    await target.customStatement('''
      CREATE TRIGGER reject_fail BEFORE INSERT ON transactions
      WHEN NEW.category = 'Fail' BEGIN SELECT RAISE(ABORT, 'test failure'); END;
    ''');
    await expectLater(backup.restore(preview), throwsA(anything));
    expect(
      await TransactionRepository(
        target,
      ).getTransactionsPage(limit: 50, offset: 0),
      isEmpty,
    );
  });

  test('v3 migration preserves rows and backfills unique external IDs', () async {
    final file = File('${temp.path}/old.db');
    final old = sqlite3.sqlite3.open(file.path);
    old.execute('''
      CREATE TABLE transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL, amount REAL NOT NULL, category TEXT NOT NULL,
        description TEXT, source TEXT NOT NULL, payment_method TEXT,
        receipt_image_path TEXT, transaction_date INTEGER NOT NULL,
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
      );
    ''');
    old.execute(
      "INSERT INTO transactions (type, amount, category, source, transaction_date, created_at, updated_at) VALUES ('expense', 100, 'A', 'manual', 1, 1, 1), ('income', 200, 'B', 'manual', 2, 2, 2);",
    );
    old.execute('PRAGMA user_version = 3');
    old.dispose();
    final migrated = AppDatabase.forTesting(NativeDatabase(file));
    try {
      final rows = await migrated.select(migrated.transactions).get();
      expect(rows, hasLength(2));
      expect(rows.map((tx) => tx.externalId).toSet(), hasLength(2));
      expect(rows.every((tx) => tx.externalId != null), isTrue);
      expect(rows.map((tx) => tx.amount), containsAll([100, 200]));
    } finally {
      await migrated.close();
    }
  });
}
