import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:clipboard/clipboard.dart';
import '../../services/dispatch_service.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart';

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
  final Map<String, Timer> _activeRideTimers = {};
  final Map<String, Duration> _activeRideDurations = {};
  final Map<String, DateTime> _activeRideStartTimes = {};
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

    // فحص حالة السائقين بعد تحميل الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndFixDriversAvailability();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    // تنظيف مؤقتات الرحلة
    _activeRideTimers.forEach((key, timer) => timer.cancel());
    _activeRideTimers.clear();
    super.dispose();
  }

  // تشغيل التحديث التلقائي كل 15 ثانية
  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadRequestsData();
      }
    });
  }

  // تحميل بيانات الطلبات
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
            DateTime createdAt = _parseDateTime(data['createdAt']);

            return {
              'id': doc.id,
              'department': data['department'] as String? ?? 'غير محدد',
              'fromLocation': data['fromLocation'] as String? ?? 'غير محدد',
              'destination': data['toLocation'] as String? ?? 'غير محدد',
              'status': data['status'] as String? ?? 'PENDING',
              'priority': data['priority'] as String? ?? 'Normal',
              'assignedDriverId': data['assignedDriverId'] as String?,
              'assignedDriverName': data['assignedDriverName'] as String?,
              'requesterName': data['requesterName'] as String? ?? 'غير معروف',
              'createdAt': createdAt,
              'originalData': data,
              'notes': data,
            };
          }).toList();
          _isLoading = false;
        });

        // ✅ تهيئة المؤقتات بعد تحميل البيانات
        _initializeActiveRideTimers();
      }

    } catch (error) {
      print('❌ خطأ في تحميل الطلبات: $error');
      if (mounted) {
        setState(() { _isLoading = false; });
        _showErrorSnackBar('فشل في تحميل البيانات: $error');
      }
    }
  }// ========== دوال مؤقت الرحلة قيد التنفيذ ==========

// بدء مؤقت للرحلة قيد التنفيذ
  void _startRideTimer(String requestId, DateTime startTime) {
    _activeRideTimers[requestId]?.cancel();
    _activeRideStartTimes[requestId] = startTime;

    _activeRideTimers[requestId] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          final now = DateTime.now();
          _activeRideDurations[requestId] = now.difference(startTime);
        });
      }
    });
  }

// إيقاف مؤقت الرحلة
  void _stopRideTimer(String requestId) {
    _activeRideTimers[requestId]?.cancel();
    _activeRideTimers.remove(requestId);
    _activeRideDurations.remove(requestId);
    _activeRideStartTimes.remove(requestId);
  }

// تنسيق مدة الرحلة بشكل مقروء
  String _formatActiveDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours} س ${minutes} د ${seconds} ث';
    } else if (minutes > 0) {
      return '${minutes} د ${seconds} ث';
    } else {
      return '${seconds} ث';
    }
  }

// الحصول على مدة الرحلة النشطة
  String _getActiveRideDuration(String requestId) {
    final duration = _activeRideDurations[requestId];
    if (duration != null) {
      return _formatActiveDuration(duration);
    }
    return 'بدء الرحلة...';
  }

