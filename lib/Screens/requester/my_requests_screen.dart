import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/request_model.dart';
import '../../services/database_service.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  // final DatabaseService _databaseService = DatabaseService(); // ✨ تم حذف هذا المتغير
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String? _companyId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCompanyId();
  }

  Future<void> _fetchCompanyId() async {
    if (_currentUserId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId!)
          .get();

      if (userDoc.exists) {
        setState(() {
          _companyId = userDoc.data()?['companyId'] as String?;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل بيانات الشركة: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_companyId == null || _currentUserId == null) {
      return const Center(
        child: Text('خطأ في تحديد هوية المستخدم أو الشركة.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي السابقة'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Request>>(
        // ✨ تصحيح الخطأ: استخدام اسم الفئة DatabaseService مباشرة
        stream: DatabaseService.getUserRequests(_companyId!, _currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('خطأ في تحميل البيانات: ${snapshot.error}'));
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
                      // استخدام دالة مساعدة لتلوين الحالة
                      _buildStatusText('الحالة: ${request.status}', request.status),
                      if (request.status == 'مُعين للسائق' || request.status == 'قيد التنفيذ')
                        Text('السائق: ${request.assignedDriverName ?? "لم يتم التوزيع بعد"}'),
                      Text('موعد التنفيذ: ${_formatDateTime(request.expectedTime)}'),
                    ],
                  ),
                  trailing: _buildStatusIcon(request.status),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // دالة مساعدة لتلوين حالة الطلب
  Widget _buildStatusText(String status, String rawStatus) {
    Color color = Colors.grey;
    if (rawStatus == 'مكتمل') {
      color = Colors.green;
    } else if (rawStatus == 'مرفوض' || rawStatus == 'ملغي') {
      color = Colors.red;
    } else if (rawStatus == 'قيد التنفيذ' || rawStatus == 'مُعين للسائق') {
      color = Colors.blue;
    }
    return Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold));
  }

  // دالة مساعدة لعرض الأيقونة المناسبة
  Widget _buildStatusIcon(String status) {
    if (status == 'مكتمل') {
      return const Icon(Icons.check_circle, color: Colors.green);
    } else if (status == 'قيد التنفيذ' || status == 'مُعين للسائق') {
      return const Icon(Icons.directions_car, color: Colors.blue);
    } else if (status == 'مرفوض' || status == 'ملغي') {
      return const Icon(Icons.cancel, color: Colors.red);
    }
    return const Icon(Icons.hourglass_empty, color: Colors.grey);
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} - ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}