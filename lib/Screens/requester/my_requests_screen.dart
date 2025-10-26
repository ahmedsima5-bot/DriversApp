import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'new_request_screen.dart';
import '../../providers/language_provider.dart';
import '../../locales/app_localizations.dart';

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

  String _translate(String key, String languageCode) {
    return AppLocalizations.getTranslatedValue(key, languageCode);
  }

  Future<void> _loadMyRequests() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .where('requesterId', isEqualTo: widget.userId)
          .get();

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
          // يجب توفير الترجمة 'index_creating'
          _errorMessage = _translate('index_creating', 'ar');
          _indexCreating = true;
          _isLoading = false;
        });

        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _loadMyRequests();
        });
      } else {
        setState(() {
          // يجب توفير الترجمة 'load_requests_error'
          _errorMessage = '${_translate('load_requests_error', 'ar')}: $e';
          _isLoading = false;
        });
      }
    }
  }

  // دالة جديدة لمعالجة إلغاء الطلب
  Future<void> _cancelRequest(String requestId, String currentLanguage) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_translate('cancel_request_confirmation_title', currentLanguage)),
          content: Text(_translate('cancel_request_confirmation_body', currentLanguage)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_translate('no', currentLanguage)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(_translate('yes_cancel', currentLanguage)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('requests')
            .doc(requestId)
            .update({
          'status': 'CANCELED',
          'canceledAt': FieldValue.serverTimestamp(),
          'canceledBy': widget.userId,
          // يمكن إضافة حقل إضافي لإعلام السائق في نظامك
        });

        // تحديث القائمة بعد الإلغاء
        _loadMyRequests();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_translate('request_canceled_successfully', currentLanguage)),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('Error canceling request: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_translate('cancel_request_error', currentLanguage)}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // تحديث دالة الترجمة لإضافة حالة CANCELED
  String _getStatusText(String status, String currentLanguage) {
    switch (status) {
      case 'PENDING':
        return _translate('pending', currentLanguage);
      case 'HR_PENDING':
        return _translate('hr_pending', currentLanguage);
      case 'APPROVED':
        return _translate('approved', currentLanguage);
      case 'REJECTED':
        return _translate('rejected', currentLanguage);
      case 'IN_PROGRESS':
        return _translate('in_progress', currentLanguage);
      case 'COMPLETED':
        return _translate('completed', currentLanguage);
      case 'ASSIGNED':
        return _translate('assigned', currentLanguage);
      case 'WAITING_FOR_DRIVER':
        return _translate('waiting_for_driver', currentLanguage);
      case 'CANCELED': // الحالة الجديدة
        return _translate('canceled', currentLanguage);
      default:
        return status;
    }
  }

  // تحديث دالة الألوان لإضافة حالة CANCELED
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
        return Colors.purple;
      case 'CANCELED': // اللون الرمادي للإلغاء
        return Colors.grey;
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

  String _getPriorityText(String priority, String currentLanguage) {
    switch (priority) {
      case 'Urgent':
        return _translate('urgent', currentLanguage);
      case 'Normal':
        return _translate('normal', currentLanguage);
      default:
        return priority;
    }
  }

  bool _hasDriverAssigned(Map<String, dynamic> request) {
    return request['assignedDriverId'] != null &&
        request['assignedDriverId'].toString().isNotEmpty;
  }

  String _getDriverName(Map<String, dynamic> request) {
    return request['assignedDriverName']?.toString() ??
        request['driverName']?.toString() ??
        'لم يتم التعيين بعد';
  }

  String? _getDriverImage(Map<String, dynamic> request) {
    return request['assignedDriverImage']?.toString() ??
        request['driverImage']?.toString();
  }

  Widget _buildIndexCreationMessage(String currentLanguage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Icon(Icons.build, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            _translate('system_initializing', currentLanguage),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
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
            child: Text(_translate('retry_now', currentLanguage)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final currentLanguage = languageProvider.currentLanguage;

        return Scaffold(
          appBar: AppBar(
            title: Text(_translate('my_requests', currentLanguage)),
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadMyRequests,
                tooltip: _translate('refresh', currentLanguage),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _indexCreating
              ? _buildIndexCreationMessage(currentLanguage)
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
                  child: Text(_translate('retry', currentLanguage)),
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
                Text(
                  _translate('no_requests', currentLanguage),
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  _translate('requests_will_appear_here', currentLanguage),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                          userName: widget.userName ?? _translate('user', currentLanguage),
                        ),
                      ),
                    ).then((_) => _loadMyRequests());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_translate('create_new_request', currentLanguage)),
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
                return _buildRequestCard(request, currentLanguage);
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
                    userName: widget.userName ?? _translate('user', currentLanguage),
                  ),
                ),
              ).then((_) => _loadMyRequests());
            },
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, String currentLanguage) {
    final createdAt = request['createdAt'] is Timestamp
        ? (request['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    final isUrgent = request['priority'] == 'Urgent';
    final status = request['status'] ?? 'PENDING';
    final title = request['title'] ?? _translate('transfer_request', currentLanguage);
    final description = request['details'] ?? request['description'] ?? '';
    final fromLocation = request['fromLocation'] ?? '';
    final toLocation = request['toLocation'] ?? '';
    final hasDriver = _hasDriverAssigned(request);

    // منطق الإلغاء: متاح إذا كان الطلب في حالة انتظار، أو تمت الموافقة عليه ولم يبدأ السائق الرحلة بعد.
    // سنستخدم حالة (ASSIGNED) كحد أقصى للإلغاء دون تسبب بمشاكل في المهام الجارية.
    final isCancellable = status == 'PENDING' || status == 'HR_PENDING' || status == 'APPROVED' || status == 'ASSIGNED' || status == 'WAITING_FOR_DRIVER';

    // نمنع الإلغاء إذا كانت الحالة "قيد التنفيذ" أو "مكتمل" أو "مرفوض" أو "ملغى"
    final isFinalStatus = status == 'IN_PROGRESS' || status == 'COMPLETED' || status == 'REJECTED' || status == 'CANCELED';

    // الحالة النهائية لزر الإلغاء
    final showCancelButton = isCancellable && !isFinalStatus;

    final driverName = _getDriverName(request);


    // البيانات الإضافية
    final additionalDetails = request['additionalDetails'] ?? '';
    final responsibleName = request['responsibleName'] ?? '';
    final responsiblePhone = request['responsiblePhone'] ?? '';
    final purposeType = request['purposeType'] ?? _translate('transfer', currentLanguage);

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
                          _translate('urgent', currentLanguage),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor(status)),
                  ),
                  child: Text(
                    _getStatusText(status, currentLanguage),
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

            // نوع الطلب
            if (purposeType.isNotEmpty)
              _buildSimpleInfoRow(_translate('request_type', currentLanguage), purposeType, currentLanguage),

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
                    _buildLocationRow(_translate('from', currentLanguage), fromLocation, Icons.location_on, currentLanguage),
                  if (toLocation.isNotEmpty)
                    _buildLocationRow(_translate('to', currentLanguage), toLocation, Icons.flag, currentLanguage),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // الوصف
            if (description.isNotEmpty) ...[
              _buildSimpleInfoRow(_translate('description', currentLanguage), description, currentLanguage),
              const SizedBox(height: 8),
            ],

            // التفاصيل الإضافية
            if (additionalDetails.isNotEmpty) ...[
              _buildSimpleInfoRow(_translate('additional_details', currentLanguage), additionalDetails, currentLanguage),
              const SizedBox(height: 8),
            ],

            // معلومات المسؤول
            if (responsibleName.isNotEmpty || responsiblePhone.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _translate('responsible_info', currentLanguage),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    if (responsibleName.isNotEmpty)
                      _buildSimpleInfoRow(_translate('name', currentLanguage), responsibleName, currentLanguage),
                    if (responsiblePhone.isNotEmpty)
                      _buildSimpleInfoRow(_translate('phone', currentLanguage), responsiblePhone, currentLanguage),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // معلومات السائق
            if (hasDriver) ...[
              _buildDriverInfo(request, currentLanguage),
              const SizedBox(height: 8),
            ],

            const Divider(height: 20),

            // المعلومات الإضافية وزر الإلغاء
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // القسم
                      if (request['department'] != null)
                        _buildInfoChip(
                          '${_translate('department', currentLanguage)}: ${request['department']}',
                          Icons.business,
                          color: Colors.purple,
                          currentLanguage: currentLanguage,
                        ),

                      // الأولوية
                      _buildInfoChip(
                        '${_translate('priority', currentLanguage)}: ${_getPriorityText(request['priority'] ?? 'Normal', currentLanguage)}',
                        Icons.flag,
                        color: _getPriorityColor(request['priority'] ?? 'Normal'),
                        currentLanguage: currentLanguage,
                      ),

                      // رقم الطلب
                      _buildInfoChip(
                        '${_translate('request_number', currentLanguage)}: ${request['requestId'] ?? ''}',
                        Icons.numbers,
                        color: Colors.orange,
                        currentLanguage: currentLanguage,
                      ),
                    ],
                  ),
                ),

                // زر الإلغاء (يظهر فقط إذا كانت الحالة تسمح بالإلغاء)
                if (showCancelButton)
                  OutlinedButton.icon(
                    onPressed: () => _cancelRequest(request['id'], currentLanguage),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: Text(_translate('cancel_request', currentLanguage)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfo(Map<String, dynamic> request, String currentLanguage) {
    final driverName = _getDriverName(request);
    final driverImage = _getDriverImage(request);
    final status = request['status'] ?? 'PENDING';

    // لا نعرض معلومات السائق إذا كان الطلب ملغيًا
    if (status == 'CANCELED') return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
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
                  '${_translate('driver', currentLanguage)}: $driverName',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getDriverStatusText(status, currentLanguage),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            _getDriverStatusIcon(status),
            color: _getDriverStatusColor(status),
            size: 24,
          ),
        ],
      ),
    );
  }

  String _getDriverStatusText(String status, String currentLanguage) {
    switch (status) {
      case 'ASSIGNED':
        return _translate('driver_assigned', currentLanguage);
      case 'IN_PROGRESS':
        return _translate('in_progress', currentLanguage);
      case 'COMPLETED':
        return _translate('request_completed', currentLanguage);
      case 'WAITING_FOR_DRIVER':
        return _translate('waiting_for_driver_start', currentLanguage);
      default:
        return _translate('under_followup', currentLanguage);
    }
  }

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

  Widget _buildLocationRow(String label, String location, IconData icon, String currentLanguage) {
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

  Widget _buildSimpleInfoRow(String label, String value, String currentLanguage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              value,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon, {Color? color, required String currentLanguage}) {
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