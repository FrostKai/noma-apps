import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiKeyService {
  static const String _keyStorageKey = 'gemini_api_key_user';

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

  /// Saves user's custom Gemini API key to local SharedPreferences
  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStorageKey, sanitizeKey(key));
  }

  /// Gets active Gemini API key (User Key from SharedPreferences -> fallback to .env)
  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = sanitizeKey(prefs.getString(_keyStorageKey) ?? '');

    if (userKey.isNotEmpty && userKey != 'your_gemini_api_key_here') {
      return userKey;
    }

    // Fallback to .env file
    final envKey = sanitizeKey(dotenv.env['GEMINI_API_KEY'] ?? '');
    if (envKey.isNotEmpty && envKey != 'your_gemini_api_key_here') {
      return envKey;
    }

    return '';
  }

  /// Checks if a valid API key exists
  static Future<bool> hasValidApiKey() async {
    final key = await getApiKey();
    return key.isNotEmpty && key != 'your_gemini_api_key_here';
  }

  /// Clears stored user API key
  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStorageKey);
  }
}
