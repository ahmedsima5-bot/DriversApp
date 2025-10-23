import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static StreamController<Map<String, dynamic>> _messageStream = StreamController.broadcast();
  static Stream<Map<String, dynamic>> get messageStream => _messageStream.stream;

  static bool _initialized = false;

  // 🔥 دالة تهيئة الإشعارات المحسنة
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      print('🔔 Starting notification service initialization...');

      // طلب الإذن للإشعارات
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      print('📱 Notification permission: ${settings.authorizationStatus}');

      // الحصول على token
      String? token = await _firebaseMessaging.getToken();
      print('📱 FCM Token: $token');

      // تهيئة الإشعارات المحلية
      await _initializeLocalNotifications();

      // إعداد معالجات الرسائل
      _setupMessageHandlers();

      _initialized = true;
      print('✅ Notification service initialized successfully');
    } catch (e) {
      print('❌ Error initializing notification service: $e');
      rethrow;
    }
  }

  // 🔥 حفظ الـ token للسائق الحالي
  static Future<void> saveDriverToken(String driverId, String companyId) async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(driverId)
          .update({
        'fcmToken': token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
        'isOnline': true,
      });

      print('✅ FCM token saved for driver: $driverId');
    } catch (e) {
      print('❌ Error saving driver FCM token: $e');
    }
  }

  // 🔥 إزالة الـ token عند تسجيل الخروج
  static Future<void> removeDriverToken(String driverId, String companyId) async {
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(driverId)
          .update({
        'fcmToken': FieldValue.delete(),
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      print('✅ FCM token removed for driver: $driverId');
    } catch (e) {
      print('❌ Error removing driver FCM token: $e');
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload);
      },
    );

    await _createNotificationChannel();
  }

  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'driver_channel',
      'Driver Notifications',
      description: 'Channel for driver ride notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static void _setupMessageHandlers() {
    // التعامل مع الرسائل في الواجهة
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // التعامل مع الرسائل عند فتح التطبيق
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // تحديث الـ token عند التغيير
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print('🔄 FCM token refreshed: $newToken');
    });
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📲 Received foreground message: ${message.messageId}');

    final notification = message.notification;
    final data = message.data;

    await _showLocalNotification(
      notification?.title ?? 'طلب جديد',
      notification?.body ?? 'لديك طلب جديد يحتاج للتحضير',
      data,
    );

    _messageStream.add(data);
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('📲 Received background message: ${message.messageId}');
    _handleNotificationTap(message.data);
  }

  static Future<void> _showLocalNotification(
      String title,
      String body,
      Map<String, dynamic> data
      ) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'driver_channel',
      'Driver Notifications',
      channelDescription: 'Channel for driver ride notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      colorized: true,
      color: Color(0xFFFF9800),
      ledColor: Color(0xFFFF9800),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
      payload: data.toString(),
    );
  }

  static void _handleNotificationTap(String? payload) {
    if (payload == null) return;

    print('👆 Notification tapped with payload: $payload');

    // يمكن إضافة تنقل لصفحة محددة بناءً على محتوى الإشعار
    // Example: Navigate to specific request screen
  }

  // 🔥 دالة مساعدة لإرسال إشعارات مخصصة
  static Future<void> showCustomNotification({
    required String title,
    required String body,
    required String type, // 'new_request', 'assignment', 'reminder', etc.
    Map<String, dynamic>? data,
  }) async {
    await _showLocalNotification(title, body, {
      'type': type,
      ...?data,
    });
  }

  // 🔥 إشعار طلب جديد
  static Future<void> notifyNewRequest(String requestId, String fromLocation, String toLocation) async {
    await showCustomNotification(
      title: '🚗 طلب نقل جديد',
      body: 'من $fromLocation إلى $toLocation',
      type: 'new_request',
      data: {'requestId': requestId},
    );
  }

  // 🔥 إشعار تعيين طلب
  static Future<void> notifyRequestAssigned(String requestId, String driverName) async {
    await showCustomNotification(
      title: '✅ تم تعيين طلب لك',
      body: 'طلب #${requestId.substring(0, 6)} - $driverName',
      type: 'assignment',
      data: {'requestId': requestId},
    );
  }

  static Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  // 🔥 تنظيف الموارد
  static void dispose() {
    _messageStream.close();
  }
}