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

          // ✨ معالجة createdAt بأنواعه المختلفة
          DateTime createdAt;
          if (data['createdAt'] is Timestamp) {
            createdAt = (data['createdAt'] as Timestamp).toDate();
          } else if (data['createdAt'] is String) {
            createdAt = DateTime.parse(data['createdAt']);
          } else {
            createdAt = DateTime.now();
            print('⚠️  نوع createdAt غير معروف: ${data['createdAt']}');
          }

          print('📄 معالجة طلب ${doc.id}: $createdAt');

          return {
            'id': doc.id,
            'department': data['department'] ?? 'غير محدد',
            'destination': data['toLocation'] ?? 'غير محدد',
            'status': _translateStatus(data['status'] ?? 'PENDING'),
            'priority': data['priority'] == 'Urgent' ? 'عاجل' : 'عادي',
            'assignedDriver': data['assignedDriverName'],
            'requesterName': data['requesterName'] ?? 'غير معروف',
            'createdAt': createdAt, // ✨ استخدام التاريخ المعالج
            'firebaseData': data,
          };
        }).toList();
        _loading = false;
      });

      print('🎯 الطلبات المحملة بنجاح: ${_requests.length}');

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
      case 'COMPLETED': return 'مكتمل';
      case 'HR_REJECTED': return 'مرفوض';
      default: return status;
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _requests.where((request) {
      final requestDate = request['createdAt'];

      switch (_filter) {
        case 'اليوم':
          return requestDate.isAfter(todayStart) && requestDate.isBefore(todayEnd);
        case 'العاجلة':
          return request['priority'] == 'عاجل' &&
              ['معلقة', 'بانتظار الموارد البشرية'].contains(request['status']);
        case 'الجارية':
          return ['مُعين للسائق', 'موافق عليه'].contains(request['status']);
        case 'المكتملة':
          return request['status'] == 'مكتمل';
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
    final urgentRequests = _requests.where((r) => r['priority'] == 'عاجل').length;
    final pendingRequests = _requests.where((r) =>
        ['معلقة', 'بانتظار الموارد البشرية'].contains(r['status'])).length;
    final completedToday = _requests.where((r) =>
    r['status'] == 'مكتمل' && r['createdAt'].isAfter(today)).length;

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
    Color statusColor = _getStatusColor(request['status']);
    IconData statusIcon = _getStatusIcon(request['status']);

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
            if (request['priority'] == 'عاجل')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
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
                    request['status'],
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (request['assignedDriver'] != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.person, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    request['assignedDriver']!,
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
      case 'معلقة':
      case 'بانتظار الموارد البشرية':
        return Colors.orange;
      case 'موافق عليه':
        return Colors.blue;
      case 'مُعين للسائق':
        return Colors.purple;
      case 'مكتمل':
        return Colors.green;
      case 'مرفوض':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'معلقة':
      case 'بانتظار الموارد البشرية':
        return Icons.pending;
      case 'موافق عليه':
        return Icons.check_circle;
      case 'مُعين للسائق':
        return Icons.assignment;
      case 'مكتمل':
        return Icons.done_all;
      case 'مرفوض':
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
            _buildDetailRow('الحالة:', request['status']),
            _buildDetailRow('الأولوية:', request['priority']),

            if (request['assignedDriver'] != null)
              _buildDetailRow('السائق المخصص:', request['assignedDriver']!),

            _buildDetailRow('الوقت:', DateFormat('yyyy-MM-dd HH:mm').format(request['createdAt'])),

            const Spacer(),

            // إجراءات
            if (request['priority'] == 'عاجل' &&
                ['معلقة', 'بانتظار الموارد البشرية'].contains(request['status']))
              ElevatedButton(
                onPressed: () => _approveRequest(request),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('موافقة على الطلب العاجل'),
              ),

            const SizedBox(height: 10),

            if (request['status'] != 'مكتمل' && request['assignedDriver'] == null)
              ElevatedButton(
                onPressed: () => _assignDriver(request),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('تخصيص سائق'),
              ),

            if (request['status'] == 'معلقة' && request['priority'] == 'عادي')
              ElevatedButton(
                onPressed: () => _autoAssign(request),
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

  void _approveRequest(Map<String, dynamic> request) {
    // TODO: تنفيذ الموافقة في Firebase
    print('✅ الموافقة على الطلب: ${request['id']}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تمت الموافقة على الطلب #${request['id'].substring(0, 6)}')),
    );
    _loadRequests(); // إعادة تحميل البيانات
    Navigator.pop(context);
  }

  void _assignDriver(Map<String, dynamic> request) {
    _showDriverDialog(request);
  }

  void _autoAssign(Map<String, dynamic> request) {
    // TODO: تنفيذ التوزيع التلقائي
    print('🚗 توزيع تلقائي للطلب: ${request['id']}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('جاري التوزيع التلقائي للطلب #${request['id'].substring(0, 6)}')),
    );
    _loadRequests();
    Navigator.pop(context);
  }

  void _showDriverDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => DriverAssignmentDialog(
        request: request,
        onDriverSelected: (driverName) {
          _assignDriverToRequest(request, driverName);
        },
      ),
    );
  }

  void _assignDriverToRequest(Map<String, dynamic> request, String driverName) {
    // TODO: تنفيذ تعيين السائق في Firebase
    print('👤 تعيين السائق $driverName للطلب: ${request['id']}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تعيين السائق $driverName للطلب #${request['id'].substring(0, 6)}')),
    );
    _loadRequests(); // إعادة تحميل البيانات
  }
}

// Dialog لاختيار السائق
class DriverAssignmentDialog extends StatefulWidget {
  final Map<String, dynamic> request;
  final Function(String) onDriverSelected;

  const DriverAssignmentDialog({
    super.key,
    required this.request,
    required this.onDriverSelected,
  });

  @override
  State<DriverAssignmentDialog> createState() => _DriverAssignmentDialogState();
}

class _DriverAssignmentDialogState extends State<DriverAssignmentDialog> {
  String? _selectedDriver;
  final List<String> _drivers = [
    'أحمد محمد',
    'محمد علي',
    'testdriver',
    'سعيد حسن',
    'عمر فاروق'
  ];

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
            value: _selectedDriver,
            items: _drivers.map((String driver) {
              return DropdownMenuItem<String>(
                value: driver,
                child: Text(driver),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedDriver = newValue;
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
          onPressed: _selectedDriver != null ? () {
            widget.onDriverSelected(_selectedDriver!);
            Navigator.pop(context); // إغلاق Dialog
          } : null,
          child: const Text('تعيين'),
        ),
      ],
    );
  }
}