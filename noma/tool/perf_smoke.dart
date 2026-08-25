// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final sizes = args.isEmpty
      ? const [100, 1000, 10000]
      : args.map(int.parse).toList();

  for (final size in sizes) {
    final db = sqlite3.openInMemory();
    try {
      _setup(db);
      _seed(db, size);
      final monthStart = DateTime(2026, 8).millisecondsSinceEpoch;
      final monthEnd = DateTime(2026, 9).millisecondsSinceEpoch;

      final results = <String, int>{};
      results['latest_transactions'] = _time(() {
        db.select(
          'SELECT * FROM transactions '
          'ORDER BY transaction_date DESC, id DESC LIMIT 5',
        );
      });
      results['legacy_dashboard_page_reference'] = _time(() {
        db.select(
          'SELECT * FROM transactions '
          'ORDER BY transaction_date DESC, id DESC LIMIT 50',
        );
      });
      results['monthly_history_page_1'] = _time(() {
        db.select(
          'SELECT * FROM transactions '
          'WHERE transaction_date >= ? AND transaction_date < ? '
          'ORDER BY transaction_date DESC, id DESC LIMIT 50 OFFSET 0',
          [monthStart, monthEnd],
        );
      });
      results['monthly_history_page_2'] = _time(() {
        db.select(
          'SELECT * FROM transactions '
          'WHERE transaction_date >= ? AND transaction_date < ? '
          'ORDER BY transaction_date DESC, id DESC LIMIT 50 OFFSET 50',
          [monthStart, monthEnd],
        );
      });
      results['monthly_history_type_search'] = _time(() {
        db.select(
          'SELECT * FROM transactions '
          'WHERE type = ? AND transaction_date >= ? AND transaction_date < ? '
          'AND (category LIKE ? OR description LIKE ? OR payment_method LIKE ?) '
          'ORDER BY transaction_date DESC, id DESC LIMIT 50 OFFSET 0',
          ['expense', monthStart, monthEnd, '%makan%', '%makan%', '%makan%'],
        );
      });
      results['monthly_summary'] = _time(() {
        db.select(
          'SELECT type, COUNT(id), SUM(amount) FROM transactions '
          'WHERE transaction_date >= ? AND transaction_date < ? GROUP BY type',
          [monthStart, monthEnd],
        );
      });
      results['report_categories'] = _time(() {
        db.select(
          'SELECT category, SUM(amount) AS total FROM transactions '
          'WHERE type = ? AND transaction_date >= ? AND transaction_date < ? '
          'GROUP BY category ORDER BY total DESC LIMIT 8',
          ['expense', monthStart, monthEnd],
        );
      });
      results['daily_totals'] = _time(() {
        db.select(
          "SELECT strftime('%Y-%m-%d', transaction_date / 1000, 'unixepoch', 'localtime') AS day_key, "
          'type, SUM(amount) AS total FROM transactions '
          'WHERE transaction_date >= ? AND transaction_date < ? '
          'GROUP BY day_key, type ORDER BY day_key ASC',
          [monthStart, monthEnd],
        );
      });
      results['top_receipt_items'] = _time(() {
        db.select(
          'SELECT ti.name, SUM(ti.quantity), SUM(ti.total_price) AS total '
          'FROM transaction_items ti '
          'INNER JOIN transactions t ON t.id = ti.transaction_id '
          'WHERE t.transaction_date >= ? AND t.transaction_date < ? '
          'GROUP BY ti.name ORDER BY total DESC LIMIT 5',
          [monthStart, monthEnd],
        );
      });
      results['search_page'] = _time(() {
        db.select(
          'SELECT * FROM transactions '
          'WHERE category LIKE ? OR description LIKE ? OR payment_method LIKE ? '
          'ORDER BY transaction_date DESC, id DESC LIMIT 50',
          ['%makan%', '%makan%', '%makan%'],
        );
      });
      results['detail_items'] = _time(() {
        db.select('SELECT * FROM transaction_items WHERE transaction_id = ?', [
          max(1, size ~/ 2),
        ]);
      });

      print('rows=$size rss_mb=${ProcessInfo.currentRss ~/ (1024 * 1024)}');
      for (final entry in results.entries) {
        print('${entry.key}=${entry.value}us');
      }
      _printExplain(db, monthStart, monthEnd);
    } finally {
      db.dispose();
    }
  }
}

