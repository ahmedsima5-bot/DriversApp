import 'package:flutter/material.dart';

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
  final List<Map<String, dynamic>> _drivers = [
    {
      'id': 'D001',
      'name': 'أحمد محمد',
      'phone': '+966500000001',
      'status': 'متاح',
      'assignedRequests': 2,
      'rating': 4.5,
    },
    {
      'id': 'D002',
      'name': 'محمد علي',
      'phone': '+966500000002',
      'status': 'مشغول',
      'assignedRequests': 1,
      'rating': 4.2,
    },
    {
      'id': 'D003',
      'name': 'testdriver',
      'phone': '+966500000003',
      'status': 'متاح',
      'assignedRequests': 0,
      'rating': 4.8,
    },
    {
      'id': 'D004',
      'name': 'سعيد حسن',
      'phone': '+966500000004',
      'status': 'إجازة',
      'assignedRequests': 0,
      'rating': 4.0,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة السائقين - ${widget.companyId}'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _drivers.length,
        itemBuilder: (context, index) {
          return _buildDriverCard(_drivers[index]);
        },
      ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    Color statusColor = _getStatusColor(driver['status']);

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
            Text('الطلبات المخصصة: ${driver['assignedRequests']}'),
            Row(
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text('${driver['rating']}'),
              ],
            ),
          ],
        ),
        trailing: Chip(
          label: Text(
            driver['status'],
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'متاح':
        return Colors.green;
      case 'مشغول':
        return Colors.orange;
      case 'إجازة':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showDriverDetails(Map<String, dynamic> driver) {
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
            _buildDetailRow('الحالة:', driver['status']),
            _buildDetailRow('التقييم:', '${driver['rating']} / 5.0'),
            _buildDetailRow('الطلبات النشطة:', '${driver['assignedRequests']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: تعديل بيانات السائق
              Navigator.pop(context);
            },
            child: const Text('تعديل البيانات'),
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
          Text(value),
        ],
      ),
    );
  }
}