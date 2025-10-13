import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'services/firebase_options.dart';
import '../Screens/role_router_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // تحديد خيارات Firebase للمنصة الحالية
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (e) {
    // إذا فشلت التهيئة، سنعرض الخطأ في Console.
    print("Firebase Initialization Error: $e");
    // عرض شاشة خطأ مخصصة للمستخدم
    runApp(const ErrorApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام إدارة السائقين',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // 🚨 الآن، نقطة البداية هي شاشة التوزيع
      home: const RoleRouterScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// إضافة App بسيط لإظهار الخطأ إذا فشلت التهيئة
class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            "خطأ في تهيئة النظام. يرجى التحقق من إعدادات Firebase.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red, fontSize: 18),
          ),
        ),
      ),
    );
  }
}