int _time(void Function() fn) {
  final sw = Stopwatch()..start();
  fn();
  sw.stop();
  return sw.elapsedMicroseconds;
}

void _printExplain(Database db, int monthStart, int monthEnd) {
  final latestRows = db.select(
    'EXPLAIN QUERY PLAN SELECT * FROM transactions '
    'ORDER BY transaction_date DESC, id DESC LIMIT 5',
  );
  for (final row in latestRows) {
    print('latest_transactions_explain=${row.values.join(' | ')}');
  }

  final rows = db.select(
    'EXPLAIN QUERY PLAN SELECT * FROM transactions '
    'WHERE transaction_date >= ? AND transaction_date < ? '
    'ORDER BY transaction_date DESC, id DESC LIMIT 50 OFFSET 50',
    [monthStart, monthEnd],
  );
  for (final row in rows) {
    print('monthly_history_explain=${row.values.join(' | ')}');
  }
}

void _setup(Database db) {
  db.execute('''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      category TEXT NOT NULL,
      description TEXT,
      source TEXT NOT NULL,
      payment_method TEXT,
      receipt_image_path TEXT,
      transaction_date INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
    CREATE TABLE transaction_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      quantity REAL NOT NULL DEFAULT 1,
      unit_price REAL,
      total_price REAL NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE INDEX idx_transactions_date_id
      ON transactions(transaction_date DESC, id DESC);
    CREATE INDEX idx_transactions_type_date
      ON transactions(type, transaction_date);
    CREATE INDEX idx_transactions_category_date
      ON transactions(category, transaction_date);
    CREATE INDEX idx_transaction_items_transaction_id
      ON transaction_items(transaction_id);
  ''');
}

void _seed(Database db, int rows) {
  final categories = [
    'Makanan & Minuman',
    'Belanja Harian',
    'Transportasi',
    'Tagihan & Utilitas',
    'Hiburan',
  ];
  final items = ['Beras', 'Telur', 'Kopi', 'Sabun', 'Roti'];
  final baseDate = DateTime(2026, 8, 14).millisecondsSinceEpoch;
  final dayMs = const Duration(days: 1).inMilliseconds;
  final insertTx = db.prepare(
    'INSERT INTO transactions '
    '(type, amount, category, description, source, payment_method, '
    'transaction_date, created_at, updated_at) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
  );
  final insertItem = db.prepare(
    'INSERT INTO transaction_items '
    '(transaction_id, name, quantity, unit_price, total_price, created_at) '
    'VALUES (?, ?, ?, ?, ?, ?)',
  );

  db.execute('BEGIN');
  try {
    for (var i = 0; i < rows; i++) {
      final isIncome = i % 7 == 0;
      final amount = isIncome ? 3500000.0 : 10000.0 + (i % 40) * 2500;
      final date = baseDate - (i % 720) * dayMs;
      insertTx.execute([
        isIncome ? 'income' : 'expense',
        amount,
        isIncome ? 'Gaji' : categories[i % categories.length],
        isIncome ? 'Gaji bulanan' : 'Struk Toko ${i % 24}',
        isIncome ? 'manual' : 'receipt_scan',
        i % 2 == 0 ? 'Tunai' : 'QRIS',
        date,
        date,
        date,
      ]);
      final txId = db.lastInsertRowId;
      if (!isIncome) {
        for (var j = 0; j < 3; j++) {
          final price = 7000.0 + ((i + j) % 20) * 1000;
          insertItem.execute([
            txId,
            items[(i + j) % items.length],
            1,
            price,
            price,
            date,
          ]);
        }
      }
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  } finally {
    insertTx.dispose();
    insertItem.dispose();
  }
}
