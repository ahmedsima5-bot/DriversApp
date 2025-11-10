import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/firebase_options.dart';
import 'Screens/auth/login_screen.dart';
//import 'services/dispatch_service.dart';
import 'services/language_service.dart';
import 'providers/language_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');

    final savedLanguage = await LanguageService.getLanguage();
    print('🌍 اللغة المحفوظة: $savedLanguage');

    initializeDispatchSystem();
    runApp(MyApp(savedLanguage: savedLanguage));
  } catch (e) {
    print("❌ Firebase Initialization Error: $e");
    runApp(const ErrorApp());
  }
}

void initializeDispatchSystem() {
  try {
    //final dispatchService = DispatchService();
    print('🎯 نظام التوزيع التلقائي مفعل للشركة: C001');
  } catch (e) {
    print('❌ خطأ في تفعيل نظام التوزيع: $e');
  }
}

class MyApp extends StatelessWidget {
  final String savedLanguage;

  const MyApp({super.key, required this.savedLanguage});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LanguageProvider()..initialize(savedLanguage),
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            title: 'Driver App - نظام السائقين',
            locale: Locale(languageProvider.currentLanguage),
            supportedLocales: const [
              Locale('ar'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            theme: ThemeData(
              primarySwatch: Colors.orange,
              fontFamily: languageProvider.currentLanguage == 'ar' ? 'Tajawal' : 'Roboto',
              useMaterial3: true,
            ),
            home: const LoginScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                "خطأ في تهيئة النظام",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 10),
              const Text(
                "يرجى التحقق من إعدادات Firebase وتوصيل الإنترنت",
                textAlign: TextAlign.center,
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
    );
  }
}