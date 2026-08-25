import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../tool/seed_dummy.dart' as seed;

void main() {
  late Database db;

  setUp(() {
    db = sqlite3.openInMemory();
  });

  tearDown(() {
    db.dispose();
  });

  test('seed creates deterministic dummy data with marker', () {
    final result = seed.runDummySeedCommand(db, seed.DummySeedCommand.seed);

    expect(result.after.transactions, 500);
    expect(result.after.income, 34);
    expect(result.after.expense, 466);
    expect(result.after.receiptItems, 315);
    expect(
      _count(db, "SELECT COUNT(*) FROM transactions WHERE source = 'dummy'"),
      500,
    );
  });

  test('seed is idempotent when dummy data already exists', () {
    seed.runDummySeedCommand(db, seed.DummySeedCommand.seed);
    final second = seed.runDummySeedCommand(db, seed.DummySeedCommand.seed);

    expect(second.alreadyExisted, isTrue);
    expect(second.after.transactions, 500);
    expect(_count(db, "SELECT COUNT(*) FROM transactions"), 500);
  });

  test('clear removes only dummy data and preserves real transactions', () {
    seed.ensureDummySchema(db);
    _insertRealTransaction(db);
    seed.runDummySeedCommand(db, seed.DummySeedCommand.seed);

    final cleared = seed.runDummySeedCommand(db, seed.DummySeedCommand.clear);

    expect(cleared.realBefore, 1);
    expect(cleared.realAfter, 1);
    expect(cleared.after.transactions, 0);
    expect(
      _count(db, "SELECT COUNT(*) FROM transactions WHERE source <> 'dummy'"),
      1,
    );
  });

  test('reset reseeds dummy data and preserves real transactions', () {
    seed.ensureDummySchema(db);
    _insertRealTransaction(db);
    seed.runDummySeedCommand(db, seed.DummySeedCommand.seed);

    final reset = seed.runDummySeedCommand(db, seed.DummySeedCommand.reset);

    expect(reset.realBefore, 1);
    expect(reset.realAfter, 1);
    expect(reset.after.transactions, 500);
    expect(_count(db, "SELECT COUNT(*) FROM transactions"), 501);
  });
}

int _count(Database db, String sql) => db.select(sql).first.values.first as int;

void _insertRealTransaction(Database db) {
  final now = DateTime(2026, 8, 25).millisecondsSinceEpoch;
  db.execute(
    '''
    INSERT INTO transactions
    (type, amount, category, description, source, payment_method,
     receipt_image_path, transaction_date, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?, ?)
    ''',
    [
      'expense',
      25000,
      'Makanan & Minuman',
      'Real user transaction',
      'manual',
      'Cash',
      now,
      now,
      now,
    ],
  );
}