// تهيئة المؤقتات للطلبات قيد التنفيذ
  void _initializeActiveRideTimers() {
    // إيقاف جميع المؤقتات القديمة
    _activeRideTimers.forEach((key, timer) => timer.cancel());
    _activeRideTimers.clear();
    _activeRideDurations.clear();
    _activeRideStartTimes.clear();

    // بدء مؤقتات جديدة للطلبات قيد التنفيذ
    for (final request in _allRequests) {
      final status = request['status'] as String;
      if (status == 'IN_PROGRESS') {
        final originalData = request['originalData'];
        final startTime = originalData['rideStartTime'] as Timestamp?;

        if (startTime != null) {
          _startRideTimer(request['id'], startTime.toDate());
        } else {
          // إذا لم يكن هناك وقت بدء محفوظ، استخدم وقت الإنشاء
          _startRideTimer(request['id'], request['createdAt'] as DateTime);
        }
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

  // ✅ دالة النسخ الفعلية
  Future<void> _copyRequestId(String requestId) async {
    try {
      await FlutterClipboard.copy(requestId);
      _showSuccessSnackBar('تم نسخ رقم الطلب: $requestId');
    } catch (error) {
      _showErrorSnackBar('فشل في نسخ الرقم: $error');
    }
  }

  // ========== دوال إدارة السائقين ==========

  // دالة تعيين سائق محدد
  Future<void> _assignToSpecificDriver(
      String companyId,
      String requestId,
      String driverId,
      String driverName,
      String assignedBy,
      String assignedByName,
      ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // تحديث حالة الطلب
        final requestRef = _firestore
            .collection('companies')
            .doc(companyId)
            .collection('requests')
            .doc(requestId);

        transaction.update(requestRef, {
          'status': 'ASSIGNED',
          'assignedDriverId': driverId,
          'assignedDriverName': driverName,
          'assignedAt': FieldValue.serverTimestamp(),
          'assignedBy': assignedBy,
          'assignedByName': assignedByName,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // تحديث حالة السائق
        final driverRef = _firestore
            .collection('companies')
            .doc(companyId)
            .collection('drivers')
            .doc(driverId);

        transaction.update(driverRef, {
          'isAvailable': false,
          'currentRequestId': requestId,
          'lastAssignedAt': FieldValue.serverTimestamp(),
        });

        // إضافة سجل في التاريخ
        final historyRef = _firestore
            .collection('companies')
            .doc(companyId)
            .collection('requests')
            .doc(requestId)
            .collection('history')
            .doc();

        transaction.set(historyRef, {
          'action': 'ASSIGNED',
          'description': 'تم تعيين السائق $driverName',
          'performedBy': assignedByName,
          'timestamp': FieldValue.serverTimestamp(),
          'driverId': driverId,
          'driverName': driverName,
        });
      });

      print('✅ تم تعيين السائق $driverName للطلب $requestId');
    } catch (error) {
      print('❌ خطأ في تعيين السائق: $error');
      throw Exception('فشل في تعيين السائق: $error');
    }
  }

  // دالة تحويل السائق
  Future<void> _reassignDriver(
      String companyId,
      String requestId,
      String newDriverId,
      String newDriverName,
      String reassignedBy,
      String reassignedByName,
      String reason,
      ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // الحصول على بيانات الطلب الحالية
        final requestRef = _firestore
            .collection('companies')
            .doc(companyId)
            .collection('requests')
            .doc(requestId);

        final requestDoc = await transaction.get(requestRef);
        final oldDriverId = requestDoc['assignedDriverId'] as String?;
        final oldDriverName = requestDoc['assignedDriverName'] as String?;

        // تحديث حالة الطلب
        transaction.update(requestRef, {
          'status': 'ASSIGNED',
          'assignedDriverId': newDriverId,
          'assignedDriverName': newDriverName,
          'reassignedAt': FieldValue.serverTimestamp(),
          'reassignedBy': reassignedBy,
          'reassignedByName': reassignedByName,
          'reassignmentReason': reason,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // تحرير السائق القديم إذا كان موجوداً
        if (oldDriverId != null && oldDriverId.isNotEmpty) {
          final oldDriverRef = _firestore
              .collection('companies')
              .doc(companyId)
              .collection('drivers')
              .doc(oldDriverId);

          transaction.update(oldDriverRef, {
            'isAvailable': true,
            'currentRequestId': null,
          });
        }

        // تحديث حالة السائق الجديد
        final newDriverRef = _firestore
            .collection('companies')
            .doc(companyId)
            .collection('drivers')
            .doc(newDriverId);

        transaction.update(newDriverRef, {
          'isAvailable': false,
          'currentRequestId': requestId,
          'lastAssignedAt': FieldValue.serverTimestamp(),
        });

        // إضافة سجل في التاريخ
        final historyRef = _firestore
            .collection('companies')
            .doc(companyId)
            .collection('requests')
            .doc(requestId)
            .collection('history')
            .doc();

        String description = 'تم تحويل الطلب إلى السائق $newDriverName';
        if (oldDriverName != null) {
          description = 'تم تحويل الطلب من $oldDriverName إلى $newDriverName';
        }

        transaction.set(historyRef, {
          'action': 'REASSIGNED',
          'description': description,
          'reason': reason,
          'performedBy': reassignedByName,
          'timestamp': FieldValue.serverTimestamp(),
          'oldDriverId': oldDriverId,
          'oldDriverName': oldDriverName,
          'newDriverId': newDriverId,
          'newDriverName': newDriverName,
        });
      });

      print('✅ تم تحويل الطلب $requestId إلى السائق $newDriverName');
    } catch (error) {
      print('❌ خطأ في تحويل السائق: $error');
      throw Exception('فشل في تحويل السائق: $error');
    }
  }

  // ========== الدوال الجديدة للملاحظات ==========

  // التحقق من وجود ملاحظات صالحة للعرض
  bool _hasValidNotes(Map<String, dynamic> notesData) {
    final validFields = _extractImportantNotes(notesData);
    return validFields.isNotEmpty;
  }

  // استخراج الحقول المهمة فقط
  Map<String, dynamic> _extractImportantNotes(Map<String, dynamic> notesData) {
    final importantNotes = <String, dynamic>{};

    // الحقول التي نريد عرضها
    const importantFields = [
      'title',
      'details',
      'purposeType',
      'notes',
      'description',
      'reason',
      'additionalInfo',
      'specialRequirements',
      'comments'
    ];

    // إضافة الحقول المهمة فقط
    for (final field in importantFields) {
      if (notesData[field] != null &&
          notesData[field].toString().isNotEmpty &&
          notesData[field].toString() != 'null') {
        importantNotes[field] = notesData[field];
      }
    }

    return importantNotes;
  }

  // بناء عرض الملاحظات
  List<Widget> _buildNotesDisplay(Map<String, dynamic> notesData) {
    final importantNotes = _extractImportantNotes(notesData);

    // إذا لم توجد ملاحظات مهمة
    if (importantNotes.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'لا توجد ملاحظات مكتوبة',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        )
      ];
    }

    return importantNotes.entries.map((entry) {
      return _buildDetailRow(_getNoteFieldLabel(entry.key), entry.value.toString());
    }).toList();
  }

  // ترجمة أسماء الحقول لعرضها بشكل مفهوم
  String _getNoteFieldLabel(String fieldName) {
    const labels = {
      'title': 'عنوان الطلب',
      'details': 'التفاصيل',
      'purposeType': 'نوع الخدمة',
      'notes': 'ملاحظات',
      'description': 'الوصف',
      'reason': 'السبب',
      'additionalInfo': 'معلومات إضافية',
      'specialRequirements': 'متطلبات خاصة',
      'comments': 'تعليقات',
    };
    return labels[fieldName] ?? fieldName;
  }

  // ========== الدوال الجديدة لإدارة السائقين ==========

  // فحص وتصحيح حالة السائقين
  Future<void> _checkAndFixDriversAvailability() async {
    try {
      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .get();

      print('🔍 عدد السائقين النشطين: ${driversSnapshot.docs.length}');

      for (final doc in driversSnapshot.docs) {
        final data = doc.data();
        print('🚗 السائق: ${data['name']} - متاح: ${data['isAvailable']} - الطلب الحالي: ${data['currentRequestId']}');
      }
    } catch (error) {
      print('❌ خطأ في فحص السائقين: $error');
    }
  }

  // دالة التوزيع التلقائي المحسنة
  Future<void> _autoAssignRequest(Map<String, dynamic> request) async {
    try {
      _showLoadingDialog('جاري البحث عن سائق متاح...');

      // البحث عن سائق متاح
      final availableDrivers = await _getAvailableDriversList();

      if (availableDrivers.isEmpty) {
        if (mounted) Navigator.pop(context); // إغلاق dialog التحميل
        _showErrorSnackBar('لا يوجد سائقين متاحين حالياً');
        return;
      }

      // اختيار أول سائق متاح (يمكن تطوير الخوارزمية لاحقاً)
      final selectedDriver = availableDrivers.first;

      // استخدام الدالة المحلية لتعيين السائق
      await _assignToSpecificDriver(
        widget.companyId,
        request['id'],
        selectedDriver['id'],
        selectedDriver['name'],
        'hr_user',
        'مسؤول الموارد البشرية',
      );

      if (mounted) Navigator.pop(context); // إغلاق dialog التحميل
      if (mounted) Navigator.pop(context); // إغلاق صفحة التفاصيل

      _showSuccessSnackBar('تم التعيين التلقائي للسائق ${selectedDriver['name']}');
      _loadRequestsData();

    } catch (error) {
      if (mounted) Navigator.pop(context); // إغلاق dialog التحميل
      _showErrorSnackBar('خطأ في التوزيع التلقائي: $error');
      print('❌ خطأ في التوزيع التلقائي: $error');
    }
  }

  // تعيين سائق يدوياً (معدلة للسماح بالسائقين المشغولين)
  Future<void> _assignDriverManually(Map<String, dynamic> request) async {
    try {
      // فحص حالة السائقين أولاً
      await _checkAndFixDriversAvailability();

      // جلب جميع السائقين النشطين (بما فيهم المشغولين)
      final allActiveDrivers = await _getAllActiveDrivers();
      final availableDrivers = allActiveDrivers.where((driver) => driver['isAvailable'] == true).toList();
      final busyDrivers = allActiveDrivers.where((driver) => driver['isAvailable'] == false).toList();

      print('📊 عدد السائقين المتاحين: ${availableDrivers.length}');
      print('📊 عدد السائقين المشغولين: ${busyDrivers.length}');

      // إذا لم يوجد سائقين نهائياً
      if (allActiveDrivers.isEmpty) {
        _showErrorSnackBar('لا يوجد سائقين نشطين في النظام');
        return;
      }

      // عرض جميع السائقين مع إمكانية اختيار المشغولين أيضاً
      _showAllDriversSelectionDialog(request, allActiveDrivers, availableDrivers, busyDrivers);
    } catch (error) {
      _showErrorSnackBar('خطأ في جلب السائقين: $error');
      print('❌ خطأ في تعيين السائق يدوياً: $error');
    }
  }

  // عرض جميع السائقين (المتاحين والمشغولين)
  void _showAllDriversSelectionDialog(
      Map<String, dynamic> request,
      List<Map<String, dynamic>> allDrivers,
      List<Map<String, dynamic>> availableDrivers,
      List<Map<String, dynamic>> busyDrivers,
      ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر السائق'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (availableDrivers.isNotEmpty) ...[
                const Text(
                  'السائقون المتاحون:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                ...availableDrivers.map((driver) => ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(driver['name']),
                  subtitle: Text('${driver['vehicleType']} - ${driver['completedRides']} مشاوير - متاح'),
                  onTap: () {
                    Navigator.pop(context);
                    _assignDriverToRequest(request, driver);
                  },
                )).toList(),
                const SizedBox(height: 16),
              ],

              if (busyDrivers.isNotEmpty) ...[
                const Text(
                  'السائقون المشغولون:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                ...busyDrivers.map((driver) => ListTile(
                  leading: const Icon(Icons.schedule, color: Colors.orange),
                  title: Text(driver['name']),
                  subtitle: Text('${driver['vehicleType']} - ${driver['completedRides']} مشاوير - مشغول'),
                  onTap: () {
                    Navigator.pop(context);
                    _showConfirmBusyDriverDialog(request, driver);
                  },
                )).toList(),
              ],

              if (allDrivers.isEmpty)
                const Text('لا يوجد سائقين في النظام'),
            ],
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

  // تأكيد تعيين سائق مشغول
  void _showConfirmBusyDriverDialog(Map<String, dynamic> request, Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد التعيين'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('السائق ${driver['name']} مشغول حالياً.'),
            const SizedBox(height: 8),
            const Text('هل تريد تعيينه لهذا الطلب؟'),
            const SizedBox(height: 8),
            const Text(
              'ملاحظة: سيتم تحرير الطلب الحالي لهذا السائق تلقائياً.',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // إغلاق dialog التأكيد
              _assignBusyDriverToRequest(request, driver);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('نعم، تعيين'),
          ),
        ],
      ),
    );
  }
