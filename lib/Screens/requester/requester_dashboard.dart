import 'package:flutter/material.dart';
import 'new_request_screen.dart';
import 'my_requests_screen.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class RequesterDashboard extends StatefulWidget {
  final String companyId;
  final String userId;
  final String userName; // إضافة userName

  const RequesterDashboard({
    super.key,
    required this.companyId,
    required this.userId,
    required this.userName, // إضافة userName
  });

  @override
  State<RequesterDashboard> createState() => _RequesterDashboardState();
}

class _RequesterDashboardState extends State<RequesterDashboard> {
  final AuthService _authService = AuthService();

  Future<void> _signOut(BuildContext context) async {
    // تأكيد تسجيل الخروج
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // تسجيل الخروج
      await _authService.signOut();

      // ✅ العودة مباشرة لشاشة تسجيل الدخول
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة مقدم الطلبات'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_task, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              'مرحباً بك في لوحة تقديم الطلبات',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'معرف الشركة: ${widget.companyId}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // زر إنشاء طلب جديد
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NewTransferRequestScreen(
                      companyId: widget.companyId,
                      userId: widget.userId, // ✅ إضافة userId
                      userName: widget.userName, // ✅ إضافة userName
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'إنشاء طلب جديد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 15),

            // زر متابعة الطلبات
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MyRequestsScreen(
                      companyId: widget.companyId,
                      userId: widget.userId,
                      userName: widget.userName, // ✅ إضافة userName
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'متابعة طلباتي',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 20),

            // معلومات المستخدم
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  const Text(
                    'معلومات المستخدم',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text('معرف المستخدم: ${widget.userId}'),
                  Text('اسم المستخدم: ${widget.userName}'), // ✅ إضافة اسم المستخدم
                  Text('معرف الشركة: ${widget.companyId}'),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // زر تسجيل خروج إضافي في الجسم
            TextButton(
              onPressed: () => _signOut(context),
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}