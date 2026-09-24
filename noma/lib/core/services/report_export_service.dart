import 'dart:io';

import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

import '../database/app_database.dart';
import '../../features/transaction/data/transaction_repository.dart';

class ReportExportService {
  final AppDatabase db;
  const ReportExportService(this.db);

  Future<File> exportPdf(File file, String period, ReportData report) async {
    final document = pw.Document();
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/roboto-regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/roboto-bold.ttf'),
    );
    final summary = report.summary;
    String money(double amount) =>
        'Rp ${NumberFormat.decimalPattern('id_ID').format(amount)}';
    pw.Widget section(String title, Iterable<String> lines) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 16),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        ...lines.map(
          (line) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5),
            child: pw.Text(line),
          ),
        ),
      ],
    );
    document.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (_) => [
          pw.Text(
            'Laporan Noma',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Periode: $period'),
          section('Ringkasan', [
            'Pemasukan: ${money(summary.income)}',
            'Pengeluaran: ${money(summary.expense)}',
            'Selisih: ${money(summary.balance)}',
            'Jumlah transaksi: ${summary.count}',
          ]),
          section(
            'Kategori Pengeluaran',
            report.expenseCategories.map((e) => '${e.name}: ${money(e.total)}'),
          ),
          section(
            'Merchant Teratas',
            report.topMerchants.map((e) => '${e.name}: ${money(e.total)}'),
          ),
          section(
            'Barang Teratas',
            report.topReceiptItems.map((e) => '${e.name}: ${money(e.total)}'),
          ),
        ],
      ),
    );
    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }

  Future<File> exportExcel(
    File file, {
    int? startMs,
    int? endMs,
    required int count,
  }) async {
    if (count > 10000) {
      throw const FormatException(
        'Lebih dari 10.000 transaksi. Pilih periode yang lebih pendek.',
      );
    }
    final excel = Excel.createExcel();
    final transactions = excel['Transaksi'];
    final itemsSheet = excel['Item Struk'];
    transactions.appendRow(
      [
        'Tanggal',
        'Tipe',
        'Kategori',
        'Deskripsi',
        'Nominal',
        'Metode Bayar',
        'Sumber',
      ].map(TextCellValue.new).toList(),
    );
    itemsSheet.appendRow(
      [
        'Tanggal',
        'Transaksi',
        'Nama Barang',
        'Jumlah',
        'Harga Satuan',
        'Total',
      ].map(TextCellValue.new).toList(),
    );
    var offset = 0;
    while (true) {
      final query = db.select(db.transactions)
        ..orderBy([
          (t) => OrderingTerm.desc(t.transactionDate),
          (t) => OrderingTerm.desc(t.id),
        ])
        ..limit(500, offset: offset);
      if (startMs != null) {
        query.where((t) => t.transactionDate.isBiggerOrEqualValue(startMs));
      }
      if (endMs != null) {
        query.where((t) => t.transactionDate.isSmallerThanValue(endMs));
      }
      final page = await query.get();
      if (page.isEmpty) break;
      final items = await (db.select(
        db.transactionItems,
      )..where((t) => t.transactionId.isIn(page.map((tx) => tx.id)))).get();
      final byId = {for (final tx in page) tx.id: tx};
      for (final tx in page) {
        transactions.appendRow([
          TextCellValue(
            DateFormat(
              'yyyy-MM-dd',
            ).format(DateTime.fromMillisecondsSinceEpoch(tx.transactionDate)),
          ),
          TextCellValue(tx.type),
          TextCellValue(tx.category),
          TextCellValue(tx.description ?? ''),
          DoubleCellValue(tx.amount),
          TextCellValue(tx.paymentMethod ?? ''),
          TextCellValue(tx.source),
        ]);
      }
      for (final item in items) {
        final tx = byId[item.transactionId]!;
        itemsSheet.appendRow([
          TextCellValue(
            DateFormat(
              'yyyy-MM-dd',
            ).format(DateTime.fromMillisecondsSinceEpoch(tx.transactionDate)),
          ),
          TextCellValue(tx.description ?? tx.category),
          TextCellValue(item.name),
          DoubleCellValue(item.quantity),
          if (item.unitPrice == null)
            TextCellValue('')
          else
            DoubleCellValue(item.unitPrice!),
          DoubleCellValue(item.totalPrice),
        ]);
      }
      offset += page.length;
      if (page.length < 500) break;
    }
    excel.delete('Sheet1');
    final bytes = excel.save();
    if (bytes == null) throw StateError('Gagal membuat file Excel.');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
