import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiKeyService {
  static const String _keyStorageKey = 'groq_api_key_user';
  static const String _legacyKeyStorageKey = 'gemini_api_key_user';

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

  /// Saves user's custom Groq or Gemini API key to local SharedPreferences
  static Future<void> saveApiKey(String key) async {
    final clean = sanitizeKey(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStorageKey, clean);
    if (clean.startsWith('AIzaSy')) {
      await prefs.setString(_legacyKeyStorageKey, clean);
    }
  }

  /// Saves user's custom Gemini API key specifically for Vision features
  static Future<void> saveGeminiApiKey(String key) async {
    final clean = sanitizeKey(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_legacyKeyStorageKey, clean);
  }

  /// Gets active primary API key (Groq or Gemini)
  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = sanitizeKey(prefs.getString(_keyStorageKey) ?? prefs.getString(_legacyKeyStorageKey) ?? '');

    if (userKey.isNotEmpty &&
        userKey != 'your_groq_api_key_here' &&
        userKey != 'your_gemini_api_key_here') {
      return userKey;
    }

    final envKey = sanitizeKey(dotenv.env['GROQ_API_KEY'] ?? dotenv.env['GEMINI_API_KEY'] ?? '');
    if (envKey.isNotEmpty &&
        envKey != 'your_groq_api_key_here' &&
        envKey != 'your_gemini_api_key_here') {
      return envKey;
    }

    return '';
  }

  /// Gets active Gemini API Key specifically for Vision features (Google Lens tech)
  static Future<String> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final geminiUserKey = sanitizeKey(prefs.getString(_legacyKeyStorageKey) ?? '');
    if (geminiUserKey.isNotEmpty && geminiUserKey.startsWith('AIzaSy')) {
      return geminiUserKey;
    }

    final primaryKey = await getApiKey();
    if (primaryKey.startsWith('AIzaSy')) {
      return primaryKey;
    }

    final envGeminiKey = sanitizeKey(dotenv.env['GEMINI_API_KEY'] ?? '');
    if (envGeminiKey.isNotEmpty && envGeminiKey.startsWith('AIzaSy')) {
      return envGeminiKey;
    }

    return '';
  }

  /// Checks if a valid API key exists
  static Future<bool> hasValidApiKey() async {
    final key = await getApiKey();
    return key.isNotEmpty &&
        key != 'your_groq_api_key_here' &&
        key != 'your_gemini_api_key_here';
  }

  /// Clears stored user API keys
  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStorageKey);
    await prefs.remove(_legacyKeyStorageKey);
  }
}
