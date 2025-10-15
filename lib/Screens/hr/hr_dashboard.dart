import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import 'widgets/stats_cards.dart';
import 'widgets/requests_table.dart';

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
        .where('company_id', isEqualTo: widget.companyId)
        .get();
    setState(() => _totalEmployees = snapshot.docs.length);
  }

  Future<void> _loadRequestsStats() async {
    final urgentSnapshot = await DatabaseService.getUrgentPendingRequests(widget.companyId).first;
    final pendingSnapshot = await FirebaseFirestore.instance
        .collection('artifacts/${widget.companyId}/public/data/requests')
        .where('status', isEqualTo: 'PENDING')
        .get();

    setState(() {
      _urgentRequests = urgentSnapshot.docs.length;
      _pendingRequests = pendingSnapshot.docs.length;
    });
  }

  Future<void> _loadDriversCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('company_id', isEqualTo: widget.companyId)
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