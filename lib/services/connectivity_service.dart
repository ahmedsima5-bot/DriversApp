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

  // 4. دالة للتحقق الفوري من الحالة الحالية للاتصال
  static Future<bool> isConnected() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }
}