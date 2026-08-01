import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/gemini_api_service.dart';

final geminiApiServiceProvider = Provider<GeminiApiService>((ref) {
  return GeminiApiService();
});
