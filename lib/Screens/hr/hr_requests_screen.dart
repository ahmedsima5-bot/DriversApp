import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      print('🔄 جلب الطلبات من الشركة: ${widget.companyId}');

      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .orderBy('createdAt', descending: true)
          .get();

      print('✅ عدد المستندات المستلمة: ${requestsSnapshot.docs.length}');

      setState(() {
        _requests = requestsSnapshot.docs.map((doc) {
          final data = doc.data();

          DateTime createdAt;
          if (data['createdAt'] is Timestamp) {
            createdAt = (data['createdAt'] as Timestamp).toDate();
          } else if (data['createdAt'] is String) {
            createdAt = DateTime.parse(data['createdAt']);
          } else {
            createdAt = DateTime.now();
          }

          return {
            'id': doc.id,
            'department': data['department'] ?? 'غير محدد',
            'destination': data['toLocation'] ?? 'غير محدد',
            'status': data['status'] ?? 'PENDING', // 🔥 الحفاظ على الحالة الأصلية
            'priority': data['priority'] ?? 'Normal',
            'assignedDriverId': data['assignedDriverId'],
            'assignedDriverName': data['assignedDriverName'],
            'requesterName': data['requesterName'] ?? 'غير معروف',
            'createdAt': createdAt,
            'firebaseData': data,
          };
        }).toList();
        _loading = false;
      });

    } catch (e) {
      print('❌ خطأ في جلب الطلبات: $e');
      setState(() { _loading = false; });
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
      default: return status;
    }
  }

  // 🔥 دالة جديدة لجلب السائقين الفعليين من Firebase
  // 🔥 دالة محسنة لجلب السائقين مع معايير التوزيع العادل
  Future<List<Map<String, dynamic>>> _getAvailableDrivers() async {
    try {
      final driversSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .get();

      print('🚗 عدد السائقين المستلم: ${driversSnapshot.docs.length}');

      final drivers = driversSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'غير معروف',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'isAvailable': data['isAvailable'] ?? true,
          'isOnline': data['isOnline'] ?? false,
          'completedRides': data['completedRides'] ?? 0,
          'rating': data['rating'] ?? 5.0,
          'vehicleType': data['vehicleInfo']?['type'] ?? 'سيارة',
          'lastAssignment': data['lastAssignment'] ?? Timestamp.now(),
        };
      }).toList();

      // 🔥 ترتيب السائقين حسب معايير التوزيع العادل
      drivers.sort((a, b) {
        // 1. السائقون المتاحون أولاً
        if (a['isAvailable'] == true && b['isAvailable'] != true) return -1;
        if (a['isAvailable'] != true && b['isAvailable'] == true) return 1;

        // 2. السائقون المتصلون أولاً
        if (a['isOnline'] == true && b['isOnline'] != true) return -1;
        if (a['isOnline'] != true && b['isOnline'] == true) return 1;

        // 3. الأقل في عدد المشاوير المنجزة (لتحقيق العدالة)
        final aRides = a['completedRides'] as int;
        final bRides = b['completedRides'] as int;
        if (aRides < bRides) return -1;
        if (aRides > bRides) return 1;

        // 4. الأعلى تقييماً
        final aRating = a['rating'] as double;
        final bRating = b['rating'] as double;
        if (aRating > bRating) return -1;
        if (aRating < bRating) return 1;

        // 5. الأقدم في التعيين (لمن لم يحصل على طلب منذ فترة)
        final aLastAssignment = a['lastAssignment'] as Timestamp;
        final bLastAssignment = b['lastAssignment'] as Timestamp;
        return aLastAssignment.compareTo(bLastAssignment);
      });

      print('🎯 السائقون بعد الترتيب:');
      for (var driver in drivers) {
        print('   - ${driver['name']} | متاح: ${driver['isAvailable']} | مشاوير: ${driver['completedRides']}');
      }

      return drivers;
    } catch (e) {
      print('❌ خطأ في جلب السائقين: $e');
      return [];
    }
  }

  // 🔥 دالة جديدة للموافقة على الطلب
  Future<void> _approveRequest(Map<String, dynamic> request) async {
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .doc(request['id'])
          .update({
        'status': 'HR_APPROVED',
        'hrApprovedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ تمت الموافقة على الطلب: ${request['id']}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت الموافقة على الطلب #${request['id'].substring(0, 6)}'),
          backgroundColor: Colors.green,
        ),
      );

      _loadRequests(); // إعادة تحميل البيانات
    } catch (e) {
      print('❌ خطأ في الموافقة على الطلب: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الموافقة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🔥 دالة جديدة لتعيين السائق
  Future<void> _assignDriverToRequest(Map<String, dynamic> request, String driverId, String driverName) async {
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .doc(request['id'])
          .update({
        'status': 'ASSIGNED',
        'assignedDriverId': driverId,
        'assignedDriverName': driverName,
        'assignedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // 🔥 تحديث حالة السائق ليكون غير متاح
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .doc(driverId)
          .update({
        'isAvailable': false,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });

      print('✅ تم تعيين السائق $driverName للطلب: ${request['id']}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تعيين السائق $driverName للطلب #${request['id'].substring(0, 6)}'),
          backgroundColor: Colors.green,
        ),
      );

      _loadRequests(); // إعادة تحميل البيانات
    } catch (e) {
      print('❌ خطأ في تعيين السائق: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التعيين: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🔥 دالة جديدة للتوزيع التلقائي
  Future<void> _autoAssign(Map<String, dynamic> request) async {
    try {
      final availableDrivers = await _getAvailableDrivers();
      if (availableDrivers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد سائقين متاحين حالياً'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // اختيار أول سائق متاح
      final driver = availableDrivers.firstWhere(
            (driver) => driver['isAvailable'] == true,
        orElse: () => availableDrivers.first,
      );

      await _assignDriverToRequest(request, driver['id'], driver['name']);

    } catch (e) {
      print('❌ خطأ في التوزيع التلقائي: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التوزيع التلقائي: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _requests.where((request) {
      final requestDate = request['createdAt'];
      final status = request['status'];
      final priority = request['priority'];

      switch (_filter) {
        case 'اليوم':
          return requestDate.isAfter(todayStart) && requestDate.isBefore(todayEnd);
        case 'العاجلة':
          return priority == 'Urgent' &&
              ['PENDING', 'HR_PENDING'].contains(status);
        case 'الجارية':
          return ['ASSIGNED', 'IN_PROGRESS', 'HR_APPROVED'].contains(status);
        case 'المكتملة':
          return status == 'COMPLETED';
        case 'الكل':
        default:
          return true;
      }
    }).toList();
  }

  // إحصائيات سريعة
  Map<String, int> get _stats {
    final today = DateTime.now().subtract(const Duration(days: 1));
    final todayRequests = _requests.where((r) => r['createdAt'].isAfter(today)).length;
    final urgentRequests = _requests.where((r) => r['priority'] == 'Urgent').length;
    final pendingRequests = _requests.where((r) =>
        ['PENDING', 'HR_PENDING'].contains(r['status'])).length;
    final completedToday = _requests.where((r) =>
    r['status'] == 'COMPLETED' && r['createdAt'].isAfter(today)).length;

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
          _buildStatCard('طلبات اليوم', stats['today']!, Colors.blue, Icons.today),
          const SizedBox(width: 12),
          _buildStatCard('عاجلة', stats['urgent']!, Colors.orange, Icons.warning),
          const SizedBox(width: 12),
          _buildStatCard('قيد الانتظار', stats['pending']!, Colors.red, Icons.pending),
          const SizedBox(width: 12),
          _buildStatCard('مكتملة اليوم', stats['completed']!, Colors.green, Icons.check_circle),
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
    final status = request['status'];
    final priority = request['priority'];
    final translatedStatus = _translateStatus(status);

    Color statusColor = _getStatusColor(status);
    IconData statusIcon = _getStatusIcon(status);

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
                if (request['assignedDriverName'] != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.person, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    request['assignedDriverName']!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Text(
          DateFormat('HH:mm').format(request['createdAt']),
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
        return Colors.red;
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
        return Icons.cancel;
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
      case 'الكل':
        return 'جميع الطلبات';
      default:
        return '';
    }
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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

            // تفاصيل الطلب
            _buildDetailRow('القسم:', request['department']),
            _buildDetailRow('الموظف:', request['requesterName']),
            _buildDetailRow('الوجهة:', request['destination']),
            _buildDetailRow('الحالة:', _translateStatus(request['status'])),
            _buildDetailRow('الأولوية:', request['priority'] == 'Urgent' ? 'عاجل' : 'عادي'),

            if (request['assignedDriverName'] != null)
              _buildDetailRow('السائق المخصص:', request['assignedDriverName']!),

            _buildDetailRow('الوقت:', DateFormat('yyyy-MM-dd HH:mm').format(request['createdAt'])),

            const Spacer(),

            // إجراءات
            if (request['priority'] == 'Urgent' &&
                ['PENDING', 'HR_PENDING'].contains(request['status']))
              ElevatedButton(
                onPressed: () {
                  _approveRequest(request);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('موافقة على الطلب العاجل'),
              ),

            const SizedBox(height: 10),

            if (['HR_APPROVED', 'PENDING', 'HR_PENDING'].contains(request['status']) &&
                request['assignedDriverId'] == null)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showDriverDialog(request);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('تخصيص سائق'),
              ),

            if (request['status'] == 'PENDING' && request['priority'] == 'Normal')
              ElevatedButton(
                onPressed: () {
                  _autoAssign(request);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('توزيع تلقائي'),
              ),
          ],
        ),
      ),
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

  void _showDriverDialog(Map<String, dynamic> request) async {
    final availableDrivers = await _getAvailableDrivers();

    if (availableDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد سائقين متاحين حالياً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => DriverAssignmentDialog(
        request: request,
        drivers: availableDrivers,
        onDriverSelected: (driverId, driverName) {
          _assignDriverToRequest(request, driverId, driverName);
        },
      ),
    );
  }
}

// Dialog لاختيار السائق
class DriverAssignmentDialog extends StatefulWidget {
  final Map<String, dynamic> request;
  final List<Map<String, dynamic>> drivers;
  final Function(String, String) onDriverSelected;

  const DriverAssignmentDialog({
    super.key,
    required this.request,
    required this.drivers,
    required this.onDriverSelected,
  });

  @override
  State<DriverAssignmentDialog> createState() => _DriverAssignmentDialogState();
}

class _DriverAssignmentDialogState extends State<DriverAssignmentDialog> {
  String? _selectedDriverId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تخصيص سائق'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('اختر سائق للطلب:'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedDriverId,
            items: widget.drivers.map((driver) {
              return DropdownMenuItem<String>(
                value: driver['id'],
                child: Text('${driver['name']} - ${driver['isAvailable'] ? 'متاح' : 'مشغول'}'),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedDriverId = newValue;
              });
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'اختر السائق',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _selectedDriverId != null ? () {
            final selectedDriver = widget.drivers.firstWhere(
                    (driver) => driver['id'] == _selectedDriverId
            );
            widget.onDriverSelected(_selectedDriverId!, selectedDriver['name']);
            Navigator.pop(context);
          } : null,
          child: const Text('تعيين'),
        ),
      ],
    );
  }
}