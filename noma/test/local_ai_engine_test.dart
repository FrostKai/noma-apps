import 'package:flutter_test/flutter_test.dart';
import 'package:noma/core/services/local_ai_engine.dart';

void main() {
  group('LocalAiEngine NLP Parser', () {
    test('accurately extracts amount when preceded by quantity', () {
      final result1 = LocalAiEngine.parseNaturalText('Makan siang 2 orang 50000');
      expect(result1['amount'], equals(50000));
      expect(result1['type'], equals('expense'));
      expect(result1['category'], equals('Makanan & Minuman'));

      final result2 = LocalAiEngine.parseNaturalText('Beli 3 sabun 15000');
      expect(result2['amount'], equals(15000));
      expect(result2['type'], equals('expense'));
    });

    test('extracts formatted thousand separator and explicit Rp currency', () {
      final result1 = LocalAiEngine.parseNaturalText('Beli 5 buku total Rp 75.000');
      expect(result1['amount'], equals(75000));

      final result2 = LocalAiEngine.parseNaturalText('Belanja bulanan 350.000');
      expect(result2['amount'], equals(350000));
    });

    test('extracts shorthand currency suffix juta and ribu', () {
      final result1 = LocalAiEngine.parseNaturalText('Gaji bulanan 7.5 juta transfer bca');
      expect(result1['amount'], equals(7500000));
      expect(result1['type'], equals('income'));
      expect(result1['category'], equals('Gaji'));
      expect(result1['payment_method'], equals('Transfer BCA'));

      final result2 = LocalAiEngine.parseNaturalText('Kopi kenangan 2 cup 38k bayar qris');
      expect(result2['amount'], equals(38000));
      expect(result2['category'], equals('Makanan & Minuman'));

      final result3 = LocalAiEngine.parseNaturalText('Isi bensin 50rb');
      expect(result3['amount'], equals(50000));
      expect(result3['category'], equals('Transportasi'));
    });

    test('extracts small standard transaction without confusion', () {
      final result = LocalAiEngine.parseNaturalText('Parkir motor 2000');
      expect(result['amount'], equals(2000));
      expect(result['category'], equals('Transportasi'));
    });
  });
}
