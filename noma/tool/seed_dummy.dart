// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const _source = 'dummy';
const _androidPackage = 'com.noma.app';
const _androidDbPath = 'app_flutter/noma_app.db';

Future<void> main(List<String> args) async {
  final command = _command(args);
  if (command == null) {
    _printUsage();
    exitCode = 64;
    return;
  }

  if (args.contains('--android')) {
    try {
      await _runAndroid(command, args);
    } catch (e) {
      stderr.writeln('Android dummy seeder failed: $e');
      exitCode = 1;
    }
    return;
  }

  final dbPath = _dbPath(args);
  Directory(p.dirname(dbPath)).createSync(recursive: true);
  final db = sqlite3.open(dbPath);

  try {
    final result = runDummySeedCommand(db, command);
    print(result.message);
    printDummyStats(result.after, dbPath: dbPath);
  } finally {
    db.dispose();
  }
}

DummySeedCommand? _command(List<String> args) {
  final commands = [
    if (args.contains('--seed')) DummySeedCommand.seed,
    if (args.contains('--clear')) DummySeedCommand.clear,
    if (args.contains('--reset')) DummySeedCommand.reset,
  ];
  return commands.length == 1 ? commands.single : null;
}

String _dbPath(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--db' && i + 1 < args.length) return args[i + 1];
    if (args[i].startsWith('--db=')) return args[i].substring(5);
  }

  final home =
      Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      '.';
  return p.join(home, 'Documents', 'noma_app.db');
}

Future<void> _runAndroid(DummySeedCommand command, List<String> args) async {
  if (_hasDbArg(args)) {
    throw ArgumentError('--db cannot be combined with --android.');
  }

  final adb = _findAdb();
  if (adb == null) {
    throw StateError(
      'ADB tidak ditemukan. Pastikan Android SDK platform-tools tersedia.',
    );
  }

  final device = await _selectAndroidDevice(adb, _deviceArg(args));
  print('Android device: $device');
  print('Package: $_androidPackage');
  print('Runtime DB: /data/user/0/$_androidPackage/$_androidDbPath');

  final dbCheck = await _runProcess(adb, [
    '-s',
    device,
    'shell',
    'run-as',
    _androidPackage,
    'ls',
    _androidDbPath,
  ]);
  if (dbCheck.exitCode != 0) {
    throw StateError(
      'Database runtime tidak ditemukan atau package bukan debug build. '
      'Jalankan Noma debug sekali, lalu coba lagi. Detail: ${dbCheck.stderr.trim()}',
    );
  }

  final stop = await _runProcess(adb, [
    '-s',
    device,
    'shell',
    'am',
    'force-stop',
    _androidPackage,
  ]);
  if (stop.exitCode != 0) {
    throw StateError('Gagal force-stop Noma: ${stop.stderr.trim()}');
  }

  try {
    final entry = _writeAndroidSeedEntry();
    final result = await _runFlutterSeed(
      device: device,
      entryPath: entry.path,
      command: command,
    );
    if (result.output.contains('Android dummy operation failed')) {
      throw StateError('Android seed runner reported failure.');
    }
    if (result.exitCode != 0 && !result.hasSuccessOutput) {
      throw StateError(
        'Flutter Android seed runner exited with code ${result.exitCode}.',
      );
    }
  } finally {
    await _restoreNormalAndroidApp(adb, device);
  }
}

bool _hasDbArg(List<String> args) {
  return args.any((arg) => arg == '--db' || arg.startsWith('--db='));
}

String? _deviceArg(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--device' && i + 1 < args.length) return args[i + 1];
    if (args[i].startsWith('--device=')) return args[i].substring(9);
  }
  return null;
}

