import 'package:flutter/material.dart';

class SimpleNotificationService {
  // عرض إشعارات محلية بسيطة
  static void showNotification(BuildContext context, {
    required String title,
    required String message,
    Color color = Colors.orange,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(message),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  // إشعار طلب جديد
  static void notifyNewRequest(BuildContext context, String requestId) {
    showNotification(
      context,
      title: '🚗 طلب نقل جديد',
      message: 'تم استلام طلب جديد #${requestId.substring(0, 6)}',
      color: Colors.green,
    );
  }

  // إشعار تعيين طلب
  static void notifyRequestAssigned(BuildContext context, String requestId) {
    showNotification(
      context,
      title: '✅ تم التعيين',
      message: 'تم تعيين الطلب #${requestId.substring(0, 6)} لك',
      color: Colors.blue,
    );
  }

  // إشعار بدء الرحلة
  static void notifyRideStarted(BuildContext context, String requestId) {
    showNotification(
      context,
      title: '🚀 بدء الرحلة',
      message: 'تم بدء الرحلة للطلب #${requestId.substring(0, 6)}',
      color: Colors.orange,
    );
  }

  // إشعار إنهاء الرحلة
  static void notifyRideCompleted(BuildContext context, String requestId) {
    showNotification(
      context,
      title: '🏁 انتهت الرحلة',
      message: 'تم إنهاء الرحلة للطلب #${requestId.substring(0, 6)}',
      color: Colors.green,
    );
  }

  // إشعار خطأ
  static void notifyError(BuildContext context, String message) {
    showNotification(
      context,
      title: '❌ خطأ',
      message: message,
      color: Colors.red,
    );
  }

  // إشعار نجاح
  static void notifySuccess(BuildContext context, String message) {
    showNotification(
      context,
      title: '✅ تم بنجاح',
      message: message,
      color: Colors.green,
    );
  }
}