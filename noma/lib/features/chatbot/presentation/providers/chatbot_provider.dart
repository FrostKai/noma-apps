import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/providers/ai_service_provider.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../../transaction/presentation/providers/transaction_provider.dart';
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
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // 1. Save user message to DB
      await _repo.addMessage(
        ChatMessagesCompanion.insert(
          role: 'user',
          content: text.trim(),
          createdAt: now,
        ),
      );

      // 2. Aggregate Financial Context from Riverpod providers
      final balance = _ref.read(totalBalanceStreamProvider).valueOrNull ?? 0.0;
      final income = _ref.read(totalIncomeStreamProvider).valueOrNull ?? 0.0;
      final expense = _ref.read(totalExpenseStreamProvider).valueOrNull ?? 0.0;

      final financialContext = '''
Total Saldo: Rp ${balance.toInt()}
Total Pemasukan: Rp ${income.toInt()}
Total Pengeluaran: Rp ${expense.toInt()}
''';

      // 3. Get history for multi-turn directly from repository
      final recentMessages = await _repo.getRecentMessages(limit: 6);
      final history = recentMessages.reversed.map((m) {
        return {
          'role': m.role,
          'content': m.content,
        };
      }).toList();

      // 4. Call Gemini AI API
      final aiService = _ref.read(geminiApiServiceProvider);
      final reply = await aiService.sendChatMessage(
        userMessage: text.trim(),
        financialContext: financialContext,
        conversationHistory: history,
      );

      // 5. Save AI response to DB
      await _repo.addMessage(
        ChatMessagesCompanion.insert(
          role: 'assistant',
          content: reply,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> clearHistory() async {
    await _repo.clearHistory();
  }
}
