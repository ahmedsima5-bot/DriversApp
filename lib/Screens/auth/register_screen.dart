import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/language_service.dart';
import '../../locales/app_localizations.dart';
import '../role_router_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  String _currentLanguage = 'ar';

  // قائمة الأقسام ستُجلب من Firestore
  List<String> _departmentOptions = [];
  // الخيارات الثابتة للأدوار
  final List<String> _roleOptions = ['Requester', 'Driver', 'HR'];

  String? _selectedDepartment;
  String? _selectedRole;

  // مفتاح النموذج للتحقق من صحة الإدخالات
  final _formKey = GlobalKey<FormState>();

  // قيمة ثابتة مؤقتة لمعرّف الشركة (نستخدمها لجلب الأقسام)
  static const String _companyId = 'C001';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _fetchDepartments();
  }

  Future<void> _loadLanguage() async {
    final savedLanguage = await LanguageService.getLanguage();
    setState(() {
      _currentLanguage = savedLanguage;
    });
  }

  Future<void> _changeLanguage(String newLanguage) async {
    await LanguageService.setLanguage(newLanguage);
    setState(() {
      _currentLanguage = newLanguage;
    });
  }

  String _translate(String key) {
    return AppLocalizations.getTranslatedValue(key, _currentLanguage);
  }

  // جلب الأقسام من Firestore باستخدام Stream
  void _fetchDepartments() {
    DatabaseService.getDepartmentsStream(_companyId).listen((departments) {
      if (mounted) {
        setState(() {
          _departmentOptions = departments;
          if (departments.isEmpty) {
            _errorMessage = _currentLanguage == 'ar'
                ? "لا توجد أقسام متاحة حاليًا. يرجى التواصل مع مسؤول الموارد البشرية."
                : "No departments available currently. Please contact HR.";
          }
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _currentLanguage == 'ar'
              ? "خطأ في تحميل الأقسام: $error"
              : "Error loading departments: $error";
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // دالة مساعدة لترجمة الدور للعرض
  String _getDisplayRole(String value) {
    if (_currentLanguage == 'ar') {
      switch (value) {
        case 'HR':
          return 'إداري';
        case 'Driver':
          return 'سائق';
        case 'Requester':
        default:
          return 'موظف';
      }
    } else {
      return value;
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDepartment == null || _selectedRole == null) {
      setState(() {
        _errorMessage = _currentLanguage == 'ar'
            ? 'يجب اختيار القسم والدور.'
            : 'You must select department and role.';
      });
      return;
    }

    if (_departmentOptions.isEmpty) {
      setState(() {
        _errorMessage = _currentLanguage == 'ar'
            ? 'لا يمكن التسجيل حاليًا. لا توجد أقسام متاحة.'
            : 'Cannot register currently. No departments available.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      User? user = await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
        _selectedRole!,
        _selectedDepartment!,
        _companyId,
      );

      if (user != null && mounted) {
        // التوجيه إلى شاشة التوزيع بعد النجاح
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const RoleRouterScreen(),
          ),
        );
      } else {
        setState(() {
          _errorMessage = _currentLanguage == 'ar'
              ? 'فشل في إنشاء الحساب.'
              : 'Failed to create account.';
        });
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = _currentLanguage == 'ar'
            ? 'كلمة المرور ضعيفة جداً.'
            : 'The password is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = _currentLanguage == 'ar'
            ? 'هذا البريد الإلكتروني مُسجل بالفعل.'
            : 'The account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = _currentLanguage == 'ar'
            ? 'البريد الإلكتروني غير صالح.'
            : 'Invalid email address.';
      } else if (e.code == 'operation-not-allowed') {
        message = _currentLanguage == 'ar'
            ? 'عملية التسجيل غير مسموحة حالياً.'
            : 'Registration is not allowed at the moment.';
      } else {
        message = _currentLanguage == 'ar'
            ? 'خطأ في التسجيل: ${e.message}'
            : 'Registration error: ${e.message}';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = _currentLanguage == 'ar'
            ? 'خطأ عام: $e'
            : 'General error: $e';
      });
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_translate('register')),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // ✅ زر اختيار اللغة في AppBar
          PopupMenuButton<String>(
            icon: const Icon(Icons.language, color: Colors.white),
            onSelected: _changeLanguage,
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'ar',
                child: Row(
                  children: [
                    const Icon(Icons.language, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(_translate('arabic')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'en',
                child: Row(
                  children: [
                    const Icon(Icons.language, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(_translate('english')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // عرض اللغة الحالية
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _currentLanguage == 'ar' ? 'العربية' : 'English',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),

                // حقل الاسم
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: _translate('name'),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return _currentLanguage == 'ar'
                          ? 'يُرجى إدخال الاسم.'
                          : 'Please enter your name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // حقل البريد الإلكتروني
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: _translate('email'),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return _translate('email_required');
                    }
                    if (!value.contains('@')) {
                      return _translate('invalid_email');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // حقل كلمة المرور
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _translate('password'),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return _translate('password_required');
                    }
                    if (value.length < 6) {
                      return _translate('password_length');
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 25),

                // اختيار القسم
                if (_departmentOptions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.teal),
                        const SizedBox(width: 10),
                        Text(
                          _errorMessage ?? (_currentLanguage == 'ar' ? 'جاري تحميل الأقسام...' : 'Loading departments...'),
                          style: TextStyle(
                            color: _errorMessage != null ? Colors.red : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: _currentLanguage == 'ar' ? 'اختيار القسم' : 'Select Department',
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                      prefixIcon: const Icon(Icons.apartment),
                    ),
                    initialValue: _selectedDepartment,
                    hint: Text(_currentLanguage == 'ar' ? 'اختر قسمك' : 'Choose your department'),
                    items: _departmentOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedDepartment = newValue;
                      });
                    },
                    validator: (value) => value == null
                        ? (_currentLanguage == 'ar' ? 'يُرجى اختيار القسم.' : 'Please select department.')
                        : null,
                  ),
                const SizedBox(height: 15),

                // اختيار الدور
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: _currentLanguage == 'ar' ? 'اختيار الدور' : 'Select Role',
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    prefixIcon: const Icon(Icons.work),
                  ),
                  initialValue: _selectedRole,
                  hint: Text(_currentLanguage == 'ar' ? 'اختر دورك' : 'Choose your role'),
                  items: _roleOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(_getDisplayRole(value)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedRole = newValue;
                    });
                  },
                  validator: (value) => value == null
                      ? (_currentLanguage == 'ar' ? 'يُرجى اختيار الدور.' : 'Please select role.')
                      : null,
                ),

                const SizedBox(height: 25),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // زر إنشاء الحساب
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : Text(_translate('register'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 15),

                // رابط العودة لتسجيل الدخول
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    _currentLanguage == 'ar' ? 'لدي حساب بالفعل؟ تسجيل الدخول' : 'Already have an account? Login',
                    style: const TextStyle(color: Colors.blueGrey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}