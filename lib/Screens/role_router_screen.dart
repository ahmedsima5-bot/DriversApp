import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'hr/hr_main_screen.dart';
import 'requester/requester_dashboard.dart';
import 'driver/driver_dashboard.dart';

class RoleRouterScreen extends StatefulWidget {
  const RoleRouterScreen({super.key});

  @override
  State<RoleRouterScreen> createState() => _RoleRouterScreenState();
}

class _RoleRouterScreenState extends State<RoleRouterScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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

  // 🔍 دالة محسنة لجلب دور المستخدم ورقم الشركة
  Future<Map<String, dynamic>> _getUserRoleAndCompanyId(String userId) async {
    try {
      // البحث في جميع الشركات عن المستخدم
      final companiesSnapshot = await _firestore.collection('companies').get();

      for (var companyDoc in companiesSnapshot.docs) {
        final companyId = companyDoc.id;
        final userDoc = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          return {
            'role': userData['role'] ?? 'Requester',
            'company_id': companyId,
            'name': userData['name'] ?? 'مستخدم',
            'department': userData['department'] ?? 'غير محدد',
          };
        }
      }

      // إذا لم يتم العثور على المستخدم، البحث في collection السائقين
      for (var companyDoc in companiesSnapshot.docs) {
        final companyId = companyDoc.id;
        final driversSnapshot = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('drivers')
            .where('email', isEqualTo: _user?.email)
            .get();

        if (driversSnapshot.docs.isNotEmpty) {
          final driverData = driversSnapshot.docs.first.data();
          return {
            'role': 'Driver',
            'company_id': companyId,
            'name': driverData['name'] ?? 'سائق',
            'department': driverData['department'] ?? 'السائقين',
          };
        }
      }

      throw Exception('لم يتم العثور على بيانات المستخدم');
    } catch (e) {
      print('❌ خطأ في جلب دور المستخدم ورقم الشركة: $e');
      rethrow;
    }
  }

  Future<void> _fetchUserRole(String userId) async {
    try {
      setState(() {
        _isDataLoaded = false;
        _error = null;
      });

      final userData = await _getUserRoleAndCompanyId(userId);

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
    final userName = _userData!['name'] as String;
    final userId = _user?.uid ?? '';

    print('🎯 توجيه المستخدم إلى: $role - الشركة: $companyId - الاسم: $userName');

    // التوجيه حسب الدور
    switch (role) {
      case 'HR':
        return HRMainScreen(companyId: companyId);

      case 'Requester':
        return RequesterDashboard( // ✅ إزالة const وإضافة المعاملات
          companyId: companyId,
          userId: userId,
          userName: userName ?? 'مستخدم', // ✅ إضافة userName مع قيمة افتراضية
        );

      case 'Driver':
        return DriverDashboard(userName: userName);

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