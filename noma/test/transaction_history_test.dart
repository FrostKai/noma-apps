import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noma/core/database/app_database.dart';
import 'package:noma/features/transaction/data/transaction_repository.dart';
import 'package:noma/features/transaction/presentation/providers/transaction_provider.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('current month query returns only current month rows', () async {
    await _insertTx(db, date: DateTime(2026, 8, 25), category: 'Makanan');
    await _insertTx(db, date: DateTime(2026, 7, 25), category: 'Transportasi');

    final rows = await repo.getTransactionsPage(
      startMs: DateTime(2026, 8).millisecondsSinceEpoch,
      endMs: DateTime(2026, 9).millisecondsSinceEpoch,
      limit: 50,
      offset: 0,
    );

    expect(rows, hasLength(1));
    expect(rows.single.category, 'Makanan');
  });

  test('previous and empty month queries are isolated', () async {
    await _insertTx(db, date: DateTime(2026, 7, 20), category: 'Transportasi');

    final previousMonth = await repo.getTransactionsPage(
      startMs: DateTime(2026, 7).millisecondsSinceEpoch,
      endMs: DateTime(2026, 8).millisecondsSinceEpoch,
      limit: 50,
      offset: 0,
    );
    final emptyMonth = await repo.getTransactionsPage(
      startMs: DateTime(2026, 6).millisecondsSinceEpoch,
      endMs: DateTime(2026, 7).millisecondsSinceEpoch,
      limit: 50,
      offset: 0,
    );

    expect(previousMonth, hasLength(1));
    expect(emptyMonth, isEmpty);
  });

  test(
    'type, search, month plus type, and month plus search filters combine',
    () async {
      await _insertTx(
        db,
        type: 'expense',
        date: DateTime(2026, 8, 25),
        category: 'Makanan',
        description: 'makan siang',
      );
      await _insertTx(
        db,
        type: 'income',
        date: DateTime(2026, 8, 24),
        category: 'Gaji',
        description: 'gaji bulanan',
      );
      await _insertTx(
        db,
        type: 'expense',
        date: DateTime(2026, 7, 24),
        category: 'Makanan',
        description: 'makan malam',
      );

      final augustStart = DateTime(2026, 8).millisecondsSinceEpoch;
      final septemberStart = DateTime(2026, 9).millisecondsSinceEpoch;

      final expenseRows = await repo.getTransactionsPage(
        type: 'expense',
        startMs: augustStart,
        endMs: septemberStart,
        limit: 50,
        offset: 0,
      );
      final searchRows = await repo.getTransactionsPage(
        searchQuery: 'gaji',
        startMs: augustStart,
        endMs: septemberStart,
        limit: 50,
        offset: 0,
      );
      final monthTypeSearchRows = await repo.getTransactionsPage(
        type: 'expense',
        searchQuery: 'makan',
        startMs: augustStart,
        endMs: septemberStart,
        limit: 50,
        offset: 0,
      );

      expect(expenseRows.map((tx) => tx.type), ['expense']);
      expect(searchRows.single.category, 'Gaji');
      expect(monthTypeSearchRows, hasLength(1));
      expect(
        monthTypeSearchRows.single.transactionDate,
        greaterThanOrEqualTo(augustStart),
      );
    },
  );

  test('pagination uses offset pages without increasing limit', () async {
    for (var i = 0; i < 120; i++) {
      await _insertTx(
        db,
        date: DateTime(2026, 8, 25).subtract(Duration(minutes: i)),
        category: 'Tx $i',
      );
    }

    final firstPage = await repo.getTransactionsPage(
      startMs: DateTime(2026, 8).millisecondsSinceEpoch,
      endMs: DateTime(2026, 9).millisecondsSinceEpoch,
      limit: 50,
      offset: 0,
    );
    final secondPage = await repo.getTransactionsPage(
      startMs: DateTime(2026, 8).millisecondsSinceEpoch,
      endMs: DateTime(2026, 9).millisecondsSinceEpoch,
      limit: 50,
      offset: 50,
    );
    final thirdPage = await repo.getTransactionsPage(
      startMs: DateTime(2026, 8).millisecondsSinceEpoch,
      endMs: DateTime(2026, 9).millisecondsSinceEpoch,
      limit: 50,
      offset: 100,
    );

    expect(firstPage, hasLength(50));
    expect(secondPage, hasLength(50));
    expect(thirdPage, hasLength(20));
    expect(
      firstPage
          .map((tx) => tx.id)
          .toSet()
          .intersection(secondPage.map((tx) => tx.id).toSet()),
      isEmpty,
    );
  });

  test('changing month starts from a fresh first page', () async {
    for (var i = 0; i < 60; i++) {
      await _insertTx(
        db,
        date: DateTime(2026, 8, 25).subtract(Duration(minutes: i)),
        category: 'Agustus',
      );
    }
    await _insertTx(db, date: DateTime(2026, 7, 25), category: 'Juli');

    final augustPageTwo = await repo.getTransactionsPage(
      startMs: DateTime(2026, 8).millisecondsSinceEpoch,
      endMs: DateTime(2026, 9).millisecondsSinceEpoch,
      limit: 50,
      offset: 50,
    );
    final julyFirstPage = await repo.getTransactionsPage(
      startMs: DateTime(2026, 7).millisecondsSinceEpoch,
      endMs: DateTime(2026, 8).millisecondsSinceEpoch,
      limit: 50,
      offset: 0,
    );

    expect(augustPageTwo, hasLength(10));
    expect(julyFirstPage, hasLength(1));
    expect(julyFirstPage.single.category, 'Juli');
  });

  test(
    'transaction addition and deletion update persisted history data',
    () async {
      final controller = TransactionController(repo);
      final added = await controller.addTransaction(
        type: 'expense',
        amount: 25000,
        category: 'Makanan',
        description: 'makan',
        source: 'manual',
        paymentMethod: 'Tunai',
        transactionDate: DateTime(2026, 8, 25),
      );
      expect(added, isTrue);

      final rows = await repo.getTransactionsPage(
        startMs: DateTime(2026, 8).millisecondsSinceEpoch,
        endMs: DateTime(2026, 9).millisecondsSinceEpoch,
        limit: 50,
        offset: 0,
      );
      expect(rows, hasLength(1));

      final deleted = await controller.deleteTransaction(rows.single.id);
      expect(deleted, isTrue);
      final afterDelete = await repo.getTransactionsPage(
        startMs: DateTime(2026, 8).millisecondsSinceEpoch,
        endMs: DateTime(2026, 9).millisecondsSinceEpoch,
        limit: 50,
        offset: 0,
      );
      expect(afterDelete, isEmpty);
    },
  );

  test('large dataset history page stays bounded', () async {
    await _insertManyTx(db, count: 10000);

    final rows = await repo.getTransactionsPage(
      startMs: DateTime(2026, 8).millisecondsSinceEpoch,
      endMs: DateTime(2026, 9).millisecondsSinceEpoch,
      limit: 50,
      offset: 0,
    );

    expect(rows, hasLength(50));
  });

  test('latest transactions are limited and sorted by date then id', () async {
    final older = await _insertTx(
      db,
      date: DateTime(2026, 8, 23),
      category: 'Older',
    );
    final firstSameDate = await _insertTx(
      db,
      date: DateTime(2026, 8, 25),
      category: 'Same Date First',
    );
    final secondSameDate = await _insertTx(
      db,
      date: DateTime(2026, 8, 25),
      category: 'Same Date Second',
    );
    for (var i = 0; i < 10; i++) {
      await _insertTx(
        db,
        date: DateTime(2026, 8, 24).subtract(Duration(minutes: i)),
        category: 'Middle $i',
      );
    }

    final rows = await repo.getLatestTransactions(limit: 5);

    expect(rows, hasLength(5));
    expect(rows[0].id, secondSameDate);
    expect(rows[1].id, firstSameDate);
    expect(rows.map((tx) => tx.id), isNot(contains(older)));
  });

  test('latest transactions query stays bounded on a large dataset', () async {
    await _insertManyTx(db, count: 10000);

    final rows = await repo.getLatestTransactions(limit: 5);

    expect(rows, hasLength(5));
  });

  test('report summary aggregates the selected period only', () async {
    await _insertTx(
      db,
      type: 'income',
      date: DateTime(2026, 8, 25),
      category: 'Gaji',
    );
    await _insertTx(
      db,
      type: 'expense',
      date: DateTime(2026, 8, 24),
      category: 'Makanan',
    );
    await _insertTx(
      db,
      type: 'expense',
      date: DateTime(2026, 7, 24),
      category: 'Transportasi',
    );

    final report = await repo
        .watchReportData(
          startMs: DateTime(2026, 8).millisecondsSinceEpoch,
          endMs: DateTime(2026, 9).millisecondsSinceEpoch,
        )
        .first
        .timeout(const Duration(seconds: 2));

    expect(report.summary.count, 2);
    expect(report.summary.income, 5000000);
    expect(report.summary.expense, 25000);
    expect(report.summary.balance, 4975000);
  });
}

Future<int> _insertTx(
  AppDatabase db, {
  String type = 'expense',
  required DateTime date,
  required String category,
  String? description,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          type: type,
          amount: type == 'income' ? 5000000 : 25000,
          category: category,
          description: Value(description),
          source: 'manual',
          paymentMethod: const Value('Tunai'),
          transactionDate: date.millisecondsSinceEpoch,
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _insertManyTx(AppDatabase db, {required int count}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.batch((batch) {
    batch.insertAll(
      db.transactions,
      List.generate(count, (i) {
        final type = i.isEven ? 'expense' : 'income';
        final date = DateTime(2026, 8, 25).subtract(Duration(minutes: i));
        return TransactionsCompanion.insert(
          type: type,
          amount: type == 'income' ? 5000000 : 25000,
          category: type == 'income' ? 'Gaji' : 'Makanan',
          source: 'manual',
          paymentMethod: const Value('Tunai'),
          transactionDate: date.millisecondsSinceEpoch,
          createdAt: now,
          updatedAt: now,
        );
      }),
    );
  });
}
