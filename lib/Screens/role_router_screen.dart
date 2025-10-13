import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
// استيراد شاشات الأدوار
import 'hr/hr_main_screen.dart';
// استيراد شاشة الدخول لإعادة التوجيه إليها
import 'auth/login_screen.dart';

// شاشة التوجيه حسب الدور
class RoleRouterScreen extends StatefulWidget {
  const RoleRouterScreen({super.key});

  @override
  State<RoleRouterScreen> createState() => _RoleRouterScreenState();
}

class _RoleRouterScreenState extends State<RoleRouterScreen> {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isDataLoaded = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    // استخدام onAuthStateChanged للاستماع للتغييرات
    _authService.user.listen((user) {
      if (user != null && mounted) {
        _user = user;
        _fetchUserRole(user.uid);
      } else {
        // إذا لم يكن هناك مستخدم، يجب أن ينتقل إلى شاشة الدخول
        if (mounted) {
          setState(() {
            _user = null;
            _isDataLoaded = true; // نعتبر التحميل انتهى
          });
          // بما أن التطبيق سيبدأ غالباً من هذه الشاشة، يجب التحقق من حالة المستخدم
          // وتوجيهه إلى شاشة الدخول إذا لم يكن مسجلاً
        }
      }
    });

    // جلب حالة المصادقة الأولية عند البداية
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _fetchUserRole(_user!.uid);
    } else {
      _isDataLoaded = true;
    }
  }

  Future<void> _fetchUserRole(String userId) async {
    final userData = await _authService.getUserRoleAndCompanyId(userId);
    if (mounted) {
      setState(() {
        _userData = userData;
        _isDataLoaded = true;
      });
    }
  }

  Widget _navigateToRoleScreen() {
    if (_userData == null || _user == null) {
      // 🚨 إذا لم يكن هناك مستخدم مسجل دخول أو حدث خطأ في جلب الدور
      // نعيد توجيه المستخدم إلى شاشة LoginScreen
      return const LoginScreen();
    }

    final role = _userData!['role'] as String;
    final companyId = _userData!['company_id'] as String;

    switch (role) {
      case 'HR':
        return HRMainScreen(companyId: companyId);
      case 'Requester':
        return const Center(child: Text('شاشة طالب الخدمة (Requester) - غير مُفعلة حالياً'));
      case 'Driver':
        return const Center(child: Text('شاشة السائق (Driver) - غير مُفعلة حالياً'));
      default:
      // التعامل مع الأدوار غير المعروفة
        return Center(child: Text('الدور غير مدعوم: $role'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataLoaded) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text('جارٍ التحقق من حالة المصادقة...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    // التوجيه إلى الشاشة المناسبة (الدخول أو الدور المحدد)
    return _navigateToRoleScreen();
  }
}
