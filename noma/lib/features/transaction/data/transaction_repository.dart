import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

typedef TransactionItemInput = ({
  String name,
  double quantity,
  double? unitPrice,
  double totalPrice,
});

const int defaultTransactionPageSize = 50;

class TransactionSummary {
  final int count;
  final double income;
  final double expense;
  final String? topExpenseCategory;
  final double topExpenseCategoryAmount;

  const TransactionSummary({
    required this.count,
    required this.income,
    required this.expense,
    this.topExpenseCategory,
    this.topExpenseCategoryAmount = 0,
  });

  double get balance => income - expense;
}

class CategoryTotal {
  final String name;
  final double total;

  const CategoryTotal({required this.name, required this.total});
}

class DailyTransactionTotal {
  final String dayKey;
  final double income;
  final double expense;

  const DailyTransactionTotal({
    required this.dayKey,
    required this.income,
    required this.expense,
  });
}

class ReceiptItemTotal {
  final String name;
  final double quantity;
  final double total;

  const ReceiptItemTotal({
    required this.name,
    required this.quantity,
    required this.total,
  });
}

class ReportData {
  final TransactionSummary summary;
  final List<CategoryTotal> expenseCategories;
  final List<ReceiptItemTotal> topReceiptItems;
  final List<CategoryTotal> topMerchants;

  const ReportData({
    required this.summary,
    required this.expenseCategories,
    required this.topReceiptItems,
    required this.topMerchants,
  });
}

abstract class ITransactionRepository {
  Stream<List<Transaction>> watchTransactionsPage({
    String type,
    String searchQuery,
    int? startMs,
    int? endMs,
    int limit,
    int offset,
  });
  Future<List<Transaction>> getTransactionsPage({
    String type,
    String searchQuery,
    int? startMs,
    int? endMs,
    int limit,
    int offset,
  });
  Stream<List<Transaction>> watchLatestTransactions({int limit});
  Future<List<Transaction>> getLatestTransactions({int limit});
  Stream<TransactionSummary> watchSummary({int? startMs, int? endMs});
  Stream<ReportData> watchReportData({int? startMs, int? endMs});
  Stream<List<DailyTransactionTotal>> watchDailyTotals({
    required int startMs,
    required int endMs,
  });
  Stream<double> watchTotalBalance();
  Stream<double> watchTotalIncome();
  Stream<double> watchTotalExpense();
  Future<int> addTransaction(
    TransactionsCompanion transaction, {
    List<TransactionItemInput> items,
  });
  Future<List<TransactionItem>> getTransactionItems(int transactionId);
  Future<void> replaceTransactionItems(
    int transactionId,
    List<TransactionItemInput> items,
  );
  Future<bool> updateTransaction(
    Transaction transaction, {
    List<TransactionItemInput>? items,
  });
  Future<int> deleteTransaction(int id);
}

class TransactionRepository implements ITransactionRepository {
  final AppDatabase _db;

  TransactionRepository(this._db);

