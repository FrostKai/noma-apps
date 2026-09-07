import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/providers/ai_service_provider.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../data/chatbot_repository.dart';

final chatbotRepositoryProvider = Provider<IChatbotRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ChatbotRepository(db);
});

final chatMessagesStreamProvider =
    StreamProvider.autoDispose<List<ChatMessage>>((ref) {
      final repo = ref.watch(chatbotRepositoryProvider);
      return repo.watchChatMessages();
    });

final chatbotControllerProvider =
    StateNotifierProvider<ChatbotController, AsyncValue<void>>((ref) {
      return ChatbotController(
        ref.watch(chatbotRepositoryProvider),
        ref.watch(geminiApiServiceProvider),
        ref,
      );
    });

class ChatbotController extends StateNotifier<AsyncValue<void>> {
  final IChatbotRepository _repo;
  final Ref _ref;

  ChatbotController(this._repo, _, this._ref) : super(const AsyncData(null));

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    state = const AsyncLoading();

    try {
      final historyBeforeInsert = await _repo.getRecentMessages(limit: 8);

      await _repo.addMessage(
        ChatMessagesCompanion.insert(
          role: 'user',
          content: text.trim(),
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final financialContext = await _buildRichFinancialContext();

      final historyPayload = historyBeforeInsert.map((msg) {
        return {'role': msg.role, 'content': msg.content};
      }).toList();

      final aiService = _ref.read(geminiApiServiceProvider);
      final aiReply = await aiService.sendChatMessage(
        userMessage: text.trim(),
        financialContext: financialContext,
        conversationHistory: historyPayload,
      );

      await _repo.addMessage(
        ChatMessagesCompanion.insert(
          role: 'assistant',
          content: aiReply,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<String> _buildRichFinancialContext() async {
    final db = _ref.read(databaseProvider);

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month).millisecondsSinceEpoch;
    final nextMonthStart = DateTime(
      now.year,
      now.month + 1,
    ).millisecondsSinceEpoch;
    final results = await Future.wait([
      _sumTransactions(db, type: 'income'),
      _sumTransactions(db, type: 'expense'),
      _sumTransactions(
        db,
        type: 'income',
        startMs: monthStart,
        endMs: nextMonthStart,
      ),
      _sumTransactions(
        db,
        type: 'expense',
        startMs: monthStart,
        endMs: nextMonthStart,
      ),
      _topExpenseCategories(db, limit: 5),
      _recentTransactions(db, limit: 5),
    ]);

    final totalIncome = results[0] as double;
    final totalExpense = results[1] as double;
    final thisMonthIncome = results[2] as double;
    final thisMonthExpense = results[3] as double;
    final sortedCategories = results[4] as List<MapEntry<String, double>>;
    final recentTransactions = results[5] as List<Transaction>;
    final balance = totalIncome - totalExpense;

    final catBuffer = StringBuffer();
    if (sortedCategories.isEmpty) {
      catBuffer.writeln('- Belum ada pengeluaran per kategori.');
    } else {
      for (final entry in sortedCategories) {
        catBuffer.writeln(
          '- ${entry.key}: ${CurrencyFormatter.formatRupiah(entry.value)}',
        );
      }
    }

    final recentBuffer = StringBuffer();
    if (recentTransactions.isEmpty) {
      recentBuffer.writeln('- Belum ada catatan transaksi.');
    } else {
      for (final tx in recentTransactions) {
        final d = DateTime.fromMillisecondsSinceEpoch(tx.transactionDate);
        final dateStr = '${d.day}/${d.month}/${d.year}';
        final typeLabel = tx.type == 'income' ? 'Pemasukan' : 'Pengeluaran';
        final desc = tx.description != null && tx.description!.isNotEmpty
            ? ' (${tx.description})'
            : '';
        recentBuffer.writeln(
          '- $dateStr | $typeLabel | ${tx.category} | ${CurrencyFormatter.formatRupiah(tx.amount)}$desc',
        );
      }
    }

    final monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final currentMonthName = monthNames[now.month - 1];

    return '''
Data Keuangan Pengguna Saat Ini:
- Total Saldo Bersih: ${CurrencyFormatter.formatRupiah(balance)}
- Total Pemasukan Keseluruhan: ${CurrencyFormatter.formatRupiah(totalIncome)}
- Total Pengeluaran Keseluruhan: ${CurrencyFormatter.formatRupiah(totalExpense)}

Periode Bulan Ini ($currentMonthName ${now.year}):
- Pemasukan Bulan Ini: ${CurrencyFormatter.formatRupiah(thisMonthIncome)}
- Pengeluaran Bulan Ini: ${CurrencyFormatter.formatRupiah(thisMonthExpense)}

Pengeluaran Berdasarkan Kategori (Urut Terbesar):
${catBuffer.toString().trim()}

5 Transaksi Terakhir:
${recentBuffer.toString().trim()}
''';
  }

  Future<double> _sumTransactions(
    AppDatabase db, {
    required String type,
    int? startMs,
    int? endMs,
  }) async {
    final sumAmount = db.transactions.amount.sum();
    final query = db.selectOnly(db.transactions)
      ..addColumns([sumAmount])
      ..where(
        _transactionPredicate(db, type: type, startMs: startMs, endMs: endMs),
      );

    final row = await query.getSingleOrNull();
    return row?.read(sumAmount) ?? 0.0;
  }

  Future<List<MapEntry<String, double>>> _topExpenseCategories(
    AppDatabase db, {
    required int limit,
  }) async {
    final sumAmount = db.transactions.amount.sum();
    final category = db.transactions.category;
    final query = db.selectOnly(db.transactions)
      ..addColumns([category, sumAmount])
      ..where(_transactionPredicate(db, type: 'expense'))
      ..groupBy([category])
      ..orderBy([OrderingTerm.desc(sumAmount)])
      ..limit(limit);

    final rows = await query.get();
    return rows
        .map(
          (row) =>
              MapEntry(row.read(category) ?? '-', row.read(sumAmount) ?? 0.0),
        )
        .toList();
  }

  Future<List<Transaction>> _recentTransactions(
    AppDatabase db, {
    required int limit,
  }) {
    return (db.select(db.transactions)
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.transactionDate,
              mode: OrderingMode.desc,
            ),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
  }

  Expression<bool> _transactionPredicate(
    AppDatabase db, {
    required String type,
    int? startMs,
    int? endMs,
  }) {
    Expression<bool> predicate = db.transactions.type.equals(type);
    if (startMs != null) {
      predicate =
          predicate &
          db.transactions.transactionDate.isBiggerOrEqualValue(startMs);
    }
    if (endMs != null) {
      predicate =
          predicate & db.transactions.transactionDate.isSmallerThanValue(endMs);
    }
    return predicate;
  }

  Future<void> clearHistory() async {
    await _repo.clearHistory();
  }
}
