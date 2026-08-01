// Fallback stub — this file is never actually imported at runtime.
// Dart's conditional import selects either native.dart or web.dart.

import 'package:drift/drift.dart';

QueryExecutor openConnection() {
  throw UnsupportedError(
    'Cannot create a database connection without dart:ffi or dart:html.',
  );
}
