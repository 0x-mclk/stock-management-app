import '../models/gemini_model_info.dart';

/// Şablon: Bu dosyayı `gemini_config.dart` olarak kopyalayın ve anahtarı yapıştırın.
class GeminiConfig {
  static const String _localKey = '';

  static String get apiKey {
    const fromEnv = String.fromEnvironment('GEMINI_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _localKey;
  }

  static bool get isConfigured => apiKey.trim().isNotEmpty;

  static const String defaultModelId = 'gemini-2.5-flash-lite';

  static String get model => defaultModelId;

  static const Map<String, ModelInfo> availableModels = {
    'gemini-2.5-flash-lite': ModelInfo(
      id: 'gemini-2.5-flash-lite',
      displayName: 'Gemini 2.5 Flash Lite',
      requestsPerMinute: 10,
      tokensPerMinute: 250000,
      requestsPerDay: 20,
    ),
  };

  static List<String> get fallbackModels => availableModels.keys.toList();

  static const int maxOutputTokens = 4096;
}
