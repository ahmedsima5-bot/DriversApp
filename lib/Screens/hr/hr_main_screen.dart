import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ⚠️ تم تغيير الاستيراد إلى الأسماء الصحيحة:
import 'hr_admin_dashboard.dart'; // لوحة التحكم (التقارير والموافقات)
import '../requester/new_request_screen.dart'; // صفحة طلب جديد (يمكن لـ HR استخدامها)
import 'company_settings.dart'; // إعدادات الشركة

// شاشة إدارة الموارد البشرية الرئيسية - تستخدم علامات تبويب
class HRMainScreen extends StatefulWidget {
  final String companyId;
  const HRMainScreen({required this.companyId, super.key});

  @override
  State<HRMainScreen> createState() => _HRMainScreenState();
}

class _HRMainScreenState extends State<HRMainScreen> {
  int _selectedIndex = 0; // لتبويب التنقل السفلي

  // ⚠️ تم تعريف قائمة الشاشات بـ 'late final' كما في الكود المرسل.
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // تهيئة قائمة الشاشات بمرور companyId
    _screens = [
      // 1. لوحة الموارد البشرية (تم تصحيح اسم الفئة إلى HrAdminDashboard)
      HrAdminDashboard(companyId: widget.companyId),
      // 2. طلب جديد (ملاحظة: NewRequestScreen قد تحتاج companyId لاحقاً)
      const NewRequestScreen(),
      // 3. إعدادات الشركة (تم تصحيح اسم الفئة إلى CompanySettingsScreen وإزالة const)
      CompanySettingsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // دالة مساعدة لترجمة العناوين (يمكن استخدامها في AppBar الخاص بكل شاشة فرعية بدلاً من هنا)
  String _getTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'لوحة تحكم الموارد البشرية';
      case 1:
        return 'إرسال طلب جديد';
      case 2:
        return 'إعدادات الشركة والأقسام';
      default:
        return 'إدارة النقل';
    }
  }

  @override
  Widget build(BuildContext context) {
    // يمكنك استخدام FirebaseAuth للتحقق من حالة المصادقة
    return Scaffold(
      // استخدام AppBar هنا لعرض العنوان العام والـ Logout
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // TODO: Implement logout logic using FirebaseAuth
              // FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      // عرض الشاشة المختارة
      body: _screens[_selectedIndex],
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl, // لضمان عرض أيقونات BottomNav بشكل صحيح من اليمين
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'الرئيسية/التقارير',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_task),
              label: 'طلب جديد',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business_center),
              label: 'إعدادات الشركة',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.purple[800],
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
