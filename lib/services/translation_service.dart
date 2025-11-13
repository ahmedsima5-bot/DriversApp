import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  static const String _baseUrl = 'https://translation.googleapis.com/language/translate/v2';
  static String? _apiKey;

  static void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  static Future<String> translateText({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'auto',
  }) async {
    if (_apiKey == null) {
      throw Exception('Google Translate API key not set');
    }

    // إذا النص فارغ أو قصير جداً، لا داعي للترجمة
    if (text.trim().isEmpty || text.trim().length < 2) {
      return text;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'q': text,
          'target': targetLanguage,
          'source': sourceLanguage,
          'format': 'text'
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final translatedText = data['data']['translations'][0]['translatedText'];
        return translatedText;
      } else {
        print('Translation API error: ${response.statusCode} - ${response.body}');
        return text; // إرجاع النص الأصلي في حالة الخطأ
      }
    } catch (e) {
      print('Translation error: $e');
      return text; // إرجاع النص الأصلي في حالة الخطأ
    }
  }

  // دالة مساعدة للكشف التلقائي عن لغة النص
  static Future<String> detectLanguage(String text) async {
    if (_apiKey == null) {
      throw Exception('Google Translate API key not set');
    }

    try {
      final response = await http.post(
        Uri.parse('https://translation.googleapis.com/language/translate/v2/detect?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'q': text,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final detectedLanguage = data['data']['detections'][0][0]['language'];
        return detectedLanguage;
      } else {
        return 'en'; // إفتراضي إنجليزي في حالة الخطأ
      }
    } catch (e) {
      print('Language detection error: $e');
      return 'en';
    }
  }
}