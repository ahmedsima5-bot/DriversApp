import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRealStats();
  }

  Future<void> _loadRealStats() async {
    try {
      // جلب إحصائيات الطلبات
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
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('التقارير والإحصائيات - ${widget.companyId}'),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRealStats,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // الإحصائيات الأساسية
          _buildStatCard('إجمالي الطلبات', _stats['totalRequests'].toString(),
              Icons.request_page, Colors.blue),
          _buildStatCard('طلبات عاجلة', _stats['urgentRequests'].toString(),
              Icons.warning, Colors.orange),
          _buildStatCard('طلبات مكتملة', _stats['completedRequests'].toString(),
              Icons.check_circle, Colors.green),
          _buildStatCard('طلبات معلقة', _stats['pendingRequests'].toString(),
              Icons.pending, Colors.red),
          _buildStatCard('السائقين النشطين', _stats['activeDrivers'].toString(),
              Icons.directions_car, Colors.teal),

          const SizedBox(height: 20),
          _buildInfoCard(),
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
        trailing: Text(value, style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color
        )),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'معلومات النظام',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('آخر تحديث:', DateTime.now().toString().substring(0, 16)),
            _buildInfoRow('معرف الشركة:', widget.companyId),
            _buildInfoRow('إجمالي البيانات:', '${_stats['totalRequests']} طلب، ${_stats['activeDrivers']} سائق'),
            const SizedBox(height: 16),
            const Text(
              '💡 هذه الإحصائيات مبنية على البيانات الفعلية في النظام',
              style: TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
}