// حساب مدة الرحلة وعرضها
  String _getRideDuration(Map<String, dynamic> request) {
    try {
      final originalData = request['originalData'];

      // إذا كانت المدة محفوظة مباشرة
      if (originalData['rideDuration'] != null) {
        final durationInSeconds = originalData['rideDuration'] as int;
        final duration = Duration(seconds: durationInSeconds);
        return _formatDuration(duration);
      }

      // إذا كان هناك وقت بدء وانتهاء
      final startTime = originalData['rideStartTime'] as Timestamp?;
      final endTime = originalData['rideEndTime'] as Timestamp?;

      if (startTime != null && endTime != null) {
        final duration = endTime.toDate().difference(startTime.toDate());
        return _formatDuration(duration);
      }

      return 'غير محسوبة';
    } catch (e) {
      return 'خطأ في الحساب';
    }
  }

// تنسيق المدة بشكل مقروء
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours} س ${minutes} د';
    } else {
      return '${minutes} دقيقة';
    }
  }
  // تعيين سائق مشغول (مع تحرير طلبه الحالي)
  Future<void> _assignBusyDriverToRequest(Map<String, dynamic> request, Map<String, dynamic> driver) async {
    try {
      _showLoadingDialog('جاري تعيين السائق المشغول...');



      // ثانياً: تعيين السائق للطلب الجديد
      await _assignToSpecificDriver(
        widget.companyId,
        request['id'],
        driver['id'],
        driver['name'],
        'hr_user',
        'مسؤول الموارد البشرية',
      );

      if (mounted) Navigator.pop(context); // إغلاق dialog التحميل
      if (mounted) Navigator.pop(context); // إغلاق صفحة التفاصيل

      _showSuccessSnackBar('تم تعيين السائق ${driver['name']} بنجاح');
      _loadRequestsData();
    } catch (error) {
      if (mounted) Navigator.pop(context); // إغلاق dialog التحميل
      _showErrorSnackBar('خطأ في تعيين السائق المشغول: $error');
      print('❌ خطأ في تعيين السائق المشغول: $error');
    }
  }

  // الحصول على الطلب الحالي للسائق
  Future<String?> _getDriverCurrentRequest(String driverId) async {
    try {
      final driverDoc = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .doc(driverId)
          .get();

      return driverDoc.data()?['currentRequestId'] as String?;
    } catch (error) {
      print('❌ خطأ في جلب الطلب الحالي للسائق: $error');
      return null;
    }
  }

  // تحرير السائق من طلبه الحالي
  Future<void> _freeDriverFromCurrentRequest(String driverId, String currentRequestId) async {
    try {
      // تحديث حالة السائق
      await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .doc(driverId)
          .update({
        'isAvailable': true,
        'currentRequestId': null,
      });

      // تحديث حالة الطلب القديم إلى "ملغى" أو "متحول"
      await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .doc(currentRequestId)
          .update({
        'status': 'REASSIGNED',
        'reassignedReason': 'تم تحويل السائق لطلب آخر',
        'reassignedAt': FieldValue.serverTimestamp(),
      });

      print('✅ تم تحرير السائق $driverId من الطلب $currentRequestId');
    } catch (error) {
      print('❌ خطأ في تحرير السائق: $error');
      throw Exception('فشل في تحرير السائق: $error');
    }
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
          _buildStatCard('Today requests', stats['today']!, Colors.blue, Icons.today),
          const SizedBox(width: 12),
          _buildStatCard('Urgent', stats['urgent']!, Colors.orange, Icons.warning),
          const SizedBox(width: 12),
          _buildStatCard('Pending', stats['pending']!, Colors.red, Icons.pending),
          const SizedBox(width: 12),
          _buildStatCard('Today completed', stats['completed']!, Colors.green, Icons.check_circle),
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
// عنصر طلب فردي
// عنصر طلب فردي
  Widget _buildRequestItem(Map<String, dynamic> request) {
    final status = request['status'] as String;
    final priority = request['priority'] as String;
    final statusText = _getStatusText(status);
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final assignedDriver = request['assignedDriverName'];

    // التحقق إذا كان الطلب مكتملاً وعرض المدة
    final bool isCompleted = status == 'COMPLETED';
    final String rideDuration = isCompleted ? _getRideDuration(request) : '';

    // التحقق إذا كان الطلب قيد التنفيذ وعرض المؤقت النشط
    final bool isInProgress = status == 'IN_PROGRESS';
    final String activeDuration = isInProgress ? _getActiveRideDuration(request['id']) : '';

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
              child: GestureDetector(
                onTap: () {
                  _copyRequestId(request['id']);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلب #${request['id']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'انقر لنسخ الرقم',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
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
                // عرض مدة الرحلة للطلبات المكتملة
                if (isCompleted && rideDuration.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.timer, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    rideDuration,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                // عرض المؤقت النشط للطلبات قيد التنفيذ
                if (isInProgress && activeDuration.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.timer, size: 12, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(
                    activeDuration,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('HH:mm').format(request['createdAt'] as DateTime),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (isCompleted && rideDuration.isNotEmpty)
              Text(
                rideDuration,
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (isInProgress && activeDuration.isNotEmpty)
              Text(
                activeDuration,
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        onTap: () => _showRequestDetails(request),
      ),
    );
  }  // عرض تفاصيل الطلب
  void _showRequestDetails(Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _buildRequestDetailsSheet(request);
      },
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
            child: GestureDetector(
              onTap: () {
                _copyRequestId(value);
              },
              child: SelectableText(
                value,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
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

  // ورقة تفاصيل الطلب
  Widget _buildRequestDetailsSheet(Map<String, dynamic> request) {
    final status = request['status'] as String;
    final priority = request['priority'] as String;

    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان والإغلاق
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تفاصيل الطلب',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _copyRequestId(request['id']);
                        },
                        child: Row(
                          children: [
                            Text(
                              'طلب #${request['id']}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.content_copy, size: 16, color: Colors.blue),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
// عرض المؤقت النشط للرحلة قيد التنفيذ
            if (status == 'IN_PROGRESS')
              _buildDetailSection(
                title: 'معلومات الرحلة النشطة',
                children: [
                  _buildDetailRow('المدة المنقضية:', _getActiveRideDuration(request['id'])),
                  if (request['originalData']['rideStartTime'] != null)
                    _buildDetailRow(
                      'وقت البدء:',
                      DateFormat('yyyy-MM-dd HH:mm').format(
                          (request['originalData']['rideStartTime'] as Timestamp).toDate()
                      ),
                    ),
                  _buildDetailRow(
                    'الوقت الحالي:',
                    DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                  ),
                ],
              ),
            const SizedBox(height: 20),

            // معلومات الأساسية
            _buildDetailSection(
              title: 'المعلومات الأساسية',
              children: [
                _buildDetailRow('رقم الطلب:', request['id']),
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

            // عرض الملاحظات إذا كانت موجودة
            if (request['notes'] != null && _hasValidNotes(request['notes']))
              _buildDetailSection(
                title: 'الملاحظات',
                children: _buildNotesDisplay(request['notes']),
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
// عرض مدة الرحلة في التفاصيل للطلبات المكتملة
            if (status == 'COMPLETED')
              _buildDetailSection(
                title: 'معلومات الرحلة',
                children: [
                  _buildDetailRow('مدة الرحلة:', _getRideDuration(request)),
                  if (request['originalData']['rideStartTime'] != null)
                    _buildDetailRow(
                      'وقت البدء:',
                      DateFormat('yyyy-MM-dd HH:mm').format(
                          (request['originalData']['rideStartTime'] as Timestamp).toDate()
                      ),
                    ),
                  if (request['originalData']['rideEndTime'] != null)
                    _buildDetailRow(
                      'وقت الانتهاء:',
                      DateFormat('yyyy-MM-dd HH:mm').format(
                          (request['originalData']['rideEndTime'] as Timestamp).toDate()
                      ),
                    ),
                ],
              ),

            // أزرار التحكم
            _buildActionButtons(request, status),
          ],
        ),
      ),
    );
  }

  // أزرار التحكم في الطلب
  Widget _buildActionButtons(Map<String, dynamic> request, String status) {
    // تحديد الحالات التي تظهر فيها أزرار التعيين
    final bool showAssignmentButtons = [
      'PENDING',
      'HR_PENDING',
      'WAITING_FOR_DRIVER',
      'HR_APPROVED'
    ].contains(status);

    // تحديد الحالات التي تظهر فيها أزرار التحويل
    final bool showReassignmentButton = [
      'ASSIGNED',
      'IN_PROGRESS',
      'HR_APPROVED'
    ].contains(status);

    // تحديد الحالات التي يظهر فيها زر الإلغاء
    final bool showCancelButton = [
      'PENDING',
      'HR_PENDING',
      'WAITING_FOR_DRIVER',
      'ASSIGNED',
      'IN_PROGRESS',
      'HR_APPROVED'
    ].contains(status);

    return Column(
      children: [
        // أزرار التعيين
        if (showAssignmentButtons)
          Column(
            children: [
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
              const SizedBox(height: 12),
            ],
          ),

        // زر التحويل
        if (showReassignmentButton)
          Column(
            children: [
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
              const SizedBox(height: 12),
            ],
          ),

        // زر الإلغاء
        if (showCancelButton)
          Column(
            children: [
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
              const SizedBox(height: 12),
            ],
          ),

        // موافقة على الطلبات العاجلة (لحالة HR_PENDING فقط)
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
        if (mounted) Navigator.pop(context); // إغلاق صفحة التفاصيل
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

      if (mounted) Navigator.pop(context); // إغلاق dialog التحميل
      if (mounted) Navigator.pop(context); // إغلاق صفحة التفاصيل

      _showSuccessSnackBar('تمت الموافقة على الطلب العاجل');
      _loadRequestsData();
    } catch (error) {
      if (mounted) Navigator.pop(context); // إغلاق dialog التحميل
      _showErrorSnackBar('خطأ في الموافقة: $error');
    }
  }

  // ========== دوال مساعدة ==========

  // جلب السائقين المتاحين (مؤكدة)
  Future<List<Map<String, dynamic>>> _getAvailableDriversList() async {
    try {
      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();

      final availableDrivers = driversSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'غير معروف',
          'vehicleType': data['vehicleInfo']?['type'] ?? 'سيارة',
          'completedRides': (data['completedRides'] as num?)?.toInt() ?? 0,
          'isAvailable': data['isAvailable'] ?? true,
        };
      }).toList();

      print('✅ عدد السائقين المتاحين: ${availableDrivers.length}');
      return availableDrivers;

    } catch (error) {
      print('❌ خطأ في جلب السائقين المتاحين: $error');
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

  // تعيين السائق للطلب
  Future<void> _assignDriverToRequest(Map<String, dynamic> request, Map<String, dynamic> driver) async {
    try {
      _showLoadingDialog('جاري التعيين...');

      // استخدام الدالة المحلية لتعيين السائق
      await _assignToSpecificDriver(
        widget.companyId,
        request['id'],
        driver['id'],
        driver['name'],
        'hr_user',
        'مسؤول الموارد البشرية',
      );

      if (mounted) Navigator.pop(context); // إغلاق dialog التحميل
      if (mounted) Navigator.pop(context); // إغلاق صفحة التفاصيل

      _showSuccessSnackBar('تم تعيين السائق ${driver['name']}');
      _loadRequestsData();
    } catch (error) {
      if (mounted) Navigator.pop(context); // إغلاق dialog التحميل
      _showErrorSnackBar('خطأ في التعيين: $error');
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

  // تنفيذ تحويل السائق
  Future<void> _performDriverReassignment(Map<String, dynamic> request, Map<String, dynamic> newDriver) async {
    try {
      _showLoadingDialog('جاري التحويل...');

      // استخدام الدالة المحلية بدلاً من الدالة في Service
      await _reassignDriver(
          widget.companyId,
          request['id'],
          newDriver['id'],
          newDriver['name'],
          'hr_user',
          'مسؤول الموارد البشرية',
          'تحويل من قبل الموارد البشرية'
      );

      if (mounted) Navigator.pop(context); // إغلاق dialog التحميل
      if (mounted) Navigator.pop(context); // إغلاق صفحة التفاصيل

      _showSuccessSnackBar('تم التحويل إلى السائق ${newDriver['name']}');
      _loadRequestsData();
    } catch (error) {
      if (mounted) Navigator.pop(context); // إغلاق dialog التحميل
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