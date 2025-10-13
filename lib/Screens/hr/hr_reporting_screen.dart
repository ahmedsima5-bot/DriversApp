import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ⚠️ ملاحظة: يمكن استخدام مكتبات متقدمة للرسوم البيانية مثل fl_chart أو syncfusion_flutter_charts
// هنا سنستخدم تصميم مكانس (Placeholders) مع إطار عمل منظم للتقارير.

class HrReportingScreen extends StatelessWidget {
  final String companyId;
  const HrReportingScreen({required this.companyId, super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // تقارير السائقين، تقارير المشاوير، تحليل الطلبات
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التقارير الشاملة والمقارنات'),
          backgroundColor: Colors.purple[800],
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'أداء السائقين'),
              Tab(icon: Icon(Icons.route), text: 'تحليل المشاوير'),
              Tab(icon: Icon(Icons.analytics), text: 'تحليل الطلبات'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1. تقارير أداء السائقين (Driver Reports)
            DriverPerformanceReport(companyId: companyId),

            // 2. تحليل المشاوير (Ride Reports)
            RideEfficiencyReport(companyId: companyId),

            // 3. تحليل الطلبات حسب الأقسام (Department/Requester Reports)
            DepartmentRequestAnalysis(companyId: companyId),
          ],
        ),
      ),
    );
  }
}

// ===============================================
// جزء 1: تقارير أداء السائقين
// ===============================================
class DriverPerformanceReport extends StatelessWidget {
  final String companyId;
  const DriverPerformanceReport({required this.companyId, super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportTitle('أداء السائقين حسب الإنجاز والوقت'),
          _buildFilterRow(),
          _buildStatCard(Icons.local_shipping, 'أفضل سائق للشهر', 'محمد السعدي - 98% إنجاز'),
          _buildStatCard(Icons.timer, 'متوسط زمن الاستجابة', '7.5 دقائق'),
          _buildChartPlaceholder(
            title: 'مقارنة إنجاز المشاوير (آخر 3 أشهر)',
            details: 'مكان مخصص لرسم بياني يوضح نسبة الإنجاز والرفض لكل سائق.',
          ),
          const SizedBox(height: 20),
          _buildDriverListPlaceholder(),
        ],
      ),
    );
  }
}

// ===============================================
// جزء 2: تحليل المشاوير
// ===============================================
class RideEfficiencyReport extends StatelessWidget {
  final String companyId;
  const RideEfficiencyReport({required this.companyId, super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportTitle('تحليل كفاءة المشاوير والتكاليف'),
          _buildFilterRow(),
          _buildStatCard(Icons.attach_money, 'إجمالي التكاليف التقديرية (شهرية)', '15,000 ريال'),
          _buildStatCard(Icons.route, 'متوسط المسافة للمشوار', '12.4 كم'),
          _buildChartPlaceholder(
            title: 'توزيع حالات المشاوير (مكتمل/ملغي/قيد التنفيذ)',
            details: 'مكان مخصص لرسم بياني دائري (Pie Chart) لحالات المشاوير.',
          ),
          const SizedBox(height: 20),
          _buildTopRoutesPlaceholder(),
        ],
      ),
    );
  }
}

// ===============================================
// جزء 3: تحليل الطلبات حسب الأقسام
// (لتلبية طلب: "أعرف مين البيطلب أكثر واي قسم")
// ===============================================
class DepartmentRequestAnalysis extends StatelessWidget {
  final String companyId;
  const DepartmentRequestAnalysis({required this.companyId, super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportTitle('تحليل الطلبات حسب الأقسام والمستخدمين'),
          _buildFilterRow(),
          _buildStatCard(Icons.business, 'أكثر قسم طلبًا (آخر 3 أشهر)', 'قسم المبيعات - 45 طلب'),
          _buildStatCard(Icons.person, 'أكثر مستخدم طلبًا', 'فهد الأحمد - 12 طلب'),
          _buildChartPlaceholder(
            title: 'توزيع طلبات المشاوير حسب الأقسام',
            details: 'مكان مخصص لرسم بياني شريطي (Bar Chart) يوضح عدد الطلبات لكل قسم.',
          ),
          const SizedBox(height: 20),
          _buildTopRequestersPlaceholder(),
        ],
      ),
    );
  }
}

// ===============================================
// الويدجت المشتركة والوظائف المساعدة
// ===============================================

Widget _buildReportTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.purple,
      ),
    ),
  );
}

Widget _buildFilterRow() {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'الفترة الزمنية',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            value: '30 days',
            items: const [
              DropdownMenuItem(value: '7 days', child: Text('آخر 7 أيام')),
              DropdownMenuItem(value: '30 days', child: Text('آخر 30 يوم')),
              DropdownMenuItem(value: '90 days', child: Text('آخر 90 يوم')),
            ],
            onChanged: (value) {},
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () {
            // منطق تحميل التقرير أو التصدير
          },
          icon: const Icon(Icons.download),
          label: const Text('تصدير'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            backgroundColor: Colors.purple[600],
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}

Widget _buildStatCard(IconData icon, String title, String value) {
  return Card(
    elevation: 3,
    margin: const EdgeInsets.symmetric(vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ListTile(
      leading: Icon(icon, size: 35, color: Colors.blueGrey),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.purple[800],
        ),
      ),
    ),
  );
}

Widget _buildChartPlaceholder({required String title, required String details}) {
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            height: 200,
            width: double.infinity,
            color: Colors.grey[200],
            child: Center(
              child: Text(
                details,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildDriverListPlaceholder() {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'قائمة تفصيلية بأداء السائقين:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Divider(),
          ListTile(title: Text('سائق 1: 50 مشوار، 2 تأخير'), trailing: Icon(Icons.arrow_forward)),
          ListTile(title: Text('سائق 2: 45 مشوار، 5 تأخير'), trailing: Icon(Icons.arrow_forward)),
          ListTile(title: Text('سائق 3: 60 مشوار، 1 تأخير'), trailing: Icon(Icons.arrow_forward)),
        ],
      ),
    ),
  );
}

Widget _buildTopRoutesPlaceholder() {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أكثر المسارات تكراراً:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Divider(),
          ListTile(title: Text('الرياض -> جدة (50 مرة)'), trailing: Icon(Icons.trending_up)),
          ListTile(title: Text('الخبر -> الدمام (35 مرة)'), trailing: Icon(Icons.trending_up)),
        ],
      ),
    ),
  );
}

Widget _buildTopRequestersPlaceholder() {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أكثر المستخدمين/الأقسام طلبًا (بيانات وهمية):',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Divider(),
          ListTile(title: Text('قسم المبيعات (45)'), trailing: Text('45 طلب')),
          ListTile(title: Text('فهد الأحمد (المحاسبة) (12)'), trailing: Text('12 طلب')),
          ListTile(title: Text('قسم التسويق (8)'), trailing: Text('8 طلبات')),
        ],
      ),
    ),
  );
}
