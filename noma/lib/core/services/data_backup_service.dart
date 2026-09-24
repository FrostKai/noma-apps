import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

class BackupPreview {
  final List<Category> categories;
  final List<({Transaction transaction, List<TransactionItem> items})>
  transactions;
  final int newTransactions;
  final int skippedTransactions;
  final int newCategories;

  const BackupPreview({
    required this.categories,
    required this.transactions,
    required this.newTransactions,
    required this.skippedTransactions,
    required this.newCategories,
  });
}

class DataBackupService {
  final AppDatabase db;
  const DataBackupService(this.db);

  Future<File> exportToFile(File file) async {
    await db.transaction(() async {
      final missing = await (db.select(
        db.transactions,
      )..where((t) => t.externalId.isNull())).get();
      for (final tx in missing) {
        await (db.update(db.transactions)..where((t) => t.id.equals(tx.id)))
            .write(TransactionsCompanion(externalId: Value(const Uuid().v4())));
      }
    });
    final categories = await db.select(db.categories).get();
    final sink = file.openWrite();
    try {
      sink.write('{"format":"noma-backup","version":1,"categories":');
      sink.write(jsonEncode(categories.map((c) => c.toJson()).toList()));
      sink.write(',"transactions":[');
      var offset = 0;
      var first = true;
      while (true) {
        final page =
            await (db.select(db.transactions)
                  ..orderBy([(t) => OrderingTerm.asc(t.id)])
                  ..limit(500, offset: offset))
                .get();
        if (page.isEmpty) break;
        final items = await (db.select(
          db.transactionItems,
        )..where((t) => t.transactionId.isIn(page.map((tx) => tx.id)))).get();
        final byTransaction = <int, List<TransactionItem>>{};
        for (final item in items) {
          byTransaction.putIfAbsent(item.transactionId, () => []).add(item);
        }
        for (final tx in page) {
          if (!first) sink.write(',');
          first = false;
          sink.write(
            jsonEncode({
              ...tx.toJson(),
              'receiptImagePath': null,
              'items': (byTransaction[tx.id] ?? [])
                  .map((i) => i.toJson())
                  .toList(),
            }),
          );
        }
        offset += page.length;
        if (page.length < 500) break;
      }
      sink.write(']}');
      await sink.flush();
      return file;
    } finally {
      await sink.close();
    }
  }

  Future<BackupPreview> prepareRestore(File file) async {
    final data = await compute(_decodeBackup, await file.readAsString());
    final categories = <Category>[];
    for (final raw in data['categories'] as List) {
      final category = Category.fromJson(Map<String, dynamic>.from(raw as Map));
      if (category.name.trim().isEmpty ||
          !{'income', 'expense', 'both'}.contains(category.type)) {
        throw const FormatException('Kategori backup tidak valid.');
      }
      categories.add(category);
    }
    final transactions =
        <({Transaction transaction, List<TransactionItem> items})>[];
    final seen = <String>{};
    for (final raw in data['transactions'] as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final tx = Transaction.fromJson(row);
      if (tx.externalId == null ||
          tx.externalId!.isEmpty ||
          !seen.add(tx.externalId!) ||
          !{'income', 'expense'}.contains(tx.type) ||
          tx.amount <= 0 ||
          !tx.amount.isFinite ||
          tx.category.trim().isEmpty ||
          tx.source.trim().isEmpty ||
          tx.transactionDate <= 0) {
        throw const FormatException(
          'Transaksi backup tidak valid atau duplikat.',
        );
      }
      final items = <TransactionItem>[];
      for (final itemRaw in row['items'] as List) {
        final item = TransactionItem.fromJson(
          Map<String, dynamic>.from(itemRaw as Map),
        );
        if (item.transactionId != tx.id ||
            item.name.trim().isEmpty ||
            item.quantity <= 0 ||
            !item.quantity.isFinite ||
            item.totalPrice <= 0 ||
            !item.totalPrice.isFinite ||
            (item.unitPrice != null &&
                (!item.unitPrice!.isFinite || item.unitPrice! < 0))) {
          throw const FormatException('Item struk backup tidak valid.');
        }
        items.add(item);
      }
      transactions.add((transaction: tx, items: items));
    }
    final existing = await (db.selectOnly(
      db.transactions,
    )..addColumns([db.transactions.externalId])).get();
    final ids = existing
        .map((r) => r.read(db.transactions.externalId))
        .whereType<String>()
        .toSet();
    final names = (await db.select(db.categories).get())
        .map((c) => c.name)
        .toSet();
    final skipped = transactions
        .where((entry) => ids.contains(entry.transaction.externalId))
        .length;
    return BackupPreview(
      categories: categories,
      transactions: transactions,
      newTransactions: transactions.length - skipped,
      skippedTransactions: skipped,
      newCategories: categories.where((c) => !names.contains(c.name)).length,
    );
  }

  Future<({int added, int skipped})> restore(BackupPreview preview) =>
      db.transaction(() async {
        final names = (await db.select(db.categories).get())
            .map((c) => c.name)
            .toSet();
        for (final category in preview.categories) {
          if (!names.add(category.name)) continue;
          await db
              .into(db.categories)
              .insert(
                CategoriesCompanion.insert(
                  name: category.name,
                  icon: Value(category.icon),
                  color: Value(category.color),
                  type: category.type,
                  isDefault: Value(category.isDefault),
                  createdAt: category.createdAt,
                ),
              );
        }
        var added = 0;
        var skipped = 0;
        for (final entry in preview.transactions) {
          final tx = entry.transaction;
          final exists =
              await (db.select(db.transactions)
                    ..where((t) => t.externalId.equals(tx.externalId!)))
                  .getSingleOrNull();
          if (exists != null) {
            skipped++;
            continue;
          }
          final id = await db
              .into(db.transactions)
              .insert(
                TransactionsCompanion.insert(
                  externalId: Value(tx.externalId),
                  type: tx.type,
                  amount: tx.amount,
                  category: tx.category,
                  description: Value(tx.description),
                  source: tx.source,
                  paymentMethod: Value(tx.paymentMethod),
                  receiptImagePath: const Value(null),
                  transactionDate: tx.transactionDate,
                  createdAt: tx.createdAt,
                  updatedAt: tx.updatedAt,
                ),
              );
          if (entry.items.isNotEmpty) {
            await db.batch(
              (batch) => batch.insertAll(db.transactionItems, [
                for (final item in entry.items)
                  TransactionItemsCompanion.insert(
                    transactionId: id,
                    name: item.name,
                    quantity: Value(item.quantity),
                    unitPrice: Value(item.unitPrice),
                    totalPrice: item.totalPrice,
                    createdAt: item.createdAt,
                  ),
              ]),
            );
          }
          added++;
        }
        return (added: added, skipped: skipped);
      });
}

Map<String, dynamic> _decodeBackup(String content) {
  final decoded = jsonDecode(content);
  if (decoded is! Map ||
      decoded['format'] != 'noma-backup' ||
      decoded['version'] != 1 ||
      decoded['categories'] is! List ||
      decoded['transactions'] is! List) {
    throw const FormatException('File ini bukan backup Noma versi 1.');
  }
  return Map<String, dynamic>.from(decoded);
}
