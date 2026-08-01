import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/api_key_service.dart';
import 'local_ai_engine.dart';

class GeminiApiService {
  final Dio _dio;

  static const List<String> _endpoints = [
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent',
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent',
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-8b:generateContent',
  ];

  GeminiApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 25),
                receiveTimeout: const Duration(seconds: 35),
              ),
            );

  Future<String> _getApiKey() async {
    final rawKey = await ApiKeyService.getApiKey();
    final key = ApiKeyService.sanitizeKey(rawKey);
    if (key.isEmpty || key == 'your_groq_api_key_here' || key == 'your_gemini_api_key_here') {
      throw Exception('API Key Groq belum diisi. Silakan dapatkan API Key gratis dari console.groq.com pada menu Pengaturan.');
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
            if (statusCode == 429 || msg.contains('Quota exceeded') || msg.contains('RESOURCE_EXHAUSTED')) {
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
  "payment_method": "metode pembayaran yang disebutkan (misal: Tunai, Gopay, OVO, ShopeePay, Transfer BCA, Mandiri, BRI, dll, atau 'Tunai' jika tidak ada)"
}

Catatan:
- Pastikan amount adalah angka murni tanpa pemisah titik/koma.
- Hanya kembalikan string JSON valid.
''';

    final payload = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'parts': [
            {'text': text}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'response_mime_type': 'application/json',
      }
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

  /// 2. Scan Receipt Image using Gemini Vision Multimodal API
  Future<Map<String, dynamic>> scanReceiptImage(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    const systemPrompt = '''
Kamu adalah sistem ekstraksi struk belanja untuk aplikasi keuangan "Noma".
Tugasmu adalah membaca foto struk yang diberikan dan mengembalikan data terstruktur dalam format JSON yang valid.

Format JSON yang diharapkan:
{
  "store_name": "nama toko/merchant",
  "date": "YYYY-MM-DD (jika tanggal ditemukan, jika tidak isi dengan tanggal hari ini)",
  "total": angka (integer, total belanja akhir),
  "category_suggestion": "kategori yang paling sesuai: Makanan & Minuman, Belanja Harian, Transportasi, Tagihan & Utilitas, Hiburan, Kesehatan, Fashion & Kecantikan, Rumah Tangga, Lainnya",
  "items": [
    {
      "name": "nama barang",
      "total_price": angka (integer),
      "quantity": angka (integer)
    }
  ]
}

Catatan:
- Pastikan nilai total dan total_price berupa angka murni.
- Jika foto bukan struk belanja atau teks tidak dapat dibaca, kembalikan JSON: {"error": "Foto tidak dapat dibaca atau bukan struk belanja"}
''';

    final geminiKey = await ApiKeyService.getGeminiApiKey();
    final primaryKey = await _getApiKey();
    final activeKey = geminiKey.isNotEmpty ? geminiKey : primaryKey;

    if (activeKey.isEmpty) {
      throw Exception('API Key belum diatur. Silakan atur API Key pada menu Pengaturan.');
    }

    if (activeKey.startsWith('gsk_')) {
      throw Exception('Groq API Key (gsk_) hanya mendukung teks/chat. Pemindaian foto struk membutuhkan Gemini API Key gratis (teknologi Google Lens). Silakan masukkan Gemini API Key pada Pengaturan.');
    }

    final payload = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            },
            {'text': 'Baca foto struk belanja ini dan ekstrak informasinya secara rinci dalam JSON.'}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'response_mime_type': 'application/json',
      }
    };

    try {
      final response = await _postPayloadWithFallback(payload, activeKey);

      final candidates = response.data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates.first['content'];
        final parts = content['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          final rawText = parts.first['text'] as String;
          final jsonString = _cleanJsonString(rawText);
          final result = jsonDecode(jsonString) as Map<String, dynamic>;
          if (result.containsKey('error')) {
            throw Exception(result['error']);
          }
          return result;
        }
      }
      throw Exception('Foto struk tidak terbaca. Pastikan foto terang dan teks jelas.');
    } on DioException catch (e) {
      throw Exception(_extractDioErrorMessage(e));
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// 3. Financial Chatbot Assistant Conversation
  Future<String> sendChatMessage({
    required String userMessage,
    required String financialContext,
    required List<Map<String, String>> conversationHistory,
  }) async {
    final systemPrompt = '''
Kamu adalah "Nomi", asisten AI pintar, ramah, dan serba bisa dari aplikasi Noma.
Tugasmu adalah menjawab PERTANYAAN APAPUN dari pengguna dengan cerdas, ramah, wawasan luas, dan solutif dalam Bahasa Indonesia.

Kemampuanmu:
1. Menjawab pertanyaan umum (pengetahuan umum, sains, teknologi, matematika, tips kehidupan, resep, hobi, analisis, dll).
2. Memberikan saran finansial, penghematan, investasi, dan analisis keuangan pribadi secara mendalam.
3. Memahami data keuangan pengguna jika pengguna bertanya tentang uang/saldo/pengeluaran mereka.

Konteks Data Keuangan Pengguna Saat Ini:
$financialContext

Aturan Respon:
- Jawab dengan santun, cerdas, informatif, dan praktis.
- Gunakan format Markdown (teks tebal, bullet points, angka) agar balasanmu indah dan mudah dibaca.
- Jika pengguna bertanya topik umum (bukan tentang data uangnya), tetap jawablah pertanyaan tersebut dengan sangat baik, cerdas, dan menyenangkan!
''';

    final contents = <Map<String, dynamic>>[];

    // Add multi-turn history
    for (final msg in conversationHistory) {
      contents.add({
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'parts': [
          {'text': msg['content']}
        ]
      });
    }

    // Add current user message
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ]
    });

    final payload = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
      }
    };

    try {
      final apiKey = await _getApiKey();
      if (apiKey.startsWith('gsk_')) {
        final messages = conversationHistory.map((m) {
          return {
            'role': m['role'] == 'user' ? 'user' : 'assistant',
            'content': m['content'] ?? '',
          };
        }).toList();

        messages.add({'role': 'user', 'content': userMessage});

        return await _callGroqChat(
          apiKey: apiKey,
          systemPrompt: systemPrompt,
          messages: messages,
        );
      }

      if (apiKey.startsWith('sk-or')) {
        final messages = conversationHistory.map((m) {
          return {
            'role': m['role'] == 'user' ? 'user' : 'assistant',
            'content': m['content'] ?? '',
          };
        }).toList();

        messages.add({'role': 'user', 'content': userMessage});

        return await _callOpenRouterChat(
          apiKey: apiKey,
          systemPrompt: systemPrompt,
          messages: messages,
        );
      }

      final response = await _postPayloadWithFallback(payload, apiKey);

      final candidates = response.data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates.first['content'];
        final parts = content['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          return parts.first['text'] as String;
        }
      }
      throw Exception('Gagal mendapatkan jawaban dari Nomi AI');
    } on DioException catch (e) {
      throw Exception(_extractDioErrorMessage(e));
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      if (err.contains('API Key') && err.contains('belum diisi')) {
        return LocalAiEngine.generateChatbotReply(
          userMessage: userMessage,
          financialContext: financialContext,
        );
      }
      throw Exception(err);
    }
  }

  Future<String> _callGroqChat({
    required String apiKey,
    required String systemPrompt,
    required List<Map<String, String>> messages,
  }) async {
    final formattedMessages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...messages,
    ];

    final response = await _dio.post(
      'https://api.groq.com/openai/v1/chat/completions',
      data: {
        'model': 'llama-3.3-70b-versatile',
        'messages': formattedMessages,
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
    throw Exception('Gagal mendapatkan respon dari Groq AI');
  }



  Future<Map<String, dynamic>> _callGroqJson({
    required String apiKey,
    required String systemPrompt,
    required String userText,
  }) async {
    final response = await _dio.post(
      'https://api.groq.com/openai/v1/chat/completions',
      data: {
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userText},
        ],
        'response_format': {'type': 'json_object'},
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

  Future<String> _callOpenRouterChat({
    required String apiKey,
    required String systemPrompt,
    required List<Map<String, String>> messages,
  }) async {
    final formattedMessages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...messages,
    ];

    final response = await _dio.post(
      'https://openrouter.ai/api/v1/chat/completions',
      data: {
        'model': 'meta-llama/llama-3.3-70b-instruct:free',
        'messages': formattedMessages,
        'temperature': 0.7,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://noma.app',
          'X-Title': 'Noma Financial App',
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
    throw Exception('Gagal mendapatkan respon dari OpenRouter AI');
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
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userText},
        ],
        'response_format': {'type': 'json_object'},
        'temperature': 0.1,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://noma.app',
          'X-Title': 'Noma Financial App',
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

  /// Posts payload with automatic model endpoint fallback chain & dual headers/query authentication
  Future<Response> _postPayloadWithFallback(Map<String, dynamic> payload, String apiKey) async {
    DioException? lastException;

    final options = Options(
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
    );

    for (final endpoint in _endpoints) {
      try {
        final url = '$endpoint?key=$apiKey';
        return await _dio.post(url, data: payload, options: options);
      } on DioException catch (e) {
        lastException = e;

        // Check if error is an API Key or Auth error -> rethrow immediately!
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

        // Only fallback to next model if endpoint is 404 (not found) or 429 (rate limit on specific model) or 503
        final statusCode = e.response?.statusCode;
        if (statusCode == 404 || statusCode == 429 || statusCode == 503) {
          continue;
        }

        rethrow;
      }
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

    // Fallback regex to extract JSON object if markdown stripping left extra characters
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
    if (match != null) {
      return match.group(0)!;
    }

    return cleaned;
  }
}
