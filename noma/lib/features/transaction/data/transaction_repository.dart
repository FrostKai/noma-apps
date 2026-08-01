import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

abstract class ITransactionRepository {
  Stream<List<Transaction>> watchAllTransactions();
  Stream<List<Transaction>> watchRecentTransactions({int limit = 10});
  Stream<double> watchTotalBalance();
  Stream<double> watchTotalIncome();
  Stream<double> watchTotalExpense();
  Future<int> addTransaction(TransactionsCompanion transaction);
  Future<bool> updateTransaction(Transaction transaction);
  Future<int> deleteTransaction(int id);
}

class TransactionRepository implements ITransactionRepository {
  final AppDatabase _db;

  TransactionRepository(this._db);

  @override
  Stream<List<Transaction>> watchAllTransactions() {
    return (_db.select(_db.transactions)
          ..orderBy([
            (t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  @override
  Stream<List<Transaction>> watchRecentTransactions({int limit = 10}) {
    return (_db.select(_db.transactions)
          ..orderBy([
            (t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
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
  Future<int> addTransaction(TransactionsCompanion transaction) {
    return _db.into(_db.transactions).insert(transaction);
  }

  @override
  Future<bool> updateTransaction(Transaction transaction) {
    return _db.update(_db.transactions).replace(transaction);
  }

  @override
  Future<int> deleteTransaction(int id) {
    return (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }
}
