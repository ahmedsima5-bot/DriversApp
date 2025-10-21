import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'new_request_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  final String companyId;
  final String userId;
  final String? userName;

  const MyRequestsScreen({
    super.key,
    required this.companyId,
    required this.userId,
    this.userName,
  });

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _indexCreating = false;

  @override
  void initState() {
    super.initState();
    _loadMyRequests();
  }

  Future<void> _loadMyRequests() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // استعلام مبسط بدون orderBy أولاً لتجنب مشكلة الفهرس
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .where('requesterId', isEqualTo: widget.userId)
          .get();

      // ترتيب البيانات محلياً
      final sortedDocs = snapshot.docs.toList()
        ..sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          return (bTime?.millisecondsSinceEpoch ?? 0)
              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
        });

      setState(() {
        _requests = sortedDocs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
        _isLoading = false;
        _indexCreating = false;
      });
    } catch (e) {
      print('Error loading requests: $e');

      if (e.toString().contains('index') || e.toString().contains('requires an index')) {
        setState(() {
          _errorMessage = 'جاري إنشاء الفهرس في النظام...\nيرجى المحاولة مرة أخرى خلال دقيقة';
          _indexCreating = true;
          _isLoading = false;
        });

        // إعادة المحاولة تلقائياً بعد 5 ثواني
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _loadMyRequests();
        });
      } else {
        setState(() {
          _errorMessage = 'خطأ في تحميل الطلبات: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING':
        return 'قيد الانتظار';
      case 'HR_PENDING':
        return 'بانتظار الموارد البشرية';
      case 'APPROVED':
        return 'مقبول';
      case 'REJECTED':
        return 'مرفوض';
      case 'IN_PROGRESS':
        return 'قيد التنفيذ';
      case 'COMPLETED':
        return 'مكتمل';
      case 'ASSIGNED':
        return 'تم التعيين';
      case 'WAITING_FOR_DRIVER':
        return 'بانتظار السائق'; // ✅ تم التحويل للعربية
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'HR_PENDING':
        return Colors.deepOrange;
      case 'APPROVED':
        return Colors.blue;
      case 'ASSIGNED':
        return Colors.blue.shade700;
      case 'IN_PROGRESS':
        return Colors.green;
      case 'COMPLETED':
        return Colors.green.shade700;
      case 'REJECTED':
        return Colors.red;
      case 'WAITING_FOR_DRIVER':
        return Colors.purple; // ✅ لون مميز لانتظار السائق
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Urgent':
        return Colors.red;
      case 'Normal':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'Urgent':
        return 'عاجل';
      case 'Normal':
        return 'عادي';
      default:
        return priority;
    }
  }

  // ✅ دالة جديدة للتحقق من وجود سائق معين
  bool _hasDriverAssigned(Map<String, dynamic> request) {
    return request['assignedDriverId'] != null &&
        request['assignedDriverId'].toString().isNotEmpty;
  }

  // ✅ دالة جديدة للحصول على اسم السائق
  String _getDriverName(Map<String, dynamic> request) {
    return request['assignedDriverName']?.toString() ??
        request['driverName']?.toString() ??
        'لم يتم التعيين بعد';
  }

  // ✅ دالة جديدة للحصول على صورة السائق
  String? _getDriverImage(Map<String, dynamic> request) {
    return request['assignedDriverImage']?.toString() ??
        request['driverImage']?.toString();
  }

  Widget _buildIndexCreationMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Icon(Icons.build, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'جاري تهيئة النظام...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadMyRequests,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('إعادة المحاولة الآن'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMyRequests,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _indexCreating
          ? _buildIndexCreationMessage()
          : _errorMessage.isNotEmpty && !_indexCreating
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMyRequests,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      )
          : _requests.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'لا توجد طلبات',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'سيظهر هنا الطلبات التي تقوم بإنشائها',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NewTransferRequestScreen(
                      companyId: widget.companyId,
                      userId: widget.userId,
                      userName: widget.userName ?? 'مستخدم',
                    ),
                  ),
                ).then((_) => _loadMyRequests());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
              ),
              child: const Text('إنشاء طلب جديد'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadMyRequests,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _requests.length,
          itemBuilder: (context, index) {
            final request = _requests[index];
            return _buildRequestCard(request);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewTransferRequestScreen(
                companyId: widget.companyId,
                userId: widget.userId,
                userName: widget.userName ?? 'مستخدم',
              ),
            ),
          ).then((_) => _loadMyRequests());
        },
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final createdAt = request['createdAt'] is Timestamp
        ? (request['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    final isUrgent = request['priority'] == 'Urgent';
    final status = request['status'] ?? 'PENDING';
    final title = request['title'] ?? 'طلب نقل';
    final description = request['details'] ?? request['description'] ?? '';
    final fromLocation = request['fromLocation'] ?? '';
    final toLocation = request['toLocation'] ?? '';
    final hasDriver = _hasDriverAssigned(request);
    final driverName = _getDriverName(request);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان والحالة
            Row(
              children: [
                // علامة عاجل
                if (isUrgent) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning, size: 14, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'عاجل',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // العنوان
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),

                // حالة الطلب
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor(status)),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // التاريخ والوقت
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  DateFormat('yyyy/MM/dd').format(createdAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  DateFormat('HH:mm').format(createdAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // المواقع
            if (fromLocation.isNotEmpty || toLocation.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (fromLocation.isNotEmpty)
                    _buildLocationRow('من:', fromLocation, Icons.location_on),
                  if (toLocation.isNotEmpty)
                    _buildLocationRow('إلى:', toLocation, Icons.flag),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // الوصف
            if (description.isNotEmpty) ...[
              Text(
                description,
                style: const TextStyle(fontSize: 14, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
            ],

            // ✅ معلومات السائق (تظهر في جميع الحالات إذا كان هناك سائق)
            if (hasDriver) ...[
              _buildDriverInfo(request),
              const SizedBox(height: 8),
            ],

            const Divider(height: 20),

            // المعلومات الإضافية
            Row(
              children: [
                // القسم
                if (request['department'] != null) ...[
                  _buildInfoChip(
                    'القسم: ${request['department']}',
                    Icons.business,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 8),
                ],

                // الأولوية
                _buildInfoChip(
                  'الأولوية: ${_getPriorityText(request['priority'] ?? 'Normal')}',
                  Icons.flag,
                  color: _getPriorityColor(request['priority'] ?? 'Normal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ ويدجت جديدة لعرض معلومات السائق
  Widget _buildDriverInfo(Map<String, dynamic> request) {
    final driverName = _getDriverName(request);
    final driverImage = _getDriverImage(request);
    final status = request['status'] ?? 'PENDING';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          // صورة السائق أو أيقونة افتراضية
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: driverImage != null
                ? CircleAvatar(
              backgroundImage: NetworkImage(driverImage),
            )
                : Icon(
              Icons.person,
              color: Colors.blue.shade800,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'السائق: $driverName',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getDriverStatusText(status),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
          // أيقونة حسب حالة الطلب
          Icon(
            _getDriverStatusIcon(status),
            color: _getDriverStatusColor(status),
            size: 24,
          ),
        ],
      ),
    );
  }

  // ✅ دالة للحصول على نص حالة السائق
  String _getDriverStatusText(String status) {
    switch (status) {
      case 'ASSIGNED':
        return 'تم تعيين السائق';
      case 'IN_PROGRESS':
        return 'جاري التنفيذ';
      case 'COMPLETED':
        return 'تم إكمال الطلب';
      case 'WAITING_FOR_DRIVER':
        return 'بانتظار بدء التنفيذ';
      default:
        return 'تحت المتابعة';
    }
  }

  // ✅ دالة للحصول على أيقونة حالة السائق
  IconData _getDriverStatusIcon(String status) {
    switch (status) {
      case 'ASSIGNED':
        return Icons.person;
      case 'IN_PROGRESS':
        return Icons.directions_car;
      case 'COMPLETED':
        return Icons.check_circle;
      case 'WAITING_FOR_DRIVER':
        return Icons.access_time;
      default:
        return Icons.person_outline;
    }
  }

  // ✅ دالة للحصول على لون حالة السائق
  Color _getDriverStatusColor(String status) {
    switch (status) {
      case 'ASSIGNED':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.green;
      case 'COMPLETED':
        return Colors.green.shade700;
      case 'WAITING_FOR_DRIVER':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLocationRow(String label, String location, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              location,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon, {Color? color}) {
    final chipColor = color ?? Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: chipColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}