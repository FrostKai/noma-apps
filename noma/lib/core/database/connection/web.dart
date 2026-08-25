import 'package:drift/drift.dart';
// ignore: deprecated_member_use
import 'package:drift/web.dart';

/// Creates a database connection for web platforms using sql.js (IndexedDB).
QueryExecutor openConnection() {
  return WebDatabase('noma_app');
}
