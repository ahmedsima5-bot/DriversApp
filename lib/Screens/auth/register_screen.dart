import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
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
    _fetchDepartments();
  }

  // جلب الأقسام من Firestore باستخدام Stream
  void _fetchDepartments() {
    DatabaseService.getDepartmentsStream(_companyId).listen((departments) {
      if (mounted) {
        setState(() {
          _departmentOptions = departments;
          if (departments.isEmpty) {
            _errorMessage = "لا توجد أقسام متاحة حاليًا. يرجى التواصل مع مسؤول الموارد البشرية.";
          }
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _errorMessage = "خطأ في تحميل الأقسام: $error";
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
    switch (value) {
      case 'HR':
        return 'إداري';
      case 'Driver':
        return 'سائق';
      case 'Requester':
      default:
        return 'موظف';
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDepartment == null || _selectedRole == null) {
      setState(() {
        _errorMessage = 'يجب اختيار القسم والدور.';
      });
      return;
    }

    if (_departmentOptions.isEmpty) {
      setState(() {
        _errorMessage = 'لا يمكن التسجيل حاليًا. لا توجد أقسام متاحة.';
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
          MaterialPageRoute(builder: (context) => const RoleRouterScreen()),
        );
      } else {
        setState(() {
          _errorMessage = 'فشل في إنشاء الحساب.';
        });
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'كلمة المرور ضعيفة جداً.';
      } else if (e.code == 'email-already-in-use') {
        message = 'هذا البريد الإلكتروني مُسجل بالفعل.';
      } else if (e.code == 'invalid-email') {
        message = 'البريد الإلكتروني غير صالح.';
      } else if (e.code == 'operation-not-allowed') {
        message = 'عملية التسجيل غير مسموحة حالياً.';
      } else {
        message = 'خطأ في التسجيل: ${e.message}';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ عام: $e';
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
        title: const Text('إنشاء حساب جديد'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'التسجيل لتحديد الدور والصفحة المناسبة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // حقل الاسم
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يُرجى إدخال الاسم.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // حقل البريد الإلكتروني
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال البريد الإلكتروني.';
                    }
                    if (!value.contains('@')) {
                      return 'أدخل بريد إلكتروني صالح.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // حقل كلمة المرور
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور (6 أحرف على الأقل)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال كلمة المرور.';
                    }
                    if (value.length < 6) {
                      return 'يجب أن لا تقل كلمة المرور عن 6 أحرف.';
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
                          _errorMessage ?? 'جاري تحميل الأقسام...',
                          style: TextStyle(
                            color: _errorMessage != null ? Colors.red : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'اختيار القسم',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                      prefixIcon: Icon(Icons.apartment),
                    ),
                    value: _selectedDepartment,
                    hint: const Text('اختر قسمك'),
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
                    validator: (value) => value == null ? 'يُرجى اختيار القسم.' : null,
                  ),
                const SizedBox(height: 15),

                // اختيار الدور
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'اختيار الدور',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    prefixIcon: Icon(Icons.work),
                  ),
                  value: _selectedRole,
                  hint: const Text('اختر دورك'),
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
                  validator: (value) => value == null ? 'يُرجى اختيار الدور.' : null,
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
                      : const Text('إنشاء الحساب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 15),

                // رابط العودة لتسجيل الدخول
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'لدي حساب بالفعل؟ تسجيل الدخول',
                    style: TextStyle(color: Colors.blueGrey),
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