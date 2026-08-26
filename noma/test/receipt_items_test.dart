import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noma/core/database/app_database.dart';
import 'package:noma/core/services/api_key_service.dart';
import 'package:noma/core/services/gemini_api_service.dart';
import 'package:noma/features/receipt_scanner/domain/receipt_review_utils.dart';
import 'package:noma/features/transaction/data/transaction_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('receipt review parsing', () {
    test('parses valid receipt with items', () {
      final review = ReceiptReviewUtils.fromScanResult({
        'store_name': 'Noma Mart',
        'date': '2026-08-25',
        'total': 'Rp25.000',
        'category_suggestion': 'Belanja Harian',
        'items': [
          {
            'name': 'Susu',
            'quantity': 2,
            'unit_price': 'Rp10.000',
            'total_price': 'Rp20.000',
          },
          {'name': 'Roti', 'quantity': 1, 'total_price': 5000},
        ],
      });

      expect(review.merchant, 'Noma Mart');
      expect(review.total, 25000);
      expect(review.items, hasLength(2));
      expect(review.items.first.unitPrice, 10000);
      expect(ReceiptReviewUtils.validateScanResult({'total': 25000}), isNull);
    });

    test('handles invalid, missing total, missing merchant, and mismatch', () {
      expect(
        ReceiptReviewUtils.validateScanResult({'store_name': 'Noma Mart'}),
        isNotNull,
      );

      final review = ReceiptReviewUtils.fromScanResult({
        'total': 25000,
        'items': [
          {'name': 'A', 'quantity': 2, 'unit_price': 9000},
        ],
      });

      expect(review.merchant, 'Struk Belanja');
      expect(review.items.single.totalPrice, 18000);
      expect(ReceiptReviewUtils.totalItems(review.items), 18000);
      expect(ReceiptReviewUtils.hasTotalMismatch(25000, review.items), isTrue);
      expect(ReceiptReviewUtils.totalDifference(25000, review.items), 7000);
    });
  });

  group('Gemini receipt response parsing', () {
    test('scanReceiptImage returns parsed JSON', () async {
      SharedPreferences.setMockInitialValues({});
      await ApiKeyService.saveGeminiApiKey('AIzaSyTestKey');

      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((_) {
          return _geminiResponse(
            '{"store_name":"Noma Mart","total":25000,"items":[]}',
          );
        });

      final result = await GeminiApiService(
        dio: dio,
      ).scanReceiptImage(Uint8List.fromList([1, 2, 3]));

      expect(result['store_name'], 'Noma Mart');
      expect(result['total'], 25000);
    });

    test('scanReceiptImage throws on malformed AI text', () async {
      SharedPreferences.setMockInitialValues({});
      await ApiKeyService.saveGeminiApiKey('AIzaSyTestKey');

      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((_) => _geminiResponse('not-json'));

      expect(
        () => GeminiApiService(
          dio: dio,
        ).scanReceiptImage(Uint8List.fromList([1, 2, 3])),
        throwsException,
      );
    });

    test('parseNaturalText accepts optional transaction items', () async {
      SharedPreferences.setMockInitialValues({});
      await ApiKeyService.saveApiKey('AIzaSyTestKey');

      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((_) {
          return _geminiResponse(
            '{"type":"expense","amount":25000,"category":"Belanja Harian","description":"Indomaret","payment_method":"QRIS","items":[{"name":"Susu","quantity":2,"unit_price":10000,"total_price":20000},{"name":"Roti","quantity":1,"total_price":5000}]}',
          );
        });

      final result = await GeminiApiService(
        dio: dio,
      ).parseNaturalText('indomaret susu 2x 10000 roti 5000 qris');
      final items = ReceiptReviewUtils.extractReceiptItems(
        result['items'] as List,
      );

      expect(result['amount'], 25000);
      expect(items, hasLength(2));
      expect(items.first.name, 'Susu');
      expect(ReceiptReviewUtils.totalItems(items), 25000);
    });
  });

  group('transaction items repository', () {
    late AppDatabase db;
    late TransactionRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = TransactionRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('saves transaction with zero and multiple items', () async {
      final withoutItems = await _insertReceiptTransaction(repo, items: []);
      expect(await repo.getTransactionItems(withoutItems), isEmpty);

      final withItems = await _insertReceiptTransaction(
        repo,
        amount: 25000,
        items: [
          (name: 'Susu', quantity: 2, unitPrice: 10000, totalPrice: 20000),
          (name: 'Roti', quantity: 1, unitPrice: null, totalPrice: 5000),
        ],
      );

      final items = await repo.getTransactionItems(withItems);
      expect(items, hasLength(2));
      expect(items.first.name, 'Susu');
      expect(items.first.unitPrice, 10000);
      expect(items.last.totalPrice, 5000);
    });

    test('edits transaction fields without changing items', () async {
      final id = await _insertReceiptTransaction(
        repo,
        items: [
          (name: 'Susu', quantity: 1, unitPrice: 12000, totalPrice: 12000),
        ],
      );
      final tx = (await repo.getTransactionsPage(limit: 50, offset: 0)).single;

      final updated = await repo.updateTransaction(
        tx.copyWith(amount: 15000, category: 'Makanan & Minuman'),
      );

      expect(updated, isTrue);
      expect((await repo.getTransactionItems(id)).single.name, 'Susu');
      expect(
        (await repo.getTransactionsPage(limit: 50, offset: 0)).single.amount,
        15000,
      );
    });

    test(
      'updates transaction and replaces items when items are provided',
      () async {
        final id = await _insertReceiptTransaction(
          repo,
          items: [
            (name: 'Susu', quantity: 1, unitPrice: 12000, totalPrice: 12000),
          ],
        );
        final tx = (await repo.getTransactionsPage(
          limit: 50,
          offset: 0,
        )).single;

        final updated = await repo.updateTransaction(
          tx.copyWith(amount: 24000),
          items: [
            (name: 'Kopi', quantity: 2, unitPrice: 12000, totalPrice: 24000),
          ],
        );

        final items = await repo.getTransactionItems(id);
        expect(updated, isTrue);
        expect(items, hasLength(1));
        expect(items.single.name, 'Kopi');
        expect(items.single.totalPrice, 24000);
      },
    );

    test('replaces receipt items and cascades on delete', () async {
      final id = await _insertReceiptTransaction(
        repo,
        items: [
          (name: 'Susu', quantity: 1, unitPrice: 12000, totalPrice: 12000),
        ],
      );

      await repo.replaceTransactionItems(id, [
        (name: 'Kopi', quantity: 2, unitPrice: 6000, totalPrice: 12000),
      ]);
      expect((await repo.getTransactionItems(id)).single.name, 'Kopi');

      await repo.deleteTransaction(id);
      expect(await repo.getTransactionItems(id), isEmpty);
    });

    test('rolls back transaction when item insert fails', () async {
      expect(
        () => _insertReceiptTransaction(
          repo,
          items: [(name: '', quantity: 1, unitPrice: null, totalPrice: 1000)],
        ),
        throwsArgumentError,
      );

      expect(await repo.getTransactionsPage(limit: 50, offset: 0), isEmpty);
    });

    test('top receipt items report respects period filtering', () async {
      await _insertReceiptTransaction(
        repo,
        date: DateTime(2026, 8, 25),
        items: [
          (name: 'Susu', quantity: 2, unitPrice: 10000, totalPrice: 20000),
          (name: 'Roti', quantity: 1, unitPrice: null, totalPrice: 5000),
        ],
      );
      await _insertReceiptTransaction(
        repo,
        date: DateTime(2026, 7, 25),
        items: [
          (name: 'Susu', quantity: 10, unitPrice: 10000, totalPrice: 100000),
        ],
      );

      final report = await repo
          .watchReportData(
            startMs: DateTime(2026, 8).millisecondsSinceEpoch,
            endMs: DateTime(2026, 9).millisecondsSinceEpoch,
          )
          .first
          .timeout(const Duration(seconds: 2));

      expect(report.topReceiptItems.first.name, 'Susu');
      expect(report.topReceiptItems.first.quantity, 2);
      expect(report.topReceiptItems.first.total, 20000);
    });

    test('stores receipt image path metadata', () async {
      await _insertReceiptTransaction(
        repo,
        receiptImagePath: '/tmp/receipt.jpg',
        items: const [],
      );

      final tx = (await repo.getTransactionsPage(limit: 50, offset: 0)).single;
      expect(tx.receiptImagePath, '/tmp/receipt.jpg');
    });
  });
}

Future<int> _insertReceiptTransaction(
  TransactionRepository repo, {
  double amount = 12000,
  DateTime? date,
  String? receiptImagePath,
  required List<TransactionItemInput> items,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return repo.addTransaction(
    TransactionsCompanion.insert(
      type: 'expense',
      amount: amount,
      category: 'Belanja Harian',
      description: const Value('Struk Noma Mart'),
      source: 'receipt_scan',
      paymentMethod: const Value('Tunai'),
      receiptImagePath: Value(receiptImagePath),
      transactionDate: (date ?? DateTime(2026, 8, 25)).millisecondsSinceEpoch,
      createdAt: now,
      updatedAt: now,
    ),
    items: items,
  );
}

ResponseBody _geminiResponse(String text) {
  return ResponseBody.fromString(
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text},
            ],
          },
        },
      ],
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _FakeAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
