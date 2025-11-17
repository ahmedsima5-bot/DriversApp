import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  StorageService(this._prefs);

  // حفظ بيانات الدخول بشكل آمن
  Future<void> saveLoginCredentials(String email, String password) async {
    await _secureStorage.write(key: 'saved_email', value: email);
    await _secureStorage.write(key: 'saved_password', value: password);
    await _prefs.setBool('remember_me', true);
  }

  // جلب بيانات الدخول المحفوظة
  Future<Map<String, String?>> getSavedCredentials() async {
    final email = await _secureStorage.read(key: 'saved_email');
    final password = await _secureStorage.read(key: 'saved_password');
    return {'email': email, 'password': password};
  }

  // التحقق من تفعيل خيار "تذكرني"
  bool get rememberMe => _prefs.getBool('remember_me') ?? false;

  // حفظ إعدادات البصمة
  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool('biometric_enabled', enabled);
  }

  // التحقق من تفعيل البصمة
  bool get isBiometricEnabled => _prefs.getBool('biometric_enabled') ?? false;

  // مسح البيانات المحفوظة
  Future<void> clearSavedCredentials() async {
    await _secureStorage.delete(key: 'saved_email');
    await _secureStorage.delete(key: 'saved_password');
    await _prefs.setBool('remember_me', false);
    await _prefs.setBool('biometric_enabled', false);
  }
}