import 'package:flutter_test/flutter_test.dart';
import 'package:noma/core/services/api_key_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saveApiKey stores and returns Gemini key', () async {
    SharedPreferences.setMockInitialValues({});

    await ApiKeyService.saveApiKey(' "AIzaSyTestKey12345678901234567890" ');

    expect(
      await ApiKeyService.getApiKey(),
      'AIzaSyTestKey12345678901234567890',
    );
    expect(
      await ApiKeyService.getGeminiApiKey(),
      'AIzaSyTestKey12345678901234567890',
    );
  });

  test('ignores legacy Groq key when looking up Gemini key', () async {
    SharedPreferences.setMockInitialValues({
      'groq_api_key_user': 'gsk_old_key',
    });

    expect(await ApiKeyService.getApiKey(), isEmpty);
    expect(await ApiKeyService.getGeminiApiKey(), isEmpty);
  });

  test('reads Gemini key stored in legacy primary slot', () async {
    SharedPreferences.setMockInitialValues({
      'groq_api_key_user': 'AIzaSyLegacyGeminiKey123456789012345',
    });

    expect(
      await ApiKeyService.getGeminiApiKey(),
      'AIzaSyLegacyGeminiKey123456789012345',
    );
  });
}
