import 'package:flutter/material.dart';

class RequestsTable extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final String filter;
  final Function(Map<String, dynamic>) onRequestTap;

  const RequestsTable({
    super.key,
    required this.requests,
    required this.filter,
    required this.onRequestTap,
  });

  @override
  Widget build(BuildContext context) {
    // تصفية الطلبات حسب الفلتر
    final filteredRequests = _getFilteredRequests();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredRequests.length,
      itemBuilder: (context, index) {
        final request = filteredRequests[index];
        return _buildRequestCard(request, context);
      },
    );
  }

  List<Map<String, dynamic>> _getFilteredRequests() {
    switch (filter) {
      case 'عاجل':
        return requests.where((request) => request['priority'] == 'عاجل').toList();
      case 'معلقة':
        return requests.where((request) => request['status'] == 'معلقة').toList();
      case 'جارية':
        return requests.where((request) => request['status'] == 'جارية').toList();
      default:
        return requests;
    }
  }

  Widget _buildRequestCard(Map<String, dynamic> request, BuildContext context) {
    Color statusColor = _getStatusColor(request['status']);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 10,
          height: 40,
          color: statusColor,
        ),
        title: Text('طلب #${request['id']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${request['destination']}'),
            Text('${request['department']}'),
            if (request['assignedDriver'] != null)
              Text('السائق: ${request['assignedDriver']}'),
          ],
        ),
        trailing: Chip(
          label: Text(
            request['status'],
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          backgroundColor: statusColor,
        ),
        onTap: () => onRequestTap(request),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'معلقة':
        return Colors.orange;
      case 'مقبول':
        return Colors.green;
      case 'جارية':
        return Colors.blue;
      case 'مرفوض':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}