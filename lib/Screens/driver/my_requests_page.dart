import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/language_provider.dart';
import '../../locales/app_localizations.dart';

class MyRequestsPage extends StatefulWidget {
  final String companyId;
  final String userId;
  final String userName;

  const MyRequestsPage({
    super.key,
    required this.companyId,
    required this.userId,
    required this.userName,
  });

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

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
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .where('requesterId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _requests = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading requests: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildRequestItem(Map<String, dynamic> request, String currentLanguage) {
    final createdAt = request['createdAt'] is Timestamp
        ? (request['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    // الحفاظ على اللغة الأصلية للمحتوى
    final title = request['title'] ?? _translate('transfer_request', currentLanguage);
    final fromLocation = request['fromLocation'] ?? '';
    final toLocation = request['toLocation'] ?? '';
    final status = request['status'] ?? 'PENDING';
    final description = request['details'] ?? request['description'] ?? '';
    final isUrgent = request['priority'] == 'Urgent';
    final department = request['department'] ?? '';
    final requesterName = request['requesterName'] ?? widget.userName;

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان والطابع العاجل
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
                    title, // الحفاظ على اللغة الأصلية
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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

            // اسم الموظف الطالب
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  '${_translate('requester', currentLanguage)}: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  requesterName, // الحفاظ على اللغة الأصلية
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // وصف الطلب (محفوظ كما هو بدون ترجمة)
            if (description.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.description, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      description, // الحفاظ على اللغة الأصلية
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // المواقع (محفوظة كما هي بدون ترجمة)
            if (fromLocation.isNotEmpty || toLocation.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.place, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$fromLocation → $toLocation', // الحفاظ على اللغة الأصلية
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // التاريخ والوقت
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  DateFormat('yyyy/MM/dd - HH:mm').format(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // معلومات إضافية
            Wrap(
              spacing: 8,
              children: [
                // رقم الطلب
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_translate('request_number', currentLanguage)}: ${request['requestId'] ?? ''}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),

                // القسم (محفوظ كما هو بدون ترجمة)
                if (department.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_translate('department', currentLanguage)}: $department', // الحفاظ على اللغة الأصلية
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.purple.shade800,
                      ),
                    ),
                  ),

                // الأولوية
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUrgent ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_translate('priority', currentLanguage)}: ${isUrgent ? _translate('urgent', currentLanguage) : _translate('normal', currentLanguage)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isUrgent ? Colors.red.shade800 : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
      case 'HR_PENDING':
        return Colors.orange;
      case 'APPROVED':
      case 'ASSIGNED':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.green;
      case 'COMPLETED':
        return Colors.green.shade700;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final currentLanguage = languageProvider.currentLanguage;

        return Scaffold(
          appBar: AppBar(
            title: Text(_translate('my_requests', currentLanguage)),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
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
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _loadMyRequests,
            child: ListView(
              children: [
                const SizedBox(height: 8),
                ..._requests.map((request) => _buildRequestItem(request, currentLanguage)),
              ],
            ),
          ),
        );
      },
    );
  }
}