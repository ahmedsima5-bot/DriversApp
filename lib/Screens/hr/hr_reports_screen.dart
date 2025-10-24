import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _topDrivers = [];
  List<Map<String, dynamic>> _bottomDrivers = [];
  List<Map<String, dynamic>> _requestsByDay = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRealStats();
  }

  Future<void> _loadRealStats() async {
    setState(() => _loading = true);
    try {
      final requestsSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .get();

      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .get();

      // حساب الإحصائيات الأساسية
      final totalRequests = requestsSnapshot.docs.length;
      final urgentRequests = requestsSnapshot.docs
          .where((doc) => doc.data()['priority'] == 'Urgent')
          .length;
      final completedRequests = requestsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'COMPLETED')
          .length;
      final pendingRequests = requestsSnapshot.docs
          .where((doc) => ['PENDING', 'HR_PENDING'].contains(doc.data()['status']))
          .length;
      final activeDrivers = driversSnapshot.docs
          .where((doc) => doc.data()['isActive'] == true)
          .length;

      // تحليل أداء السائقين
      List<Map<String, dynamic>> allDrivers = driversSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['name'] ?? 'سائق غير معروف',
          'completedRides': data['completedRides'] ?? 0,
          'isActive': data['isActive'] ?? false,
          'rating': data['rating'] ?? 5.0,
        };
      }).toList();

      allDrivers.sort((a, b) => b['completedRides'].compareTo(a['completedRides']));
      final activeDriversList = allDrivers.where((d) => d['isActive'] == true).toList();
      _topDrivers = activeDriversList.take(3).toList();
      _bottomDrivers = activeDriversList.length > 3
          ? activeDriversList.sublist(activeDriversList.length - 3)
          : [];

      // بيانات الرسم البياني
      _requestsByDay = _generateWeeklyData(requestsSnapshot.docs);

      setState(() {
        _stats = {
          'totalRequests': totalRequests,
          'urgentRequests': urgentRequests,
          'completedRequests': completedRequests,
          'pendingRequests': pendingRequests,
          'activeDrivers': activeDrivers,
        };
        _loading = false;
      });
    } catch (e) {
      print('❌ خطأ في جلب الإحصائيات: $e');
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _generateWeeklyData(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final now = DateTime.now();
    final weekDays = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

    List<Map<String, dynamic>> data = [];

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);

      final dayRequests = docs.where((doc) {
        final timestamp = doc.data()['createdAt'];
        DateTime requestDate;
        if (timestamp is Timestamp) {
          requestDate = timestamp.toDate();
        } else {
          return false;
        }
        return requestDate.isAfter(dayStart) && requestDate.isBefore(dayEnd);
      }).length;

      data.add({
        'day': weekDays[day.weekday % 7],
        'count': dayRequests,
      });
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.blue.shade700),
            onPressed: _loadRealStats,
          ),
        ],
      ),
      body: _loading
          ? _buildLoadingShimmer()
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقات الإحصائيات الرئيسية
            _buildStatsGrid(),

            const SizedBox(height: 24),

            // الرسم البياني
            _buildChartCard(),

            const SizedBox(height: 24),

            // أداء السائقين
            _buildDriverPerformanceSection(),

            const SizedBox(height: 24),

            // معلومات إضافية
            _buildAdditionalInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildShimmerCard(height: 120),
        const SizedBox(height: 16),
        _buildShimmerCard(height: 200),
        const SizedBox(height: 16),
        _buildShimmerCard(height: 180),
        const SizedBox(height: 16),
        _buildShimmerCard(height: 150),
      ],
    );
  }

  Widget _buildShimmerCard({double height = 100}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: Colors.blue.shade600,
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildModernStatCard(
          title: 'إجمالي الطلبات',
          value: _stats['totalRequests'].toString(),
          icon: Icons.request_page_rounded,
          color: Colors.blue.shade600,
          gradient: [Colors.blue.shade600, Colors.blue.shade400],
        ),
        _buildModernStatCard(
          title: 'طلبات عاجلة',
          value: _stats['urgentRequests'].toString(),
          icon: Icons.warning_amber_rounded,
          color: Colors.orange.shade600,
          gradient: [Colors.orange.shade600, Colors.orange.shade400],
        ),
        _buildModernStatCard(
          title: 'طلبات مكتملة',
          value: _stats['completedRequests'].toString(),
          icon: Icons.check_circle_rounded,
          color: Colors.green.shade600,
          gradient: [Colors.green.shade600, Colors.green.shade400],
        ),
        _buildModernStatCard(
          title: 'طلبات معلقة',
          value: _stats['pendingRequests'].toString(),
          icon: Icons.pending_actions_rounded,
          color: Colors.red.shade600,
          gradient: [Colors.red.shade600, Colors.red.shade400],
        ),
      ],
    );
  }

  Widget _buildModernStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required List<Color> gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -10,
            right: -10,
            child: Icon(
              icon,
              size: 80,
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'الطلبات خلال الأسبوع',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: SfCartesianChart(
              primaryXAxis: CategoryAxis(
                labelRotation: -45,
                majorGridLines: const MajorGridLines(width: 0),
              ),
              primaryYAxis: NumericAxis(
                majorGridLines: const MajorGridLines(width: 0),
              ),
              series: <ColumnSeries<Map<String, dynamic>, String>>[
                ColumnSeries<Map<String, dynamic>, String>(
                  dataSource: _requestsByDay,
                  xValueMapper: (data, _) => data['day'],
                  yValueMapper: (data, _) => data['count'],
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(4),
                  width: 0.6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverPerformanceSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              const Text(
                'أداء السائقين',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildPerformanceList(
            title: '🏆 الأكثر أداءً',
            drivers: _topDrivers,
            color: Colors.green.shade600,
          ),

          const SizedBox(height: 16),

          _buildPerformanceList(
            title: '📊 يحتاج تحسين',
            drivers: _bottomDrivers,
            color: Colors.orange.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceList({
    required String title,
    required List<Map<String, dynamic>> drivers,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        if (drivers.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'لا توجد بيانات كافية',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ...drivers.asMap().entries.map((entry) {
            final index = entry.key;
            final driver = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                            const SizedBox(width: 4),
                            Text(
                              '${driver['rating']?.toStringAsFixed(1) ?? '5.0'}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${driver['completedRides']} مشوار',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildAdditionalInfo() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.purple.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'تحليلات متقدمة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAnalyticsRow('معدل الإنجاز', '${(_stats['completedRequests'] / (_stats['totalRequests'] == 0 ? 1 : _stats['totalRequests']) * 100).toStringAsFixed(1)}%'),
          _buildAnalyticsRow('السائقين النشطين', _stats['activeDrivers'].toString()),
          _buildAnalyticsRow('آخر تحديث', _formatTime(DateTime.now())),
          const SizedBox(height: 8),
          Text(
            '📈 هذه الإحصائيات تساعد في اتخاذ قرارات استراتيجية لتحسين كفاءة العمليات',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}