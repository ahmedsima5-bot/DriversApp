import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const String _languageKey = 'selected_language';

  static Future<void> setLanguage(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
      print('💾 اللغة saved: $languageCode');
    } catch (e) {
      print('❌ Error saving language: $e');
    }
  }

  static Future<String> getLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final language = prefs.getString(_languageKey) ?? 'ar';
      print('📖 اللغة loaded: $language');
      return language;
    } catch (e) {
      print('❌ Error loading language: $e');
      return 'ar';
    }
  }
}