import 'package:drift/drift.dart';
import 'package:drift/web.dart';

/// Creates a database connection for web platforms using sql.js (IndexedDB).
QueryExecutor openConnection() {
  return WebDatabase('noma_app');
}
