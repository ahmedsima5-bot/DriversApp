// my_requests_screen.dart
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/request_model.dart';
class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseService databaseService = DatabaseService();
    final String currentUserId = 'user_001'; // استبدل بآلية الحصول على ID المستخدم الحقيقي

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات السابقة'),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Request>>(
        stream: databaseService.getUserRequests(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('خطأ في تحميل البيانات'));
          }
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return const Center(child: Text('لا توجد طلبات سابقة'));
          }
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text('غرض الطلب: ${request.purpose}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('القسم: ${request.department}'),
                      Text('الأولوية: ${request.priority}'),
                      Text('الحالة: ${request.status}'),
                      if (request.status == 'مُعين للسائق')
                        Text('السائق: ${request.assignedDriverName ?? "لم يتم التوزيع بعد"}'),
                      Text('موعد التنفيذ: ${_formatDateTime(request.expectedTime)}'),
                    ],
                  ),
                  trailing: request.status == 'مُعين للسائق'
                      ? const Icon(Icons.directions_car, color: Colors.green)
                      : const Icon(Icons.hourglass_empty, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} - ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}