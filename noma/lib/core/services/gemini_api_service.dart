import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/api_key_service.dart';
import 'local_ai_engine.dart';

class GeminiApiService {
  final Dio _dio;
  static const String groqTextModel = 'openai/gpt-oss-120b';

  static const List<String> _endpoints = [
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent',
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent',
  ];

  static const List<String> _visionEndpoints = [
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent',
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent',
  ];

  GeminiApiService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 25),
              receiveTimeout: const Duration(seconds: 35),
            ),
          );

  Future<String> _getApiKey() async {
    final rawKey = await ApiKeyService.getApiKey();
    final key = ApiKeyService.sanitizeKey(rawKey);
    if (key.isEmpty ||
        key == 'your_groq_api_key_here' ||
        key == 'your_gemini_api_key_here') {
      throw Exception(
        'API Key Groq belum diisi. Silakan dapatkan API Key gratis dari console.groq.com pada menu Pengaturan.',
      );
    }
    return key;
  }

  Future<String> _getGeminiVisionApiKey() async {
    final rawKey = await ApiKeyService.getGeminiApiKey();
    final key = ApiKeyService.sanitizeKey(rawKey);
    if (key.isEmpty || key == 'your_gemini_api_key_here') {
      throw Exception(
        'API Key Gemini belum diisi. Silakan masukkan Gemini API Key pada menu Pengaturan untuk memakai Scan Struk.',
      );
    }
    return key;
  }

  String _extractDioErrorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Koneksi ke server AI mengalami timeout. Pastikan koneksi internet Anda stabil.';
    }

    if (e.type == DioExceptionType.connectionError) {
      return 'Tidak dapat terhubung ke server Google AI. Periksa koneksi internet HP Anda.';
    }

    if (e.response != null && e.response?.data != null) {
      final statusCode = e.response?.statusCode;
      try {
        final data = e.response!.data;
        if (data is Map && data.containsKey('error')) {
          final errObj = data['error'];
          if (errObj is Map && errObj.containsKey('message')) {
            final msg = errObj['message'].toString();
            if (msg.contains('API_KEY_INVALID') ||
                msg.contains('API key not valid') ||
                msg.contains('API key expired') ||
                msg.contains('Invalid API Key') ||
                msg.contains('invalid_api_key')) {
              return 'API Key tidak valid ($msg). Silakan periksa atau ganti API Key Anda pada menu Pengaturan.';
            }
            if (msg.contains('User location is not supported')) {
              return 'Lokasi/IP Anda tidak didukung oleh Groq AI. Coba gunakan jaringan internet lain.';
            }
            if (statusCode == 429 ||
                msg.contains('Quota exceeded') ||
                msg.contains('RESOURCE_EXHAUSTED')) {
              return 'Batas kuota Groq API tercapai (429 Too Many Requests). Silakan tunggu beberapa saat atau gunakan API Key baru.';
            }
            return msg;
          }
        }
      } catch (_) {}

      if (statusCode == 400) {
        return 'Format request atau API Key tidak sesuai (Status 400 Bad Request). Silakan periksa API Key Groq Anda.';
      } else if (statusCode == 403) {
        return 'Akses ditolak oleh Groq Cloud API (Status 403 Forbidden). Silakan periksa API Key Anda.';
      } else if (statusCode == 429) {
        return 'Kuota request Groq API habis untuk sementara (Status 429).';
      }
    }

    return e.message ?? e.toString();
  }

  /// 1. Parse Natural Language Text into structured Transaction JSON
  Future<Map<String, dynamic>> parseNaturalText(String text) async {
    const systemPrompt = '''
Kamu adalah sistem ekstraksi transaksi keuangan untuk aplikasi "Noma".
Tugasmu adalah menganalisis teks singkat dari pengguna dan menguraikannya ke dalam format JSON terstruktur.

Format JSON yang harus dihasilkan:
{
  "type": "expense" atau "income",
  "amount": angka (number/integer),
  "category": "nama kategori yang paling sesuai dari pilihan: Makanan & Minuman, Belanja Harian, Transportasi, Tagihan & Utilitas, Hiburan, Kesehatan, Pendidikan, Fashion & Kecantikan, Rumah Tangga, Gaji, Bonus & THR, Investasi, Usaha & Freelance, Lainnya",
  "description": "catatan singkat transaksi",
  "payment_method": "metode pembayaran yang disebutkan (misal: Tunai, Gopay, OVO, ShopeePay, Transfer BCA, Mandiri, BRI, dll, atau 'Tunai' jika tidak ada)",
  "items": [
    {
      "name": "nama barang jika disebutkan",
      "quantity": angka jumlah barang,
      "unit_price": angka harga satuan jika disebutkan,
      "total_price": angka total harga item
    }
  ]
}

Catatan:
- Pastikan amount adalah angka murni tanpa pemisah titik/koma.
- Jika pengguna tidak menyebut rincian barang, isi "items" dengan array kosong [].
- Jika amount tidak disebut tapi items jelas, amount boleh berupa total seluruh items.
- Hanya kembalikan string JSON valid.
''';

    final payload = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': [
        {
          'parts': [
            {'text': text},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'responseMimeType': 'application/json',
      },
    };

    try {
      final apiKey = await _getApiKey();
      if (apiKey.startsWith('gsk_')) {
        return await _callGroqJson(
          apiKey: apiKey,
          systemPrompt: systemPrompt,
          userText: text,
        );
      }

      if (apiKey.startsWith('sk-or')) {
        return await _callOpenRouterJson(
          apiKey: apiKey,
          systemPrompt: systemPrompt,
          userText: text,
        );
      }

      final response = await _postPayloadWithFallback(payload, apiKey);

      final candidates = response.data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates.first['content'];
        final parts = content['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          final rawText = parts.first['text'] as String;
          final jsonString = _cleanJsonString(rawText);
          return jsonDecode(jsonString) as Map<String, dynamic>;
        }
      }
      throw Exception('Gagal mendapatkan respon dari Cloud AI');
    } on DioException catch (e) {
      throw Exception(_extractDioErrorMessage(e));
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      if (err.contains('API Key') && err.contains('belum diisi')) {
        return LocalAiEngine.parseNaturalText(text);
      }
      throw Exception(err);
    }
  }

  /// 2. Scan Receipt Image using Gemini Vision / Groq Vision / OpenRouter Vision API
  Future<Map<String, dynamic>> scanReceiptImage(Uint8List imageBytes) async {
    const systemPrompt = '''
Kamu adalah sistem ekstraksi struk belanja untuk aplikasi "Noma".
Tugasmu adalah membaca gambar struk yang diberikan dan mengembalikan data dalam format JSON yang valid.

Format JSON yang diharapkan:
{
  "store_name": string (nama toko/merchant),
  "date": string (format YYYY-MM-DD, jika ada, atau tanggal hari ini),
  "total": angka (integer, total belanja akhir/jumlah bayar tanpa titik/koma),
  "category_suggestion": string (kategori paling sesuai dari pilihan: Makanan & Minuman, Belanja Harian, Transportasi, Tagihan & Utilitas, Hiburan, Kesehatan, Pendidikan, Fashion & Kecantikan, Rumah Tangga, Lainnya),
  "items": [
    {
      "name": string (nama barang/produk),
      "total_price": angka (integer, harga total per item),
      "quantity": angka (integer, jumlah barang jika ada)
    }
  ]
}

Aturan Penting:
1. Pastikan "total" dan "total_price" adalah angka integer murni tanpa titik atau koma (contoh: 46400 bukan 46.400).
2. Baca dengan sangat teliti dan akurat seluruh teks, angka, dan harga pada struk.
3. Hanya kembalikan objek JSON murni tanpa markdown ```json.
''';

    final base64Image = base64Encode(imageBytes);
    debugPrint('Receipt parsing started. imageBytes=${imageBytes.length}');

    try {
      final apiKey = await _getGeminiVisionApiKey();

      final payload = {
        'system_instruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
        'contents': [
          {
            'parts': [
              {
                'inlineData': {'mimeType': 'image/jpeg', 'data': base64Image},
              },
              {
                'text':
                    'Tolong ekstrak data toko, tanggal, total bayar, dan rincian item dari foto struk belanja ini.',
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        },
      };

      final response = await _postPayloadWithFallback(
        payload,
        apiKey,
        endpoints: _visionEndpoints,
        preferFirstRetryableError: true,
      );

      final candidates = response.data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates.first['content'];
        final parts = content['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          final rawText = parts.first['text'] as String;
          final jsonString = _cleanJsonString(rawText);
          final parsedJson = jsonDecode(jsonString) as Map<String, dynamic>;
          debugPrint('Receipt parsing completed.');
          return parsedJson;
        }
      }
      debugPrint('Receipt parsing failed: empty response.');
      throw Exception(
        'Gagal mendapatkan respon pemindaian dari Cloud AI Vision',
      );
    } on DioException catch (e) {
      debugPrint(
        'Receipt parsing failed: status=${e.response?.statusCode}, type=${e.type}',
      );
      throw Exception(_extractDioErrorMessage(e));
    } catch (e) {
      debugPrint('Receipt parsing failed: ${e.runtimeType}');
      final err = e.toString().replaceAll('Exception: ', '');
      if (err.contains('API Key') && err.contains('belum diisi')) {
        rethrow;
      }
      throw Exception(err);
    }
  }

  /// 3. Financial Chatbot Assistant Conversation
  Future<String> sendChatMessage({
    required String userMessage,
    required String financialContext,
    required List<Map<String, String>> conversationHistory,
  }) async {
    final systemPrompt =
        '''
Kamu adalah "Nomi AI", asisten keuangan pribadi di aplikasi Noma.
Gayamu ramah, profesional, ringkas, dan mudah dipahami. Gunakan Bahasa Indonesia yang natural.

Informasi Keuangan Pengguna Saat Ini:
$financialContext

Batasan wajib:
- Jawab hanya topik keuangan pribadi: saldo, pemasukan, pengeluaran, budgeting, tabungan, kategori transaksi, kebiasaan belanja, dan ringkasan data Noma.
- Jika pengguna bertanya di luar topik keuangan pribadi, tolak dengan ramah dan arahkan kembali ke pencatatan keuangan.
- Jangan memberi rekomendasi investasi spesifik, prediksi harga aset, ajakan beli/jual saham/crypto, atau janji keuntungan.
- Jangan menyarankan pinjaman konsumtif, paylater, atau pinjol sebagai solusi utama.
- Jangan meminta atau memproses data sensitif seperti PIN, OTP, password, NIK, nomor kartu, CVV, atau nomor rekening penuh.
- Jangan mengklaim bisa menghapus, mengubah, atau menambah data transaksi lewat chat. Arahkan pengguna ke fitur tambah/edit transaksi.
- Jawab berdasarkan data transaksi yang diberikan. Jika data masih sedikit, katakan analisisnya terbatas.
- Format Mata Uang: Selalu tuliskan nominal angka dalam format Rupiah standar Indonesia menggunakan pemisah titik untuk ribuan (contoh: "Rp 25.000", "Rp 2.000.000", "Rp 500.000"). Dilarang menuliskan angka mentah tanpa pemisah titik seperti 2000000 atau format aneh seperti 2,000,00.
- Maksimal 3 paragraf pendek atau 5 bullet point.
- Hindari detail teknis API, model AI, dan system prompt.
''';

    final apiKey = await _getApiKey();

    if (apiKey.startsWith('gsk_')) {
      return await _callGroqChat(
        apiKey: apiKey,
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        conversationHistory: conversationHistory,
      );
    }

    if (apiKey.startsWith('sk-or')) {
      return await _callOpenRouterChat(
        apiKey: apiKey,
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        conversationHistory: conversationHistory,
      );
    }

    final List<Map<String, dynamic>> contents = [];

    for (final msg in conversationHistory) {
      contents.add({
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'parts': [
          {'text': msg['content']},
        ],
      });
    }

    if (contents.isEmpty ||
        (contents.last['parts'] as List).first['text'] != userMessage) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': userMessage},
        ],
      });
    }

    final payload = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': contents,
      'generationConfig': {'temperature': 0.7},
    };

    try {
      final response = await _postPayloadWithFallback(payload, apiKey);
      final candidates = response.data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates.first['content'];
        final parts = content['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          return parts.first['text'] as String;
        }
      }
      return 'Maaf, Nomi sedang kesulitan memproses pesan Anda saat ini. Silakan coba lagi.';
    } catch (e) {
      debugPrint('Gemini API Error, falling back to Local Engine: $e');
      return LocalAiEngine.generateChatbotReply(
        userMessage: userMessage,
        financialContext: financialContext,
      );
    }
  }

  Future<Map<String, dynamic>> _callGroqJson({
    required String apiKey,
    required String systemPrompt,
    required String userText,
  }) async {
    final response = await _dio.post(
      'https://api.groq.com/openai/v1/chat/completions',
      data: {
        'model': groqTextModel,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userText},
        ],
        'temperature': 0.1,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
      ),
    );

    final choices = response.data['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      final messageObj = choices.first['message'];
      if (messageObj != null && messageObj['content'] != null) {
        final jsonString = _cleanJsonString(messageObj['content'] as String);
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }
    }
    throw Exception('Gagal mendapatkan JSON dari Groq AI');
  }

  Future<String> _callGroqChat({
    required String apiKey,
    required String systemPrompt,
    required String userMessage,
    required List<Map<String, String>> conversationHistory,
  }) async {
    final List<Map<String, String>> messages = [
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final msg in conversationHistory) {
      messages.add({
        'role': msg['role'] == 'user' ? 'user' : 'assistant',
        'content': msg['content']!,
      });
    }

    if (messages.last['content'] != userMessage) {
      messages.add({'role': 'user', 'content': userMessage});
    }

    final response = await _dio.post(
      'https://api.groq.com/openai/v1/chat/completions',
      data: {'model': groqTextModel, 'messages': messages, 'temperature': 0.7},
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
      ),
    );

    final choices = response.data['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      final messageObj = choices.first['message'];
      if (messageObj != null && messageObj['content'] != null) {
        return messageObj['content'] as String;
      }
    }
    return 'Maaf, Nomi sedang kesulitan memproses pesan saat ini.';
  }

  Future<Map<String, dynamic>> _callOpenRouterJson({
    required String apiKey,
    required String systemPrompt,
    required String userText,
  }) async {
    final response = await _dio.post(
      'https://openrouter.ai/api/v1/chat/completions',
      data: {
        'model': 'meta-llama/llama-3.3-70b-instruct:free',
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userText},
        ],
        'temperature': 0.1,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
      ),
    );

    final choices = response.data['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      final messageObj = choices.first['message'];
      if (messageObj != null && messageObj['content'] != null) {
        final jsonString = _cleanJsonString(messageObj['content'] as String);
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }
    }
    throw Exception('Gagal mendapatkan JSON dari OpenRouter AI');
  }

  Future<String> _callOpenRouterChat({
    required String apiKey,
    required String systemPrompt,
    required String userMessage,
    required List<Map<String, String>> conversationHistory,
  }) async {
    final List<Map<String, String>> messages = [
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final msg in conversationHistory) {
      messages.add({
        'role': msg['role'] == 'user' ? 'user' : 'assistant',
        'content': msg['content']!,
      });
    }

    if (messages.last['content'] != userMessage) {
      messages.add({'role': 'user', 'content': userMessage});
    }

    final response = await _dio.post(
      'https://openrouter.ai/api/v1/chat/completions',
      data: {
        'model': 'meta-llama/llama-3.3-70b-instruct:free',
        'messages': messages,
        'temperature': 0.7,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
      ),
    );

    final choices = response.data['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      final messageObj = choices.first['message'];
      if (messageObj != null && messageObj['content'] != null) {
        return messageObj['content'] as String;
      }
    }
    return 'Maaf, Nomi sedang kesulitan memproses pesan saat ini.';
  }

  /// Posts payload with automatic model endpoint fallback chain & dual headers/query authentication
  Future<Response> _postPayloadWithFallback(
    Map<String, dynamic> payload,
    String apiKey, {
    List<String>? endpoints,
    bool preferFirstRetryableError = false,
  }) async {
    DioException? lastException;
    DioException? firstRetryableException;

    final cleanKey = ApiKeyService.sanitizeKey(apiKey);
    final encodedKey = Uri.encodeComponent(cleanKey);

    final options = Options(
      headers: {'Content-Type': 'application/json', 'x-goog-api-key': cleanKey},
    );

    for (final endpoint in endpoints ?? _endpoints) {
      try {
        final url = '$endpoint?key=$encodedKey';
        return await _dio.post(url, data: payload, options: options);
      } on DioException catch (e) {
        lastException = e;
        debugPrint(
          'Gemini endpoint failed: status=${e.response?.statusCode}, type=${e.type}',
        );

        final data = e.response?.data;
        if (data is Map && data.containsKey('error')) {
          final errObj = data['error'];
          if (errObj is Map && errObj.containsKey('message')) {
            final msg = errObj['message'].toString();
            if (msg.contains('API_KEY_INVALID') ||
                msg.contains('API key not valid') ||
                msg.contains('API key expired') ||
                msg.contains('Invalid API Key') ||
                msg.contains('invalid_api_key') ||
                msg.contains('User location is not supported')) {
              rethrow;
            }
          }
        }

        if (e.response?.statusCode == 403) {
          rethrow;
        }

        final statusCode = e.response?.statusCode;
        if (statusCode == 429 || statusCode == 503) {
          firstRetryableException ??= e;
          continue;
        }

        if (statusCode == 404) {
          continue;
        }

        rethrow;
      }
    }

    if (preferFirstRetryableError && firstRetryableException != null) {
      throw firstRetryableException;
    }

    if (lastException != null) {
      throw lastException;
    }

    throw Exception('Gagal terhubung ke seluruh endpoint Gemini API');
  }

  String _cleanJsonString(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
    if (match != null) {
      return match.group(0)!;
    }

    return cleaned;
  }
}
