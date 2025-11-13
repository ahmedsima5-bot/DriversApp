import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'hr_requests_screen.dart';
import 'hr_drivers_management.dart';
import 'hr_reports_screen.dart';
import 'hr_control_panel.dart';
// 💡 استيراد شاشة طلب جديد (يجب التأكد من المسار الصحيح لديك)
import '../requester/new_request_screen.dart';


class HRMainScreen extends StatefulWidget {
  final String companyId;

  const HRMainScreen({super.key, required this.companyId});

  @override
  State<HRMainScreen> createState() => _HRMainScreenState();
}

class _HRMainScreenState extends State<HRMainScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _pendingRequestsCount = 0;
  bool _loadingPendingCount = true;

  // 💡 تحديد بيانات افتراضية للمستخدم الحالي لعمل زر الطلب الجديد
  String _currentUserId = 'HR_Admin_ID';
  String _currentUserName = 'مسؤول الموارد البشرية';


  @override
  void initState() {
    super.initState();
    _loadPendingRequestsCount();
    _getCurrentUserAndLoadCount(); // 💡 إضافة دالة جلب بيانات المستخدم
  }

  // 💡 دالة لجلب بيانات المستخدم الحالي
  void _getCurrentUserAndLoadCount() {
    final user = _auth.currentUser;
    if (user != null) {
      // في تطبيق حقيقي، يجب جلب اسم المستخدم من Firestore هنا
      setState(() {
        _currentUserId = user.uid;
        _currentUserName = user.displayName ?? 'مسؤول الموارد البشرية';
      });
    }
  }

  Future<void> _loadPendingRequestsCount() async {
    try {
      final requestsSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .where('status', whereIn: ['PENDING', 'HR_PENDING'])
          .get();

      // 💡 إضافة فحص mounted قبل setState
      if (mounted) {
        setState(() {
          _pendingRequestsCount = requestsSnapshot.docs.length;
          _loadingPendingCount = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في جلب عدد الطلبات المعلقة: $e');
      // 💡 إضافة فحص mounted قبل setState
      if (mounted) {
        setState(() {
          _loadingPendingCount = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      // 💡 إضافة فحص mounted قبل استخدام Navigator
      if (mounted) {
        // تأكد من وجود مسار '/login' في ملف main.dart
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('❌ خطأ في تسجيل الخروج: $e');
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('تسجيل الخروج'),
          ],
        ),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('تسجيل خروج'),
          ),
        ],
      ),
    );
  }

  // 💡 دالة لفتح شاشة إنشاء طلب جديد
  void _navigateToNewRequestScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        // يجب أن يكون هذا هو اسم الـ Class الصحيح لصفحة الطلب الجديد لديك
        builder: (context) => NewTransferRequestScreen(
          companyId: widget.companyId,
          userId: _currentUserId, // نمرر الـ ID
          userName: _currentUserName, // نمرر الاسم
        ),
      ),
    );
  }

  Widget _buildQuickInfo() {
    return Container(
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
            'وصول سريع',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          const Text(
            'اختر لوحة التحكم للحصول على نظرة شاملة على إحصائيات الشركة',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (_pendingRequestsCount > 0)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'يوجد $_pendingRequestsCount طلب يحتاج موافقة',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => HRDashboard(companyId: widget.companyId),
                ),
              );
            },
            child: const Text(
              'افتح لوحة التحكم مباشرة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الموارد البشرية - ${widget.companyId}'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutConfirmation,
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView( // 💡 استخدام SingleChildScrollView لضمان التمرير على الشاشات الصغيرة
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              Text(
                // 💡 ترحيب باسم المستخدم
                'مرحباً بك يا $_currentUserName',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'معرف الشركة: ${widget.companyId}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // زر لوحة التحكم
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => HRDashboard(companyId: widget.companyId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(280, 70), // زيادة حجم الزر
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  elevation: 6, // زيادة الظل
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dashboard, size: 28), // زيادة حجم الأيقونة
                    SizedBox(width: 12),
                    Text(
                      'لوحة التحكم',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // زر إدارة الطلبات مع إشعار
              Stack(
                alignment: AlignmentDirectional.centerEnd, // تعديل المحاذاة ليكون الإشعار على اليسار في التصميم العربي
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => HRRequestsScreen(companyId: widget.companyId),
                        ),
                      )
                      // ❌ تم حذف .then((_) => _loadPendingRequestsCount()) لضمان استقرار الشاشة
                          .then((_) {
                        if (mounted) {
                          _loadPendingRequestsCount();
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(280, 60), // توحيد الحجم
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.request_page, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'إدارة الطلبات',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  if (_pendingRequestsCount > 0 && !_loadingPendingCount)
                    Positioned(
                      // 💡 تعديل وضع الإشعار ليكون على اليسار (بداية الـ Stack)
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _pendingRequestsCount > 9 ? '9+' : _pendingRequestsCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 15),

              // زر إدارة السائقين
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => HRDriversManagement(companyId: widget.companyId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(280, 60),
                  backgroundColor: Colors.indigo.shade600, // تغيير اللون لزيادة التباين
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_car, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'إدارة السائقين',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // زر التقارير
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => HRReportsScreen(companyId: widget.companyId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(280, 60),
                  backgroundColor: Colors.purple.shade600,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.analytics, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'التقارير والإحصائيات',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // معلومات سريعة
              _buildQuickInfo(),
            ],
          ),
        ),
      ),
      // 💡 إضافة الزر العائم في أسفل يسار الشاشة (Floating Action Button)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToNewRequestScreen,
        tooltip: 'إنشاء طلب جديد', // الإيحاء النصي
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // شكل مربع خفيف
        icon: const Icon(Icons.add), // علامة +
        label: const Text(
          'طلب جديد', // النص المكتوب
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      // 💡 وضع الزر في أسفل يسار الشاشة (EndDocked/End) ليتناسب مع التصميم العربي
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}