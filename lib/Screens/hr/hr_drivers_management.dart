import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart'; // 🔥 حزمة الخرائط (مجانية ولا تحتاج API Key)
import 'package:latlong2/latlong.dart';      // 🔥 لحساب الإحداثيات

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
    setState(() => _loading = true);
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
            'location': data['location'] as Map<String, dynamic>?, // 🔥 جلب بيانات الموقع
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
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

  Future<void> _toggleDriverActiveStatus(String driverId, bool newStatus) async {
    try {
      await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .doc(driverId)
          .update({
        'isActive': newStatus,
        if (!newStatus) 'isAvailable': false,
      });

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
  // 🔥 وظيفة فتح شاشة التتبع على الخريطة (باستخدام flutter_map)
  // ------------------------------------------------------------------
  void _showDriverLocation(Map<String, dynamic> driver) {
    final driverId = driver['id'] as String;
    final driverName = driver['name'] as String;
    final locationData = driver['location'] as Map<String, dynamic>?;

    if (locationData == null || locationData['latitude'] == null || locationData['longitude'] == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ لا تتوفر بيانات موقع حالية لهذا السائق.')),
        );
      }
      return;
    }

    // تحويل الإحداثيات إلى نوع LatLng لاستخدامه في الخريطة
    final initialLocation = LatLng(
      (locationData['latitude'] as num).toDouble(),
      (locationData['longitude'] as num).toDouble(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (context) {
        return DriverLocationTracker(
          companyId: widget.companyId,
          driverId: driverId,
          driverName: driverName,
          initialLocation: initialLocation,
        );
      },
    );
  }
  // ------------------------------------------------------------------


  String _getStatus(bool isAvailable, bool isActive) {
    if (!isActive) return 'غير نشط';
    // تحديد حالة "قيد العمل"
    if (!isAvailable) return 'مشغول';
    return 'متاح';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'متاح':
        return Colors.green;
      case 'مشغول':
        return Colors.orange;
      case 'غير نشط':
        return Colors.red.shade700;
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
    final bool locationAvailable = (driver['location'] as Map<String, dynamic>?) != null;

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

            // زر التحكم بحالة النشاط
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // إغلاق النافذة
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
          ],
        ),
        actions: [
          // 🔥 زر التتبع المباشر
          TextButton.icon(
            icon: const Icon(Icons.location_on, color: Colors.blue),
            label: const Text('تتبع مباشر'),
            onPressed: locationAvailable
                ? () {
              Navigator.pop(context); // إغلاق نافذة التفاصيل
              _showDriverLocation(driver); // فتح نافذة التتبع
            }
                : null, // تعطيل الزر إذا لم يكن هناك موقع
          ),
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

// ===================================================================
// 🔥 الكلاس الجديد لتتبع السائق على الخريطة (باستخدام flutter_map)
// ===================================================================

class DriverLocationTracker extends StatelessWidget {
  final String companyId;
  final String driverId;
  final String driverName;
  final LatLng initialLocation;

  const DriverLocationTracker({
    super.key,
    required this.companyId,
    required this.driverId,
    required this.driverName,
    required this.initialLocation,
  });

  // ------------------------------------------------------------------
  // دالة تُنشئ Stream لجلب تحديثات الموقع من Firestore
  // ------------------------------------------------------------------
  Stream<DocumentSnapshot<Map<String, dynamic>>> _getLocationStream() {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('drivers')
        .doc(driverId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تتبع مباشر: $driverName'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _getLocationStream(),
        builder: (context, snapshot) {
          LatLng currentPosition = initialLocation;
          String statusText = 'جاري الاتصال...';

          if (snapshot.hasError) {
            statusText = 'خطأ في جلب البيانات: ${snapshot.error}';
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            statusText = 'جاري تحميل الموقع الأولي...';
          } else if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data();
            final location = data?['location'] as Map<String, dynamic>?;

            if (location != null && location['latitude'] != null && location['longitude'] != null) {
              currentPosition = LatLng(
                (location['latitude'] as num).toDouble(),
                (location['longitude'] as num).toDouble(),
              );
              statusText = 'موقع السائق مُحدَّث لحظياً.';
            } else {
              statusText = 'السائق لم يُرسل موقعه بعد.';
            }
          }

          return Stack(
            children: [
              // 🛑 مكون الخريطة (FlutterMap)
              FlutterMap(
                // مفتاح يسمح للخريطة بتحديث العرض عند تغير initialCenter
                key: ValueKey(currentPosition),
                options: MapOptions(
                  initialCenter: currentPosition,
                  initialZoom: 16.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  // طبقة الخرائط (TileLayer) من OpenStreetMap
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.hrdriversmanagement', // استبدلها باسم تطبيقك
                    // إعدادات الكاش إذا لزم الأمر
                  ),
                  // طبقة العلامات (Markers)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: currentPosition,
                        width: 80,
                        height: 80,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // شريط معلومات الحالة
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 14,
                            color: snapshot.hasError ? Colors.red : Colors.blueGrey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'الإحداثيات: (${currentPosition.latitude.toStringAsFixed(5)}, ${currentPosition.longitude.toStringAsFixed(5)})',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}