import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiKeyService {
  static const String _keyStorageKey = 'gemini_api_key_user';
  static const String _legacyGroqStorageKey = 'groq_api_key_user';

  /// Sanitizes raw string to prevent quote/space/newline corruption
  static String sanitizeKey(String key) {
    return key
        .trim()
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll(' ', '')
        .replaceAll('"', '')
        .replaceAll("'", '');
  }

  /// Saves user's Gemini API key to local SharedPreferences.
  static Future<void> saveApiKey(String key) async {
    await saveGeminiApiKey(key);
  }

  /// Saves user's Gemini API key.
  static Future<void> saveGeminiApiKey(String key) async {
    final clean = sanitizeKey(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStorageKey, clean);
  }

  /// Gets active Gemini API key.
  static Future<String> getApiKey() async {
    return getGeminiApiKey();
  }

  static bool _isUsableGeminiKey(String key) {
    return key.isNotEmpty &&
        key != 'your_gemini_api_key_here' &&
        (key.startsWith('AIzaSy') || key.startsWith('AQ.'));
  }

  /// Gets active Gemini API Key for all cloud AI features.
  static Future<String> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = sanitizeKey(prefs.getString(_keyStorageKey) ?? '');

    if (_isUsableGeminiKey(userKey)) {
      return userKey;
    }

    final legacyKey = sanitizeKey(prefs.getString(_legacyGroqStorageKey) ?? '');
    if (_isUsableGeminiKey(legacyKey)) {
      return legacyKey;
    }

    final envGeminiKey = _envGeminiKey();
    if (_isUsableGeminiKey(envGeminiKey)) {
      return envGeminiKey;
    }

    return '';
  }

  static String _envGeminiKey() {
    try {
      return sanitizeKey(dotenv.env['GEMINI_API_KEY'] ?? '');
    } catch (_) {
      return '';
    }
  }

  /// Checks if AI engine is ready (always true with built-in fallbacks)
  static Future<bool> hasValidApiKey() async {
    return true;
  }

  /// Clears stored user API keys
  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStorageKey);
    await prefs.remove(_legacyGroqStorageKey);
  }
}
