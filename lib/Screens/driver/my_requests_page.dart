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
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  bool _isLoading = true;
  int _selectedFilter = 0; // 0: الكل, 1: اليوم, 2: الأسبوع, 3: الشهر

  @override
  void initState() {
    super.initState();
    _loadAllRequests();
  }

  String _translate(String key, String languageCode) {
    return AppLocalizations.getTranslatedValue(key, languageCode);
  }

  Future<void> _loadAllRequests() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .where('requesterId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _allRequests = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
        _applyFilter(0);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading requests: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilter(int filterIndex) {
    setState(() {
      _selectedFilter = filterIndex;
      final now = DateTime.now();

      switch (filterIndex) {
        case 0: // الكل
          _filteredRequests = _allRequests;
          break;
        case 1: // اليوم
          final todayStart = DateTime(now.year, now.month, now.day);
          _filteredRequests = _allRequests.where((request) {
            final createdAt = request['createdAt'] is Timestamp
                ? (request['createdAt'] as Timestamp).toDate()
                : DateTime.now();
            return createdAt.isAfter(todayStart);
          }).toList();
          break;
        case 2: // الأسبوع
          final weekStart = now.subtract(const Duration(days: 7));
          _filteredRequests = _allRequests.where((request) {
            final createdAt = request['createdAt'] is Timestamp
                ? (request['createdAt'] as Timestamp).toDate()
                : DateTime.now();
            return createdAt.isAfter(weekStart);
          }).toList();
          break;
        case 3: // الشهر
          final monthStart = DateTime(now.year, now.month, 1);
          _filteredRequests = _allRequests.where((request) {
            final createdAt = request['createdAt'] is Timestamp
                ? (request['createdAt'] as Timestamp).toDate()
                : DateTime.now();
            return createdAt.isAfter(monthStart);
          }).toList();
          break;
      }
    });
  }

  // 🔥 دالة لحساب إحصائيات الأداء
  // 🔥 دالة لحساب إحصائيات الأداء
  // 🔥 دالة لحساب إحصائيات الأداء
  Map<String, dynamic> _calculatePerformanceStats() {
    final completed = _allRequests.where((r) => r['status'] == 'COMPLETED').length;
    final inProgress = _allRequests.where((r) => r['status'] == 'IN_PROGRESS').length;
    final assigned = _allRequests.where((r) => r['status'] == 'ASSIGNED').length;
    final total = _allRequests.length;

    // حساب متوسط مدة الرحلة
    double avgDuration = 0;
    final completedRequests = _allRequests.where((r) => r['status'] == 'COMPLETED' && r['rideDuration'] != null);
    if (completedRequests.isNotEmpty) {
      final totalDuration = completedRequests.fold<int>(0, (sum, r) => sum + ((r['rideDuration'] ?? 0) as int));
      avgDuration = totalDuration / completedRequests.length;
    }

    return {
      'total': total,
      'completed': completed,
      'inProgress': inProgress,
      'assigned': assigned,
      'completionRate': total > 0 ? (completed / total * 100) : 0,
      'avgDuration': avgDuration,
    };
  }

  // 🔥 بطاقة إحصائيات الأداء
  Widget _buildPerformanceCard(String currentLanguage) {
    final stats = _calculatePerformanceStats();

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  _translate('performance_report', currentLanguage),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // الإحصائيات الرئيسية
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  _translate('total_rides', currentLanguage),
                  stats['total'].toString(),
                  Colors.blue,
                ),
                _buildStatItem(
                  _translate('completed', currentLanguage),
                  stats['completed'].toString(),
                  Colors.green,
                ),
                _buildStatItem(
                  _translate('completion_rate', currentLanguage),
                  '${stats['completionRate'].toStringAsFixed(1)}%',
                  Colors.orange,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // معلومات إضافية
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  _translate('in_progress', currentLanguage),
                  stats['inProgress'].toString(),
                  Colors.blue,
                ),
                _buildStatItem(
                  _translate('assigned', currentLanguage),
                  stats['assigned'].toString(),
                  Colors.orange,
                ),
                _buildStatItem(
                  _translate('avg_duration', currentLanguage),
                  '${(stats['avgDuration'] / 60).toStringAsFixed(1)} ${_translate('minutes', currentLanguage)}',
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> request, String currentLanguage) {
    final createdAt = request['createdAt'] is Timestamp
        ? (request['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    final title = request['title'] ?? _translate('transfer_request', currentLanguage);
    final fromLocation = request['fromLocation'] ?? '';
    final toLocation = request['toLocation'] ?? '';
    final status = request['status'] ?? 'PENDING';
    final description = request['details'] ?? request['description'] ?? '';
    final isUrgent = request['priority'] == 'Urgent';
    final department = request['department'] ?? '';
    final requesterName = request['requesterName'] ?? widget.userName;
    final vehicleInfo = request['vehicleInfo'] as Map<String, dynamic>?;

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
                    title,
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

            // معلومات السيارة إذا كانت متوفرة
            if (vehicleInfo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_car, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Text(
                      '${vehicleInfo['model']} - ${vehicleInfo['plateNumber']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

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
                  requesterName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // وصف الطلب
            if (description.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.description, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      description,
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

            // المواقع
            if (fromLocation.isNotEmpty || toLocation.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.place, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$fromLocation → $toLocation',
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

                // القسم
                if (department.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_translate('department', currentLanguage)}: $department',
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
                onPressed: _loadAllRequests,
                tooltip: _translate('refresh', currentLanguage),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              // 🔥 بطاقة الأداء
              _buildPerformanceCard(currentLanguage),

              // 🔥 أزرار التصفية
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterButton(0, _translate('all', currentLanguage), currentLanguage),
                    _buildFilterButton(1, _translate('today', currentLanguage), currentLanguage),
                    _buildFilterButton(2, _translate('this_week', currentLanguage), currentLanguage),
                    _buildFilterButton(3, _translate('this_month', currentLanguage), currentLanguage),
                  ],
                ),
              ),

              // 🔥 عدد النتائج
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${_translate('showing', currentLanguage)} ${_filteredRequests.length} ${_translate('requests', currentLanguage)}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),

              // 🔥 قائمة الطلبات
              Expanded(
                child: _filteredRequests.isEmpty
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
                    ],
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: _loadAllRequests,
                  child: ListView(
                    children: [
                      const SizedBox(height: 8),
                      ..._filteredRequests.map((request) => _buildRequestItem(request, currentLanguage)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterButton(int index, String text, String currentLanguage) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(text),
        selected: _selectedFilter == index,
        onSelected: (selected) => _applyFilter(index),
        backgroundColor: Colors.grey.shade200,
        selectedColor: Colors.orange.shade200,
        checkmarkColor: Colors.orange,
        labelStyle: TextStyle(
          color: _selectedFilter == index ? Colors.orange.shade800 : Colors.grey.shade800,
        ),
      ),
    );
  }
}