import 'package:flutter/material.dart';

class MyRequestsPage extends StatelessWidget {
  const MyRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي'),
        backgroundColor: Colors.orange,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          _buildRequestItem('طلب #001', 'جدة - الرياض', 'معلق'),
          _buildRequestItem('طلب #002', 'مكة - المدينة', 'مكتمل'),
          _buildRequestItem('طلب #003', 'الدمام - الأحساء', 'قيد التنفيذ'),
        ],
      ),
    );
  }

  Widget _buildRequestItem(String id, String route, String status) {
    Color statusColor = Colors.grey;

    if (status == 'مكتمل') statusColor = Colors.green;
    if (status == 'قيد التنفيذ') statusColor = Colors.orange;

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: const Icon(Icons.local_shipping, color: Colors.orange),
        title: Text(id),
        subtitle: Text(route),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ),
        onTap: () {
          // TODO: تفاصيل الطلب
        },
      ),
    );
  }
}