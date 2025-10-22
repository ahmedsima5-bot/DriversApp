import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HRDriversManagement extends StatefulWidget {
  final String companyId;

  const HRDriversManagement({
    super.key,
    required this.companyId,
  });

  @override
  State<HRDriversManagement> createState() => _HRDriversManagementState();
}

class _HRDriversManagementState extends State<HRDriversManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _drivers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRealDrivers();
  }

  Future<void> _loadRealDrivers() async {
    try {
      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .get();

      setState(() {
        _drivers = driversSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'سائق غير معروف',
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? 'غير محدد',
            'isAvailable': data['isAvailable'] ?? false,
            'isActive': data['isActive'] ?? false,
            'completedRides': data['completedRides'] ?? 0,
            'currentRequestId': data['currentRequestId'],
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
      print('❌ خطأ في جلب السائقين: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  String _getStatus(bool isAvailable, bool isActive) {
    if (!isActive) return 'غير نشط';
    return isAvailable ? 'متاح' : 'مشغول';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'متاح':
        return Colors.green;
      case 'مشغول':
        return Colors.orange;
      case 'غير نشط':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة السائقين - ${widget.companyId}'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRealDrivers,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _drivers.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا يوجد سائقين مسجلين',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _drivers.length,
        itemBuilder: (context, index) {
          return _buildDriverCard(_drivers[index]);
        },
      ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final status = _getStatus(driver['isAvailable'], driver['isActive']);
    final statusColor = _getStatusColor(status);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: const Icon(Icons.person, color: Colors.green),
        ),
        title: Text(driver['name']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الهاتف: ${driver['phone']}'),
            Text('البريد: ${driver['email']}'),
            Text('المشاوير المكتملة: ${driver['completedRides']}'),
          ],
        ),
        trailing: Chip(
          label: Text(
            status,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          backgroundColor: statusColor,
        ),
        onTap: () {
          _showDriverDetails(driver);
        },
      ),
    );
  }

  void _showDriverDetails(Map<String, dynamic> driver) {
    final status = _getStatus(driver['isAvailable'], driver['isActive']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل السائق - ${driver['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('رقم السائق:', driver['id']),
            _buildDetailRow('الهاتف:', driver['phone']),
            _buildDetailRow('البريد:', driver['email']),
            _buildDetailRow('الحالة:', status),
            _buildDetailRow('المشاوير المكتملة:', '${driver['completedRides']}'),
            _buildDetailRow('نشط:', driver['isActive'] ? 'نعم' : 'لا'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}