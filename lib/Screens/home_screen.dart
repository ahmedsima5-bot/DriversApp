import 'package:flutter/material.dart';
import '../../services/auth_service.dart'; // لاستخدام دالة تسجيل الخروج

// هذه الشاشة هي الصفحة الرئيسية للموظفين العاديين (طالبي الخدمة)
class RequesterHomeScreen extends StatelessWidget {
  const RequesterHomeScreen({super.key});

  // دالة تسجيل الخروج
  void _logout(BuildContext context) async {
    await AuthService().signOut();
    // يجب التوجيه إلى شاشة تسجيل الدخول بعد تسجيل الخروج
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/', // يجب أن يكون هذا هو مسار شاشة تسجيل الدخول
            (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // لدينا علامتي تبويب: "طلب جديد" و "طلباتي"
      child: Scaffold(
        appBar: AppBar(
          title: const Text('شاشة طالب الخدمة'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
              onPressed: () => _logout(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.add_task), text: 'طلب جديد'),
              Tab(icon: Icon(Icons.list_alt), text: 'طلباتي'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: const TabBarView(
          children: [
            // 1. شاشة إنشاء طلب جديد (سنكملها لاحقاً)
            Center(child: Text('نموذج إنشاء طلب جديد (قريباً)')),

            // 2. شاشة عرض الطلبات السابقة
            Center(child: Text('قائمة الطلبات السابقة والحالة (قريباً)')),
          ],
        ),
      ),
    );
  }
}
