import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'services/dispatch_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');

    // 🎯 تفعيل نظام التوزيع التلقائي - صححت الشركة لـ C001
    initializeDispatchSystem();

    runApp(const MyApp());
  } catch (e) {
    print("❌ Firebase Initialization Error: $e");
    runApp(const ErrorApp());
  }
}

// ✨ دالة تفعيل نظام التوزيع - صححت الشركة
void initializeDispatchSystem() {
  try {
    final dispatchService = DispatchService();

    // 🔥 التصحيح: استخدم C001 بدل default_company
    dispatchService.startListening('C001');

    print('🎯 نظام التوزيع التلقائي مفعل للشركة: C001');
  } catch (e) {
    print('❌ خطأ في تفعيل نظام التوزيع: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام إدارة النقل',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'Tajawal',
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  "خطأ في تهيئة النظام",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "يرجى التحقق من إعدادات Firebase وتوصيل الإنترنت",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => main(),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}