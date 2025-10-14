import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/database_service.dart';
import '../../models/request_model.dart';

// الفئة الرئيسية التي تمثل لوحة تحكم الموارد البشرية
class HrAdminDashboard extends StatelessWidget {
  final String companyId;
  const HrAdminDashboard({required this.companyId, super.key});

  @override
  Widget build(BuildContext context) {
    // تحديد ما إذا كانت الشاشة كبيرة (سطح مكتب/تابلت) أم صغيرة (هاتف)
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم إدارة الموارد البشرية'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications, color: Colors.white)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings, color: Colors.white)),
        ],
      ),
      // الشريط الجانبي (Drawer) يظهر فقط على الشاشات الصغيرة
      drawer: isDesktop ? null : const Drawer(child: SidebarMenu()),
      body: SafeArea(
        child: Row(
          children: [
            // الشريط الجانبي يظهر فقط على الشاشات الكبيرة
            if (isDesktop) const SidebarMenu(),

            // المحتوى الرئيسي للوحة التحكم
            Expanded(
              child: DashboardContent(companyId: companyId),
            ),
          ],
        ),
      ),
    );
  }
}

// قائمة الشريط الجانبي (Sidebar)
class SidebarMenu extends StatelessWidget {
  const SidebarMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Colors.indigo.shade800,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.indigo.shade700),
            child: const Text(
              'إدارة الموارد البشرية',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          _buildMenuItem(context, Icons.dashboard, 'نظرة عامة'),
          _buildMenuItem(context, Icons.people, 'قائمة الموظفين'),
          _buildMenuItem(context, Icons.pending_actions, 'طلبات النقل العاجلة'),
          _buildMenuItem(context, Icons.cast_for_education, 'التدريب'),
          _buildMenuItem(context, Icons.report, 'التقارير'),
        ],
      ),
    );
  }

  ListTile _buildMenuItem(BuildContext context, IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        if (MediaQuery.of(context).size.width < 1000) {
          Navigator.pop(context);
        }
      },
    );
  }
}

// محتوى لوحة التحكم الرئيسي
class DashboardContent extends StatelessWidget {
  final String companyId;
  const DashboardContent({required this.companyId, super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width >= 1000;
    final crossAxisCount = isLargeScreen ? 4 : size.width >= 600 ? 2 : 1;
    final childAspectRatio = isLargeScreen ? 1.5 : 1.2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مرحباً بك، مدير الموارد البشرية!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // شبكة بطاقات الملخص
          GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: childAspectRatio,
            children: const [ // تم إعادة const بعد التعديل
              DashboardCard(
                title: 'إجمالي الموظفين',
                value: '452',
                icon: Icons.people_alt,
                color: Colors.blue,
              ),
              DashboardCard(
                title: 'طلبات عاجلة (اليوم)',
                value: '12',
                icon: Icons.priority_high,
                color: Colors.orange,
              ),
              DashboardCard(
                title: 'الطلبات المنجزة',
                value: '380',
                icon: Icons.done_all,
                color: Colors.green,
              ),
              DashboardCard(
                title: 'السائقين المتاحين',
                value: '8',
                icon: Icons.person_add,
                color: Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 30),

          // قسم طلبات النقل العاجلة المعلقة
          const Text(
            'طلبات النقل العاجلة المعلقة للموافقة',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 15),
          UrgentRequestsTable(companyId: companyId),

          const SizedBox(height: 30),

          // قسم المهام السريعة
          const Text(
            'مهام سريعة',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 15,
            runSpacing: 15,
            children: [
              QuickActionButton(
                label: 'عرض لوحة السائقين',
                icon: Icons.map,
                onPressed: () {},
              ),
              QuickActionButton(
                label: 'مراجعة التقارير',
                icon: Icons.rate_review,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ويدجت بطاقة الملخص
class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const DashboardCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  Color _getShade700(Color c) {
    if (c is MaterialColor) {
      return c[700] ?? c;
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, size: 30, color: color),
              ],
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: _getShade700(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ويدجت زر الإجراء السريع
class QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const QuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.indigo,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// *************** ويدجت جلب وعرض الطلبات العاجلة ***************

class UrgentRequestsTable extends StatelessWidget {
  final String companyId;
  const UrgentRequestsTable({required this.companyId, super.key});

  // دالة لمعالجة الموافقة أو الرفض
  void _handleApproval(
      BuildContext context, Request request, bool isApproved) async {
    final status = isApproved ? 'HR_APPROVED' : 'REJECTED';
    try {
      await DatabaseService.updateRequestStatusAndApprover(
        companyId: companyId,
        requestId: request.requestId,
        newStatus: status,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'تم ${isApproved ? 'قبول' : 'رفض'} طلب ${request.requesterName} بنجاح.')),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error updating request status: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('حدث خطأ أثناء معالجة الطلب، حاول مرة أخرى.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // استخدم StreamBuilder لجلب الطلبات العاجلة في الوقت الحقيقي
    return StreamBuilder<QuerySnapshot>(
      stream: DatabaseService.getUrgentPendingRequests(companyId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('حدث خطأ في جلب البيانات.'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('لا توجد طلبات نقل عاجلة معلقة حالياً.'),
              ));
        }

        // تحويل الوثائق إلى قائمة نماذج الطلبات (Request Models)
        final requests = snapshot.data!.docs
            .map((doc) => Request.fromMap(
            doc.data() as Map<String, dynamic>))
            .toList();

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // ✨ تم تصحيح خطأ عدم إرسال 'rows' هنا
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('اسم الموظف', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('نوع الطلب', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('التفاصيل', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('وقت البداية المتوقع', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('الإجراء', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: requests.map((request) { // ✨ تم تمرير قائمة الصفوف هنا
                  return DataRow(cells: [
                    DataCell(Text(request.requesterName)),
                    DataCell(Text(request.purposeType)),
                    DataCell(SizedBox(
                        width: 150,
                        child: Text(request.details, overflow: TextOverflow.ellipsis))),
                    DataCell(Text(
                        '${request.startTimeExpected.hour}:${request.startTimeExpected.minute.toString().padLeft(2, '0')}')),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: () => _handleApproval(context, request, true), // قبول
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => _handleApproval(context, request, false), // رفض
                          ),
                        ],
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}