String? _findAdb() {
  final envAdb = Platform.environment['ADB'];
  if (envAdb != null && envAdb.isNotEmpty && File(envAdb).existsSync()) {
    return envAdb;
  }

  final candidates = [
    p.join(
      Platform.environment['LOCALAPPDATA'] ?? '',
      'Android',
      'Sdk',
      'platform-tools',
      Platform.isWindows ? 'adb.exe' : 'adb',
    ),
    p.join(
      Platform.environment['ANDROID_HOME'] ?? '',
      'platform-tools',
      Platform.isWindows ? 'adb.exe' : 'adb',
    ),
    p.join(
      Platform.environment['ANDROID_SDK_ROOT'] ?? '',
      'platform-tools',
      Platform.isWindows ? 'adb.exe' : 'adb',
    ),
  ];

  for (final candidate in candidates) {
    if (candidate.isNotEmpty && File(candidate).existsSync()) {
      return candidate;
    }
  }

  final pathDirs = (Platform.environment['PATH'] ?? '').split(
    Platform.isWindows ? ';' : ':',
  );
  for (final dir in pathDirs) {
    final candidate = p.join(dir, Platform.isWindows ? 'adb.exe' : 'adb');
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}

Future<String> _selectAndroidDevice(String adb, String? requested) async {
  final result = await _runProcess(adb, ['devices']);
  if (result.exitCode != 0) {
    throw StateError('Gagal menjalankan adb devices: ${result.stderr.trim()}');
  }

  final devices = result.stdout
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.endsWith('\tdevice'))
      .map((line) => line.split('\t').first)
      .toList();

  if (requested != null) {
    if (!devices.contains(requested)) {
      throw StateError(
        'Device $requested tidak ditemukan. Device tersedia: ${devices.join(', ')}',
      );
    }
    return requested;
  }

  if (devices.isEmpty) {
    throw StateError('Tidak ada Android device aktif dari adb devices.');
  }
  if (devices.length > 1) {
    throw StateError(
      'Lebih dari satu Android device aktif: ${devices.join(', ')}. '
      'Gunakan --device <id>.',
    );
  }
  return devices.single;
}

Future<_ProcessResultText> _runProcess(
  String executable,
  List<String> args,
) async {
  final result = await Process.run(
    executable,
    args,
    runInShell: Platform.isWindows,
  );
  return _ProcessResultText(
    result.exitCode,
    (result.stdout ?? '').toString(),
    (result.stderr ?? '').toString(),
  );
}

File _writeAndroidSeedEntry() {
  final file = File(p.join('.dart_tool', 'noma_android_seed_entry.dart'));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(_androidSeedEntrySource);
  return file;
}

Future<_FlutterSeedResult> _runFlutterSeed({
  required String device,
  required String entryPath,
  required DummySeedCommand command,
}) async {
  final process = await Process.start('flutter', [
    'run',
    '-d',
    device,
    '-t',
    entryPath,
    '--debug',
    '--dart-define=NOMA_DUMMY_SEED_COMMAND=${command.name}',
  ], runInShell: Platform.isWindows);

  final output = StringBuffer();
  final stdoutDone = process.stdout.transform(utf8.decoder).forEach((data) {
    stdout.write(data);
    output.write(data);
  });
  final stderrDone = process.stderr.transform(utf8.decoder).forEach((data) {
    stderr.write(data);
    output.write(data);
  });

  try {
    final exitCode = await process.exitCode.timeout(const Duration(minutes: 5));
    await Future.wait([stdoutDone, stderrDone]);
    return _FlutterSeedResult(exitCode, output.toString());
  } on TimeoutException {
    process.kill();
    throw TimeoutException('Flutter Android seed runner timeout.');
  }
}

Future<void> _restoreNormalAndroidApp(String adb, String device) async {
  print('Restoring normal Noma debug app...');
  final buildCode = await _runStreamingProcess('flutter', [
    'build',
    'apk',
    '--debug',
    '-t',
    'lib/main.dart',
  ], timeout: const Duration(minutes: 5));
  if (buildCode != 0) {
    throw StateError('Failed to rebuild normal Noma debug APK.');
  }

  final apk = p.join('build', 'app', 'outputs', 'flutter-apk', 'app-debug.apk');
  final install = await _runProcess(adb, ['-s', device, 'install', '-r', apk]);
  if (install.exitCode != 0) {
    throw StateError('Failed to reinstall normal Noma app: ${install.stderr}');
  }

  await _runProcess(adb, [
    '-s',
    device,
    'shell',
    'am',
    'force-stop',
    _androidPackage,
  ]);
  print('Normal Noma debug app restored. Restart Noma to reload providers.');
}

