import 'dart:io';

import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noma/core/database/app_database.dart';
import 'package:noma/core/services/report_export_service.dart';
import 'package:noma/features/transaction/data/transaction_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Directory temp;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    temp = await Directory.systemTemp.createTemp('noma-report-test-');
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  test('Excel contains only selected period and its receipt items', () async {
    final repo = TransactionRepository(db);
    for (final month in [7, 8]) {
      final now = DateTime(2026, month, 25).millisecondsSinceEpoch;
      await repo.addTransaction(
        TransactionsCompanion.insert(
          type: 'expense',
          amount: 12000,
          category: 'Bulan $month',
          source: 'manual',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
        items: [
          (
            name: 'Item $month',
            quantity: 1,
            unitPrice: 12000,
            totalPrice: 12000,
          ),
        ],
      );
    }
    final file = await ReportExportService(db).exportExcel(
      File('${temp.path}/report.xlsx'),
      startMs: DateTime(2026, 8).millisecondsSinceEpoch,
      endMs: DateTime(2026, 9).millisecondsSinceEpoch,
      count: 1,
    );
    final excel = Excel.decodeBytes(await file.readAsBytes());
    expect(excel['Transaksi'].rows, hasLength(2));
    expect(excel['Item Struk'].rows, hasLength(2));
    expect(
      excel['Transaksi'].rows.last[2]!.value.toString(),
      contains('Bulan 8'),
    );
    expect(
      excel['Item Struk'].rows.last[2]!.value.toString(),
      contains('Item 8'),
    );
  });

  test(
    'PDF is generated from report summary and large Excel export is refused',
    () async {
      const report = ReportData(
        summary: TransactionSummary(count: 1, income: 0, expense: 12000),
        expenseCategories: [CategoryTotal(name: 'Makanan', total: 12000)],
        topReceiptItems: [
          ReceiptItemTotal(name: 'Kopi', quantity: 1, total: 12000),
        ],
        topMerchants: [],
      );
      final service = ReportExportService(db);
      final pdf = await service.exportPdf(
        File('${temp.path}/report.pdf'),
        'Bulan Ini',
        report,
      );
      expect(await pdf.length(), greaterThan(100));
      await expectLater(
        service.exportExcel(File('${temp.path}/large.xlsx'), count: 10001),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
