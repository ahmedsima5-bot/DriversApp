import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HRDashboard extends StatefulWidget {
  final String companyId;
  const HRDashboard({required this.companyId, super.key});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
  int _totalEmployees = 0;
  int _urgentRequests = 0;
  int _pendingRequests = 0;
  int _onlineDrivers = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      await Future.wait([
        _loadEmployeesCount(),
        _loadRequestsStats(),
        _loadDriversCount(),
      ]);
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEmployeesCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('companyId', isEqualTo: widget.companyId)
        .get();
    setState(() => _totalEmployees = snapshot.docs.length);
  }

  Future<void> _loadRequestsStats() async {
    try {
      // 🔄 الحصول على الطلبات العاجلة مباشرة من Firestore
      final urgentSnapshot = await FirebaseFirestore.instance
          .collection('artifacts/${widget.companyId}/public/data/requests')
          .where('status', isEqualTo: 'PENDING')
          .where('priority', isEqualTo: 'HIGH') // أو 'urgent' حسب هيكل بياناتك
          .get();

      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('artifacts/${widget.companyId}/public/data/requests')
          .where('status', isEqualTo: 'PENDING')
          .get();

      setState(() {
        _urgentRequests = urgentSnapshot.docs.length;
        _pendingRequests = pendingSnapshot.docs.length;
      });
    } catch (e) {
      print('Error loading requests stats: $e');
      // إذا لم يكن هناك حقل priority، استخدم PENDING فقط
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('artifacts/${widget.companyId}/public/data/requests')
          .where('status', isEqualTo: 'PENDING')
          .get();

      setState(() {
        _urgentRequests = 0;
        _pendingRequests = pendingSnapshot.docs.length;
      });
    }
  }

  Future<void> _loadDriversCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('companyId', isEqualTo: widget.companyId)
        .where('role', isEqualTo: 'Driver')
        .get();
    setState(() => _onlineDrivers = snapshot.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // بطاقات الإحصائيات
          StatsGrid(
            totalEmployees: _totalEmployees,
            urgentRequests: _urgentRequests,
            pendingRequests: _pendingRequests,
            onlineDrivers: _onlineDrivers,
          ),
          const SizedBox(height: 24),

          // الطلبات العاجلة
          if (_urgentRequests > 0) ...[
            _buildSectionTitle('طلبات عاجلة تحتاج موافقة'),
            UrgentRequestsTable(companyId: widget.companyId),
            const SizedBox(height: 24),
          ],

          // آخر الطلبات
          _buildSectionTitle('آخر الطلبات'),
          LatestRequestsWidget(companyId: widget.companyId),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        TextButton(
          onPressed: () {
            // TODO: الانتقال للشاشة المختصة
          },
          child: const Text('عرض الكل'),
        ),
      ],
    );
  }
}

// 🎯 تعريف StatsGrid Widget
class StatsGrid extends StatelessWidget {
  final int totalEmployees;
  final int urgentRequests;
  final int pendingRequests;
  final int onlineDrivers;

  const StatsGrid({
    super.key,
    required this.totalEmployees,
    required this.urgentRequests,
    required this.pendingRequests,
    required this.onlineDrivers,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('إجمالي الموظفين', totalEmployees, Icons.people, Colors.blue),
        _buildStatCard('طلبات عاجلة', urgentRequests, Icons.warning, Colors.orange),
        _buildStatCard('طلبات بانتظار الموافقة', pendingRequests, Icons.pending_actions, Colors.amber),
        _buildStatCard('سائقين متصلين', onlineDrivers, Icons.directions_car, Colors.green),
      ],
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// 🎯 تعريف UrgentRequestsTable Widget
class UrgentRequestsTable extends StatelessWidget {
  final String companyId;

  const UrgentRequestsTable({required this.companyId, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('artifacts/$companyId/public/data/requests')
          .where('status', isEqualTo: 'PENDING')
          .where('priority', isEqualTo: 'HIGH')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا توجد طلبات عاجلة'),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الطلبات العاجلة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1),
                  },
                  border: TableBorder.all(color: Colors.grey.shade300),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade100),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('المقدم', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('الغرض', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('الوقت', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('الإجراء', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...requests.map((doc) {
                      final request = doc.data() as Map<String, dynamic>;
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(request['requesterName'] ?? 'غير معروف'),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(request['purpose'] ?? ''),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(_formatDate(request['createdAt'])),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: IconButton(
                              icon: const Icon(Icons.visibility, size: 20),
                              onPressed: () {
                                // TODO: عرض تفاصيل الطلب
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MM/dd HH:mm').format(timestamp.toDate());
    }
    return '--';
  }
}

// Widget للطلبات الأخيرة
class LatestRequestsWidget extends StatelessWidget {
  final String companyId;
  const LatestRequestsWidget({required this.companyId, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('artifacts/$companyId/public/data/requests')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final requests = snapshot.data!.docs;
        if (requests.isEmpty) return const Text('لا توجد طلبات');

        return Card(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: Icon(
                  _getStatusIcon(request['status']),
                  color: _getStatusColor(request['status']),
                ),
                title: Text(request['requesterName'] ?? 'غير معروف'),
                subtitle: Text(request['purpose'] ?? ''),
                trailing: Text(_formatDate(request['createdAt'])),
                onTap: () {
                  // TODO: عرض تفاصيل الطلب
                },
              );
            },
          ),
        );
      },
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'APPROVED': return Icons.check_circle;
      case 'REJECTED': return Icons.cancel;
      case 'PENDING': return Icons.pending;
      default: return Icons.hourglass_empty;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED': return Colors.green;
      case 'REJECTED': return Colors.red;
      case 'PENDING': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MM/dd HH:mm').format(timestamp.toDate());
    }
    return '--';
  }
}