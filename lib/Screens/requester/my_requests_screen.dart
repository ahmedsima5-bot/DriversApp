import 'package:flutter/material.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return _buildRequestCard(index);
        },
      ),
    );
  }

  Widget _buildRequestCard(int index) {
    final requests = [
      {'type': 'عاجل', 'status': 'مقبول', 'color': Colors.green, 'date': '2024-01-15'},
      {'type': 'عادي', 'status': 'قيد الانتظار', 'color': Colors.orange, 'date': '2024-01-14'},
      {'type': 'مهم', 'status': 'مرفوض', 'color': Colors.red, 'date': '2024-01-13'},
      {'type': 'عادي', 'status': 'مكتمل', 'color': Colors.blue, 'date': '2024-01-12'},
      {'type': 'عاجل', 'status': 'قيد الانتظار', 'color': Colors.orange, 'date': '2024-01-11'},
    ];

    final request = requests[index];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'طلب نقل ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: request['color'] as Color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    request['status'] as String,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('النوع: ${request['type']}'),
            Text('التاريخ: ${request['date']}'),
            const SizedBox(height: 8),
            const Text(
              'نقل موظفين من المقر الرئيسي إلى فرع المدينة',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}