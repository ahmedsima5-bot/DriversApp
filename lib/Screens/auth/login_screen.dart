import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../providers/language_provider.dart';
import '../../locales/app_localizations.dart';
import '../role_router_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  final _formKey = GlobalKey<FormState>();

  String _translate(String key, String languageCode) {
    return AppLocalizations.getTranslatedValue(key, languageCode);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // ✅ التوجيه بعد تسجيل الدخول الناجح
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const RoleRouterScreen(),
          ),
        );
      }

    } on FirebaseAuthException catch (e) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      String message;
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        message = _translate('incorrect_credentials', languageProvider.currentLanguage);
      } else if (e.code == 'invalid-email') {
        message = _translate('invalid_email', languageProvider.currentLanguage);
      } else if (e.code == 'user-disabled') {
        message = _translate('account_disabled', languageProvider.currentLanguage);
      } else if (e.code == 'too-many-requests') {
        message = _translate('too_many_attempts', languageProvider.currentLanguage);
      } else {
        message = _translate('login_error', languageProvider.currentLanguage) + ' ${e.message}';
      }
      _errorMessage = message;
    } catch (e) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      _errorMessage = _translate('general_error', languageProvider.currentLanguage) + ' $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final currentLanguage = languageProvider.currentLanguage;
        final isRTL = currentLanguage == 'ar';

        return Scaffold(
          appBar: AppBar(
            title: Text(_translate('login', currentLanguage)),
            centerTitle: true,
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.language, color: Colors.white),
                onSelected: (String newLanguage) async {
                  // 🔥 التعديل: استخدام setLanguage بدل changeLanguage
                  await languageProvider.setLanguage(newLanguage);
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: 'ar',
                    child: Row(
                      children: [
                        const Icon(Icons.language, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(_translate('arabic', currentLanguage)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'en',
                    child: Row(
                      children: [
                        const Icon(Icons.language, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(_translate('english', currentLanguage)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Directionality(
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.local_shipping,
                        size: 80,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 40),

                      // عرض اللغة الحالية
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          currentLanguage == 'ar' ? 'العربية' : 'English',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _emailController,
                        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: _translate('email', currentLanguage),
                          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                          prefixIcon: const Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return _translate('email_required', currentLanguage);
                          }
                          if (!value.contains('@')) {
                            return _translate('invalid_email', currentLanguage);
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: _translate('password', currentLanguage),
                          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                          prefixIcon: const Icon(Icons.lock),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return _translate('password_required', currentLanguage);
                          }
                          if (value.length < 6) {
                            return _translate('password_length', currentLanguage);
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 25),

                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 5,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : Text(
                              _translate('login_button', currentLanguage),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                        child: Text(
                          _translate('register', currentLanguage),
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 🔥 قسم معلومات الترجمة (للتطوير فقط - يمكن حذفه لاحقاً)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _translate('language_info', currentLanguage),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Current: $currentLanguage',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}