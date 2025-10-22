import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  String _currentLanguage = 'ar';

  LanguageProvider() {
    loadLanguage();
  }

  String get currentLanguage => _currentLanguage;

  Future<void> changeLanguage(String newLanguage) async {
    _currentLanguage = newLanguage;

    // حفظ في SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', newLanguage);

    notifyListeners(); // يحدث كل التطبيق
  }

  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('language') ?? 'ar';
    notifyListeners();
  }
}