import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'hr/hr_main_screen.dart';
import 'requester/requester_dashboard.dart';
import 'driver/driver_dashboard.dart';

// استيراد شاشات جميع الأدوار
import 'hr/hr_main_screen.dart';
import 'requester/requester_dashboard.dart'; // استخدم RequesterDashboard بدلاً من HomeScreen
// import 'driver/driver_dashboard.dart'; // إذا كان لديك شاشات للسائقين

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  void _initializeAuth() {
    // الاستماع لتغييرات حالة المصادقة
    _authService.user.listen((user) {
      print('🔄 تغيير حالة المصادقة: ${user?.uid}');
      if (mounted) {
        setState(() {
          _user = user;
        });
        if (user != null) {
          _fetchUserRole(user.uid);
        } else {
          setState(() {
            _isDataLoaded = true;
            _userData = null;
          });
        }
      }
    });

    // جلب المستخدم الحالي إذا كان مسجلاً
    _user = _authService.currentUser;
    if (_user != null) {
      _fetchUserRole(_user!.uid);
    } else {
      setState(() {
        _isDataLoaded = true;
      });
    }
  }

  Future<void> _fetchUserRole(String userId) async {
    try {
      setState(() {
        _isDataLoaded = false;
        _error = null;
      });

      final userData = await _authService.getUserRoleAndCompanyId(userId);

      if (mounted) {
        setState(() {
          _userData = userData;
          _isDataLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDataLoaded = true;
          _error = e.toString();
        });
      }
      print('❌ Error fetching user role: $e');
    }
  }

  Widget _navigateToRoleScreen() {
    if (!_isDataLoaded) {
      return _buildLoadingScreen();
    }

    if (_user == null) {
      print('🚨 لا يوجد مستخدم مسجل - التوجيه إلى تسجيل الدخول');
      return const LoginScreen();
    }

    if (_error != null) {
      return _buildErrorScreen();
    }

    if (_userData == null) {
      return _buildLoadingUserDataScreen();
    }

    final role = _userData!['role'] as String;
    final companyId = _userData!['company_id'] as String;

    print('🎯 توجيه المستخدم إلى: $role - الشركة: $companyId');

    // التوجيه حسب الدور
    switch (role) {
      case 'HR':
        return HRMainScreen(companyId: companyId);

      case 'Requester':
        return const RequesterDashboard(); // استخدام RequesterDashboard بدلاً من HomeScreen

      case 'Driver':
        return DriverDashboard(userName: _userData!['name'] ?? 'السائق');

      default:
        return _buildUnsupportedRoleScreen(role);
    }
  }

  // شاشة التحميل
  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('جارٍ التحقق من بيانات المستخدم...', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // شاشة الخطأ
  Widget _buildErrorScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 20),
              const Text(
                'خطأ في تحميل البيانات',
                style: TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => _fetchUserRole(_user!.uid),
                child: const Text('إعادة المحاولة'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => _authService.signOut(),
                child: const Text('العودة لتسجيل الدخول'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // شاشة تحميل بيانات المستخدم
  Widget _buildLoadingUserDataScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text('جارٍ جلب بيانات المستخدم...'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _authService.signOut(),
              child: const Text('العودة لتسجيل الدخول'),
            ),
          ],
        ),
      ),
    );
  }

  // شاشة السائق (يمكن استبدالها بشاشة حقيقية)
  Widget _buildDriverScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة السائق'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            const Text(
              'مرحباً بك أيها السائق',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'هنا ستظهر طلبات النقل المخصصة لك',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // TODO: الانتقال لصفحة طلبات السائق
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('عرض طلباتي'),
            ),
          ],
        ),
      ),
    );
  }

  // شاشة الدور غير المدعوم
  Widget _buildUnsupportedRoleScreen(String role) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 64),
              const SizedBox(height: 20),
              const Text(
                'دور غير مدعوم',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'الدور "$role" غير مدعوم في التطبيق',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Text(
                'الرجاء التواصل مع المسؤول',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => _authService.signOut(),
                child: const Text('العودة لتسجيل الدخول'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _navigateToRoleScreen();
  }
}