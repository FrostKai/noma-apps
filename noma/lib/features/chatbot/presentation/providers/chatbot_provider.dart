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

final chatMessagesStreamProvider = StreamProvider.autoDispose<List<ChatMessage>>((ref) {
  final repo = ref.watch(chatbotRepositoryProvider);
  return repo.watchChatMessages();
});

final chatbotControllerProvider = StateNotifierProvider<ChatbotController, AsyncValue<void>>((ref) {
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
        return {
          'role': msg.role,
          'content': msg.content,
        };
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
    final allTxs = await (db.select(db.transactions)
          ..orderBy([
            (t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ]))
        .get();

    double totalIncome = 0;
    double totalExpense = 0;
    double thisMonthIncome = 0;
    double thisMonthExpense = 0;

    final now = DateTime.now();
    final Map<String, double> categoryExpenses = {};

    for (final tx in allTxs) {
      final txDate = DateTime.fromMillisecondsSinceEpoch(tx.transactionDate);
      final isThisMonth = txDate.year == now.year && txDate.month == now.month;

      if (tx.type == 'income') {
        totalIncome += tx.amount;
        if (isThisMonth) thisMonthIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
        if (isThisMonth) thisMonthExpense += tx.amount;
        categoryExpenses[tx.category] = (categoryExpenses[tx.category] ?? 0) + tx.amount;
      }
    }

    final balance = totalIncome - totalExpense;

    final sortedCategories = categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final catBuffer = StringBuffer();
    if (sortedCategories.isEmpty) {
      catBuffer.writeln('- Belum ada pengeluaran per kategori.');
    } else {
      for (final entry in sortedCategories.take(5)) {
        catBuffer.writeln('- ${entry.key}: ${CurrencyFormatter.formatRupiah(entry.value)}');
      }
    }

    final recentBuffer = StringBuffer();
    if (allTxs.isEmpty) {
      recentBuffer.writeln('- Belum ada catatan transaksi.');
    } else {
      for (final tx in allTxs.take(5)) {
        final d = DateTime.fromMillisecondsSinceEpoch(tx.transactionDate);
        final dateStr = '${d.day}/${d.month}/${d.year}';
        final typeLabel = tx.type == 'income' ? 'Pemasukan' : 'Pengeluaran';
        final desc = tx.description != null && tx.description!.isNotEmpty ? ' (${tx.description})' : '';
        recentBuffer.writeln('- $dateStr | $typeLabel | ${tx.category} | ${CurrencyFormatter.formatRupiah(tx.amount)}$desc');
      }
    }

    final monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
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

  Future<void> clearHistory() async {
    await _repo.clearHistory();
  }
}

