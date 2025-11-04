import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

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
  List<Map<String, dynamic>> _peakHours = [];
  List<Map<String, dynamic>> _departmentStats = [];
  List<Map<String, dynamic>> _performanceAlerts = [];
  List<String> _improvementSuggestions = [];
  bool _loading = true;

  // 🔥 إحصائيات جديدة
  double _averageResponseTime = 0.0;
  double _cancellationRate = 0.0;
  double _operationalEfficiency = 0.0;

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
      final cancelledRequests = requestsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'CANCELLED')
          .length;
      final activeDrivers = driversSnapshot.docs
          .where((doc) => doc.data()['isActive'] == true)
          .length;

      // 🔥 تحليل أداء السائقين - بدون تقييم العملاء
      List<Map<String, dynamic>> allDrivers = driversSnapshot.docs.map((doc) {
        final data = doc.data();

        final completedRides = (data['completedRides'] as num?)?.toInt() ?? 0;
        final isActive = data['isActive'] ?? false;

        // 🔥 نظام نقاط مبسط (بدون تقييم العملاء)
        double score = _calculateDriverScore(
          completedRides: completedRides,
          isActive: isActive,
        );

        return {
          'id': doc.id,
          'name': data['name'] ?? 'سائق غير معروف',
          'completedRides': completedRides,
          'isActive': isActive,
          'score': score,
          'phone': data['phone'] ?? 'غير متوفر',
          'email': data['email'] ?? 'غير متوفر',
          'vehicleType': data['vehicleInfo']?['type'] ?? 'غير محدد',
        };
      }).toList();

      // ترتيب السائقين حسب النقاط - FIXED: Added null safety
      allDrivers.sort((a, b) => (b['score'] ?? 0.0).compareTo(a['score'] ?? 0.0));

      final activeDriversList = allDrivers.where((d) => d['isActive'] == true).toList();

      _topDrivers = activeDriversList.take(3).toList();
      _bottomDrivers = activeDriversList.length > 3
          ? activeDriversList.sublist(activeDriversList.length - 3).reversed.toList()
          : [];

      // 🔥 تحليلات جديدة
      _requestsByDay = _generateWeeklyData(requestsSnapshot.docs);
      _peakHours = _analyzePeakHours(requestsSnapshot.docs);
      _departmentStats = _analyzeDepartmentStats(requestsSnapshot.docs);
      _averageResponseTime = _calculateAverageResponseTime(requestsSnapshot.docs);
      _cancellationRate = _calculateCancellationRate(totalRequests, cancelledRequests);
      _operationalEfficiency = _calculateOperationalEfficiency(completedRequests, totalRequests);
      _performanceAlerts = _generatePerformanceAlerts(activeDriversList);
      _improvementSuggestions = _generateImprovementSuggestions();

      setState(() {
        _stats = {
          'totalRequests': totalRequests,
          'urgentRequests': urgentRequests,
          'completedRequests': completedRequests,
          'pendingRequests': pendingRequests,
          'cancelledRequests': cancelledRequests,
          'activeDrivers': activeDrivers,
          'totalRides': _calculateTotalRides(activeDriversList),
        };
        _loading = false;
      });
    } catch (e) {
      print('❌ خطأ في جلب الإحصائيات: $e');
      setState(() => _loading = false);
    }
  }

  // 🔥 نظام نقاط مبسط (بدون تقييم العملاء)
  double _calculateDriverScore({
    required int completedRides,
    required bool isActive,
  }) {
    double score = 0.0;

    // 1. عدد المشاوير (70% من النقاط)
    if (completedRides > 0) {
      score += (completedRides * 0.7).clamp(0, 70);
    }

    // 2. النشاط (30% من النقاط)
    if (isActive) {
      score += 30;
    }

    return score;
  }

  // 🔥 دالة جديدة: تحليل أوقات الذروة
  List<Map<String, dynamic>> _analyzePeakHours(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    Map<int, int> hourCounts = {};

    for (var doc in docs) {
      final timestamp = doc.data()['createdAt'];
      if (timestamp is Timestamp) {
        final hour = timestamp.toDate().hour;
        hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
      }
    }

    final list = hourCounts.entries
        .map((e) => {'hour': e.key, 'count': e.value})
        .toList();

    // الحل: تحويل صريح للنوع
    list.sort((a, b) {
      final countA = (a['count'] as num).toInt();
      final countB = (b['count'] as num).toInt();
      return countB.compareTo(countA);
    });

    return list;
  }

  // 🔥 دالة جديدة: تحليل إحصائيات الأقسام
  List<Map<String, dynamic>> _analyzeDepartmentStats(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    Map<String, int> departmentCounts = {};

    for (var doc in docs) {
      final department = doc.data()['department'] ?? 'غير محدد';
      departmentCounts[department] = (departmentCounts[department] ?? 0) + 1;
    }

    final list = departmentCounts.entries
        .map((e) => {'department': e.key, 'count': e.value})
        .toList();

    // الحل: تحويل صريح للنوع
    list.sort((a, b) {
      final countA = (a['count'] as num).toInt();
      final countB = (b['count'] as num).toInt();
      return countB.compareTo(countA);
    });

    return list;
  }

  // 🔥 دالة جديدة: حساب متوسط وقت الاستجابة
  double _calculateAverageResponseTime(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int totalSeconds = 0;
    int count = 0;

    for (var doc in docs) {
      final data = doc.data();
      if (data['assignedTime'] != null && data['createdAt'] != null) {
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        final assignedTime = (data['assignedTime'] as Timestamp).toDate();
        final difference = assignedTime.difference(createdAt).inSeconds;
        if (difference > 0) {
          totalSeconds += difference;
          count++;
        }
      }
    }

    return count > 0 ? (totalSeconds / count / 60) : 0.0; // بالدقائق
  }

  // 🔥 دالة جديدة: حساب نسبة الإلغاء
  double _calculateCancellationRate(int totalRequests, int cancelledRequests) {
    return totalRequests > 0 ? (cancelledRequests / totalRequests * 100) : 0.0;
  }

  // 🔥 دالة جديدة: حساب الكفاءة التشغيلية
  double _calculateOperationalEfficiency(int completedRequests, int totalRequests) {
    return totalRequests > 0 ? (completedRequests / totalRequests * 100) : 0.0;
  }

  // 🔥 دالة جديدة: إنشاء تنبيهات الأداء
  List<Map<String, dynamic>> _generatePerformanceAlerts(List<Map<String, dynamic>> drivers) {
    List<Map<String, dynamic>> alerts = [];

    // تحقق من السائقين قليلي النشاط
    for (var driver in drivers) {
      final completedRides = driver['completedRides'] as int? ?? 0;
      if (completedRides < 5) {
        alerts.add({
          'type': 'low_activity',
          'message': '${driver['name']} لديه عدد قليل من المشاوير',
          'priority': 'medium',
          'driver': driver,
        });
      }
    }

    // تحقق من نسبة الإلغاء العالية
    if (_cancellationRate > 15) {
      alerts.add({
        'type': 'high_cancellation',
        'message': 'نسبة إلغاء الطلبات مرتفعة (${_cancellationRate.toStringAsFixed(1)}%)',
        'priority': 'high',
      });
    }

    // تحقق من وقت الاستجابة الطويل
    if (_averageResponseTime > 20) {
      alerts.add({
        'type': 'slow_response',
        'message': 'متوسط وقت الاستجابة طويل (${_averageResponseTime.toStringAsFixed(1)} دقيقة)',
        'priority': 'high',
      });
    }

    return alerts;
  }

  // 🔥 دالة جديدة: توليد توصيات التحسين
  List<String> _generateImprovementSuggestions() {
    List<String> suggestions = [];

    if (_cancellationRate > 15) {
      suggestions.add('• نسبة الإلغاء مرتفعة - تحسين توزيع الطلبات وتدريب السائقين');
    }

    if (_averageResponseTime > 20) {
      suggestions.add('• وقت الاستجابة طويل - زيادة عدد السائقين النشطين خلال أوقات الذروة');
    }

    final pendingRequests = _stats['pendingRequests'] as int? ?? 0;
    if (pendingRequests > 10) {
      suggestions.add('• طلبات معلقة كثيرة - تسريع عملية التوزيع والموافقة');
    }

    if (_bottomDrivers.isNotEmpty) {
      suggestions.add('• هناك سائقين بحاجة لتدريب إضافي لتحسين الأداء');
    }

    if (_peakHours.isNotEmpty && (_peakHours.first['count'] as int? ?? 0) > 10) {
      suggestions.add('• توزيع السائقين بشكل استراتيجي خلال ساعات الذروة');
    }

    return suggestions;
  }

  int _calculateTotalRides(List<Map<String, dynamic>> drivers) {
    int total = 0;
    for (var driver in drivers) {
      final rides = (driver['completedRides'] as int?) ?? 0;
      total += rides;
    }
    return total;
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
        title: const Text('التقارير والإحصائيات المتقدمة'),
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

            // الرسم البياني الأسبوعي
            _buildChartCard(),

            const SizedBox(height: 24),

            // 🔥 تحليلات الأداء التشغيلي
            _buildOperationalAnalytics(),

            const SizedBox(height: 24),

            // 🔥 أوقات الذروة
            _buildPeakHoursCard(),

            const SizedBox(height: 24),

            // أداء السائقين
            _buildDriverPerformanceSection(),

            const SizedBox(height: 24),

            // 🔥 تنبيهات الأداء
            _buildPerformanceAlertsCard(),

            const SizedBox(height: 24),

            // 🔥 توصيات التحسين
            _buildImprovementSuggestionsCard(),
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
          value: (_stats['totalRequests'] ?? 0).toString(),
          icon: Icons.request_page_rounded,
          color: Colors.blue.shade600,
          gradient: [Colors.blue.shade600, Colors.blue.shade400],
        ),
        _buildModernStatCard(
          title: 'طلبات عاجلة',
          value: (_stats['urgentRequests'] ?? 0).toString(),
          icon: Icons.warning_amber_rounded,
          color: Colors.orange.shade600,
          gradient: [Colors.orange.shade600, Colors.orange.shade400],
        ),
        _buildModernStatCard(
          title: 'طلبات مكتملة',
          value: (_stats['completedRequests'] ?? 0).toString(),
          icon: Icons.check_circle_rounded,
          color: Colors.green.shade600,
          gradient: [Colors.green.shade600, Colors.green.shade400],
        ),
        _buildModernStatCard(
          title: 'سائقين نشطين',
          value: (_stats['activeDrivers'] ?? 0).toString(),
          icon: Icons.people_alt_rounded,
          color: Colors.purple.shade600,
          gradient: [Colors.purple.shade600, Colors.purple.shade400],
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
                  xValueMapper: (data, _) => data['day'] as String,
                  yValueMapper: (data, _) => data['count'] as int,
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

  // 🔥 بطاقة جديدة: التحليلات التشغيلية
  Widget _buildOperationalAnalytics() {
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
              Icon(Icons.speed_rounded, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'التحليلات التشغيلية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildAnalyticItem(
                '⏱️ متوسط وقت الاستجابة',
                '${_averageResponseTime.toStringAsFixed(1)} دقيقة',
                Colors.blue.shade600,
              ),
              _buildAnalyticItem(
                '📊 الكفاءة التشغيلية',
                '${_operationalEfficiency.toStringAsFixed(1)}%',
                Colors.green.shade600,
              ),
              _buildAnalyticItem(
                '❌ نسبة الإلغاء',
                '${_cancellationRate.toStringAsFixed(1)}%',
                Colors.red.shade600,
              ),
              _buildAnalyticItem(
                '🚗 إجمالي المشاوير',
                (_stats['totalRides'] ?? 0).toString(),
                Colors.purple.shade600,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticItem(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 بطاقة جديدة: أوقات الذروة
  Widget _buildPeakHoursCard() {
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
              Icon(Icons.access_time_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text(
                'أوقات الذروة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_peakHours.isEmpty)
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
            Column(
              children: _peakHours.take(5).map((hourData) {
                final hour = hourData['hour'] as int? ?? 0;
                final count = hourData['count'] as int? ?? 0;
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$hour',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ساعة $hour:00',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '$count طلب',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
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
          const SizedBox(height: 8),
          Text(
            '📊 التقييم بناء على: عدد المشاوير (70%) + النشاط (30%)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),

          _buildPerformanceList(
            title: '🏆 الأكثر أداءً',
            drivers: _topDrivers,
            color: Colors.green.shade600,
          ),

          const SizedBox(height: 16),

          _buildPerformanceList(
            title: '📈 يحتاج تحسين',
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
            final completedRides = driver['completedRides'] as int? ?? 0;
            final score = driver['score'] as double? ?? 0.0;
            final name = driver['name'] as String? ?? 'سائق غير معروف';
            final vehicleType = driver['vehicleType'] as String? ?? 'غير محدد';

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
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.directions_car, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              vehicleType,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.leaderboard, size: 14, color: color),
                            const SizedBox(width: 4),
                            Text(
                              '${score.toStringAsFixed(0)} نقطة',
                              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
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
                      '$completedRides مشوار',
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

  // 🔥 بطاقة جديدة: تنبيهات الأداء
  Widget _buildPerformanceAlertsCard() {
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
              Icon(Icons.notifications_active_rounded, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Text(
                'تنبيهات الأداء',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_performanceAlerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '🎉 جميع المؤشرات ضمن المعدلات الطبيعية',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            Column(
              children: _performanceAlerts.map((alert) {
                Color alertColor = Colors.orange.shade600;
                IconData alertIcon = Icons.warning_amber_rounded;

                if (alert['priority'] == 'high') {
                  alertColor = Colors.red.shade600;
                  alertIcon = Icons.error_rounded;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: alertColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: alertColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(alertIcon, color: alertColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          alert['message'] as String,
                          style: TextStyle(
                            color: alertColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // 🔥 بطاقة جديدة: توصيات التحسين
  Widget _buildImprovementSuggestionsCard() {
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
              Icon(Icons.lightbulb_rounded, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'توصيات التحسين',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_improvementSuggestions.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '🎉 الأداء العام ممتاز ولا توجد توصيات حالياً',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            Column(
              children: _improvementSuggestions.map((suggestion) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.tips_and_updates_rounded,
                          color: Colors.amber.shade600, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          suggestion,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          Text(
            '💡 هذه التوصيات تساعد في تحسين كفاءة العمليات ورفع مستوى الخدمة',
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
}