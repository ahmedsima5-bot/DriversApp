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
  String _currentFilter = 'اليوم';
  List<Map<String, dynamic>> _allRequests = [];
  bool _isLoading = true;
  final DispatchService _dispatchService = DispatchService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _autoRefreshTimer;

  // قائمة الفلاتر المتاحة
  final List<String> _filters = [
    'اليوم',
    'العاجلة',
    'الجارية',
    'المكتملة',
    'الملغية',
    'الكل'
  ];

  @override
  void initState() {
    super.initState();
    _loadRequestsData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // تشغيل التحديث التلقائي كل 30 ثانية
  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadRequestsData();
      }
    });
  }

  // تحميل بيانات الطلبات
  Future<void> _loadRequestsData() async {
    try {
      if (mounted) {
        setState(() { _isLoading = true; });
      }

      final requestsSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _allRequests = requestsSnapshot.docs.map((doc) {
            final data = doc.data();

            // معالجة تاريخ الإنشاء
            DateTime createdAt = _parseDateTime(data['createdAt']);

            return {
              'id': doc.id,
              'department': data['department'] as String? ?? 'غير محدد',
              'fromLocation': data['fromLocation'] as String? ?? 'غير محدد',
              'destination': data['toLocation'] as String? ?? 'غير محدد',
              'status': data['status'] as String? ?? 'PENDING',
              'priority': data['priority'] as String? ?? 'Normal',
              // 💡 تأكد من سلامة نوع البيانات هنا
              'assignedDriverId': data['assignedDriverId'] as String?,
              'assignedDriverName': data['assignedDriverName'] as String?,
              'requesterName': data['requesterName'] as String? ?? 'غير معروف',
              'createdAt': createdAt,
              'originalData': data,
            };
          }).toList();
          _isLoading = false;
        });
      }

    } catch (error) {
      print('❌ خطأ في تحميل الطلبات: $error');
      if (mounted) {
        setState(() { _isLoading = false; });
        _showErrorSnackBar('فشل في تحميل البيانات: $error');
      }
    }
  }

  // معالجة التاريخ من أنواع مختلفة
  DateTime _parseDateTime(dynamic dateData) {
    if (dateData is Timestamp) {
      return dateData.toDate();
    } else if (dateData is String) {
      try {
        return DateTime.parse(dateData);
      } catch (_) {
        return DateTime.now();
      }
    } else {
      return DateTime.now();
    }
  }

  // ترجمة حالة الطلب
  String _getStatusText(String status) {
    const statusMap = {
      'PENDING': 'معلقة',
      'HR_PENDING': 'بانتظار الموارد البشرية',
      'HR_APPROVED': 'موافق عليه',
      'ASSIGNED': 'مُعين للسائق',
      'IN_PROGRESS': 'قيد التنفيذ',
      'COMPLETED': 'مكتمل',
      'HR_REJECTED': 'مرفوض',
      'WAITING_FOR_DRIVER': 'بانتظار السائق',
      'CANCELLED': 'ملغى',
    };
    return statusMap[status] ?? status;
  }

  // فلترة الطلبات حسب النوع المحدد
  List<Map<String, dynamic>> get _filteredRequests {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _allRequests.where((request) {
      final requestDate = request['createdAt'] as DateTime;
      final status = request['status'] as String;
      final priority = request['priority'] as String;

      switch (_currentFilter) {
        case 'اليوم':
          return requestDate.isAfter(todayStart) && requestDate.isBefore(todayEnd);
        case 'العاجلة':
          return priority == 'Urgent' && ['PENDING', 'HR_PENDING'].contains(status);
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

  // إحصائيات سريعة
  Map<String, int> get _quickStats {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return {
      'today': _allRequests.where((r) => (r['createdAt'] as DateTime).isAfter(todayStart)).length,
      'urgent': _allRequests.where((r) => r['priority'] == 'Urgent').length,
      'pending': _allRequests.where((r) => ['PENDING', 'HR_PENDING', 'WAITING_FOR_DRIVER'].contains(r['status'])).length,
      'completed': _allRequests.where((r) => r['status'] == 'COMPLETED' && (r['createdAt'] as DateTime).isAfter(todayStart)).length,
    };
  }

  // الحصول على لون الحالة
  Color _getStatusColor(String status) {
    const colorMap = {
      'PENDING': Colors.orange,
      'HR_PENDING': Colors.orange,
      'HR_APPROVED': Colors.blue,
      'ASSIGNED': Colors.purple,
      'IN_PROGRESS': Colors.green,
      'COMPLETED': Color(0xFF2E7D32),
      'HR_REJECTED': Colors.red,
      'CANCELLED': Colors.red,
      'WAITING_FOR_DRIVER': Colors.amber,
    };
    return colorMap[status] ?? Colors.grey;
  }

  // الحصول على أيقونة الحالة
  IconData _getStatusIcon(String status) {
    const iconMap = {
      'PENDING': Icons.pending,
      'HR_PENDING': Icons.pending,
      'HR_APPROVED': Icons.check_circle,
      'ASSIGNED': Icons.assignment,
      'IN_PROGRESS': Icons.directions_car,
      'COMPLETED': Icons.done_all,
      'HR_REJECTED': Icons.cancel,
      'CANCELLED': Icons.cancel,
      'WAITING_FOR_DRIVER': Icons.schedule,
    };
    return iconMap[status] ?? Icons.help;
  }

  // عرض رسالة خطأ
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // عرض رسالة نجاح
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _quickStats;

    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة الطلبات - ${widget.companyId}'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequestsData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // بطاقات الإحصائيات
          _buildStatisticsCards(stats),

          // شريط الفلترة
          _buildFilterBar(),

          // قائمة الطلبات
          Expanded(
            child: _filteredRequests.isEmpty
                ? _buildEmptyState()
                : _buildRequestsList(),
          ),
        ],
      ),
    );
  }

  // واجهة الإحصائيات
  Widget _buildStatisticsCards(Map<String, int> stats) {
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

  // بطاقة إحصائية فردية
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

  // شريط الفلترة
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                label: Text(filter),
                selected: _currentFilter == filter,
                selectedColor: Colors.blue.shade100,
                onSelected: (selected) {
                  setState(() {
                    _currentFilter = filter;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // واجهة فارغة
  Widget _buildEmptyState() {
    return const Center(
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
    );
  }

  // قائمة الطلبات
  Widget _buildRequestsList() {
    return ListView.builder(
      itemCount: _filteredRequests.length,
      itemBuilder: (context, index) {
        final request = _filteredRequests[index];
        return _buildRequestItem(request);
      },
    );
  }

  // عنصر طلب فردي
  Widget _buildRequestItem(Map<String, dynamic> request) {
    final status = request['status'] as String;
    final priority = request['priority'] as String;
    final statusText = _getStatusText(status);
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final assignedDriver = request['assignedDriverName'];

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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'عاجل',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
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
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (assignedDriver != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.person, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    assignedDriver,
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

  // عرض تفاصيل الطلب
  void _showRequestDetails(Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _buildRequestDetailsSheet(request);
      },
    );
  }

  // ورقة تفاصيل الطلب
  Widget _buildRequestDetailsSheet(Map<String, dynamic> request) {
    final status = request['status'] as String;
    final priority = request['priority'] as String;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان والإغلاق
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تفاصيل الطلب',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // معلومات الأساسية
          _buildDetailSection(
            title: 'المعلومات الأساسية',
            children: [
              _buildDetailRow('القسم:', request['department']),
              _buildDetailRow('الموظف:', request['requesterName']),
              _buildDetailRow('الحالة:', _getStatusText(status)),
              _buildDetailRow('الأولوية:', priority == 'Urgent' ? 'عاجل' : 'عادي'),
            ],
          ),

          const SizedBox(height: 20),

          // مسار الرحلة
          _buildDetailSection(
            title: 'مسار الرحلة',
            children: [
              _buildDetailRow('نقطة الانطلاق:', request['fromLocation']),
              _buildDetailRow('الوجهة:', request['destination']),
            ],
          ),

          const SizedBox(height: 20),

          // معلومات السائق إذا موجود
          if (request['assignedDriverName'] != null)
            _buildDetailSection(
              title: 'السائق',
              children: [
                _buildDetailRow('السائق:', request['assignedDriverName']!),
              ],
            ),

          const SizedBox(height: 20),

          // وقت الإنشاء
          _buildDetailRow(
            'وقت الطلب:',
            DateFormat('yyyy-MM-dd HH:mm').format(request['createdAt'] as DateTime),
          ),

          const SizedBox(height: 30),

          // أزرار التحكم
          _buildActionButtons(request, status),
        ],
      ),
    );
  }

  // قسم تفاصيل
  Widget _buildDetailSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  // صف تفاصيل
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // أزرار التحكم في الطلب
  Widget _buildActionButtons(Map<String, dynamic> request, String status) {
    return Column(
      children: [
        // أزرار التعيين للطلبات النشطة
        if (['PENDING', 'HR_PENDING', 'WAITING_FOR_DRIVER'].contains(status))
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person),
                  label: const Text('تعيين سائق'),
                  onPressed: () => _assignDriverManually(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('توزيع تلقائي'),
                  onPressed: () => _autoAssignRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),

        if (['PENDING', 'HR_PENDING', 'WAITING_FOR_DRIVER'].contains(status))
          const SizedBox(height: 12),

        // زر التحويل للطلاب المعينة
        if (['ASSIGNED', 'IN_PROGRESS'].contains(status))
          ElevatedButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: const Text('تحويل لسائق آخر'),
            onPressed: () => _reassignToAnotherDriver(request),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),

        if (['ASSIGNED', 'IN_PROGRESS'].contains(status))
          const SizedBox(height: 12),

        // زر الإلغاء للطلبات النشطة
        if (['PENDING', 'HR_PENDING', 'WAITING_FOR_DRIVER', 'ASSIGNED', 'IN_PROGRESS'].contains(status))
          ElevatedButton.icon(
            icon: const Icon(Icons.cancel),
            label: const Text('إلغاء الطلب'),
            onPressed: () => _cancelThisRequest(request),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),

        // موافقة على الطلبات العاجلة
        if (status == 'HR_PENDING' && request['priority'] == 'Urgent')
          ElevatedButton.icon(
            icon: const Icon(Icons.thumb_up),
            label: const Text('موافقة على الطلب العاجل'),
            onPressed: () => _approveUrgentRequest(request),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
      ],
    );
  }

  // ========== دوال التحكم في الطلبات ==========

  // تعيين سائق يدوياً
  Future<void> _assignDriverManually(Map<String, dynamic> request) async {
    try {
      final availableDrivers = await _getAvailableDriversList();

      if (availableDrivers.isEmpty) {
        _showErrorSnackBar('لا يوجد سائقين متاحين حالياً');
        return;
      }

      _showDriverSelectionDialog(request, availableDrivers);
    } catch (error) {
      _showErrorSnackBar('خطأ في جلب السائقين: $error');
    }
  }

  // التوزيع التلقائي
  Future<void> _autoAssignRequest(Map<String, dynamic> request) async {
    try {
      _showLoadingDialog('جاري التوزيع التلقائي...');

      await _dispatchService.approveUrgentRequest(
        widget.companyId,
        request['id'],
        'hr_user',
        'مسؤول الموارد البشرية',
      );

      if (mounted) Navigator.pop(context); // إغلاق dialog التحميل
      if (mounted) Navigator.pop(context); // إغلاق صفحة التفاصيل
      if (mounted) _showSuccessSnackBar('تمت الموافقة على الطلب العاجل');

      _showSuccessSnackBar('تم التوزيع التلقائي بنجاح');
      _loadRequestsData();
    } catch (error) {
      Navigator.pop(context); // إغلاق dialog التحميل
      _showErrorSnackBar('خطأ في التوزيع التلقائي: $error');
    }
  }

  // تحويل لسائق آخر
  Future<void> _reassignToAnotherDriver(Map<String, dynamic> request) async {
    if (request['assignedDriverId'] == null) {
      _showErrorSnackBar('هذا الطلب غير معين لأي سائق');
      return;
    }

    try {
      final allDrivers = await _getAllActiveDrivers();
      final otherDrivers = allDrivers.where((driver) =>
      driver['id'] != request['assignedDriverId']).toList();

      if (otherDrivers.isEmpty) {
        _showErrorSnackBar('لا يوجد سائقين آخرين متاحين');
        return;
      }

      _showReassignmentDialog(request, otherDrivers);
    } catch (error) {
      _showErrorSnackBar('خطأ في التحويل: $error');
    }
  }

  // إلغاء الطلب
  Future<void> _cancelThisRequest(Map<String, dynamic> request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: const Text('هل أنت متأكد من إلغاء هذا الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _cancelRequestImplementation(request);
        Navigator.pop(context); // إغلاق صفحة التفاصيل
        _showSuccessSnackBar('تم إلغاء الطلب بنجاح');
        _loadRequestsData();
      } catch (error) {
        _showErrorSnackBar('خطأ في الإلغاء: $error');
      }
    }
  }

  // موافقة على طلب عاجل
  Future<void> _approveUrgentRequest(Map<String, dynamic> request) async {
    try {
      _showLoadingDialog('جاري الموافقة...');

      await _dispatchService.approveUrgentRequest(
        widget.companyId,
        request['id'],
        'hr_user',
        'مسؤول الموارد البشرية',
      );

      Navigator.pop(context); // إغلاق dialog التحميل
      Navigator.pop(context); // إغلاق صفحة التفاصيل

      _showSuccessSnackBar('تمت الموافقة على الطلب العاجل');
      _loadRequestsData();
    } catch (error) {
      Navigator.pop(context); // إغلاق dialog التحميل
      _showErrorSnackBar('خطأ في الموافقة: $error');
    }
  }

  // ========== دوال مساعدة ==========

  // جلب السائقين المتاحين
  Future<List<Map<String, dynamic>>> _getAvailableDriversList() async {
    try {
      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();

      return driversSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'غير معروف',
          'vehicleType': data['vehicleInfo']?['type'] ?? 'سيارة',
          'completedRides': (data['completedRides'] as num?)?.toInt() ?? 0,
        };
      }).toList();
    } catch (error) {
      print('❌ خطأ في جلب السائقين: $error');
      return [];
    }
  }

  // جلب جميع السائقين النشطين
  Future<List<Map<String, dynamic>>> _getAllActiveDrivers() async {
    try {
      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .get();

      return driversSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'غير معروف',
          'isAvailable': data['isAvailable'] ?? true,
          'vehicleType': data['vehicleInfo']?['type'] ?? 'سيارة',
          'completedRides': (data['completedRides'] as num?)?.toInt() ?? 0,
        };
      }).toList();
    } catch (error) {
      print('❌ خطأ في جلب السائقين: $error');
      return [];
    }
  }

  // عرض dialog اختيار السائق
  void _showDriverSelectionDialog(Map<String, dynamic> request, List<Map<String, dynamic>> drivers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر السائق'),
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
                  Navigator.pop(context);
                  _assignDriverToRequest(request, driver);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // عرض dialog التحويل
  void _showReassignmentDialog(Map<String, dynamic> request, List<Map<String, dynamic>> drivers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحويل المشوار'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              final isAvailable = driver['isAvailable'] == true;

              return ListTile(
                leading: Icon(
                  isAvailable ? Icons.check_circle : Icons.schedule,
                  color: isAvailable ? Colors.green : Colors.orange,
                ),
                title: Text(driver['name']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${driver['vehicleType']} - ${driver['completedRides']} مشاوير'),
                    Text(
                      isAvailable ? 'متاح' : 'مشغول',
                      style: TextStyle(
                        color: isAvailable ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.pop(context);
                  _performDriverReassignment(request, driver);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // تعيين السائق للطلب
  Future<void> _assignDriverToRequest(Map<String, dynamic> request, Map<String, dynamic> driver) async {
    try {
      _showLoadingDialog('جاري التعيين...');

      await _dispatchService.assignToSpecificDriver(
        widget.companyId,
        request['id'],
        driver['id'],
        driver['name'],
        'hr_user',
        'مسؤول الموارد البشرية',
      );

      Navigator.pop(context); // إغلاق dialog التحميل
      Navigator.pop(context); // إغلاق صفحة التفاصيل

      _showSuccessSnackBar('تم تعيين السائق ${driver['name']}');
      _loadRequestsData();
    } catch (error) {
      Navigator.pop(context); // إغلاق dialog التحميل
      _showErrorSnackBar('خطأ في التعيين: $error');
    }
  }

  // تنفيذ تحويل السائق
  Future<void> _performDriverReassignment(Map<String, dynamic> request, Map<String, dynamic> newDriver) async {
    try {
      _showLoadingDialog('جاري التحويل...');

      await _dispatchService.reassignDriver(
          widget.companyId,
          request['id'],
          newDriver['id'],
          newDriver['name'],
          'hr_user',
          'مسؤول الموارد البشرية',
          'تحويل من قبل الموارد البشرية'
      );

      Navigator.pop(context); // إغلاق dialog التحميل
      Navigator.pop(context); // إغلاق صفحة التفاصيل

      _showSuccessSnackBar('تم التحويل إلى السائق ${newDriver['name']}');
      _loadRequestsData();
    } catch (error) {
      Navigator.pop(context); // إغلاق dialog التحميل
      _showErrorSnackBar('خطأ في التحويل: $error');
    }
  }

  // تنفيذ إلغاء الطلب
  Future<void> _cancelRequestImplementation(Map<String, dynamic> request) async {
    final assignedDriverId = request['assignedDriverId'] as String?;

    // تحرير السائق إذا كان معيناً
    if (assignedDriverId != null && assignedDriverId.isNotEmpty) {
      await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .doc(assignedDriverId)
          .update({
        'isAvailable': true,
        'currentRequestId': null,
      });
    }

    // تحديث حالة الطلب
    await _firestore
        .collection('companies')
        .doc(widget.companyId)
        .collection('requests')
        .doc(request['id'])
        .update({
      'status': 'CANCELLED',
      'cancelledBy': 'HR',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  // عرض dialog تحميل
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}
