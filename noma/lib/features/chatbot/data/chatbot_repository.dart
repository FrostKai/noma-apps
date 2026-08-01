import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

abstract class IChatbotRepository {
  Stream<List<ChatMessage>> watchChatMessages();
  Future<List<ChatMessage>> getRecentMessages({int limit = 10});
  Future<int> addMessage(ChatMessagesCompanion message);
  Future<int> clearHistory();
}

class ChatbotRepository implements IChatbotRepository {
  final AppDatabase _db;

  ChatbotRepository(this._db);

  @override
  Stream<List<ChatMessage>> watchChatMessages() {
    return (_db.select(_db.chatMessages)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  @override
  Future<List<ChatMessage>> getRecentMessages({int limit = 10}) {
    return (_db.select(_db.chatMessages)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  @override
  Future<int> addMessage(ChatMessagesCompanion message) {
    return _db.into(_db.chatMessages).insert(message);
  }

  @override
  Future<int> clearHistory() {
    return _db.delete(_db.chatMessages).go();
  }
}
