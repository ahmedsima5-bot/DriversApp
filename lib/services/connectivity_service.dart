import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

// هذا الكلاس مصمم ليكون Singleton (نسخة واحدة فقط) ليتم استخدامه في جميع أنحاء التطبيق.
class ConnectivityService {
  // 1. إنشاء نسخة واحدة فقط من الكلاس
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal() {
    // الجديد
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // نستخدم النتيجة الأولى، أو يمكنك دمج النتائج حسب الحاجة
      _controller.add(results.first);
    });
  }

  // 2. StreamController لتتبع التغييرات
  final StreamController<ConnectivityResult> _controller =
  StreamController<ConnectivityResult>.broadcast();

  // 3. Getter يتيح الوصول إلى Stream لمراقبة تغييرات الاتصال
  Stream<ConnectivityResult> get connectivityStream => _controller.stream;

  // هذا هو التعديل الوحيد المطلوب في ملف الخدمة
  static Future<bool> isConnected() async {
    final results = await Connectivity().checkConnectivity();

    // نستخدم results.contains(ConnectivityResult.none) للتحقق مما إذا كانت القائمة تحتوي على عدم اتصال
    return !results.contains(ConnectivityResult.none);
  }
}