import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// في language_provider.dart
class LanguageProvider with ChangeNotifier {
  String _currentLanguage = 'ar';

  String get currentLanguage => _currentLanguage;

  // 🔥 التعديل: دالة التهيئة مع معالجة الأخطاء
  Future<void> _initializeLanguage() async {
    try {
      await loadLanguage();
    } catch (e) {
      print('❌ Error initializing language: $e');
      _currentLanguage = 'ar';
    }
  }

  // 🔥 التعديل: دالة تغيير اللغة المحسنة
  Future<void> setLanguage(String newLanguage) async {
    if (_currentLanguage == newLanguage) return; // لا داعي للتحديث إذا نفس اللغة

    _currentLanguage = newLanguage;

    try {
      // حفظ في SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', newLanguage);
      print('💾 Language saved: $newLanguage');
    } catch (e) {
      print('❌ Error saving language: $e');
      // نستمر في العمل حتى لو فشل الحفظ
    }

    notifyListeners(); // يحدث كل التطبيق
  }
  Future<void> loadUserLanguage(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists && userDoc.data()?['language'] != null) {
        _currentLanguage = userDoc.data()?['language'];
        notifyListeners();
        debugPrint('✅ Loaded user language: $_currentLanguage');
      }
    } catch (e) {
      debugPrint('❌ Error loading user language: $e');
    }
  }

  // دالة جديدة لحفظ لغة المستخدم في Firebase
  Future<void> saveUserLanguage(String userId, String language) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'language': language});

      _currentLanguage = language;
      notifyListeners();
      debugPrint('✅ Saved user language: $language');
    } catch (e) {
      debugPrint('❌ Error saving user language: $e');
    }
  }

  void changeLanguage(String language) {
    _currentLanguage = language;
    notifyListeners();
  }

  // 🔥 التعديل: دالة تحميل اللغة المحسنة
  Future<void> loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('language');

      if (savedLanguage != null && savedLanguage.isNotEmpty) {
        _currentLanguage = savedLanguage;
        print('📖 Language loaded: $savedLanguage');
      } else {
        _currentLanguage = 'ar'; // القيمة الافتراضية
        print('🌍 Default language set: ar');
      }
    } catch (e) {
      print('❌ Error loading language: $e');
      _currentLanguage = 'ar'; // القيمة الافتراضية في حالة الخطأ
    }

    notifyListeners();
  }

  // 🔥 التعديل الجديد: دالة التهيئة للاستخدام من main.dart
  Future<void> initialize(String savedLanguage) async {
    if (savedLanguage.isNotEmpty) {
      _currentLanguage = savedLanguage;
      print('🎯 Language initialized from main: $savedLanguage');
    } else {
      await loadLanguage();
    }
    notifyListeners();
  }

  // 🔥 التعديل الجديد: دالة للتبديل بين اللغات
  Future<void> toggleLanguage() async {
    final newLanguage = _currentLanguage == 'ar' ? 'en' : 'ar';
    await setLanguage(newLanguage);
  }

  // 🔥 التعديل الجديد: دالة للتحقق من اللغة الحالية
  bool get isArabic => _currentLanguage == 'ar';
  bool get isEnglish => _currentLanguage == 'en';

  // 🔥 التعديل الجديد: دالة للحصول على اسم اللغة
  String get languageName {
    switch (_currentLanguage) {
      case 'ar':
        return 'العربية';
      case 'en':
        return 'English';
      default:
        return 'العربية';
    }
  }

  // 🔥 التعديل الجديد: دالة للحصول على اتجاه النص
  TextDirection get textDirection {
    return _currentLanguage == 'ar' ? TextDirection.rtl : TextDirection.ltr;
  }

  // 🔥 التعديل الجديد: دالة للتحقق من اتجاه RTL
  bool get isRTL => _currentLanguage == 'ar';

  // 🔥 التعديل الجديد: دالة لإعادة التعيين
  Future<void> resetToDefault() async {
    await setLanguage('ar');
  }

  // 🔥 التعديل الجديد: دالة للتحقق من دعم اللغة
  bool isLanguageSupported(String languageCode) {
    return ['ar', 'en'].contains(languageCode);
  }
}