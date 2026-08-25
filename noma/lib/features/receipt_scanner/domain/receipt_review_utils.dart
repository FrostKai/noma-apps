import '../../transaction/data/transaction_repository.dart';

class ReceiptReviewData {
  final String merchant;
  final String dateText;
  final double total;
  final String category;
  final List<TransactionItemInput> items;

  const ReceiptReviewData({
    required this.merchant,
    required this.dateText,
    required this.total,
    required this.category,
    required this.items,
  });
}

class ReceiptReviewUtils {
  ReceiptReviewUtils._();

  static ReceiptReviewData fromScanResult(Map<String, dynamic> result) {
    return ReceiptReviewData(
      merchant: extractMerchant(result),
      dateText: (result['date'] as String?)?.trim() ?? '',
      total: extractTotalAmount(result),
      category:
          (result['category_suggestion'] as String?)?.trim().isNotEmpty == true
          ? (result['category_suggestion'] as String).trim()
          : 'Belanja Harian',
      items: extractReceiptItems((result['items'] as List?) ?? const []),
    );
  }

  static String? validateScanResult(Map<String, dynamic> result) {
    final aiError = result['error'];
    if (aiError is String && aiError.trim().isNotEmpty) {
      return aiError;
    }

    final total = extractTotalAmount(result);
    if (total <= 0) {
      return 'Total struk tidak terbaca. Silakan scan ulang dengan foto yang lebih jelas atau input manual.';
    }

    return null;
  }

  static String extractMerchant(Map<String, dynamic> result) {
    final raw =
        result['store_name'] ?? result['merchant'] ?? result['toko'] ?? '';
    final merchant = raw.toString().trim();
    return merchant.isEmpty ? 'Struk Belanja' : merchant;
  }

  static double extractTotalAmount(Map<String, dynamic> result) {
    final items = (result['items'] as List?) ?? const [];
    final rawTotal =
        result['total'] ??
        result['total_amount'] ??
        result['grand_total'] ??
        result['jumlah_total'] ??
        result['total_harga'] ??
        result['total_belanja'] ??
        result['amount'];

    var extractedTotal = parseAmount(rawTotal);

    if (extractedTotal == 0.0 && items.isNotEmpty) {
      for (final item in items) {
        if (item is Map) {
          extractedTotal += parseAmount(
            item['total_price'] ?? item['price'] ?? item['harga'],
          );
        }
      }
    }

    return extractedTotal;
  }

  static List<TransactionItemInput> extractReceiptItems(List items) {
    final parsedItems = <TransactionItemInput>[];

    for (final rawItem in items) {
      if (rawItem is! Map) continue;

      final name = (rawItem['name'] ?? rawItem['nama'] ?? rawItem['item'] ?? '')
          .toString()
          .trim();
      if (name.isEmpty) continue;

      final quantity = parseQuantity(
        rawItem['quantity'] ?? rawItem['qty'] ?? rawItem['jumlah'],
      );
      final normalizedQuantity = quantity <= 0 ? 1.0 : quantity;
      final unitPrice = parseAmount(
        rawItem['unit_price'] ??
            rawItem['price_per_item'] ??
            rawItem['harga_satuan'],
      );
      var totalPrice = parseAmount(
        rawItem['total_price'] ?? rawItem['price'] ?? rawItem['harga'],
      );
      if (totalPrice <= 0 && unitPrice > 0) {
        totalPrice = normalizedQuantity * unitPrice;
      }

      if (totalPrice <= 0) continue;

      parsedItems.add((
        name: name,
        quantity: normalizedQuantity,
        unitPrice: unitPrice > 0 ? unitPrice : null,
        totalPrice: totalPrice,
      ));
    }

    return parsedItems;
  }

  static TransactionItemInput normalizeItem({
    required String name,
    required double quantity,
    double? unitPrice,
    double? totalPrice,
  }) {
    final normalizedQuantity = quantity <= 0 ? 1.0 : quantity;
    final normalizedUnit = unitPrice != null && unitPrice > 0
        ? unitPrice
        : null;
    final normalizedTotal = totalPrice != null && totalPrice > 0
        ? totalPrice
        : (normalizedUnit ?? 0) * normalizedQuantity;

    return (
      name: name.trim(),
      quantity: normalizedQuantity,
      unitPrice: normalizedUnit,
      totalPrice: normalizedTotal,
    );
  }

  static double parseAmount(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final cleaned = val.replaceAll(RegExp(r'[^\d]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  static double parseQuantity(dynamic val) {
    if (val == null) return 1.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final cleaned = val
          .replaceAll(',', '.')
          .replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned) ?? 1.0;
    }
    return 1.0;
  }

  static double totalItems(List<TransactionItemInput> items) {
    return items.fold<double>(0, (total, item) => total + item.totalPrice);
  }

  static double totalDifference(
    double transactionTotal,
    List<TransactionItemInput> items,
  ) {
    if (items.isEmpty) return 0.0;
    return transactionTotal - totalItems(items);
  }

  static bool hasTotalMismatch(
    double transactionTotal,
    List<TransactionItemInput> items,
  ) {
    return totalDifference(transactionTotal, items).abs() >= 1;
  }
}
