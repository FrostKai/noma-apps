import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../data/transaction_repository.dart';

final transactionRepositoryProvider = Provider<ITransactionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionRepository(db);
});

final allTransactionsStreamProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchAllTransactions();
});

final recentTransactionsStreamProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchRecentTransactions(limit: 10);
});

final totalIncomeStreamProvider = StreamProvider.autoDispose<double>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchTotalIncome();
});

final totalExpenseStreamProvider = StreamProvider.autoDispose<double>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchTotalExpense();
});

final totalBalanceStreamProvider = StreamProvider.autoDispose<double>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchTotalBalance();
});

final transactionControllerProvider = StateNotifierProvider<TransactionController, AsyncValue<void>>((ref) {
  return TransactionController(ref.watch(transactionRepositoryProvider));
});

class TransactionController extends StateNotifier<AsyncValue<void>> {
  final ITransactionRepository _repo;

  TransactionController(this._repo) : super(const AsyncData(null));

  Future<bool> addTransaction({
    required String type,
    required double amount,
    required String category,
    String? description,
    String source = 'manual',
    String? paymentMethod,
    String? receiptImagePath,
    required DateTime transactionDate,
  }) async {
    state = const AsyncLoading();
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final companion = TransactionsCompanion.insert(
        type: type,
        amount: amount,
        category: category,
        description: Value(description),
        source: source,
        paymentMethod: Value(paymentMethod),
        receiptImagePath: Value(receiptImagePath),
        transactionDate: transactionDate.millisecondsSinceEpoch,
        createdAt: now,
        updatedAt: now,
      );
      await _repo.addTransaction(companion);
      state = const AsyncData(null);
      return true;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<bool> updateTransaction(Transaction transaction) async {
    state = const AsyncLoading();
    try {
      final updated = transaction.copyWith(
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _repo.updateTransaction(updated);
      state = const AsyncData(null);
      return true;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<bool> deleteTransaction(int id) async {
    state = const AsyncLoading();
    try {
      await _repo.deleteTransaction(id);
      state = const AsyncData(null);
      return true;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return false;
    }
  }
}