Future<int> _runStreamingProcess(
  String executable,
  List<String> args, {
  required Duration timeout,
}) async {
  final process = await Process.start(
    executable,
    args,
    runInShell: Platform.isWindows,
  );
  final stdoutDone = process.stdout
      .transform(utf8.decoder)
      .forEach(stdout.write);
  final stderrDone = process.stderr
      .transform(utf8.decoder)
      .forEach(stderr.write);
  try {
    final exitCode = await process.exitCode.timeout(timeout);
    await Future.wait([stdoutDone, stderrDone]);
    return exitCode;
  } on TimeoutException {
    process.kill();
    throw TimeoutException('$executable ${args.join(' ')} timeout.');
  }
}

class _ProcessResultText {
  final int exitCode;
  final String stdout;
  final String stderr;

  const _ProcessResultText(this.exitCode, this.stdout, this.stderr);
}

class _FlutterSeedResult {
  final int exitCode;
  final String output;

  const _FlutterSeedResult(this.exitCode, this.output);

  bool get hasSuccessOutput {
    return output.contains('Android dummy seed completed.') ||
        output.contains('Android dummy data already exists.') ||
        output.contains('Android dummy data cleared.');
  }
}

const _androidSeedEntrySource = r'''
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../tool/seed_dummy.dart' as seed;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }

  final commandName = const String.fromEnvironment('NOMA_DUMMY_SEED_COMMAND');
  final command = seed.DummySeedCommand.values.firstWhere(
    (value) => value.name == commandName,
    orElse: () => throw ArgumentError('Invalid seed command: $commandName'),
  );

  final dbFolder = await getApplicationDocumentsDirectory();
  final dbPath = p.join(dbFolder.path, 'noma_app.db');
  final dbFile = File(dbPath);
  if (!dbFile.existsSync()) {
    stderr.writeln('Android runtime database not found: $dbPath');
    exit(2);
  }

  final db = sqlite3.open(dbPath);
  try {
    final result = seed.runDummySeedCommand(db, command);
    final message = switch (command) {
      seed.DummySeedCommand.clear => 'Android dummy data cleared.',
      seed.DummySeedCommand.seed when result.alreadyExisted =>
        'Android dummy data already exists. Run with --reset --android to reseed.',
      _ => 'Android dummy seed completed.',
    };

    print(message);
    print('Database: Android runtime ($dbPath)');
    print('Real transactions before: ${result.realBefore}');
    print('Real transactions after: ${result.realAfter}');
    seed.printDummyStats(result.after);
    exit(0);
  } catch (error, stackTrace) {
    stderr.writeln('Android dummy operation failed: $error');
    stderr.writeln(stackTrace);
    exit(1);
  } finally {
    db.dispose();
  }
}
''';

void _printUsage() {
  print('Usage:');
  print('  dart run tool/seed_dummy.dart --seed [--db path/to/noma_app.db]');
  print('  dart run tool/seed_dummy.dart --reset [--db path/to/noma_app.db]');
  print('  dart run tool/seed_dummy.dart --clear [--db path/to/noma_app.db]');
  print('  dart run tool/seed_dummy.dart --seed --android [--device id]');
  print('  dart run tool/seed_dummy.dart --reset --android [--device id]');
  print('  dart run tool/seed_dummy.dart --clear --android [--device id]');
}

