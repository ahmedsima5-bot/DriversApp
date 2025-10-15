import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final _phoneController = TextEditingController();

  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isLoadingDepartments = true;
  String? _errorMessage;

  List<String> _departmentOptions = [];
  final List<String> _roleOptions = ['Requester', 'Driver', 'HR'];

  String? _selectedDepartment;
  String? _selectedRole;

  final _formKey = GlobalKey<FormState>();
  static const String _companyId = 'C001';

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  void _fetchDepartments() async {
    try {
      setState(() {
        _isLoadingDepartments = true;
        _errorMessage = null;
      });

      final departments = await DatabaseService.getDepartments(_companyId);

      if (mounted) {
        setState(() {
          _departmentOptions = departments;
          _isLoadingDepartments = false;

          if (departments.isEmpty) {
            _errorMessage = "لا توجد أقسام متاحة. تأكد من وجود شركة C001 في قاعدة البيانات.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDepartments = false;
          _errorMessage = "خطأ في تحميل الأقسام: $e";
          _departmentOptions = [];
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

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

  // 🚗 دالة محسنة لإضافة السائق إلى Firestore
  Future<void> _addDriverToFirestore(User user, String fullName) async {
    try {
      final driverData = {
        'driverId': user.uid,
        'uid': user.uid,
        'name': fullName,
        'email': user.email,
        'phone': _phoneController.text.isNotEmpty ? _phoneController.text : '+966000000000',
        'isOnline': true,
        'isAvailable': true,
        'isActive': true,
        'completedRides': 0,
        'department': 'السائقين',
        'role': 'driver',
        'companyId': _companyId,
        'vehicleInfo': {
          'type': 'سيارة',
          'model': '2024',
          'plate': 'غير محدد'
        },
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // ✅ إضافة إلى collection السائقين العام
      await _firestore.collection('drivers').doc(user.uid).set(driverData);

      // ✅ إضافة إلى سائقين الشركة
      await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('drivers')
          .doc(user.uid)
          .set(driverData);

      debugPrint('✅ تم إضافة السائق إلى Firestore بنجاح: ${user.uid}');
    } catch (e) {
      debugPrint('❌ خطأ في إضافة السائق إلى Firestore: $e');
      throw e;
    }
  }

  // 🎯 دالة محسنة للتسجيل
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRole == null) {
      setState(() {
        _errorMessage = 'يجب اختيار الدور.';
      });
      return;
    }

    if (_selectedRole != 'Driver' && _selectedDepartment == null) {
      setState(() {
        _errorMessage = 'يجب اختيار القسم.';
      });
      return;
    }

    if (_selectedRole != 'Driver' && _departmentOptions.isEmpty) {
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
      final department = _selectedRole == 'Driver' ? 'السائقين' : _selectedDepartment!;

      User? user = await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
        _selectedRole!,
        department,
        _companyId,
      );

      if (user != null && mounted) {
        // ✅ إذا كان سائقاً، أضفه إلى Firestore
        if (_selectedRole == 'Driver') {
          await _addDriverToFirestore(user, _nameController.text.trim());
        }

        // ✅ إضافة بيانات المستخدم العامة
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': _nameController.text.trim(),
          'email': user.email,
          'phone': _phoneController.text.trim(),
          'role': _selectedRole,
          'department': department,
          'companyId': _companyId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        debugPrint('✅ تم إنشاء حساب المستخدم: ${user.uid} - الدور: $_selectedRole');

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

                const SizedBox(height: 15),

                // حقل رقم الهاتف (اختياري)
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف (اختياري)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 25),

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
                      if (newValue == 'Driver') {
                        _selectedDepartment = null;
                      }
                    });
                  },
                  validator: (value) => value == null ? 'يُرجى اختيار الدور.' : null,
                ),

                const SizedBox(height: 15),

                // اختيار القسم (لغير السائقين)
                if (_selectedRole != 'Driver' && _selectedRole != null) ...[
                  if (_isLoadingDepartments)
                    _buildLoadingDepartments()
                  else if (_departmentOptions.isEmpty)
                    _buildNoDepartmentsError()
                  else
                    _buildDepartmentDropdown(),
                  const SizedBox(height: 15),
                ],

                // رسالة معلومات للسائقين
                if (_selectedRole == 'Driver')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'سيتم إضافتك تلقائياً إلى قائمة السائقين',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 25),

                // رسالة الخطأ
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
                  onPressed: (_isLoading ||
                      (_selectedRole != 'Driver' && _isLoadingDepartments) ||
                      (_selectedRole != 'Driver' && _departmentOptions.isEmpty))
                      ? null : _register,
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

                // زر تسجيل الدخول
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
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

  Widget _buildLoadingDepartments() {
    return Column(
      children: [
        const LinearProgressIndicator(color: Colors.teal),
        const SizedBox(height: 8),
        Text(
          'جاري تحميل الأقسام...',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildNoDepartmentsError() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            border: Border.all(color: Colors.red.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(height: 8),
              const Text(
                'لا توجد أقسام متاحة',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'تأكد من وجود شركة C001 في قاعدة البيانات',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _fetchDepartments,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentDropdown() {
    return DropdownButtonFormField<String>(
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
    );
  }
}