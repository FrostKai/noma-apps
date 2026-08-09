import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

abstract class IChatbotRepository {
  Stream<List<ChatMessage>> watchChatMessages();
  Future<List<ChatMessage>> getRecentMessages({int limit = 10});
  Future<int> addMessage(ChatMessagesCompanion message);
  Future<int> clearHistory();
  Future<int> clearMessagesOlderThan24Hours();
}

class ChatbotRepository implements IChatbotRepository {
  final AppDatabase _db;

  ChatbotRepository(this._db);

  int get _cutoff24HoursMs =>
      DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch;

  @override
  Stream<List<ChatMessage>> watchChatMessages() {
    // Auto purge messages older than 24 hours
    _purgeOldMessages();

    return (_db.select(_db.chatMessages)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(_cutoff24HoursMs))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  @override
  Future<List<ChatMessage>> getRecentMessages({int limit = 10}) async {
    await _purgeOldMessages();

    return (_db.select(_db.chatMessages)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(_cutoff24HoursMs))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  @override
  Future<int> addMessage(ChatMessagesCompanion message) async {
    await _purgeOldMessages();
    return _db.into(_db.chatMessages).insert(message);
  }

  @override
  Future<int> clearHistory() {
    return _db.delete(_db.chatMessages).go();
  }

  @override
  Future<int> clearMessagesOlderThan24Hours() {
    return _purgeOldMessages();
  }

  Future<int> _purgeOldMessages() {
    final cutoff = _cutoff24HoursMs;
    return (_db.delete(_db.chatMessages)
          ..where((t) => t.createdAt.isSmallerThanValue(cutoff)))
        .go();
  }
}

