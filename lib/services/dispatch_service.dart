import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class DispatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;

  // ✅ دالة التوزيع التلقائي للطلب المحدد
  Future<void> autoAssignSingleRequest(String companyId, String requestId) async {
    try {
      print('🚀 بدء التوزيع التلقائي للطلب: $requestId');

      final requestDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .doc(requestId)
          .get();

      if (requestDoc.exists) {
        final requestData = requestDoc.data()!;
        print('📋 بيانات الطلب: ${requestData['priority']} - ${requestData['status']}');
        await _fairAutoAssign(companyId, requestId, requestData);
      } else {
        print('❌ الطلب غير موجود: $requestId');
      }
    } catch (e) {
      print('❌ خطأ في التوزيع التلقائي للطلب: $e');
      rethrow;
    }
  }

  // 🆕 دالة التشخيص التفصيلي
  Future<void> debugSystem(String companyId) async {
    print('\n🔍 === بدء التشخيص التفصيلي للنظام ===');

    try {
      // 1. التحقق من جميع الطلبات
      final allRequests = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      print('📋 آخر 10 طلبات في النظام:');
      for (var doc in allRequests.docs) {
        final data = doc.data();
        print('   ├─ ${doc.id}');
        print('   │  - الحالة: ${data['status']}');
        print('   │  - الأولوية: ${data['priority']}');
        print('   │  - السائق: ${data['assignedDriverId'] ?? "غير مخصص"}');
        print('   │  - القسم: ${data['department']}');
        print('   └─ الوقت: ${data['createdAt']}');
      }

      // 2. التحقق من السائقين
      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .get();

      print('\n👥 السائقين النشطين: ${driversSnapshot.docs.length}');
      for (var doc in driversSnapshot.docs) {
        final data = doc.data();
        final driverId = doc.id;

        // حساب الطلبات النشطة لكل سائق
        final activeRequests = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('requests')
            .where('assignedDriverId', isEqualTo: driverId)
            .where('status', whereIn: ['ASSIGNED', 'IN_PROGRESS'])
            .get();

        print('   ├─ ${data['name']} (${doc.id})');
        print('   │  - أونلاين: ${data['isOnline'] ?? false}');
        print('   │  - متاح: ${data['isAvailable'] ?? true}');
        print('   │  - معطل: ${data['isBlocked'] ?? false}');
        print('   │  - مشاوير: ${data['completedRides'] ?? 0}');
        print('   │  - طلبات نشطة: ${activeRequests.docs.length}');
        print('   │  - قابل للتوزيع: ${activeRequests.docs.length < 3 && data['isBlocked'] != true}');
      }

      // 3. البحث عن الطلبات المعلقة
      final pendingRequests = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .where('status', whereIn: ['PENDING', 'HR_APPROVED'])
          .get();

      print('\n📊 الطلبات المعلقة للتوزيع: ${pendingRequests.docs.length}');
      for (var doc in pendingRequests.docs) {
        final data = doc.data();
        print('   ├─ ${doc.id}');
        print('   │  - الحالة: ${data['status']}');
        print('   │  - الأولوية: ${data['priority']}');
        print('   │  - السائق: ${data['assignedDriverId'] ?? "غير مخصص"}');

        if (data['priority'] == 'Normal' && data['assignedDriverId'] == null) {
          print('   │  🎯 قابل للتوزيع التلقائي');
          // توزيع فوري أثناء التشخيص
          await autoAssignSingleRequest(companyId, doc.id);
        } else {
          print('   │  ⏸️ غير قابل للتوزيع');
        }
      }

      // 4. التحقق من إعدادات النظام
      print('\n⚙️ إعدادات النظام:');
      print('   - النظام التلقائي مفعل: ${_requestsSubscription != null}');
      print('   - عدد الطلبات الكلي: ${allRequests.docs.length}');
      print('   - طلبات قابلة للتوزيع: ${pendingRequests.docs.where((doc) => doc.data()['priority'] == 'Normal' && doc.data()['assignedDriverId'] == null).length}');

    } catch (e) {
      print('❌ خطأ في التشخيص: $e');
    }

    print('✅ انتهى التشخيص التفصيلي\n');
  }

  // 🆕 نظام الاستماع التلقائي المحسن
  void startAutoDispatchListener(String companyId) {
    print('🎯 تفعيل النظام التلقائي للشركة: $companyId');

    // إيقاف أي اشتراك سابق
    _requestsSubscription?.cancel();

    _requestsSubscription = _firestore
        .collection('companies')
        .doc(companyId)
        .collection('requests')
        .snapshots()
        .listen((snapshot) async {
      print('📡 حدث جديد في الطلبات: ${snapshot.docChanges.length} تغيير');

      for (var change in snapshot.docChanges) {
        final requestData = change.doc.data() as Map<String, dynamic>? ?? {};
        final requestId = change.doc.id;
        final status = requestData['status'] as String?;
        final priority = requestData['priority'] as String?;
        final assignedDriverId = requestData['assignedDriverId'] as String?;

        print('   📝 الطلب: $requestId');
        print('   ├─ الحالة: $status');
        print('   ├─ الأولوية: $priority');
        print('   └─ السائق: $assignedDriverId');

        // شروط التوزيع التلقائي
        final bool isEligibleForAutoAssign =
            assignedDriverId == null &&
                (status == 'PENDING' || status == 'HR_APPROVED') &&
                priority == 'Normal';

        if (isEligibleForAutoAssign) {
          print('   🚀 ينطبق عليه التوزيع التلقائي - جاري التوزيع...');
          await Future.delayed(const Duration(seconds: 3));
          await autoAssignSingleRequest(companyId, requestId);
        } else {
          print('   ⏸️ لا ينطبق عليه التوزيع التلقائي');
        }
      }
    }, onError: (error) {
      print('❌ خطأ في النظام التلقائي: $error');
    });
  }

  // 🆕 إيقاف النظام التلقائي
  void stopAutoDispatchListener() {
    _requestsSubscription?.cancel();
    _requestsSubscription = null;
    print('⏹️ إيقاف النظام التلقائي للتوزيع');
  }

  // ✨ نظام التوزيع العادل - النسخة المحسنة
  Future<void> _fairAutoAssign(String companyId, String requestId, Map<String, dynamic> requestData) async {
    try {
      print('🎯 بدء التوزيع العادل للطلب: $requestId');
      print('📋 بيانات الطلب: ${requestData['priority']} - ${requestData['status']}');

      // التحقق إذا كان الطلب مخصصاً مسبقاً
      if (requestData['assignedDriverId'] != null) {
        print('⚠️ الطلب مخصص مسبقاً للسائق: ${requestData['assignedDriverName']}');
        return;
      }

      // 1. جلب جميع السائقين النشطين
      final allDrivers = await _getAllDriversForAssignment(companyId);
      print('👥 عدد السائقين النشطين: ${allDrivers.length}');

      if (allDrivers.isEmpty) {
        print('❌ لا يوجد سائقين نشطين');
        await _updateRequestStatus(companyId, requestId, 'WAITING_FOR_DRIVER', 'بانتظار سائق متاح');
        return;
      }

      // 2. تطبيق قواعد التوزيع العادل
      final selectedDriver = _selectDriverByFairRules(allDrivers, requestData);

      if (selectedDriver != null) {
        print('✅ السائق المختار: ${selectedDriver['name']} - مشاوير: ${selectedDriver['completedRides']}');
        await _assignToDriverDirectly(companyId, requestId, requestData, selectedDriver);
      } else {
        print('❌ لم يتم العثور على سائق مناسب');
        await _updateRequestStatus(companyId, requestId, 'WAITING_FOR_DRIVER', 'لا يوجد سائق مناسب');
      }

    } catch (e) {
      print('❌ خطأ في التوزيع العادل: $e');
    }
  }

  // ✨ جلب جميع السائقين مع بيانات مفصلة
  Future<List<Map<String, dynamic>>> _getAllDriversForAssignment(String companyId) async {
    try {
      print('🔍 جلب السائقين للشركة: $companyId');

      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .get();

      print('📋 عدد السائقين النشطين في Firebase: ${driversSnapshot.docs.length}');

      final List<Map<String, dynamic>> drivers = [];

      for (var doc in driversSnapshot.docs) {
        final data = doc.data();
        final driverId = doc.id;

        print('👤 فحص السائق: ${data['name']}');

        // ✅ التحقق من حالة السائق
        final driverStatus = await _checkDriverFlexibleStatus(companyId, driverId, data);

        print('   - متاح فعلياً: ${driverStatus['isActuallyAvailable']}');
        print('   - طلبات نشطة: ${driverStatus['activeRequestsCount']}');
        print('   - مشاوير مكتملة: ${driverStatus['completedRides']}');
        print('   - أونلاين: ${driverStatus['isOnline']}');
        print('   - قابل للتوزيع: ${driverStatus['canAcceptRides']}');

        if (driverStatus['canAcceptRides']) {
          drivers.add({
            'id': driverId,
            'name': data['name'] ?? 'غير معروف',
            'isAvailable': driverStatus['isActuallyAvailable'],
            'isOnline': driverStatus['isOnline'],
            'completedRides': driverStatus['completedRides'],
            'activeRequests': driverStatus['activeRequestsCount'],
            'totalWorkload': driverStatus['completedRides'] + driverStatus['activeRequestsCount'],
            'fairnessScore': _calculateFairnessScore(driverStatus['completedRides'], driverStatus['activeRequestsCount']),
            'canAcceptRides': driverStatus['canAcceptRides'],
          });
        }
      }

      print('✅ عدد السائقين القابلين للتوزيع: ${drivers.length}');
      return drivers;
    } catch (e) {
      print('❌ خطأ في جلب السائقين للتوزيع: $e');
      return [];
    }
  }

  // ✅ التحقق من حالة السائق
  Future<Map<String, dynamic>> _checkDriverFlexibleStatus(String companyId, String driverId, Map<String, dynamic> driverData) async {
    final bool isActuallyAvailable = driverData['isAvailable'] ?? true;
    final int completedRides = (driverData['completedRides'] as num?)?.toInt() ?? 0;
    final bool isOnline = driverData['isOnline'] ?? false;

    // حساب عدد الطلبات النشطة
    final activeRequests = await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('requests')
        .where('assignedDriverId', isEqualTo: driverId)
        .where('status', whereIn: ['ASSIGNED', 'IN_PROGRESS'])
        .get();

    final int activeRequestsCount = activeRequests.docs.length;

    bool canAcceptRides = true;

    // ❌ الشروط التي تمنع التوزيع:
    if (activeRequestsCount >= 3) {
      canAcceptRides = false;
      print('   ⚠️ السائق لديه $activeRequestsCount طلبات نشطة - تجاوز الحد المسموح');
    }

    if (driverData['isBlocked'] == true) {
      canAcceptRides = false;
      print('   ⚠️ السائق معطل من النظام');
    }

    return {
      'isActuallyAvailable': isActuallyAvailable,
      'isOnline': isOnline,
      'completedRides': completedRides,
      'activeRequestsCount': activeRequestsCount,
      'canAcceptRides': canAcceptRides,
    };
  }

  // ✨ اختيار السائق بناءً على قواعد العدالة
  Map<String, dynamic>? _selectDriverByFairRules(
      List<Map<String, dynamic>> drivers,
      Map<String, dynamic> requestData
      ) {
    final String priority = requestData['priority'] ?? 'Normal';

    print('📊 عدد السائقين المؤهلين: ${drivers.length}');

    if (drivers.isEmpty) {
      print('⚠️ لا يوجد سائقين مؤهلين حالياً');
      return null;
    }

    Map<String, dynamic>? selectedDriver;

    if (priority == 'Urgent') {
      final candidatesWithoutActive = drivers.where((driver) => driver['activeRequests'] == 0).toList();

      if (candidatesWithoutActive.isNotEmpty) {
        candidatesWithoutActive.sort((a, b) => (a['completedRides'] ?? 0).compareTo(b['completedRides'] ?? 0));
        selectedDriver = candidatesWithoutActive.first;
        print('🚨 طلب عاجل - تم اختيار سائق بدون طلبات نشطة: ${selectedDriver['name']}');
      } else {
        drivers.sort((a, b) => (a['completedRides'] ?? 0).compareTo(b['completedRides'] ?? 0));
        selectedDriver = drivers.first;
        print('🚨 طلب عاجل - تم اختيار سائق بأقل مشاوير: ${selectedDriver['name']}');
      }
    } else {
      drivers.sort((a, b) {
        final scoreA = a['fairnessScore'] ?? 0;
        final scoreB = b['fairnessScore'] ?? 0;
        return scoreB.compareTo(scoreA);
      });

      selectedDriver = drivers.first;
      print('📊 طلب عادي - تم اختيار السائق: ${selectedDriver['name']}');
    }

    print('🎯 تفاصيل التوزيع:');
    print('   - السائق: ${selectedDriver['name']}');
    print('   - المشاوير المكتملة: ${selectedDriver['completedRides']}');
    print('   - الطلبات النشطة: ${selectedDriver['activeRequests']}');
    print('   - درجة العدالة: ${selectedDriver['fairnessScore']?.toStringAsFixed(2)}');

    return selectedDriver;
  }

  // ✨ دالة مساعدة للتحديث المباشر
  Future<void> _assignToDriverDirectly(
      String companyId,
      String requestId,
      Map<String, dynamic> requestData,
      Map<String, dynamic> driver
      ) async {
    try {
      print('🔄 تعيين الطلب $requestId للسائق ${driver['name']}');

      await _firestore.runTransaction((transaction) async {
        transaction.update(
          _firestore
              .collection('companies')
              .doc(companyId)
              .collection('requests')
              .doc(requestId),
          {
            'assignedDriverId': driver['id'],
            'assignedDriverName': driver['name'],
            'status': 'ASSIGNED',
            'assignedTime': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
            'autoAssigned': true,
            'assignmentReason': 'توزيع عادي بناءً على عدد المشاوير',
          },
        );

        transaction.update(
          _firestore
              .collection('companies')
              .doc(companyId)
              .collection('drivers')
              .doc(driver['id']),
          {
            'lastStatusUpdate': FieldValue.serverTimestamp(),
            'currentRequestId': requestId,
          },
        );
      });

      print('✅ تم التوزيع العادل بنجاح على السائق: ${driver['name']}');

    } catch (e) {
      print('❌ خطأ في التوزيع العادل: $e');
      rethrow;
    }
  }

  // الدوال المساعدة
  double _calculateFairnessScore(int completedRides, int activeRequests) {
    final completedScore = completedRides == 0 ? 1.0 : 1.0 / (completedRides + 1);
    final activeScore = activeRequests == 0 ? 1.0 : 1.0 / (activeRequests + 1);
    return (completedScore * 0.7) + (activeScore * 0.3);
  }

  Future<void> _updateRequestStatus(
      String companyId,
      String requestId,
      String status,
      String logMessage,
      ) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .doc(requestId)
          .update({
        'status': status,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      print(logMessage);
    } catch (e) {
      print('❌ خطأ في تحديث حالة الطلب: $e');
    }
  }

  // دالة الموافقة المحسنة
  Future<void> approveUrgentRequest(
      String companyId,
      String requestId,
      String hrManagerId,
      String hrManagerName,
      ) async {
    try {
      final requestDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .doc(requestId)
          .get();

      if (requestDoc.exists) {
        final requestData = requestDoc.data()!;
        final priority = requestData['priority'] ?? 'Normal';

        if (priority == 'Normal') {
          print('🚀 طلب عادي - توزيع فوري بعد الموافقة');
          await _fairAutoAssign(companyId, requestId, requestData);
        } else if (priority == 'Urgent') {
          print('🚀 طلب عاجل - توزيع فوري بعد الموافقة');
          await _firestore
              .collection('companies')
              .doc(companyId)
              .collection('requests')
              .doc(requestId)
              .update({
            'hrApproverId': hrManagerId,
            'hrApproverName': hrManagerName,
            'hrApprovalTime': FieldValue.serverTimestamp(),
            'status': 'HR_APPROVED',
          });
          await Future.delayed(const Duration(seconds: 2));
          await _fairAutoAssign(companyId, requestId, requestData);
        }
      }
    } catch (e) {
      print('❌ خطأ في موافقة الموارد البشرية: $e');
      rethrow;
    }
  }
}
// باقي كود الصفحة...
class HRRequestsScreen extends StatefulWidget {
  final String companyId;
  const HRRequestsScreen({super.key, required this.companyId});
  @override State<HRRequestsScreen> createState() => _HRRequestsScreenState();
}

