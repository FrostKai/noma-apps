class LocalAiEngine {
  /// Local Rule-based & Regex Parser for Indonesian financial transactions
  static Map<String, dynamic> parseNaturalText(String text) {
    final lower = text.toLowerCase().trim();

    // 1. Extract Amount
    int amount = _extractAmount(lower);

    // 2. Determine Transaction Type (Income vs Expense)
    final isIncomeKeywords = [
      'gaji',
      'bonus',
      'thr',
      'dapat uang',
      'dapat rezeki',
      'terima transfer',
      'dapat tf',
      'cashback',
      'diisi',
      'pemasukan',
      'upah',
      'freelance',
      'omset',
      'laba',
      'hasil jualan',
      'dibayar',
    ];
    bool isIncome = isIncomeKeywords.any((kw) => lower.contains(kw));

    // 3. Category Detection
    String category = _detectCategory(lower, isIncome);

    // 4. Payment Method Detection
    String paymentMethod = _detectPaymentMethod(lower);

    // 5. Clean Description
    String description = text.trim();
    if (description.isEmpty) {
      description = isIncome ? 'Pemasukan' : 'Pengeluaran';
    }

    return {
      'type': isIncome ? 'income' : 'expense',
      'amount': amount,
      'category': category,
      'description': description,
      'payment_method': paymentMethod,
    };
  }

  /// Offline Receipt Parser fallback when network or API fails
  static Map<String, dynamic> parseReceiptFallback() {
    final today = DateTime.now().toString().split(' ').first;
    return {
      'store_name': 'Struk Belanja',
      'date': today,
      'total': 0,
      'category_suggestion': 'Belanja Harian',
      'items': [
        {'name': 'Item Belanja', 'total_price': 0, 'quantity': 1},
      ],
    };
  }

  static int _extractAmount(String text) {
    // Check for "juta" or "jt" e.g., 1.5 juta, 2jt, 5 juta
    final jutaMatch = RegExp(
      r'(\d+(?:[\.,]\d+)?)\s*(?:juta|jt)',
    ).firstMatch(text);
    if (jutaMatch != null) {
      final valStr = jutaMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(valStr);
      if (val != null) {
        return (val * 1000000).toInt();
      }
    }

    // Check for "rb" / "ribu" / "k" e.g., 35rb, 35k, 50 ribu
    final ribuMatch = RegExp(
      r'(\d+(?:[\.,]\d+)?)\s*(?:ribu|rb|k\b)',
    ).firstMatch(text);
    if (ribuMatch != null) {
      final valStr = ribuMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(valStr);
      if (val != null) {
        return (val * 1000).toInt();
      }
    }

    // Check for standard numbers e.g., 35000, 150.000, 500,000, Rp 35.000
    final numMatch = RegExp(
      r'(?:rp\.?\s*)?(\d{1,3}(?:[\.,]\d{3})+|\d+)',
    ).firstMatch(text);
    if (numMatch != null) {
      final rawNum = numMatch.group(1)!.replaceAll('.', '').replaceAll(',', '');
      final parsed = int.tryParse(rawNum);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    return 0; // Default fallback if no number found
  }

  static String _detectCategory(String text, bool isIncome) {
    if (isIncome) {
      if (text.contains('bonus') || text.contains('thr')) return 'Bonus & THR';
      if (text.contains('investasi') ||
          text.contains('saham') ||
          text.contains('crypto')) {
        return 'Investasi';
      }
      if (text.contains('usaha') ||
          text.contains('jualan') ||
          text.contains('freelance') ||
          text.contains('project')) {
        return 'Usaha & Freelance';
      }
      return 'Gaji';
    }

    if (RegExp(
      r'\b(kopi|makan|minum|bakso|nasgor|nasi|resto|kafe|gofood|grabfood|siang|malam|pagi|snack|roti|susu|jus|sate|mie)\b',
    ).hasMatch(text)) {
      return 'Makanan & Minuman';
    }

    if (RegExp(
      r'\b(bensin|pertalite|pertamax|angkot|bus|kereta|krl|mrt|gojek|grab|gocar|grabcar|parkir|tol|ojek|taxi)\b',
    ).hasMatch(text)) {
      return 'Transportasi';
    }

    if (RegExp(
      r'\b(listrik|token|air|pdam|pulsa|kuota|wifi|indihome|paket data|tagihan|bpjs|sewa|kontrakan|kos)\b',
    ).hasMatch(text)) {
      return 'Tagihan & Utilitas';
    }

    if (RegExp(
      r'\b(baju|celana|kaos|sepatu|tas|skincare|makeup|potong rambut|salon|barbershop|skincare|serum)\b',
    ).hasMatch(text)) {
      return 'Fashion & Kecantikan';
    }

    if (RegExp(
      r'\b(tokopedia|shopee|lazada|minimarket|indomaret|alfa|alfamart|supermarket|belanja|sabun|shampoo)\b',
    ).hasMatch(text)) {
      return 'Belanja Harian';
    }

    if (RegExp(
      r'\b(nonton|bioskop|cgv|xxi|game|steam|spotify|netflix|youtube|hiburan|rekreasi|pantai|liburan)\b',
    ).hasMatch(text)) {
      return 'Hiburan';
    }

    if (RegExp(
      r'\b(obat|dokter|apotek|vit|vitamin|rumah sakit|klinik|tes)\b',
    ).hasMatch(text)) {
      return 'Kesehatan';
    }

    if (RegExp(
      r'\b(buku|kursus|kuliah|sekolah|spp|udemy|les)\b',
    ).hasMatch(text)) {
      return 'Pendidikan';
    }

    if (RegExp(r'\b(sabun|sapu|perabot|kasur|lampu|dapur)\b').hasMatch(text)) {
      return 'Rumah Tangga';
    }

    return 'Lainnya';
  }

  static String _detectPaymentMethod(String text) {
    if (text.contains('gopay')) return 'Gopay';
    if (text.contains('ovo')) return 'OVO';
    if (text.contains('shopeepay')) return 'ShopeePay';
    if (text.contains('dana')) return 'DANA';
    if (text.contains('bca')) return 'Transfer BCA';
    if (text.contains('mandiri')) return 'Transfer Mandiri';
    if (text.contains('bri')) return 'Transfer BRI';
    if (text.contains('bni')) return 'Transfer BNI';
    if (text.contains('qris')) return 'QRIS';
    if (text.contains('debit') || text.contains('kartu')) return 'Kartu Debit';
    return 'Tunai';
  }

  /// Offline Chatbot response generator based on financial context
  static String generateChatbotReply({
    required String userMessage,
    required String financialContext,
  }) {
    final lower = userMessage.toLowerCase().trim();

    int balance = 0;
    int income = 0;
    int expense = 0;
    int monthIncome = 0;
    int monthExpense = 0;

    final balanceMatch = RegExp(r'Total Saldo (?:Bersih)?:\s*Rp\s*(-?[\d\.]+)').firstMatch(financialContext);
    if (balanceMatch != null) balance = int.tryParse(balanceMatch.group(1)!.replaceAll('.', '')) ?? 0;

    final incomeMatch = RegExp(r'Total Pemasukan (?:Keseluruhan)?:\s*Rp\s*(-?[\d\.]+)').firstMatch(financialContext);
    if (incomeMatch != null) income = int.tryParse(incomeMatch.group(1)!.replaceAll('.', '')) ?? 0;

    final expenseMatch = RegExp(r'Total Pengeluaran (?:Keseluruhan)?:\s*Rp\s*(-?[\d\.]+)').firstMatch(financialContext);
    if (expenseMatch != null) expense = int.tryParse(expenseMatch.group(1)!.replaceAll('.', '')) ?? 0;

    final monthIncMatch = RegExp(r'Pemasukan Bulan Ini:\s*Rp\s*(-?[\d\.]+)').firstMatch(financialContext);
    if (monthIncMatch != null) monthIncome = int.tryParse(monthIncMatch.group(1)!.replaceAll('.', '')) ?? 0;

    final monthExpMatch = RegExp(r'Pengeluaran Bulan Ini:\s*Rp\s*(-?[\d\.]+)').firstMatch(financialContext);
    if (monthExpMatch != null) monthExpense = int.tryParse(monthExpMatch.group(1)!.replaceAll('.', '')) ?? 0;

    if (_containsSensitiveDataRequest(lower)) {
      return 'Aku tidak bisa meminta atau memproses data sensitif seperti PIN, OTP, password, NIK, nomor kartu, CVV, atau nomor rekening penuh.\n\n'
          'Kalau kamu ingin membahas keuangan, cukup gunakan ringkasan nominal, kategori, atau kebiasaan pengeluaran tanpa data rahasia.';
    }

    if (_containsDataMutationRequest(lower)) {
      return 'Aku belum bisa menghapus, mengubah, atau menambahkan transaksi langsung lewat chat.\n\n'
          'Untuk menjaga data tetap aman, gunakan tombol tambah/edit transaksi di aplikasi Noma.';
    }

    if (_containsHighRiskInvestmentRequest(lower)) {
      return 'Aku tidak bisa memberi rekomendasi beli/jual saham, crypto, atau prediksi harga aset tertentu.\n\n'
          'Yang bisa aku bantu adalah membuat anggaran, mengecek kemampuan menabung, menyiapkan dana darurat, dan mengingatkan risiko sebelum berinvestasi.';
    }

    if (!_isGreeting(lower) && !_isFinanceRelated(lower)) {
      return 'Aku fokus membantu soal keuangan pribadi di Noma.\n\n'
          'Coba tanyakan tentang saldo, pengeluaran, pemasukan, kategori terbesar, budgeting, atau tips hemat berdasarkan transaksi kamu.';
    }

    if (lower.contains('kategori') || lower.contains('terbesar') || lower.contains('terbanyak')) {
      final catStartIndex = financialContext.indexOf('Pengeluaran Berdasarkan Kategori');
      if (catStartIndex != -1) {
        final catEndIndex = financialContext.indexOf('5 Transaksi Terakhir', catStartIndex);
        final catBlock = catEndIndex != -1
            ? financialContext.substring(catStartIndex, catEndIndex)
            : financialContext.substring(catStartIndex);

        return '**Top Pengeluaran Berdasarkan Kategori:**\n\n'
            '${catBlock.replaceAll('Pengeluaran Berdasarkan Kategori (Urut Terbesar):', '').trim()}\n\n'
            'Evaluasi kategori dengan porsi pengeluaran terbesar untuk meningkatkan potensi tabunganmu!';
      }
    }

    if (lower.contains('terakhir') || lower.contains('riwayat') || lower.contains('terbaru')) {
      final recentStartIndex = financialContext.indexOf('5 Transaksi Terakhir:');
      if (recentStartIndex != -1) {
        final recentBlock = financialContext.substring(recentStartIndex);
        return '**Catatan 5 Transaksi Terakhir:**\n\n'
            '${recentBlock.replaceAll('5 Transaksi Terakhir:', '').trim()}';
      }
    }

    if (lower.contains('saldo') || lower.contains('uangku') || lower.contains('uang saya')) {
      return '**Total Saldo Anda Saat Ini:**\n'
          'Rp ${_formatRupiah(balance)}\n\n'
          '• Total Pemasukan: Rp ${_formatRupiah(income)}\n'
          '• Total Pengeluaran: Rp ${_formatRupiah(expense)}\n\n'
          '${balance >= 0 ? "Keuangan Anda dalam kondisi positif! Tetap pertahankan penghematan." : "Perhatian: Total pengeluaran Anda melebihi pemasukan."}';
    }

    if (lower.contains('bulan ini')) {
      return '**Ringkasan Keuangan Bulan Ini:**\n\n'
          '• Pemasukan Bulan Ini: **Rp ${_formatRupiah(monthIncome > 0 ? monthIncome : income)}**\n'
          '• Pengeluaran Bulan Ini: **Rp ${_formatRupiah(monthExpense > 0 ? monthExpense : expense)}**\n\n'
          'Selisih bulan ini: **Rp ${_formatRupiah((monthIncome > 0 ? monthIncome : income) - (monthExpense > 0 ? monthExpense : expense))}**';
    }

    if (lower.contains('pengeluaran') || lower.contains('keluar') || lower.contains('habis')) {
      return '**Ringkasan Pengeluaran:**\n'
          'Total pengeluaran Anda saat ini adalah **Rp ${_formatRupiah(expense)}**.\n\n'
          '${expense > 0 ? "Pastikan Anda mencatat setiap detail transaksi harian agar arus kas tetap terkontrol dengan baik." : "Belum ada pengeluaran yang tercatat untuk periode ini."}';
    }

    if (lower.contains('pemasukan') || lower.contains('masuk') || lower.contains('gaji')) {
      return '**Ringkasan Pemasukan:**\n'
          'Total pemasukan yang tercatat sejauh ini adalah **Rp ${_formatRupiah(income)}**.\n\n'
          'Alokasikan setidaknya 20% dari pemasukan untuk tabungan atau dana darurat!';
    }

    if (lower.contains('saran') || lower.contains('hemat') || lower.contains('tips') || lower.contains('solusi')) {
      return '**Tips & Saran Penghematan Keuangan Nomi:**\n\n'
          '1. **Aturan 50/30/20:** Alokasikan 50% untuk kebutuhan pokok, 30% untuk keinginan, dan 20% untuk tabungan/investasi.\n'
          '2. **Evaluasi Pengeluaran Makanan & Jajan:** Batasi pembelian kopi/makanan pesan-antar yang sering jadi *leaky budget*.\n'
          '3. **Dana Darurat:** Usahakan memiliki tabungan setara 3-6 bulan pengeluaran harian.';
    }

    if (_isGreeting(lower)) {
      return 'Halo! Saya **Nomi**, asisten keuangan pribadi Anda.\n\n'
          'Saya bisa membantu menganalisis saldo, pengeluaran, pemasukan, kategori terbesar, dan tips penghematan berdasarkan data Noma. Ada yang mau dicek?';
    }

    return 'Terima kasih atas pertanyaannya!\n\n'
        'Berdasarkan data keuangan Anda saat ini:\n'
        '• **Saldo:** Rp ${_formatRupiah(balance)}\n'
        '• **Pemasukan:** Rp ${_formatRupiah(income)}\n'
        '• **Pengeluaran:** Rp ${_formatRupiah(expense)}\n\n'
        'Anda dapat bertanya tentang *"Berapa saldo saya?"*, *"Kategori terbesar?"*, *"Transaksi terakhir"*, atau *"Beri saran hemat"*!';
  }

  static bool _containsSensitiveDataRequest(String text) {
    return RegExp(
      r'\b(pin|otp|password|kata sandi|nik|ktp|cvv|nomor kartu|no kartu|rekening penuh|nomor rekening penuh)\b',
    ).hasMatch(text);
  }

  static bool _containsDataMutationRequest(String text) {
    final hasMutationVerb = RegExp(
      r'\b(hapus|delete|ubah|edit|ganti|tambahkan|tambah|catatkan|simpan)\b',
    ).hasMatch(text);
    final hasTransactionObject = RegExp(
      r'\b(transaksi|pengeluaran|pemasukan|catatan|riwayat)\b',
    ).hasMatch(text);
    return hasMutationVerb && hasTransactionObject;
  }

  static bool _containsHighRiskInvestmentRequest(String text) {
    final hasAsset = RegExp(
      r'\b(saham|crypto|kripto|bitcoin|btc|ethereum|eth|forex|reksadana|aset)\b',
    ).hasMatch(text);
    final hasAdviceVerb = RegExp(
      r'\b(beli|jual|buy|sell|rekomendasi|prediksi|naik|turun|cuan|profit|untung pasti)\b',
    ).hasMatch(text);
    return hasAsset && hasAdviceVerb;
  }

  static bool _isGreeting(String text) {
    return RegExp(
      r'\b(halo|hai|hi|pagi|siang|sore|malam|siapa kamu|kamu siapa|nomi)\b',
    ).hasMatch(text);
  }

  static bool _isFinanceRelated(String text) {
    return RegExp(
      r'\b(saldo|uang|duit|keuangan|finansial|pemasukan|pengeluaran|income|expense|gaji|bonus|thr|belanja|jajan|hemat|budget|anggaran|tabungan|menabung|dana darurat|kategori|transaksi|tagihan|utang|cicilan|paylater|pinjaman|dompet|laporan|bulan ini|minggu ini|hari ini)\b',
    ).hasMatch(text);
  }

  static String _formatRupiah(int amount) {
    final str = amount.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return amount < 0 ? '-${buffer.toString()}' : buffer.toString();
  }
}
