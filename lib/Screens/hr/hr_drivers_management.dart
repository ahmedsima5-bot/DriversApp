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
    setState(() => _loading = true); // تأكد من عرض شاشة التحميل عند التحديث
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
      // استخدم ScaffoldMessenger لعرض رسالة خطأ للمستخدم إذا لم تكن قادرة على استخدام حزمة logger
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ في جلب السائقين: $e')),
        );
      }
      print('❌ خطأ في جلب السائقين: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  // ------------------------------------------------------------------
  //  وظيفة تحديث حالة النشاط (تشغيل/إيقاف السائق)
  // ------------------------------------------------------------------
  Future<void> _toggleDriverActiveStatus(String driverId, bool newStatus) async {
    try {
      await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .doc(driverId)
          .update({
        'isActive': newStatus,
        // عند الإيقاف، من المنطقي جعله غير متاح أيضاً
        if (!newStatus) 'isAvailable': false,
      });

      // إعادة تحميل البيانات بعد التحديث
      await _loadRealDrivers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus ? '✅ تم تشغيل السائق بنجاح.' : '🚫 تم إيقاف السائق بنجاح.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ في تحديث الحالة: $e')),
        );
      }
      print('❌ خطأ في تحديث حالة السائق: $e');
    }
  }
  // ------------------------------------------------------------------

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
        return Colors.red.shade700; // تم تغيير اللون لتمييز الإيقاف
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
          backgroundColor: driver['isActive'] ? Colors.green.shade100 : Colors.grey.shade300,
          child: Icon(Icons.person, color: driver['isActive'] ? Colors.green : Colors.grey.shade600),
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
    final bool isActive = driver['isActive'];
    final String status = _getStatus(driver['isAvailable'], isActive);

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
            _buildDetailRow('الحالة الحالية:', status, color: _getStatusColor(status)),
            _buildDetailRow('المشاوير المكتملة:', '${driver['completedRides']}'),
            _buildDetailRow('متوفر حالياً:', driver['isAvailable'] ? 'نعم' : 'لا'),

            const Divider(height: 20),
            Text(
              'إدارة حالة النشاط (تشغيل/إيقاف)',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
            ),
            const SizedBox(height: 10),

            // ------------------------------------------------------------------
            // زر التحكم بحالة النشاط
            // ------------------------------------------------------------------
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // إغلاق النافذة
                // تبديل حالة النشاط: إذا كان نشطًا سيصبح غير نشط، والعكس صحيح
                _toggleDriverActiveStatus(driver['id'], !isActive);
              },
              icon: Icon(isActive ? Icons.person_off : Icons.play_arrow),
              label: Text(isActive ? 'إيقاف مؤقت (غير نشط)' : 'تشغيل (جعله نشطًا)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.red.shade600 : Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
            // ------------------------------------------------------------------
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

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}