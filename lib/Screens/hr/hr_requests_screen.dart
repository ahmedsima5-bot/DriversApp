import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/dispatch_service.dart';
import 'dart:async';
class HRRequestsScreen extends StatefulWidget {
  final String companyId;

  const HRRequestsScreen({
    super.key,
    required this.companyId,
  });

  @override
  State<HRRequestsScreen> createState() => _HRRequestsScreenState();
}

class _HRRequestsScreenState extends State<HRRequestsScreen> {
  String _filter = 'اليوم';
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  final DispatchService _dispatchService = DispatchService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _startPeriodicRefresh();
  }

  // 🔄 تحديث تلقائي كل 30 ثانية
  void _startPeriodicRefresh() {
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadRequests();
      }
    });
  }

  // 🆕 دالة جديدة: إصلاح حالة السائقين المعطلة
  Future<void> _fixDriversAvailability() async {
    try {
      print('🛠️ جاري إصلاح حالات السائقين...');

      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .get();

      int fixedCount = 0;

      for (var driverDoc in driversSnapshot.docs) {
        final driverData = driverDoc.data();
        final isAvailable = driverData['isAvailable'] ?? true;
        final currentRequestId = driverData['currentRequestId'] as String?;

        // إذا السائق مشغول لكن مافيه طلب حالية
        if (isAvailable == false && (currentRequestId == null || currentRequestId.isEmpty)) {
          await driverDoc.reference.update({
            'isAvailable': true,
            'lastStatusUpdate': FieldValue.serverTimestamp(),
          });
          fixedCount++;
          print('✅ تم إصلاح حالة السائق: ${driverData['name']}');
        }
      }

      if (fixedCount > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إصلاح حالة $fixedCount سائق'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadRequests(); // إعادة تحميل الطلبات بعد الإصلاح
      }
    } catch (e) {
      print('❌ خطأ في إصلاح حالات السائقين: $e');
    }
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return 'لم تُحسب بعد';

    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final remainingSeconds = duration.inSeconds.remainder(60);

    String result = '';
    if (hours > 0) {
      result += '$hours ساعة ';
    }
    if (minutes > 0) {
      result += '$minutes دقيقة ';
    }
    result += '$remainingSeconds ثانية';

    return result.trim();
  }

  Future<Map<String, dynamic>?> _getDriverVehicleDetails(String driverId) async {
    try {
      final driverDoc = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .doc(driverId)
          .get();

      if (driverDoc.exists) {
        final data = driverDoc.data();
        final vehicleInfo = data?['vehicleInfo'] as Map<String, dynamic>?;

        return {
          'type': vehicleInfo?['type'] ?? 'غير محدد',
          'plateNumber': vehicleInfo?['number'] ?? vehicleInfo?['plateNumber'] ?? 'غير محدد',
          'model': vehicleInfo?['model'] ?? 'غير محدد',
        };
      }
      return null;
    } catch (e) {
      print('❌ خطأ في جلب بيانات مركبة السائق: $e');
      return null;
    }
  }

  Future<void> _loadRequests() async {
    try {
      if (mounted) {
        setState(() { _loading = true; });
      }

      final requestsSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _requests = requestsSnapshot.docs.map((doc) {
            final data = doc.data();

            DateTime createdAt;
            final dynamic createdAtData = data['createdAt'];

            if (createdAtData is Timestamp) {
              createdAt = createdAtData.toDate();
            } else if (createdAtData is String) {
              try {
                createdAt = DateTime.parse(createdAtData);
              } catch (_) {
                createdAt = DateTime.now();
              }
            } else {
              createdAt = DateTime.now();
            }

            return {
              'id': doc.id,
              'department': data['department'] ?? 'غير محدد',
              'fromLocation': data['fromLocation'] ?? 'غير محدد',
              'destination': data['toLocation'] ?? 'غير محدد',
              'status': data['status'] ?? 'PENDING',
              'priority': data['priority'] ?? 'Normal',
              'assignedDriverId': data['assignedDriverId'] as String?,
              'assignedDriverName': data['assignedDriverName'] as String?,
              'requesterName': data['requesterName'] ?? 'غير معروف',
              'createdAt': createdAt,
              'firebaseData': data,
            };
          }).toList();
          _loading = false;
        });
      }

    } catch (e) {
      print('❌ خطأ في جلب الطلبات: $e');
      if (mounted) {
        setState(() { _loading = false; });
      }
    }
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'PENDING': return 'معلقة';
      case 'HR_PENDING': return 'بانتظار الموارد البشرية';
      case 'HR_APPROVED': return 'موافق عليه';
      case 'ASSIGNED': return 'مُعين للسائق';
      case 'IN_PROGRESS': return 'قيد التنفيذ';
      case 'COMPLETED': return 'مكتمل';
      case 'HR_REJECTED': return 'مرفوض';
      case 'WAITING_FOR_DRIVER': return 'بانتظار السائق';
      case 'CANCELLED': return 'ملغى';
      default: return status;
    }
  }

  // 🆕 دالة محسنة لجلب السائقين مع إصلاح الحالات
  Future<List<Map<String, dynamic>>> _getAvailableDrivers() async {
    try {
      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> drivers = [];

      for (var doc in driversSnapshot.docs) {
        final data = doc.data();
        final currentRequestId = data['currentRequestId'] as String?;

        // 🆕 التحقق من صحة حالة السائق
        bool isActuallyAvailable = data['isAvailable'] ?? true;

        // إذا السائق مشغول لكن مافيه طلب حالية، نصحح الحالة
        if (isActuallyAvailable == false && (currentRequestId == null || currentRequestId.isEmpty)) {
          isActuallyAvailable = true;
          // نحدث الحالة في الخلفية بدون انتظار
          doc.reference.update({
            'isAvailable': true,
            'lastStatusUpdate': FieldValue.serverTimestamp(),
          });
        }

        drivers.add({
          'id': doc.id,
          'name': data['name'] ?? 'غير معروف',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'isAvailable': isActuallyAvailable, // 🆕 نستخدم الحالة المصححة
          'isOnline': data['isOnline'] ?? false,
          'completedRides': data['completedRides'] ?? 0,
          'rating': (data['rating'] as num?)?.toDouble() ?? 5.0,
          'vehicleType': data['vehicleInfo']?['type'] ?? 'سيارة',
          'currentRequestId': currentRequestId,
        });
      }

      print('👥 عدد السائقين بعد التصحيح: ${drivers.length}');
      print('✅ السائقون المتاحون: ${drivers.where((d) => d['isAvailable'] == true).length}');

      return drivers;
    } catch (e) {
      print('❌ خطأ في جلب السائقين: $e');
      return [];
    }
  }

  // 🆕 دالة محسنة للتعيين اليدوي
  Future<void> _manualAssignDriver(Map<String, dynamic> request) async {
    try {
      final availableDrivers = await _getAvailableDrivers();

      // 🆕 فلترة السائقين المتاحين فقط
      final actuallyAvailableDrivers = availableDrivers.where((driver) => driver['isAvailable'] == true).toList();

      if (actuallyAvailableDrivers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يوجد سائقين متاحين حالياً'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تعيين سائق يدوياً'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: actuallyAvailableDrivers.length,
              itemBuilder: (context, index) {
                final driver = actuallyAvailableDrivers[index];
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(driver['name']),
                  subtitle: Text(
                      '${driver['vehicleType']} - ${driver['completedRides']} مشاوير'
                  ),
                  trailing: const Icon(Icons.check, color: Colors.green),
                  onTap: () {
                    _assignDriverToRequest(request, driver['id'], driver['name']);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في جلب السائقين: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🆕 دالة محسنة للتوزيع التلقائي من واجهة الموارد البشرية
  Future<void> _autoAssignFromHR(Map<String, dynamic> request) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جاري التوزيع التلقائي...'),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // 🆕 أولاً: نصلح حالات السائقين قبل التوزيع
      await _fixDriversAvailability();

      // ثم نترك الخدمة التلقائية تعمل
      await _dispatchService.approveUrgentRequest(
        widget.companyId,
        request['id'],
        'hr_user_id',
        'مسؤول الموارد البشرية',
      );

      // انتظار ثم إعادة تحميل
      await Future.delayed(const Duration(seconds: 3));
      _loadRequests();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التوزيع التلقائي: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelRequest(Map<String, dynamic> request) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل أنت متأكد من إلغاء هذا الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore
                    .collection('companies')
                    .doc(widget.companyId)
                    .collection('requests')
                    .doc(request['id'])
                    .update({
                  'status': 'CANCELLED',
                  'cancelledBy': 'HR',
                  'cancelledAt': FieldValue.serverTimestamp(),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم إلغاء الطلب بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }

                _loadRequests();
                Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ في الإلغاء: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم، إلغاء الطلب'),
          ),
        ],
      ),
    );
  }

  Future<void> _reassignDriver(Map<String, dynamic> request) async {
    if (request['assignedDriverId'] == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هذا الطلب غير معين لأي سائق'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final availableDrivers = await _getAvailableDrivers();
    final actuallyAvailableDrivers = availableDrivers.where((driver) => driver['isAvailable'] == true).toList();

    // استبعاد السائق الحالي
    final filteredDrivers = actuallyAvailableDrivers.where((driver) => driver['id'] != request['assignedDriverId']).toList();

    if (filteredDrivers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد سائقين آخرين متاحين'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحويل المشوار لسائق آخر'),
        content: Text('تحويل المشوار من السائق: ${request['assignedDriverName']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showReassignDriverDialog(request, filteredDrivers);
            },
            child: const Text('اختيار سائق جديد'),
          ),
        ],
      ),
    );
  }

  void _showReassignDriverDialog(Map<String, dynamic> request, List<Map<String, dynamic>> drivers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر السائق الجديد'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(driver['name']),
                subtitle: Text('${driver['vehicleType']} - ${driver['completedRides']} مشاوير'),
                onTap: () {
                  _performReassignment(request, driver);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _performReassignment(Map<String, dynamic> request, Map<String, dynamic> newDriver) async {
    try {
      await _dispatchService.reassignDriver(
          widget.companyId,
          request['id'],
          newDriver['id'],
          newDriver['name'],
          'hr_user_id',
          'مسؤول الموارد البشرية',
          'تحويل من قبل الموارد البشرية'
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحويل المشوار إلى السائق ${newDriver['name']}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التحويل: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignDriverToRequest(Map<String, dynamic> request, String driverId, String driverName) async {
    try {
      await _dispatchService.assignToSpecificDriver(
        widget.companyId,
        request['id'],
        driverId,
        driverName,
        'hr_user_id',
        'مسؤول الموارد البشرية',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تعيين السائق $driverName للطلب'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التعيين: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _requests.where((request) {
      final requestDate = request['createdAt'] as DateTime;
      final status = request['status'] as String;
      final priority = request['priority'] as String;

      switch (_filter) {
        case 'اليوم':
          return requestDate.isAfter(todayStart) && requestDate.isBefore(todayEnd);
        case 'العاجلة':
          return priority == 'Urgent' &&
              ['PENDING', 'HR_PENDING', 'HR_APPROVED'].contains(status);
        case 'الجارية':
          return ['ASSIGNED', 'IN_PROGRESS', 'HR_APPROVED'].contains(status);
        case 'المكتملة':
          return status == 'COMPLETED';
        case 'الملغية':
          return status == 'CANCELLED';
        case 'الكل':
        default:
          return true;
      }
    }).toList();
  }

  Map<String, int> get _stats {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final todayRequests = _requests.where((r) => (r['createdAt'] as DateTime).isAfter(todayStart)).length;
    final urgentRequests = _requests.where((r) => r['priority'] == 'Urgent').length;
    final pendingRequests = _requests.where((r) =>
        ['PENDING', 'HR_PENDING', 'WAITING_FOR_DRIVER'].contains(r['status'])).length;
    final completedToday = _requests.where((r) =>
    r['status'] == 'COMPLETED' && (r['createdAt'] as DateTime).isAfter(todayStart)).length;

    return {
      'today': todayRequests,
      'urgent': urgentRequests,
      'pending': pendingRequests,
      'completed': completedToday,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة الطلبات - ${widget.companyId}'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          // 🆕 زر إصلاح حالات السائقين
          IconButton(
            icon: const Icon(Icons.build),
            onPressed: _fixDriversAvailability,
            tooltip: 'إصلاح حالات السائقين',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // بطاقات الإحصائيات
          _buildStatsCards(stats),

          // فلترة الطلبات
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('اليوم', _filter == 'اليوم'),
                  const SizedBox(width: 8),
                  _buildFilterChip('العاجلة', _filter == 'العاجلة'),
                  const SizedBox(width: 8),
                  _buildFilterChip('الجارية', _filter == 'الجارية'),
                  const SizedBox(width: 8),
                  _buildFilterChip('المكتملة', _filter == 'المكتملة'),
                  const SizedBox(width: 8),
                  _buildFilterChip('الملغية', _filter == 'الملغية'),
                  const SizedBox(width: 8),
                  _buildFilterChip('الكل', _filter == 'الكل'),
                ],
              ),
            ),
          ),

          // عنوان القسم
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الطلبات (${_filteredRequests.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getFilterSubtitle(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // جدول الطلبات
          Expanded(
            child: _filteredRequests.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد طلبات',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredRequests.length,
              itemBuilder: (context, index) {
                final request = _filteredRequests[index];
                return _buildRequestCard(request);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(Map<String, int> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          _buildStatCard('طلبات اليوم', stats['today'] ?? 0, Colors.blue, Icons.today),
          const SizedBox(width: 12),
          _buildStatCard('عاجلة', stats['urgent'] ?? 0, Colors.orange, Icons.warning),
          const SizedBox(width: 12),
          _buildStatCard('قيد الانتظار', stats['pending'] ?? 0, Colors.red, Icons.pending),
          const SizedBox(width: 12),
          _buildStatCard('مكتملة اليوم', stats['completed'] ?? 0, Colors.green, Icons.check_circle),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: Colors.blue.shade100,
      onSelected: (bool value) {
        setState(() {
          _filter = label;
        });
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'] as String;
    final priority = request['priority'] as String;
    final translatedStatus = _translateStatus(status);

    Color statusColor = _getStatusColor(status);
    IconData statusIcon = _getStatusIcon(status);

    final assignedDriverName = request['assignedDriverName'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'طلب #${request['id'].substring(0, 6)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (priority == 'Urgent')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'عاجل',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${request['department']} - ${request['requesterName']}'),
            Text('الوجهة: ${request['destination']}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    translatedStatus,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (assignedDriverName != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.person, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    assignedDriverName,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Text(
          DateFormat('HH:mm').format(request['createdAt'] as DateTime),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        onTap: () => _showRequestDetails(request),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
      case 'HR_PENDING':
        return Colors.orange;
      case 'HR_APPROVED':
        return Colors.blue;
      case 'ASSIGNED':
        return Colors.purple;
      case 'IN_PROGRESS':
        return Colors.green;
      case 'COMPLETED':
        return Colors.green.shade700;
      case 'HR_REJECTED':
      case 'CANCELLED':
        return Colors.red;
      case 'WAITING_FOR_DRIVER':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PENDING':
      case 'HR_PENDING':
        return Icons.pending;
      case 'HR_APPROVED':
        return Icons.check_circle;
      case 'ASSIGNED':
        return Icons.assignment;
      case 'IN_PROGRESS':
        return Icons.directions_car;
      case 'COMPLETED':
        return Icons.done_all;
      case 'HR_REJECTED':
      case 'CANCELLED':
        return Icons.cancel;
      case 'WAITING_FOR_DRIVER':
        return Icons.schedule;
      default:
        return Icons.help;
    }
  }

  String _getFilterSubtitle() {
    switch (_filter) {
      case 'اليوم':
        return 'طلبات اليوم';
      case 'العاجلة':
        return 'طلبات عاجلة تحتاج موافقة';
      case 'الجارية':
        return 'طلبات قيد التنفيذ';
      case 'المكتملة':
        return 'طلبات منتهية';
      case 'الملغية':
        return 'طلبات ملغية';
      case 'الكل':
        return 'جميع الطلبات';
      default:
        return '';
    }
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    final String? assignedDriverId = request['assignedDriverId'] as String?;
    final vehicleInfoFromRequest = request['firebaseData']['vehicleInfo'] as Map<String, dynamic>?;
    final rideDurationInSeconds = request['firebaseData']['rideDuration'] as int? ?? 0;
    final status = request['status'] as String;

    String carType = 'غير محدد';
    String carNumber = 'غير محدد';
    String carModel = 'غير محدد';

    if (vehicleInfoFromRequest != null) {
      carType = vehicleInfoFromRequest['type'] ?? 'غير محدد';
      carNumber = vehicleInfoFromRequest['plateNumber'] ?? 'غير محدد';
      carModel = vehicleInfoFromRequest['model'] ?? 'غير محدد';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateModal) {
            if (vehicleInfoFromRequest == null && assignedDriverId != null && carType == 'غير محدد') {
              _getDriverVehicleDetails(assignedDriverId).then((details) {
                if (details != null && details['type'] != 'غير محدد') {
                  setStateModal(() {
                    carType = details['type'] ?? 'غير محدد';
                    carNumber = details['plateNumber'] ?? 'غير محدد';
                    carModel = details['model'] ?? 'غير محدد';
                  });
                }
              });
            }

            return Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تفاصيل الطلب #${request['id'].substring(0, 6)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildDetailRow('القسم:', request['department']),
                    _buildDetailRow('الموظف:', request['requesterName']),

                    const Divider(height: 20),

                    Text(
                      'مسار الرحلة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('نقطة الانطلاق (من):', request['fromLocation']),
                    _buildDetailRow('الوجهة (إلى):', request['destination']),

                    const Divider(height: 20),

                    Text(
                      'تفاصيل المركبة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildDetailRow('موديل المركبة:', carModel),
                    _buildDetailRow('نوع المركبة:', carType),
                    _buildDetailRow('رقم اللوحة:', carNumber),

                    const Divider(height: 20),

                    if (status == 'COMPLETED')
                      _buildDetailRow(
                        'مدة الرحلة:',
                        _formatDuration(rideDurationInSeconds),
                      ),

                    _buildDetailRow('الحالة:', _translateStatus(status)),
                    _buildDetailRow('الأولوية:', request['priority'] == 'Urgent' ? 'عاجل' : 'عادي'),

                    if (request['assignedDriverName'] != null)
                      _buildDetailRow('السائق المخصص:', request['assignedDriverName']!),

                    _buildDetailRow('وقت الطلب:', DateFormat('yyyy-MM-dd HH:mm').format(request['createdAt'] as DateTime)),

                    const SizedBox(height: 20),

                    // أزرار إدارة الطلب
                    _buildActionButtons(request, status),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> request, String status) {
    return Column(
      children: [
        if (['PENDING', 'HR_PENDING', 'WAITING_FOR_DRIVER'].contains(status))
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _manualAssignDriver(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('تعيين سائق يدوياً'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _autoAssignFromHR(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('توزيع تلقائي'),
                ),
              ),
            ],
          ),

        if (['PENDING', 'HR_PENDING', 'WAITING_FOR_DRIVER'].contains(status))
          const SizedBox(height: 8),

        if (['PENDING', 'HR_PENDING', 'WAITING_FOR_DRIVER'].contains(status))
          ElevatedButton(
            onPressed: () => _cancelRequest(request),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('إلغاء الطلب'),
          ),

        if (['ASSIGNED', 'IN_PROGRESS'].contains(status))
          ElevatedButton(
            onPressed: () => _reassignDriver(request),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('تحويل لسائق آخر'),
          ),

        if (status == 'HR_PENDING' && request['priority'] == 'Urgent')
          ElevatedButton(
            onPressed: () {
              _dispatchService.approveUrgentRequest(
                widget.companyId,
                request['id'],
                'hr_user_id',
                'مسؤول الموارد البشرية',
              );
              Navigator.pop(context);
              _loadRequests();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('موافقة على الطلب العاجل'),
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}