import 'package:flutter/material.dart';

class HRReportsScreen extends StatefulWidget {
  final String companyId;

  const HRReportsScreen({
    super.key,
    required this.companyId,
  });

  @override
  State<HRReportsScreen> createState() => _HRReportsScreenState();
}

class _HRReportsScreenState extends State<HRReportsScreen> {
  // بيانات افتراضية للإحصائيات
  final List<Map<String, dynamic>> _departmentStats = [
    {'department': 'المبيعات', 'requests': 15, 'color': Colors.blue},
    {'department': 'التسويق', 'requests': 12, 'color': Colors.green},
    {'department': 'التقنية', 'requests': 8, 'color': Colors.orange},
    {'department': 'المالية', 'requests': 6, 'color': Colors.purple},
    {'department': 'الموارد البشرية', 'requests': 4, 'color': Colors.red},
    {'department': 'التشغيل', 'requests': 3, 'color': Colors.teal},
  ];

  final List<Map<String, dynamic>> _driverStats = [
    {'driver': 'أحمد محمد', 'completedRequests': 25, 'rating': 4.8, 'color': Colors.blue},
    {'driver': 'محمد علي', 'completedRequests': 18, 'rating': 4.5, 'color': Colors.green},
    {'driver': 'خالد عبدالله', 'completedRequests': 15, 'rating': 4.9, 'color': Colors.orange},
    {'driver': 'سعيد حسن', 'completedRequests': 12, 'rating': 4.2, 'color': Colors.purple},
    {'driver': 'عمر فاروق', 'completedRequests': 8, 'rating': 4.7, 'color': Colors.red},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('التقارير والإحصائيات - ${widget.companyId}'),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // الإحصائيات الأساسية
          _buildStatCard('إجمالي الطلبات', '47', Icons.request_page, Colors.blue),
          _buildStatCard('طلبات عاجلة', '12', Icons.warning, Colors.orange),
          _buildStatCard('طلبات مكتملة', '35', Icons.check_circle, Colors.green),
          _buildStatCard('طلبات معلقة', '5', Icons.pending, Colors.red),
          _buildStatCard('السائقين النشطين', '8', Icons.directions_car, Colors.teal),

          const SizedBox(height: 20),

          // إحصائيات هذا الشهر
          const Text(
            'إحصائيات هذا الشهر',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildMonthlyStats(),

          const SizedBox(height: 20),

          // الطلبات حسب الأقسام
          _buildDepartmentStats(),

          const SizedBox(height: 20),

          // إحصائيات السائقين
          _buildDriverStats(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }

  Widget _buildMonthlyStats() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('طلبات جديدة', '15'),
            _buildStatRow('طلبات مكتملة', '12'),
            _buildStatRow('طلبات ملغاة', '2'),
            _buildStatRow('متوسط وقت التنفيذ', '2.3 ساعة'),
            _buildStatRow('رضا العملاء', '94%'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ✅ الطلبات حسب الأقسام
  Widget _buildDepartmentStats() {
    // ترتيب الأقسام تنازلياً حسب عدد الطلبات
    _departmentStats.sort((a, b) => b['requests'].compareTo(a['requests']));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'الطلبات حسب الأقسام',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'أكثر الأقسام طلباً للنقل',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ..._departmentStats.asMap().entries.map((entry) {
              final index = entry.key;
              final dept = entry.value;
              final rank = index + 1;

              return _buildDepartmentRow(
                dept['department'],
                dept['requests'],
                dept['color'],
                rank,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentRow(String department, int requests, Color color, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // الترتيب
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // اسم القسم
          Expanded(
            child: Text(
              department,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          // عدد الطلبات
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$requests طلب',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ إحصائيات السائقين
  Widget _buildDriverStats() {
    // ترتيب السائقين تنازلياً حسب الطلبات المكتملة
    _driverStats.sort((a, b) => b['completedRequests'].compareTo(a['completedRequests']));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'أفضل السائقين أداءً',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'السائقين الأكثر إنجازاً للطلبات',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ..._driverStats.asMap().entries.map((entry) {
              final index = entry.key;
              final driver = entry.value;
              final rank = index + 1;

              return _buildDriverRow(
                driver['driver'],
                driver['completedRequests'],
                driver['rating'],
                driver['color'],
                rank,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverRow(String driver, int completedRequests, double rating, Color color, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // الترتيب
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // معلومات السائق
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text('$rating'),
                    const SizedBox(width: 16),
                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text('$completedRequests طلب'),
                  ],
                ),
              ],
            ),
          ),
          // شارة الأداء
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getPerformanceColor(rating),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getPerformanceText(rating),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPerformanceColor(double rating) {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 4.0) return Colors.blue;
    if (rating >= 3.5) return Colors.orange;
    return Colors.red;
  }

  String _getPerformanceText(double rating) {
    if (rating >= 4.5) return 'ممتاز';
    if (rating >= 4.0) return 'جيد جداً';
    if (rating >= 3.5) return 'جيد';
    return 'مقبول';
  }
}