DummySeedResult runDummySeedCommand(Database db, DummySeedCommand command) {
  ensureDummySchema(db);
  final realBefore = _realCount(db);
  final before = readDummyStats(db);
  var message = 'Dummy seed completed.';

  if (command == DummySeedCommand.seed && before.transactions > 0) {
    return DummySeedResult(
      message: 'Dummy data already exists. Run with --reset to reseed.',
      before: before,
      after: before,
      realBefore: realBefore,
      realAfter: realBefore,
      alreadyExisted: true,
    );
  }

  if (command == DummySeedCommand.clear) {
    _clearDummy(db);
    message = 'Dummy data cleared.';
  } else {
    if (command == DummySeedCommand.reset) {
      _clearDummy(db);
    }
    _seedDummy(db);
  }

  final after = readDummyStats(db);
  final realAfter = _realCount(db);
  if (realBefore != realAfter) {
    throw StateError(
      'Non-dummy transaction count changed from $realBefore to $realAfter.',
    );
  }

  return DummySeedResult(
    message: message,
    before: before,
    after: after,
    realBefore: realBefore,
    realAfter: realAfter,
    alreadyExisted: false,
  );
}

void ensureDummySchema(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS transactions (
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
    CREATE TABLE IF NOT EXISTS transaction_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      quantity REAL NOT NULL DEFAULT 1,
      unit_price REAL,
      total_price REAL NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      icon TEXT,
      color TEXT,
      type TEXT NOT NULL,
      is_default INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS chat_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT NOT NULL PRIMARY KEY,
      value TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_transactions_date_id
      ON transactions(transaction_date DESC, id DESC);
    CREATE INDEX IF NOT EXISTS idx_transactions_type_date
      ON transactions(type, transaction_date);
    CREATE INDEX IF NOT EXISTS idx_transactions_category_date
      ON transactions(category, transaction_date);
    CREATE INDEX IF NOT EXISTS idx_transaction_items_transaction_id
      ON transaction_items(transaction_id);
  ''');

  final now = DateTime.now().millisecondsSinceEpoch;
  final insertCategory = db.prepare(
    'INSERT OR IGNORE INTO categories '
    '(name, icon, color, type, is_default, created_at) VALUES (?, ?, ?, ?, 1, ?)',
  );
  try {
    for (final category in _categories) {
      try {
        insertCategory.execute([
          category.$1,
          category.$2,
          category.$3,
          category.$4,
          now,
        ]);
      } on SqliteException {
        // Existing databases always have categories. Fresh ad-hoc test DBs may
        // not need category rows, so seeding transactions should continue.
      }
    }
  } finally {
    insertCategory.dispose();
  }
}

void _clearDummy(Database db) {
  db.execute('BEGIN IMMEDIATE');
  try {
    db.execute(
      'DELETE FROM transaction_items WHERE transaction_id IN '
      '(SELECT id FROM transactions WHERE source = ?)',
      [_source],
    );
    db.execute('DELETE FROM transactions WHERE source = ?', [_source]);
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

void _seedDummy(Database db) {
  final rng = Random(20260825);
  final insertTx = db.prepare(
    'INSERT INTO transactions '
    '(type, amount, category, description, source, payment_method, '
    'receipt_image_path, transaction_date, created_at, updated_at) '
    'VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?, ?)',
  );
  final insertItem = db.prepare(
    'INSERT INTO transaction_items '
    '(transaction_id, name, quantity, unit_price, total_price, created_at) '
    'VALUES (?, ?, ?, ?, ?, ?)',
  );

  db.execute('BEGIN IMMEDIATE');
  try {
    for (final month in _monthPlans) {
      final days = month.month == 8
          ? 25
          : DateTime(2026, month.month + 1, 0).day;
      final incomeDays = _incomeDays(month.month);

      for (final day in incomeDays) {
        final income = _pick(_incomeTemplates, rng);
        final date = _dateMs(month.month, min(day, days), 9 + rng.nextInt(4));
        insertTx.execute([
          'income',
          _jitter(income.amount, rng, 0.07),
          income.category,
          income.description,
          _source,
          _pick(_incomePaymentMethods, rng),
          date,
          date,
          date,
        ]);
      }

      final expensesNeeded = month.totalTransactions - incomeDays.length;
      for (var i = 0; i < expensesNeeded; i++) {
        final day = 1 + rng.nextInt(days);
        final hour = 7 + rng.nextInt(15);
        final expense = _expenseFor(i, rng);
        final withItems =
            rng.nextDouble() < 0.75 &&
            _receiptCatalog.containsKey(expense.merchant);
        final items = withItems
            ? _itemsFor(expense.merchant, rng)
            : const <_Item>[];
        final amount = items.isEmpty
            ? _jitter(expense.amount, rng, 0.18)
            : items.fold<double>(0, (sum, item) => sum + item.total);
        final date = _dateMs(month.month, day, hour, minute: rng.nextInt(60));

        insertTx.execute([
          'expense',
          amount,
          expense.category,
          'Struk ${expense.merchant}',
          _source,
          _pick(_expensePaymentMethods, rng),
          date,
          date,
          date,
        ]);

        final txId = db.lastInsertRowId;
        for (final item in items) {
          insertItem.execute([
            txId,
            item.name,
            item.quantity,
            item.unitPrice,
            item.total,
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

DummyStats readDummyStats(Database db) {
  final row = db
      .select(
        '''
    SELECT COUNT(*) AS transactions,
           SUM(CASE WHEN type = 'income' THEN 1 ELSE 0 END) AS income,
           SUM(CASE WHEN type = 'expense' THEN 1 ELSE 0 END) AS expense,
           MIN(transaction_date) AS min_date,
           MAX(transaction_date) AS max_date
    FROM transactions
    WHERE source = ?
    ''',
        [_source],
      )
      .first;
  final itemRow = db
      .select(
        '''
    SELECT COUNT(*) AS items
    FROM transaction_items
    WHERE transaction_id IN (SELECT id FROM transactions WHERE source = ?)
    ''',
        [_source],
      )
      .first;

  return DummyStats(
    transactions: row['transactions'] as int? ?? 0,
    income: row['income'] as int? ?? 0,
    expense: row['expense'] as int? ?? 0,
    receiptItems: itemRow['items'] as int? ?? 0,
    minDateMs: row['min_date'] as int?,
    maxDateMs: row['max_date'] as int?,
  );
}

int _realCount(Database db) {
  return db.select(
        'SELECT COUNT(*) AS total FROM transactions WHERE source <> ?',
        [_source],
      ).first['total']
      as int;
}

void printDummyStats(DummyStats stats, {String? dbPath}) {
  if (dbPath != null) {
    print('Database: $dbPath');
  }
  print('Transactions: ${stats.transactions}');
  print('Income: ${stats.income}');
  print('Expense: ${stats.expense}');
  print('Receipt items: ${stats.receiptItems}');
  print(
    'Range: ${_dateText(stats.minDateMs)} -> ${_dateText(stats.maxDateMs)}',
  );
}

int _dateMs(int month, int day, int hour, {int minute = 0}) {
  return DateTime(2026, month, day, hour, minute).millisecondsSinceEpoch;
}

String _dateText(Object? millis) {
  if (millis == null) return '-';
  final date = DateTime.fromMillisecondsSinceEpoch(millis as int);
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

T _pick<T>(List<T> values, Random rng) => values[rng.nextInt(values.length)];

double _jitter(double value, Random rng, double percent) {
  final factor = 1 + ((rng.nextDouble() * 2) - 1) * percent;
  return ((value * factor) / 500).round() * 500;
}

List<int> _incomeDays(int month) {
  return switch (month) {
    3 => const [1, 5, 15, 23, 28, 30],
    4 => const [1, 8, 14, 20, 26, 30],
    5 => const [1, 7, 16, 22, 29],
    6 => const [1, 6, 13, 18, 24, 30],
    7 => const [1, 5, 15, 21, 27],
    8 => const [1, 4, 12, 17, 22, 25],
    _ => const [1],
  };
}

_Expense _expenseFor(int index, Random rng) {
  final roll = rng.nextDouble();
  final pool = roll < 0.42
      ? _foodExpenses
      : roll < 0.65
      ? _transportExpenses
      : _otherExpenses;
  return pool[(index + rng.nextInt(pool.length)) % pool.length];
}

List<_Item> _itemsFor(String merchant, Random rng) {
  final catalog = _receiptCatalog[merchant]!;
  final count = 2 + rng.nextInt(min(4, catalog.length - 1));
  final shuffled = [...catalog]..shuffle(rng);
  return shuffled.take(count).map((item) {
    final quantity = 1 + rng.nextInt(item.maxQuantity);
    return _Item(item.name, quantity.toDouble(), item.unitPrice);
  }).toList();
}

enum DummySeedCommand { seed, clear, reset }

class DummySeedResult {
  final String message;
  final DummyStats before;
  final DummyStats after;
  final int realBefore;
  final int realAfter;
  final bool alreadyExisted;

  const DummySeedResult({
    required this.message,
    required this.before,
    required this.after,
    required this.realBefore,
    required this.realAfter,
    required this.alreadyExisted,
  });
}

class DummyStats {
  final int transactions;
  final int income;
  final int expense;
  final int receiptItems;
  final int? minDateMs;
  final int? maxDateMs;

  const DummyStats({
    required this.transactions,
    required this.income,
    required this.expense,
    required this.receiptItems,
    required this.minDateMs,
    required this.maxDateMs,
  });
}

class _MonthPlan {
  final int month;
  final int totalTransactions;

  const _MonthPlan(this.month, this.totalTransactions);
}

class _Income {
  final String category;
  final String description;
  final double amount;

  const _Income(this.category, this.description, this.amount);
}

class _Expense {
  final String category;
  final String merchant;
  final double amount;

  const _Expense(this.category, this.merchant, this.amount);
}

class _CatalogItem {
  final String name;
  final double unitPrice;
  final int maxQuantity;

  const _CatalogItem(this.name, this.unitPrice, this.maxQuantity);
}

class _Item {
  final String name;
  final double quantity;
  final double unitPrice;

  const _Item(this.name, this.quantity, this.unitPrice);

  double get total => quantity * unitPrice;
}

const _monthPlans = [
  _MonthPlan(3, 70),
  _MonthPlan(4, 80),
  _MonthPlan(5, 75),
  _MonthPlan(6, 90),
  _MonthPlan(7, 85),
  _MonthPlan(8, 100),
];

const _incomeTemplates = [
  _Income('Gaji', 'Gaji bulanan', 4000000),
  _Income('Pemasukan Lainnya', 'Uang bulanan', 1500000),
  _Income('Usaha & Freelance', 'Project freelance', 1000000),
  _Income('Bonus & THR', 'Bonus performa', 750000),
  _Income('Pemasukan Lainnya', 'Transfer masuk', 500000),
  _Income('Usaha & Freelance', 'Fee desain', 2000000),
  _Income('Bonus & THR', 'Bonus tambahan', 3000000),
];

const _incomePaymentMethods = ['Transfer', 'Debit', 'E-Wallet'];
const _expensePaymentMethods = [
  'Cash',
  'QRIS',
  'Debit',
  'Transfer',
  'E-Wallet',
];

const _foodExpenses = [
  _Expense('Makanan & Minuman', 'Warung Bu Siti', 18000),
  _Expense('Makanan & Minuman', 'Bakso Pak Slamet', 22000),
  _Expense('Makanan & Minuman', 'Kopi Kenangan', 28000),
  _Expense('Makanan & Minuman', 'KFC', 55000),
  _Expense('Makanan & Minuman', "McDonald's", 52000),
  _Expense('Makanan & Minuman', 'GrabFood', 45000),
  _Expense('Makanan & Minuman', 'Gojek Food', 42000),
];

const _transportExpenses = [
  _Expense('Transportasi', 'Gojek', 18000),
  _Expense('Transportasi', 'Grab', 22000),
  _Expense('Transportasi', 'Pertamina', 75000),
  _Expense('Transportasi', 'Parkir Mall', 5000),
  _Expense('Transportasi', 'KRL', 10000),
];

const _otherExpenses = [
  _Expense('Belanja Harian', 'Indomaret', 65000),
  _Expense('Belanja Harian', 'Alfamart', 58000),
  _Expense('Belanja Harian', 'Shopee', 150000),
  _Expense('Belanja Harian', 'Tokopedia', 180000),
  _Expense('Tagihan & Utilitas', 'PLN', 250000),
  _Expense('Tagihan & Utilitas', 'Telkomsel', 85000),
  _Expense('Hiburan', 'Steam', 120000),
  _Expense('Hiburan', 'Google Play', 35000),
  _Expense('Kesehatan', 'Apotek K24', 75000),
  _Expense('Pendidikan', 'Udemy', 150000),
  _Expense('Rumah Tangga', 'Laundry', 45000),
  _Expense('Fashion & Kecantikan', 'Shopee Fashion', 175000),
];

const _receiptCatalog = {
  'Indomaret': [
    _CatalogItem('Indomie', 3500, 5),
    _CatalogItem('Air Mineral', 4000, 4),
    _CatalogItem('Roti', 12000, 3),
    _CatalogItem('Susu', 15000, 3),
    _CatalogItem('Snack', 8500, 4),
    _CatalogItem('Sabun', 18000, 2),
  ],
  'Alfamart': [
    _CatalogItem('Air Mineral', 4000, 4),
    _CatalogItem('Kopi', 9000, 4),
    _CatalogItem('Roti', 11000, 3),
    _CatalogItem('Susu', 15500, 3),
    _CatalogItem('Snack', 8000, 4),
  ],
  'Kopi Kenangan': [
    _CatalogItem('Kopi', 22000, 3),
    _CatalogItem('Roti', 18000, 2),
    _CatalogItem('Air Mineral', 5000, 2),
  ],
  'KFC': [
    _CatalogItem('Paket Ayam', 38000, 3),
    _CatalogItem('Kentang', 18000, 2),
    _CatalogItem('Minuman', 12000, 3),
  ],
  "McDonald's": [
    _CatalogItem('Burger', 32000, 3),
    _CatalogItem('Kentang', 17000, 2),
    _CatalogItem('Minuman', 12000, 3),
  ],
  'Shopee': [
    _CatalogItem('Susu', 16000, 4),
    _CatalogItem('Snack', 9000, 5),
    _CatalogItem('Sabun', 18000, 3),
    _CatalogItem('Roti', 12000, 3),
  ],
  'Tokopedia': [
    _CatalogItem('Kopi', 25000, 4),
    _CatalogItem('Susu', 17000, 4),
    _CatalogItem('Sabun', 19000, 3),
  ],
};

const _categories = [
  ('Makanan & Minuman', 'fastfood', '#F43F5E', 'expense'),
  ('Belanja Harian', 'shopping_bag', '#06B6D4', 'expense'),
  ('Transportasi', 'directions_car', '#3B82F6', 'expense'),
  ('Tagihan & Utilitas', 'receipt_long', '#F59E0B', 'expense'),
  ('Hiburan', 'sports_esports', '#8B5CF6', 'expense'),
  ('Kesehatan', 'medical_services', '#EC4899', 'expense'),
  ('Pendidikan', 'school', '#6366F1', 'expense'),
  ('Fashion & Kecantikan', 'checkroom', '#14B8A6', 'expense'),
  ('Rumah Tangga', 'home', '#64748B', 'expense'),
  ('Pengeluaran Lainnya', 'more_horiz', '#94A3B8', 'expense'),
  ('Gaji', 'payments', '#10B981', 'income'),
  ('Bonus & THR', 'card_giftcard', '#059669', 'income'),
  ('Investasi', 'trending_up', '#3B82F6', 'income'),
  ('Usaha & Freelance', 'work', '#8B5CF6', 'income'),
  ('Pemasukan Lainnya', 'attach_money', '#10B981', 'income'),
];