class _HRRequestsScreenState extends State<HRRequestsScreen> {
  String _filter = 'اليوم';
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  final DispatchService _dispatchService = DispatchService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) _loadRequests();
    });
  }

  Future<void> _loadRequests() async {
    try {
      if (mounted) setState(() { _loading = true; });

      final requestsSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .orderBy('createdAt', descending: true)
          .get();

      final List<Map<String, dynamic>> loadedRequests = [];

      for (var doc in requestsSnapshot.docs) {
        final data = doc.data();
        DateTime createdAt = data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now();

        loadedRequests.add({
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
        });
      }

      if (mounted) {
        setState(() {
          _requests = loadedRequests;
          _loading = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في جلب الطلبات: $e');
      if (mounted) {
        setState(() { _loading = false; });
        _showMessage('خطأ في تحميل الطلبات: $e', Colors.red);
      }
    }
  }

  // 🔄 توزيع تلقائي للطلب
  Future<void> _autoAssignRequest(Map<String, dynamic> request) async {
    try {
      _showMessage('جاري التوزيع التلقائي...', Colors.blue);
      print('🎯 بدء التوزيع اليدوي للطلب: ${request['id']}');

      await _dispatchService.autoAssignSingleRequest(
        widget.companyId,
        request['id'],
      );

      await Future.delayed(const Duration(seconds: 2));
      _loadRequests();
      _showMessage('تم التوزيع التلقائي بنجاح', Colors.green);

    } catch (e) {
      print('❌ خطأ في التوزيع التلقائي: $e');
      _showMessage('خطأ في التوزيع التلقائي: $e', Colors.red);
    }
  }

  void _showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 3)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة الطلبات - ${widget.companyId}'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () async {
              _showMessage('بدء التوزيع التلقائي الفوري...', Colors.blue);
              // توزيع جميع الطلبات المتوقفة
              for (var request in _requests.where((r) =>
              ['PENDING', 'WAITING_FOR_DRIVER', 'HR_APPROVED'].contains(r['status']) &&
                  r['priority'] == 'Normal'
              )) {
                await _dispatchService.autoAssignSingleRequest(widget.companyId, request['id']);
              }
              await _loadRequests();
              _showMessage('تم التوزيع التلقائي', Colors.green);
            },
            tooltip: 'تشغيل التوزيع التلقائي',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
            tooltip: 'تحديث الطلبات',
          ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) :
      Column(children: [
        // ... باقي الواجهة بنفس الهيكل
        Expanded(child: _buildRequestsList()),
      ]),
    );
  }

  // ... باقي دوال الواجهة بنفس الهيكل السابق
  Widget _buildRequestsList() {
    final filtered = _requests.where((request) {
      final status = request['status'] as String;
      switch (_filter) {
        case 'اليوم': return (request['createdAt'] as DateTime).isAfter(DateTime.now().subtract(const Duration(days: 1)));
        case 'العاجلة': return request['priority'] == 'Urgent' && ['PENDING', 'HR_PENDING', 'HR_APPROVED'].contains(status);
        case 'الجارية': return ['ASSIGNED', 'IN_PROGRESS', 'HR_APPROVED'].contains(status);
        case 'المكتملة': return status == 'COMPLETED';
        case 'الملغية': return status == 'CANCELLED';
        default: return true;
      }
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final request = filtered[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _getStatusColor(request['status']).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(_getStatusIcon(request['status']), color: _getStatusColor(request['status']), size: 20),
            ),
            title: Row(children: [
              Expanded(child: Text('طلب #${request['id']}', style: const TextStyle(fontWeight: FontWeight.bold))),
              if (request['priority'] == 'Urgent') _buildUrgentBadge(),
            ]),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${request['department']} - ${request['requesterName']}'),
              Text('الوجهة: ${request['destination']}'),
              const SizedBox(height: 4),
              Row(children: [
                _buildStatusBadge(request['status']),
                if (request['assignedDriverName'] != null) ...[
                  const SizedBox(width: 8), const Icon(Icons.person, size: 12, color: Colors.grey),
                  const SizedBox(width: 4), Text(request['assignedDriverName']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ]),
            ]),
            trailing: Text(DateFormat('HH:mm').format(request['createdAt']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            onTap: () => _showRequestDetails(request),
          ),
        );
      },
    );
  }

  Widget _buildUrgentBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
    child: const Text('عاجل', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
  );

  Widget _buildStatusBadge(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(_translateStatus(status), style: TextStyle(color: _getStatusColor(status), fontSize: 12, fontWeight: FontWeight.bold)),
  );

  String _translateStatus(String status) {
    const statusMap = {
      'PENDING': 'معلقة', 'HR_PENDING': 'بانتظار الموارد البشرية', 'HR_APPROVED': 'موافق عليه',
      'ASSIGNED': 'مُعين للسائق', 'IN_PROGRESS': 'قيد التنفيذ', 'COMPLETED': 'مكتمل',
      'HR_REJECTED': 'مرفوض', 'WAITING_FOR_DRIVER': 'بانتظار السائق', 'CANCELLED': 'ملغى',
    };
    return statusMap[status] ?? status;
  }

  Color _getStatusColor(String status) {
    const colorMap = {
      'PENDING': Colors.orange, 'HR_PENDING': Colors.orange, 'HR_APPROVED': Colors.blue,
      'ASSIGNED': Colors.purple, 'IN_PROGRESS': Colors.green, 'COMPLETED': Color(0xFF2E7D32),
      'HR_REJECTED': Colors.red, 'CANCELLED': Colors.red, 'WAITING_FOR_DRIVER': Colors.amber,
    };
    return colorMap[status] ?? Colors.grey;
  }

  IconData _getStatusIcon(String status) {
    const iconMap = {
      'PENDING': Icons.pending, 'HR_PENDING': Icons.pending, 'HR_APPROVED': Icons.check_circle,
      'ASSIGNED': Icons.assignment, 'IN_PROGRESS': Icons.directions_car, 'COMPLETED': Icons.done_all,
      'HR_REJECTED': Icons.cancel, 'CANCELLED': Icons.cancel, 'WAITING_FOR_DRIVER': Icons.schedule,
    };
    return iconMap[status] ?? Icons.help;
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (context) => Container(padding: const EdgeInsets.all(16), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('تفاصيل الطلب #${request['id']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 16),
          _buildDetailRow('القسم:', request['department']),
          _buildDetailRow('الموظف:', request['requesterName']),
          const Divider(height: 20),
          const Text('مسار الرحلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildDetailRow('نقطة الانطلاق:', request['fromLocation']),
          _buildDetailRow('الوجهة:', request['destination']),
          const Divider(height: 20),
          _buildDetailRow('الحالة:', _translateStatus(request['status'])),
          _buildDetailRow('الأولوية:', request['priority'] == 'Urgent' ? 'عاجل' : 'عادي'),
          if (request['assignedDriverName'] != null) _buildDetailRow('السائق المخصص:', request['assignedDriverName']!),
          _buildDetailRow('وقت الطلب:', DateFormat('yyyy-MM-dd HH:mm').format(request['createdAt'])),
          const SizedBox(height: 20),
          _buildActionButtons(request, request['status']),
          const SizedBox(height: 10),
        ],
      )),
    );
  }

  Widget _buildDetailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
      const SizedBox(width: 8), Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
    ]),
  );

  Widget _buildActionButtons(Map<String, dynamic> request, String status) {
    final priority = request['priority'] as String;
    return Column(children: [
      if (['PENDING', 'WAITING_FOR_DRIVER', 'HR_APPROVED'].contains(status) && priority == 'Normal')
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: () => _manualAssignDriver(request),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('تعيين سائق يدوياً'),
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton(
            onPressed: () => _autoAssignRequest(request),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('توزيع تلقائي'),
          )),
        ]),
      if (['PENDING', 'HR_PENDING', 'WAITING_FOR_DRIVER', 'HR_APPROVED', 'ASSIGNED', 'IN_PROGRESS'].contains(status))
        ElevatedButton(
          onPressed: () => _cancelRequest(request),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
          child: const Text('إلغاء الطلب'),
        ),
    ]);
  }

  // ... باقي الدوال المساعدة
  Future<void> _manualAssignDriver(Map<String, dynamic> request) async {
    // دالة التعيين اليدوي
  }

  Future<void> _cancelRequest(Map<String, dynamic> request) async {
    // دالة الإلغاء
  }
}