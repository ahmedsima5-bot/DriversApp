import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// سنفترض وجود ملف الشاشة الجديد هنا
import 'hr_reporting_screen.dart'; // تم استيراد شاشة التقارير

class HrDashboard extends StatelessWidget {
  final String companyId;
  const HrDashboard({required this.companyId, super.key});

  // دالة مساعدة للانتقال إلى شاشة التقارير
  void _navigateToReportingScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HrReportingScreen(companyId: companyId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الموارد البشرية'),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
        actions: [
          // زر الانتقال إلى شاشة التقارير (لتلبية متطلبات تقارير السائقين والمشاوير والأقسام)
          TextButton.icon(
            onPressed: () => _navigateToReportingScreen(context),
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            label: const Text('التقارير الشاملة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ملخص حالة السائقين
            _buildSectionTitle('ملخص حالة السائقين'),
            const SizedBox(height: 12),
            DriverStatusSummary(companyId: companyId),

            const SizedBox(height: 32),

            // 2. قائمة تتبع الموقع (استبدال الـ Placeholder)
            _buildSectionTitle('مواقع السائقين المتصلين (القائمة)'),
            const SizedBox(height: 12),
            DriverLocationList(companyId: companyId), // الويدجت الجديد

            const SizedBox(height: 32),

            // 3. الطلبات العاجلة وقيد الانتظار (استبدال الـ Placeholder)
            _buildSectionTitle('الطلبات الجديدة وقيد الموافقة'),
            const SizedBox(height: 12),
            PendingRequestsSummary(companyId: companyId), // الويدجت الجديد

            const SizedBox(height: 32),

            // 4. سجل الطلبات الأخيرة
            _buildSectionTitle('سجل الطلبات الأخيرة'),
            const SizedBox(height: 12),
            LatestRideHistory(companyId: companyId),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}

// ===============================================
// الـ Widget 1: ملخص حالة السائقين (بدون تغيير)
// ===============================================

class DriverStatusSummary extends StatelessWidget {
  final String companyId;
  const DriverStatusSummary({required this.companyId, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('خطأ في تحميل بيانات السائقين'));
        }

        final drivers = snapshot.data?.docs ?? [];
        final totalDrivers = drivers.length;

        final onlineDrivers = drivers.where(
              (doc) => (doc.data() as Map<String, dynamic>)['isOnline'] == true,
        ).length;

        final offlineDrivers = totalDrivers - onlineDrivers;

        return Column(
          children: [
            Row(
              children: [
                _buildStatCard(
                  title: 'إجمالي السائقين',
                  count: totalDrivers,
                  icon: Icons.group,
                  color: Colors.indigo,
                ),
                _buildStatCard(
                  title: 'السائقون المتصلون',
                  count: onlineDrivers,
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
                _buildStatCard(
                  title: 'السائقون غير المتصلين',
                  count: offlineDrivers,
                  icon: Icons.cancel,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRatioBar(
              online: onlineDrivers,
              offline: offlineDrivers,
              total: totalDrivers,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatioBar({
    required int online,
    required int offline,
    required int total,
  }) {
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('لا يوجد سائقون لإظهار النسبة'),
      );
    }

    final onlineRatio = online / total;
    final offlineRatio = offline / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text('النسبة المئوية للحالة:', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 20,
            child: Row(
              children: [
                Flexible(
                  flex: (onlineRatio * 100).round(),
                  child: Container(color: Colors.green),
                ),
                Flexible(
                  flex: (offlineRatio * 100).round(),
                  child: Container(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'متصل: ${(onlineRatio * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
            Text(
              'غير متصل: ${(offlineRatio * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

// ===============================================
// الـ Widget 2: سجل الطلبات الأخيرة (بدون تغيير)
// ===============================================

class LatestRideHistory extends StatelessWidget {
  final String companyId;
  const LatestRideHistory({required this.companyId, super.key});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_circle_outline;
      case 'Pending':
        return Icons.access_time;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.local_shipping;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // يتم طلب آخر 7 طلبات مرتبة تنازلياً حسب وقت الإنشاء (createdAt)
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('rides')
          .orderBy('createdAt', descending: true)
          .limit(7)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LinearProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('خطأ في تحميل سجل الطلبات'));
        }

        final rides = snapshot.data?.docs ?? [];

        if (rides.isEmpty) {
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('لا يوجد سجل طلبات حالياً.'),
              ),
            ),
          );
        }

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rides.length,
            itemBuilder: (context, index) {
              final rideData = rides[index].data() as Map<String, dynamic>;

              final status = rideData['status'] ?? 'غير معروف';
              final requesterName = rideData['requesterName'] ?? 'طالب خدمة مجهول';
              final driverName = rideData['driverName'] ?? 'لم يتم التعيين';
              // نفترض أن createdAt مخزن كـ Timestamp
              final timestamp = (rideData['createdAt'] is Timestamp) ? (rideData['createdAt'] as Timestamp).toDate() : DateTime.now();

              final formattedTime = DateFormat('yyyy/MM/dd HH:mm').format(timestamp);

              return ListTile(
                leading: Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                ),
                title: Text(
                  'طلب من: $requesterName',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'الحالة: $status | السائق: $driverName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  formattedTime,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('عرض تفاصيل الطلب: ${rides[index].id}'),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}


// ===============================================
// الـ Widget 3: قائمة تتبع مواقع السائقين (DriverLocationList)
// (استبدال عنصر الخريطة النائب)
// ===============================================

class DriverLocationList extends StatelessWidget {
  final String companyId;
  const DriverLocationList({required this.companyId, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // عرض السائقين المتصلين فقط للحفاظ على التركيز
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .where('isOnline', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(height: 200, child: const Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return const Text('خطأ في تحميل مواقع السائقين');
        }

        final drivers = snapshot.data?.docs ?? [];

        if (drivers.isEmpty) {
          return Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'لا يوجد سائقون متصلون حالياً لعرض مواقعهم.',
                style: TextStyle(color: Colors.blueGrey),
              ),
            ),
          );
        }

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: drivers.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final driverName = data['name'] ?? 'سائق مجهول';
              final latitude = data['lastKnownLocation']?['latitude'] ?? 0.0;
              final longitude = data['lastKnownLocation']?['longitude'] ?? 0.0;
              final lastUpdate = (data['lastLocationUpdate'] is Timestamp)
                  ? DateFormat('HH:mm:ss').format((data['lastLocationUpdate'] as Timestamp).toDate())
                  : 'غير متوفر';

              return ListTile(
                leading: const Icon(Icons.location_on, color: Colors.blue),
                title: Text(driverName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Lat: $latitude, Lon: $longitude'),
                trailing: Text('تحديث: $lastUpdate'),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}


// ===============================================
// الـ Widget 4: ملخص الطلبات المعلقة (PendingRequestsSummary)
// (استبدال عنصر الطلبات العاجلة النائب)
// ===============================================

class PendingRequestsSummary extends StatelessWidget {
  final String companyId;
  const PendingRequestsSummary({required this.companyId, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // جلب الطلبات التي حالتها 'Pending'
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('requests') // نفترض مجموعة 'requests' للطلبات التي تحتاج موافقة HR
          .where('status', isEqualTo: 'Pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LinearProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('خطأ في تحميل الطلبات المعلقة'));
        }

        final pendingRequests = snapshot.data?.docs ?? [];

        if (pendingRequests.isEmpty) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const ListTile(
              leading: Icon(Icons.thumb_up, color: Colors.green),
              title: Text('لا توجد طلبات معلقة للموافقة'),
              subtitle: Text('جميع الطلبات تم التعامل معها أو لا توجد طلبات جديدة.'),
            ),
          );
        }

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              // عرض عدد الطلبات المعلقة كبطاقة صغيرة فوق القائمة
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'إجمالي الطلبات المعلقة:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        pendingRequests.length.toString(),
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              // عرض أول 3 طلبات بالتفصيل
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pendingRequests.length > 3 ? 3 : pendingRequests.length, // عرض أول 3 فقط
                itemBuilder: (context, index) {
                  final requestData = pendingRequests[index].data() as Map<String, dynamic>;
                  final requesterName = requestData['requester_name'] ?? 'مستخدم مجهول';
                  final priority = requestData['priority'] ?? 'عادي';

                  return ListTile(
                    leading: Icon(
                      Icons.warning_amber_rounded,
                      color: priority == 'High' ? Colors.red : Colors.orange,
                    ),
                    title: Text(
                      'طلب من: $requesterName',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('الأولوية: $priority | نوع الغرض: ${requestData['purpose_type'] ?? 'غير محدد'}'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('عرض تفاصيل طلب الموافقة: ${pendingRequests[index].id}'),
                        ),
                      );
                    },
                  );
                },
              ),
              if (pendingRequests.length > 3)
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الانتقال إلى شاشة إدارة الطلبات للموافقة على الكل')),
                    );
                  },
                  child: Text('عرض ${pendingRequests.length - 3} طلب آخر...'),
                ),
            ],
          ),
        );
      },
    );
  }
}
