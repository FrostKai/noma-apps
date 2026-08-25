import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../data/transaction_repository.dart';

final transactionRepositoryProvider = Provider<ITransactionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionRepository(db);
});

typedef TransactionPageArgs = ({
  String type,
  String searchQuery,
  int? startMs,
  int? endMs,
  int limit,
  int offset,
});

final transactionsPageStreamProvider = StreamProvider.autoDispose
    .family<List<Transaction>, TransactionPageArgs>((ref, args) {
      final repo = ref.watch(transactionRepositoryProvider);
      return repo.watchTransactionsPage(
        type: args.type,
        searchQuery: args.searchQuery,
        startMs: args.startMs,
        endMs: args.endMs,
        limit: args.limit,
        offset: args.offset,
      );
    });

final latestTransactionsStreamProvider = StreamProvider.autoDispose
    .family<List<Transaction>, int>((ref, limit) {
      final repo = ref.watch(transactionRepositoryProvider);
      return repo.watchLatestTransactions(limit: limit);
    });

typedef TransactionHistoryArgs = ({
  String type,
  String searchQuery,
  int startMs,
  int endMs,
  int pageSize,
});

class TransactionHistoryState {
  final List<Transaction> transactions;
  final int nextOffset;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  const TransactionHistoryState({
    this.transactions = const [],
    this.nextOffset = 0,
    this.isInitialLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  TransactionHistoryState copyWith({
    List<Transaction>? transactions,
    int? nextOffset,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return TransactionHistoryState(
      transactions: transactions ?? this.transactions,
      nextOffset: nextOffset ?? this.nextOffset,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final transactionHistoryControllerProvider = StateNotifierProvider.autoDispose
    .family<
      TransactionHistoryController,
      TransactionHistoryState,
      TransactionHistoryArgs
    >((ref, args) {
      final repo = ref.watch(transactionRepositoryProvider);
      return TransactionHistoryController(repo, args);
    });

class TransactionHistoryController
    extends StateNotifier<TransactionHistoryState> {
  final ITransactionRepository _repo;
  final TransactionHistoryArgs _args;

  TransactionHistoryController(this._repo, this._args)
    : super(const TransactionHistoryState()) {
    Future.microtask(loadInitial);
  }

  Future<void> loadInitial() async {
    state = const TransactionHistoryState(isInitialLoading: true);
    try {
      final page = await _loadPage(offset: 0);
      state = TransactionHistoryState(
        transactions: page,
        nextOffset: page.length,
        isInitialLoading: false,
        hasMore: page.length == _args.pageSize,
      );
    } catch (e) {
      state = TransactionHistoryState(
        isInitialLoading: false,
        hasMore: false,
        error: e,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isInitialLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _loadPage(offset: state.nextOffset);
      state = state.copyWith(
        transactions: [...state.transactions, ...page],
        nextOffset: state.nextOffset + page.length,
        isLoadingMore: false,
        hasMore: page.length == _args.pageSize,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  void removeTransaction(int id) {
    final updated = state.transactions.where((tx) => tx.id != id).toList();
    state = state.copyWith(
      transactions: updated,
      nextOffset: updated.length,
      clearError: true,
    );
  }

  Future<List<Transaction>> _loadPage({required int offset}) {
    return _repo.getTransactionsPage(
      type: _args.type,
      searchQuery: _args.searchQuery,
      startMs: _args.startMs,
      endMs: _args.endMs,
      limit: _args.pageSize,
      offset: offset,
    );
  }
}

typedef SummaryRangeArgs = ({int? startMs, int? endMs});

final transactionSummaryStreamProvider = StreamProvider.autoDispose
    .family<TransactionSummary, SummaryRangeArgs>((ref, args) {
      final repo = ref.watch(transactionRepositoryProvider);
      return repo.watchSummary(startMs: args.startMs, endMs: args.endMs);
    });

final reportDataStreamProvider = StreamProvider.autoDispose
    .family<ReportData, SummaryRangeArgs>((ref, args) {
      final repo = ref.watch(transactionRepositoryProvider);
      return repo.watchReportData(startMs: args.startMs, endMs: args.endMs);
    });

typedef DailyTotalsArgs = ({int startMs, int endMs});

final dailyTotalsStreamProvider = StreamProvider.autoDispose
    .family<List<DailyTransactionTotal>, DailyTotalsArgs>((ref, args) {
      final repo = ref.watch(transactionRepositoryProvider);
      return repo.watchDailyTotals(startMs: args.startMs, endMs: args.endMs);
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

final transactionControllerProvider =
    StateNotifierProvider<TransactionController, AsyncValue<void>>((ref) {
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
    List<TransactionItemInput> items = const [],
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
      await _repo.addTransaction(companion, items: items);
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