  @override
  Stream<List<Transaction>> watchTransactionsPage({
    String type = 'all',
    String searchQuery = '',
    int? startMs,
    int? endMs,
    int limit = defaultTransactionPageSize,
    int offset = 0,
  }) {
    final query = _db.select(_db.transactions)
      ..where(
        (_) => _transactionPredicate(
          type: type,
          searchQuery: searchQuery,
          startMs: startMs,
          endMs: endMs,
        ),
      )
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.transactionDate,
          mode: OrderingMode.desc,
        ),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ])
      ..limit(limit, offset: offset);

    return query.watch();
  }

  @override
  Future<List<Transaction>> getTransactionsPage({
    String type = 'all',
    String searchQuery = '',
    int? startMs,
    int? endMs,
    int limit = defaultTransactionPageSize,
    int offset = 0,
  }) {
    final query = _db.select(_db.transactions)
      ..where(
        (_) => _transactionPredicate(
          type: type,
          searchQuery: searchQuery,
          startMs: startMs,
          endMs: endMs,
        ),
      )
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.transactionDate,
          mode: OrderingMode.desc,
        ),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ])
      ..limit(limit, offset: offset);

    return query.get();
  }

  @override
  Stream<List<Transaction>> watchLatestTransactions({int limit = 5}) {
    final query = _db.select(_db.transactions)
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.transactionDate,
          mode: OrderingMode.desc,
        ),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ])
      ..limit(limit);

    return query.watch();
  }

  @override
  Future<List<Transaction>> getLatestTransactions({int limit = 5}) {
    final query = _db.select(_db.transactions)
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.transactionDate,
          mode: OrderingMode.desc,
        ),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ])
      ..limit(limit);

    return query.get();
  }

  @override
  Stream<TransactionSummary> watchSummary({int? startMs, int? endMs}) {
    final countRows = _db.transactions.id.count();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([countRows])
      ..where(_transactionPredicate(startMs: startMs, endMs: endMs));

    return query.watchSingle().asyncMap((_) {
      return _getSummary(startMs: startMs, endMs: endMs);
    });
  }

  @override
  Stream<ReportData> watchReportData({int? startMs, int? endMs}) {
    final countRows = _db.transactions.id.count();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([countRows])
      ..where(_transactionPredicate(startMs: startMs, endMs: endMs));

    return query.watchSingle().asyncMap((_) async {
      final summary = await _getSummary(startMs: startMs, endMs: endMs);
      final categories = await _getExpenseCategoryTotals(
        startMs: startMs,
        endMs: endMs,
      );
      final items = await _getTopReceiptItems(startMs: startMs, endMs: endMs);
      final merchants = await _getTopMerchants(startMs: startMs, endMs: endMs);

      return ReportData(
        summary: summary,
        expenseCategories: categories,
        topReceiptItems: items,
        topMerchants: merchants,
      );
    });
  }

  @override
  Stream<List<DailyTransactionTotal>> watchDailyTotals({
    required int startMs,
    required int endMs,
  }) {
    return _db
        .customSelect(
          '''
          SELECT strftime('%Y-%m-%d', transaction_date / 1000, 'unixepoch', 'localtime') AS day_key,
                 type,
                 SUM(amount) AS total
          FROM transactions
          WHERE transaction_date >= ? AND transaction_date < ?
          GROUP BY day_key, type
          ORDER BY day_key ASC
          ''',
          variables: [Variable.withInt(startMs), Variable.withInt(endMs)],
          readsFrom: {_db.transactions},
        )
        .watch()
        .map((rows) {
          final byDay = <String, ({double income, double expense})>{};
          for (final row in rows) {
            final dayKey = row.data['day_key'] as String? ?? '';
            if (dayKey.isEmpty) continue;
            final current = byDay[dayKey] ?? (income: 0.0, expense: 0.0);
            final total = (row.data['total'] as num?)?.toDouble() ?? 0;
            byDay[dayKey] = row.data['type'] == 'income'
                ? (income: total, expense: current.expense)
                : (income: current.income, expense: total);
          }

          return byDay.entries.map((entry) {
            return DailyTransactionTotal(
              dayKey: entry.key,
              income: entry.value.income,
              expense: entry.value.expense,
            );
          }).toList();
        });
  }

  Future<TransactionSummary> _getSummary({int? startMs, int? endMs}) async {
    final sumAmount = _db.transactions.amount.sum();
    final countRows = _db.transactions.id.count();
    final typeColumn = _db.transactions.type;
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([typeColumn, sumAmount, countRows])
      ..where(_transactionPredicate(startMs: startMs, endMs: endMs))
      ..groupBy([typeColumn]);

    final rows = await query.get();
    var count = 0;
    var income = 0.0;
    var expense = 0.0;

    for (final row in rows) {
      final rowCount = row.read(countRows) ?? 0;
      count += rowCount;

      final amount = row.read(sumAmount) ?? 0.0;
      if (row.read(typeColumn) == 'income') {
        income = amount;
      } else {
        expense = amount;
      }
    }

    final topCategory = await _getTopExpenseCategory(
      startMs: startMs,
      endMs: endMs,
    );

    return TransactionSummary(
      count: count,
      income: income,
      expense: expense,
      topExpenseCategory: topCategory?.key,
      topExpenseCategoryAmount: topCategory?.value ?? 0,
    );
  }

  Future<MapEntry<String, double>?> _getTopExpenseCategory({
    int? startMs,
    int? endMs,
  }) async {
    final sumAmount = _db.transactions.amount.sum();
    final category = _db.transactions.category;
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([category, sumAmount])
      ..where(
        _transactionPredicate(type: 'expense', startMs: startMs, endMs: endMs),
      )
      ..groupBy([category])
      ..orderBy([OrderingTerm.desc(sumAmount)])
      ..limit(1);

    final row = await query.getSingleOrNull();
    final name = row?.read(category);
    if (name == null) return null;

    return MapEntry(name, row?.read(sumAmount) ?? 0);
  }

  Future<List<CategoryTotal>> _getExpenseCategoryTotals({
    int? startMs,
    int? endMs,
    int limit = 8,
  }) async {
    final variables = <Variable>[
      Variable.withString('expense'),
      ..._rangeVariables(startMs: startMs, endMs: endMs),
      Variable.withInt(limit),
    ];
    final rows = await _db
        .customSelect(
          '''
          SELECT category AS name, SUM(amount) AS total
          FROM transactions
          WHERE type = ? ${_rangeWhereSql(startMs: startMs, endMs: endMs)}
          GROUP BY category
          ORDER BY total DESC
          LIMIT ?
          ''',
          variables: variables,
          readsFrom: {_db.transactions},
        )
        .get();

    return rows.map((row) {
      return CategoryTotal(
        name: row.data['name'] as String? ?? '-',
        total: (row.data['total'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  Future<List<ReceiptItemTotal>> _getTopReceiptItems({
    int? startMs,
    int? endMs,
    int limit = 5,
  }) async {
    final variables = <Variable>[
      ..._rangeVariables(startMs: startMs, endMs: endMs),
      Variable.withInt(limit),
    ];
    final rows = await _db
        .customSelect(
          '''
          SELECT ti.name AS name,
                 SUM(ti.quantity) AS quantity,
                 SUM(ti.total_price) AS total
          FROM transaction_items ti
          INNER JOIN transactions t ON t.id = ti.transaction_id
          WHERE ti.name <> '' ${_rangeWhereSql(alias: 't', startMs: startMs, endMs: endMs)}
          GROUP BY ti.name
          ORDER BY total DESC
          LIMIT ?
          ''',
          variables: variables,
          readsFrom: {_db.transactionItems, _db.transactions},
        )
        .get();

    return rows.map((row) {
      return ReceiptItemTotal(
        name: row.data['name'] as String? ?? '-',
        quantity: (row.data['quantity'] as num?)?.toDouble() ?? 0,
        total: (row.data['total'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  Future<List<CategoryTotal>> _getTopMerchants({
    int? startMs,
    int? endMs,
    int limit = 5,
  }) async {
    final variables = <Variable>[
      Variable.withString('expense'),
      Variable.withString('Struk %'),
      ..._rangeVariables(startMs: startMs, endMs: endMs),
      Variable.withInt(limit),
    ];
    final rows = await _db
        .customSelect(
          '''
          SELECT TRIM(SUBSTR(description, 7)) AS name, SUM(amount) AS total
          FROM transactions
          WHERE type = ? AND description LIKE ? ${_rangeWhereSql(startMs: startMs, endMs: endMs)}
          GROUP BY name
          HAVING name <> ''
          ORDER BY total DESC
          LIMIT ?
          ''',
          variables: variables,
          readsFrom: {_db.transactions},
        )
        .get();

    return rows.map((row) {
      return CategoryTotal(
        name: row.data['name'] as String? ?? '-',
        total: (row.data['total'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  String _rangeWhereSql({
    String alias = 'transactions',
    int? startMs,
    int? endMs,
  }) {
    final dateColumn = '$alias.transaction_date';
    final buffer = StringBuffer();
    if (startMs != null) {
      buffer.write(' AND $dateColumn >= ?');
    }
    if (endMs != null) {
      buffer.write(' AND $dateColumn < ?');
    }
    return buffer.toString();
  }

  List<Variable> _rangeVariables({int? startMs, int? endMs}) {
    return [
      if (startMs != null) Variable.withInt(startMs),
      if (endMs != null) Variable.withInt(endMs),
    ];
  }

  Expression<bool> _transactionPredicate({
    String type = 'all',
    String searchQuery = '',
    int? startMs,
    int? endMs,
  }) {
    Expression<bool> predicate = const Constant(true);

    if (type != 'all') {
      predicate = predicate & _db.transactions.type.equals(type);
    }
    if (startMs != null) {
      predicate =
          predicate &
          _db.transactions.transactionDate.isBiggerOrEqualValue(startMs);
    }
    if (endMs != null) {
      predicate =
          predicate &
          _db.transactions.transactionDate.isSmallerThanValue(endMs);
    }

    final query = searchQuery.trim();
    if (query.isNotEmpty) {
      final pattern = '%$query%';
      predicate =
          predicate &
          (_db.transactions.category.like(pattern) |
              _db.transactions.description.like(pattern) |
              _db.transactions.paymentMethod.like(pattern));
    }

    return predicate;
  }

  @override
  Stream<double> watchTotalIncome() {
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.amount.sum()])
      ..where(_db.transactions.type.equals('income'));

    return query.watchSingleOrNull().map((row) {
      if (row == null) return 0.0;
      return row.read(_db.transactions.amount.sum()) ?? 0.0;
    });
  }

  @override
  Stream<double> watchTotalExpense() {
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.amount.sum()])
      ..where(_db.transactions.type.equals('expense'));

    return query.watchSingleOrNull().map((row) {
      if (row == null) return 0.0;
      return row.read(_db.transactions.amount.sum()) ?? 0.0;
    });
  }

  @override
  Stream<double> watchTotalBalance() {
    return watchTotalIncome().asyncMap((income) async {
      final query = _db.selectOnly(_db.transactions)
        ..addColumns([_db.transactions.amount.sum()])
        ..where(_db.transactions.type.equals('expense'));

      final expenseRow = await query.getSingleOrNull();
      final expense = expenseRow?.read(_db.transactions.amount.sum()) ?? 0.0;
      return income - expense;
    });
  }

  @override
  Future<int> addTransaction(
    TransactionsCompanion transaction, {
    List<TransactionItemInput> items = const [],
  }) {
    return _db.transaction(() async {
      final transactionId = await _db
          .into(_db.transactions)
          .insert(transaction);
      if (items.isNotEmpty) {
        await _insertTransactionItems(transactionId, items);
      }
      return transactionId;
    });
  }

  @override
  Future<List<TransactionItem>> getTransactionItems(int transactionId) {
    return (_db.select(_db.transactionItems)
          ..where((t) => t.transactionId.equals(transactionId))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  @override
  Future<void> replaceTransactionItems(
    int transactionId,
    List<TransactionItemInput> items,
  ) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.transactionItems,
      )..where((t) => t.transactionId.equals(transactionId))).go();
      if (items.isNotEmpty) {
        await _insertTransactionItems(transactionId, items);
      }
    });
  }

  Future<void> _insertTransactionItems(
    int transactionId,
    List<TransactionItemInput> items,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final companions = items.map((item) {
      final name = item.name.trim();
      if (name.isEmpty || item.quantity <= 0 || item.totalPrice <= 0) {
        throw ArgumentError('Item struk tidak valid.');
      }
      return TransactionItemsCompanion.insert(
        transactionId: transactionId,
        name: name,
        quantity: Value(item.quantity),
        unitPrice: Value(item.unitPrice),
        totalPrice: item.totalPrice,
        createdAt: now,
      );
    }).toList();

    await _db.batch((batch) {
      batch.insertAll(_db.transactionItems, companions);
    });
  }

  @override
  Future<bool> updateTransaction(
    Transaction transaction, {
    List<TransactionItemInput>? items,
  }) {
    return _db.transaction(() async {
      final success = await _db.update(_db.transactions).replace(transaction);
      if (items != null) {
        await (_db.delete(
          _db.transactionItems,
        )..where((t) => t.transactionId.equals(transaction.id))).go();
        if (items.isNotEmpty) {
          await _insertTransactionItems(transaction.id, items);
        }
      }
      return success;
    });
  }

  @override
  Future<int> deleteTransaction(int id) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.transactionItems,
      )..where((t) => t.transactionId.equals(id))).go();
      return (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
    });
  }
}
