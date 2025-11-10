import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// 🚗 تعريف DispatchService داخل الملف نفسه
class DispatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✨ التعيين اليدوي للسائق
  Future<void> assignToSpecificDriver(
      String companyId,
      String requestId,
      String driverId,
      String driverName,
      String hrManagerId,
      String hrManagerName,
      ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // تحديث الطلب
        transaction.update(
          _firestore
              .collection('companies')
              .doc(companyId)
              .collection('requests')
              .doc(requestId),
          {
            'assignedDriverId': driverId,
            'assignedDriverName': driverName,
            'status': 'ASSIGNED',
            'hrApproverId': hrManagerId,
            'hrApproverName': hrManagerName,
            'hrApprovalTime': FieldValue.serverTimestamp(),
            'assignedTime': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
        );

        // تحديث السائق
        transaction.update(
          _firestore
              .collection('companies')
              .doc(companyId)
              .collection('drivers')
              .doc(driverId),
          {
            'isAvailable': false,
            'lastStatusUpdate': FieldValue.serverTimestamp(),
            'currentRequestId': requestId,
          },
        );
      });

      print('✅ تم التعيين اليدوي بنجاح للسائق: $driverName');
    } catch (e) {
      print('❌ خطأ في التعيين اليدوي: $e');
      rethrow;
    }
  }

  // ✨ تحويل الطلب من سائق إلى آخر - النسخة المحسنة
  Future<void> reassignDriver(
      String companyId,
      String requestId,
      String newDriverId,
      String newDriverName,
      String hrManagerId,
      String hrManagerName,
      String reassignmentReason) async {
    try {
      print('🔄 بدء عملية تحويل الطلب $requestId إلى السائق $newDriverName');

      // استخدام transaction لضمان التحديث المتزامن
      await _firestore.runTransaction((transaction) async {
        // 1. جلب بيانات الطلب الحالية
        final requestDoc = await transaction.get(
          _firestore
              .collection('companies')
              .doc(companyId)
              .collection('requests')
              .doc(requestId),
        );

        if (!requestDoc.exists) {
          throw Exception('الطلب غير موجود');
        }

        final requestData = requestDoc.data()!;
        final String? oldDriverId = requestData['assignedDriverId'] as String?;
        final String? oldDriverName = requestData['assignedDriverName'] as String?;

        print('📋 بيانات الطلب الحالية:');
        print('   - السائق القديم: $oldDriverId ($oldDriverName)');
        print('   - السائق الجديد: $newDriverId ($newDriverName)');

        // 2. إذا كان هناك سائق قديم، تحريره
        if (oldDriverId != null && oldDriverId.isNotEmpty) {
          print('🔄 تحرير السائق القديم: $oldDriverId');

          transaction.update(
            _firestore
                .collection('companies')
                .doc(companyId)
                .collection('drivers')
                .doc(oldDriverId),
            {
              'isAvailable': true,
              'currentRequestId': null,
              'lastStatusUpdate': FieldValue.serverTimestamp(),
            },
          );
        }

        // 3. تحديث الطلب بالسائق الجديد
        transaction.update(
          _firestore
              .collection('companies')
              .doc(companyId)
              .collection('requests')
              .doc(requestId),
          {
            'assignedDriverId': newDriverId,
            'assignedDriverName': newDriverName,
            'previousDriverId': oldDriverId,
            'previousDriverName': oldDriverName,
            'reassignmentReason': reassignmentReason,
            'reassignedBy': hrManagerId,
            'reassignedByName': hrManagerName,
            'reassignmentTime': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
        );

        // 4. تحديث السائق الجديد
        transaction.update(
          _firestore
              .collection('companies')
              .doc(companyId)
              .collection('drivers')
              .doc(newDriverId),
          {
            'isAvailable': false,
            'currentRequestId': requestId,
            'lastStatusUpdate': FieldValue.serverTimestamp(),
          },
        );
      });

      print('✅ تم تحويل الطلب بنجاح إلى $newDriverName');
    } catch (e) {
      print('❌ خطأ في تحويل السائق: $e');
      rethrow;
    }
  }

  // ✨ نظام التوزيع العادل - النسخة المحسنة
  Future<void> _fairAutoAssign(String companyId, String requestId, Map<String, dynamic> requestData) async {
    try {
      print('🎯 بدء التوزيع العادل للطلب: $requestId');

      // 1. جلب جميع السائقين النشطين
      final allDrivers = await _getAllDriversForAssignment(companyId);

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
      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> drivers = [];

      for (var doc in driversSnapshot.docs) {
        final data = doc.data();
        final driverId = doc.id;

        // حساب عدد الطلبات النشطة لكل سائق
        final activeRequests = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('requests')
            .where('assignedDriverId', isEqualTo: driverId)
            .where('status', whereIn: ['ASSIGNED', 'IN_PROGRESS'])
            .get();

        final bool isActuallyAvailable = data['isAvailable'] ?? true;
        final int activeRequestsCount = activeRequests.docs.length;
        final int completedRides = (data['completedRides'] as num?)?.toInt() ?? 0;
        final bool isOnline = data['isOnline'] ?? false;

        drivers.add({
          'id': driverId,
          'name': data['name'] ?? 'غير معروف',
          'isAvailable': isActuallyAvailable,
          'isOnline': isOnline,
          'completedRides': completedRides,
          'activeRequests': activeRequestsCount,
          'totalWorkload': completedRides + activeRequestsCount, // الحمل الكلي
          'fairnessScore': _calculateFairnessScore(completedRides, activeRequestsCount),
        });
      }

      return drivers;
    } catch (e) {
      print('❌ خطأ في جلب السائقين للتوزيع: $e');
      return [];
    }
  }

  // ✨ حساب درجة العدالة (كلما قل عدد المشاوير كلما كانت أعلى)
  double _calculateFairnessScore(int completedRides, int activeRequests) {
    // قاعدة العدالة:
    // - الأفضلية للسائقين الأقل في المشاوير المكتملة
    // - الأفضلية للسائقين الأقل في الطلبات النشطة

    final completedScore = completedRides == 0 ? 1.0 : 1.0 / (completedRides + 1);
    final activeScore = activeRequests == 0 ? 1.0 : 1.0 / (activeRequests + 1);

    return (completedScore * 0.7) + (activeScore * 0.3);
  }

  // ✨ اختيار السائق بناءً على قواعد العدالة
  Map<String, dynamic>? _selectDriverByFairRules(
      List<Map<String, dynamic>> drivers,
      Map<String, dynamic> requestData
      ) {
    final String priority = requestData['priority'] ?? 'Normal';

    // فلترة السائقين المتاحين فقط
    final availableDrivers = drivers.where((driver) =>
    driver['isAvailable'] == true &&
        driver['isOnline'] == true
    ).toList();

    if (availableDrivers.isEmpty) {
      print('⚠️ لا يوجد سائقين متاحين حالياً');
      return null;
    }

    print('📊 ${availableDrivers.length} سائق متاح للتوزيع');

    Map<String, dynamic>? selectedDriver;

    if (priority == 'Urgent') {
      // 🚨 للطلبات العاجلة: سائق بدون طلبات نشطة + الأقل في المشاوير
      final candidates = availableDrivers.where((driver) => driver['activeRequests'] == 0).toList();
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => (a['completedRides'] ?? 0).compareTo(b['completedRides'] ?? 0));
        selectedDriver = candidates.first;
      } else {
        // إذا كل السائقين مشغولين، نأخذ الأقل مشاوير
        availableDrivers.sort((a, b) => (a['completedRides'] ?? 0).compareTo(b['completedRides'] ?? 0));
        selectedDriver = availableDrivers.first;
      }
      print('🚨 طلب عاجل - تم اختيار السائق: ${selectedDriver['name']} (مشاوير: ${selectedDriver['completedRides']})');
    } else {
      // 📊 للطلبات العادية: ترتيب حسب درجة العدالة (الأعلى أولاً)
      availableDrivers.sort((a, b) {
        final scoreA = a['fairnessScore'] ?? 0;
        final scoreB = b['fairnessScore'] ?? 0;
        return scoreB.compareTo(scoreA); // ترتيب تنازلي
      });

      selectedDriver = availableDrivers.first;
      print('📊 طلب عادي - تم اختيار السائق: ${selectedDriver['name']}');
    }

    // طباعة تفاصيل التوزيع
    print('🎯 تفاصيل التوزيع العادل:');
    print('   - السائق: ${selectedDriver['name']}');
    print('   - المشاوير المكتملة: ${selectedDriver['completedRides']}');
    print('   - الطلبات النشطة: ${selectedDriver['activeRequests']}');
    print('   - درجة العدالة: ${selectedDriver['fairnessScore']?.toStringAsFixed(2)}');
    print('   - الحمل الكلي: ${selectedDriver['totalWorkload']}');

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
      await _firestore.runTransaction((transaction) async {
        // تحديث الطلب
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

        // تحديث السائق
        transaction.update(
          _firestore
              .collection('companies')
              .doc(companyId)
              .collection('drivers')
              .doc(driver['id']),
          {
            'isAvailable': false,
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

  // ✨ تحديث حالة الطلب
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

  // ✨ موافقة الموارد البشرية على الطلب العاجل - النسخة المحسنة
  Future<void> approveUrgentRequest(
      String companyId,
      String requestId,
      String hrManagerId,
      String hrManagerName, {
        String? specificDriverId,
        String? specificDriverName,
      }) async {
    try {
      if (specificDriverId != null) {
        await assignToSpecificDriver(
          companyId,
          requestId,
          specificDriverId,
          specificDriverName!,
          hrManagerId,
          hrManagerName,
        );
      } else {
        // 🔥 الجديد: استخدام النظام العادل للتوزيع
        final requestDoc = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('requests')
            .doc(requestId)
            .get();

        if (requestDoc.exists) {
          final requestData = requestDoc.data()!;

          // استخدام النظام العادل للتوزيع
          await _fairAutoAssign(companyId, requestId, requestData);

          // تسجيل موافقة الموارد البشرية
          await _firestore
              .collection('companies')
              .doc(companyId)
              .collection('requests')
              .doc(requestId)
              .update({
            'hrApproverId': hrManagerId,
            'hrApproverName': hrManagerName,
            'hrApprovalTime': FieldValue.serverTimestamp(),
          });

          print('✅ تمت الموافقة والتوزيع العادل للطلب');
        }
      }
    } catch (e) {
      print('❌ خطأ في موافقة الموارد البشرية: $e');
      rethrow;
    }
  }
}

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
      if (mounted) {
        _loadRequests();
      }
    });
  }

  // 🛠️ إصلاح شامل لحالات السائقين
  Future<void> _fixAllDriversIssues() async {
    try {
      print('🛠️ بدء الإصلاح الشامل لحالات السائقين...');

      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .get();

      int fixedCount = 0;

      for (var driverDoc in driversSnapshot.docs) {
        final driverData = driverDoc.data();
        final driverId = driverDoc.id;
        final currentRequestId = driverData['currentRequestId'] as String?;
        final isAvailable = driverData['isAvailable'] ?? true;

        // 🔥 الإصلاح 1: إذا السائق مشغول ولكن لا يوجد طلب حالية
        if (isAvailable == false && (currentRequestId == null || currentRequestId.isEmpty)) {
          await driverDoc.reference.update({
            'isAvailable': true,
            'lastStatusUpdate': FieldValue.serverTimestamp(),
          });
          fixedCount++;
          print('✅ تم إصلاح توفر السائق: ${driverData['name']}');
        }

        // 🔥 الإصلاح 2: إذا هناك طلب حالية، نتأكد من وجوده وصحته
        if (currentRequestId != null && currentRequestId.isNotEmpty) {
          final requestDoc = await _firestore
              .collection('companies')
              .doc(widget.companyId)
              .collection('requests')
              .doc(currentRequestId)
              .get();

          if (!requestDoc.exists ||
              requestDoc.data()?['assignedDriverId'] != driverId ||
              ['COMPLETED', 'CANCELLED'].contains(requestDoc.data()?['status'])) {

            await driverDoc.reference.update({
              'isAvailable': true,
              'currentRequestId': null,
              'lastStatusUpdate': FieldValue.serverTimestamp(),
            });
            fixedCount++;
            print('✅ تم إصلاح طلب السائق: ${driverData['name']}');
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إصلاح $fixedCount حالة سائق'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      _loadRequests();
    } catch (e) {
      print('❌ خطأ في الإصلاح الشامل: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الإصلاح: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 📋 جلب الطلبات مع معالجة محسنة
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

      final List<Map<String, dynamic>> loadedRequests = [];

      for (var doc in requestsSnapshot.docs) {
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
          'firebaseData': data,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الطلبات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🚗 جلب السائقين المتاحين مع التحقق الشامل
  Future<List<Map<String, dynamic>>> _getAvailableDrivers() async {
    try {
      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> availableDrivers = [];

      for (var doc in driversSnapshot.docs) {
        final data = doc.data();
        final driverId = doc.id;
        final currentRequestId = data['currentRequestId'] as String?;
        bool isActuallyAvailable = data['isAvailable'] ?? true;

        // 🔥 التحقق المزدوج من صحة الحالة
        if (currentRequestId != null && currentRequestId.isNotEmpty) {
          final requestDoc = await _firestore
              .collection('companies')
              .doc(widget.companyId)
              .collection('requests')
              .doc(currentRequestId)
              .get();

          if (requestDoc.exists &&
              requestDoc.data()?['assignedDriverId'] == driverId &&
              !['COMPLETED', 'CANCELLED'].contains(requestDoc.data()?['status'])) {
            isActuallyAvailable = false;
          } else {
            isActuallyAvailable = true;
            // تحديث حالة السائق إذا كانت غير صحيحة
            await doc.reference.update({
              'isAvailable': true,
              'currentRequestId': null,
              'lastStatusUpdate': FieldValue.serverTimestamp(),
            });
          }
        }

        if (isActuallyAvailable) {
          availableDrivers.add({
            'id': driverId,
            'name': data['name'] ?? 'غير معروف',
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? '',
            'isAvailable': true,
            'isOnline': data['isOnline'] ?? false,
            'completedRides': (data['completedRides'] as num?)?.toInt() ?? 0,
            'vehicleType': data['vehicleInfo']?['type'] ?? 'سيارة',
            'currentRequestId': null,
          });
        }
      }

      print('✅ عدد السائقين المتاحين فعلياً: ${availableDrivers.length}');
      return availableDrivers;
    } catch (e) {
      print('❌ خطأ في جلب السائقين: $e');
      return [];
    }
  }

  // 👥 جلب جميع السائقين للتحويل
  Future<List<Map<String, dynamic>>> _getAllDriversForReassign() async {
    try {
      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> allDrivers = [];

      for (var doc in driversSnapshot.docs) {
        final data = doc.data();
        final driverId = doc.id;
        final currentRequestId = data['currentRequestId'] as String?;

        // التحقق من الحالة الفعلية
        bool isActuallyAvailable = data['isAvailable'] ?? true;
        String? currentRequestStatus;

        if (currentRequestId != null && currentRequestId.isNotEmpty) {
          final requestDoc = await _firestore
              .collection('companies')
              .doc(widget.companyId)
              .collection('requests')
              .doc(currentRequestId)
              .get();

          if (requestDoc.exists) {
            currentRequestStatus = requestDoc.data()?['status'];
            if (requestDoc.data()?['assignedDriverId'] == driverId &&
                !['COMPLETED', 'CANCELLED'].contains(currentRequestStatus)) {
              isActuallyAvailable = false;
            } else {
              isActuallyAvailable = true;
            }
          }
        }

        allDrivers.add({
          'id': driverId,
          'name': data['name'] ?? 'غير معروف',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'isAvailable': isActuallyAvailable,
          'isOnline': data['isOnline'] ?? false,
          'completedRides': (data['completedRides'] as num?)?.toInt() ?? 0,
          'vehicleType': data['vehicleInfo']?['type'] ?? 'سيارة',
          'currentRequestId': currentRequestId,
          'currentRequestStatus': currentRequestStatus,
        });
      }

      print('👥 عدد السائقين للتحويل: ${allDrivers.length}');
      print('✅ السائقون المتاحون فعلياً: ${allDrivers.where((d) => d['isAvailable'] == true).length}');

      return allDrivers;
    } catch (e) {
      print('❌ خطأ في جلب السائقين للتحويل: $e');
      return [];
    }
  }

  // 🔄 التحويل إلى سائق آخر - النسخة المحسنة
  Future<void> _reassignDriver(Map<String, dynamic> request) async {
    try {
      final String? currentDriverId = request['assignedDriverId'] as String?;

      if (currentDriverId == null) {
        _showMessage('هذا الطلب غير معين لأي سائق', Colors.orange);
        return;
      }

      final allDrivers = await _getAllDriversForReassign();

      // استبعاد السائق الحالي
      final availableDrivers = allDrivers.where((driver) => driver['id'] != currentDriverId).toList();

      if (availableDrivers.isEmpty) {
        _showMessage('لا يوجد سائقين آخرين متاحين', Colors.orange);
        return;
      }

      _showDriverSelectionDialog(request, availableDrivers, 'تحويل إلى سائق آخر');

    } catch (e) {
      print('❌ خطأ في التحويل: $e');
      _showMessage('خطأ في عملية التحويل: $e', Colors.red);
    }
  }

  // 👤 تعيين سائق يدوياً
  Future<void> _manualAssignDriver(Map<String, dynamic> request) async {
    try {
      final availableDrivers = await _getAvailableDrivers();

      if (availableDrivers.isEmpty) {
        _showMessage('لا يوجد سائقين متاحين حالياً', Colors.orange);
        return;
      }

      _showDriverSelectionDialog(request, availableDrivers, 'تعيين سائق يدوياً');

    } catch (e) {
      print('❌ خطأ في التعيين اليدوي: $e');
      _showMessage('خطأ في التعيين اليدوي: $e', Colors.red);
    }
  }

  // 🎯 عرض اختيار السائقين
  void _showDriverSelectionDialog(
      Map<String, dynamic> request,
      List<Map<String, dynamic>> drivers,
      String title
      ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              final isAvailable = driver['isAvailable'] == true;
              final statusText = isAvailable ? 'متاح' : 'مشغول';
              final statusColor = isAvailable ? Colors.green : Colors.orange;
              final statusIcon = isAvailable ? Icons.check_circle : Icons.schedule;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(
                    Icons.person,
                    color: isAvailable ? Colors.blue : Colors.grey,
                  ),
                  title: Text(
                    driver['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isAvailable ? Colors.black : Colors.grey,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${driver['vehicleType']} - ${driver['completedRides']} مشاوير'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    if (title.contains('تحويل')) {
                      _performReassignment(request, driver);
                    } else {
                      _assignDriverToRequest(request, driver['id'], driver['name']);
                    }
                  },
                ),
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

  // 🔄 تنفيذ عملية التحويل
  Future<void> _performReassignment(Map<String, dynamic> request, Map<String, dynamic> newDriver) async {
    try {
      final isNewDriverAvailable = newDriver['isAvailable'] == true;

      if (!isNewDriverAvailable) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تنبيه'),
            content: Text(
                'السائق ${newDriver['name']} مشغول حالياً. '
                    'هل تريد تحويل الطلب إليه؟ سيتم تحرير الطلب الحالي منه.'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('نعم، متابعة'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
      }

      // استخدام خدمة الإرسال للتحويل
      await _dispatchService.reassignDriver(
          widget.companyId,
          request['id'],
          newDriver['id'],
          newDriver['name'],
          'hr_user_id',
          'مسؤول الموارد البشرية',
          'تحويل من قبل الموارد البشرية'
      );

      _showMessage('تم تحويل المشوار إلى السائق ${newDriver['name']}', Colors.green);
      _loadRequests();

    } catch (e) {
      print('❌ خطأ في التحويل: $e');
      _showMessage('فشل في التحويل: $e', Colors.red);
    }
  }

  // 👤 تعيين السائق للطلب
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

      _showMessage('تم تعيين السائق $driverName للطلب', Colors.green);
      _loadRequests();

    } catch (e) {
      print('❌ خطأ في التعيين: $e');
      _showMessage('خطأ في التعيين: $e', Colors.red);
    }
  }

  // ❌ إلغاء الطلب
  Future<void> _cancelRequest(Map<String, dynamic> request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الطلب'),
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

    if (confirmed != true) return;

    try {
      final String? assignedDriverId = request['assignedDriverId'] as String?;

      // إذا كان معيناً لسائق، نحرر السائق أولاً
      if (assignedDriverId != null && assignedDriverId.isNotEmpty) {
        await _firestore
            .collection('companies')
            .doc(widget.companyId)
            .collection('drivers')
            .doc(assignedDriverId)
            .update({
          'isAvailable': true,
          'currentRequestId': null,
          'lastStatusUpdate': FieldValue.serverTimestamp(),
        });
      }

      // ثم نلغي الطلب
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

      _showMessage('تم إلغاء الطلب بنجاح', Colors.green);
      _loadRequests();

    } catch (e) {
      print('❌ خطأ في الإلغاء: $e');
      _showMessage('خطأ في الإلغاء: $e', Colors.red);
    }
  }

  // 🔄 توزيع تلقائي
  Future<void> _autoAssignFromHR(Map<String, dynamic> request) async {
    try {
      _showMessage('جاري التوزيع التلقائي...', Colors.blue);

      await _dispatchService.approveUrgentRequest(
        widget.companyId,
        request['id'],
        'hr_user_id',
        'مسؤول الموارد البشرية',
      );

      await Future.delayed(const Duration(seconds: 2));
      _loadRequests();

    } catch (e) {
      print('❌ خطأ في التوزيع التلقائي: $e');
      _showMessage('خطأ في التوزيع التلقائي: $e', Colors.red);
    }
  }

  // 🎴 عرض رسالة
  void _showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // 📊 ترجمة الحالة
  String _translateStatus(String status) {
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

  // 🎨 لون الحالة
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

  // 📱 أيقونة الحالة
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

  // 📋 فلترة الطلبات
  List<Map<String, dynamic>> get _filteredRequests {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return _requests.where((request) {
      final requestDate = request['createdAt'] as DateTime;
      final status = request['status'] as String;
      final priority = request['priority'] as String;

      switch (_filter) {
        case 'اليوم':
          return requestDate.isAfter(todayStart);
        case 'العاجلة':
          return priority == 'Urgent' && ['PENDING', 'HR_PENDING', 'HR_APPROVED'].contains(status);
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

  // 📊 إحصائيات
  Map<String, int> get _stats {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final todayRequests = _requests.where((r) => (r['createdAt'] as DateTime).isAfter(todayStart)).length;
    final urgentRequests = _requests.where((r) => r['priority'] == 'Urgent').length;
    final pendingRequests = _requests.where((r) => ['PENDING', 'HR_PENDING', 'WAITING_FOR_DRIVER'].contains(r['status'])).length;
    final completedToday = _requests.where((r) => r['status'] == 'COMPLETED' && (r['createdAt'] as DateTime).isAfter(todayStart)).length;

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
          // زر الإصلاح الشامل
          IconButton(
            icon: const Icon(Icons.build),
            onPressed: _fixAllDriversIssues,
            tooltip: 'إصلاح شامل لحالات السائقين',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
            tooltip: 'تحديث الطلبات',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // بطاقات الإحصائيات
          _buildStatsCards(stats),

          // الفلترة
          _buildFilterSection(),

          // قائمة الطلبات
          _buildRequestsList(),
        ],
      ),
    );
  }

  // 🎴 بطاقات الإحصائيات
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
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
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
      ),
    );
  }

  // 🔘 قسم الفلترة
  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
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
          const SizedBox(height: 16),
          Row(
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
        ],
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

  String _getFilterSubtitle() {
    switch (_filter) {
      case 'اليوم': return 'طلبات اليوم';
      case 'العاجلة': return 'طلبات عاجلة';
      case 'الجارية': return 'طلبات قيد التنفيذ';
      case 'المكتملة': return 'طلبات منتهية';
      case 'الملغية': return 'طلبات ملغية';
      case 'الكل': return 'جميع الطلبات';
      default: return '';
    }
  }

  // 📋 قائمة الطلبات
  Widget _buildRequestsList() {
    return Expanded(
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
    );
  }

  // 🎴 بطاقة الطلب
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

  // 📋 عرض تفاصيل الطلب
  void _showRequestDetails(Map<String, dynamic> request) {
    final status = request['status'] as String;
    final priority = request['priority'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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

              _buildDetailRow('القسم:', request['department']),
              _buildDetailRow('الموظف:', request['requesterName']),

              const Divider(height: 20),

              const Text(
                'مسار الرحلة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('نقطة الانطلاق:', request['fromLocation']),
              _buildDetailRow('الوجهة:', request['destination']),

              const Divider(height: 20),

              _buildDetailRow('الحالة:', _translateStatus(status)),
              _buildDetailRow('الأولوية:', priority == 'Urgent' ? 'عاجل' : 'عادي'),

              if (request['assignedDriverName'] != null)
                _buildDetailRow('السائق المخصص:', request['assignedDriverName']!),

              _buildDetailRow('وقت الطلب:', DateFormat('yyyy-MM-dd HH:mm').format(request['createdAt'] as DateTime)),

              const SizedBox(height: 20),

              // أزرار الإدارة
              _buildActionButtons(request, status),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
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

  // 🎛️ أزرار الإدارة
  Widget _buildActionButtons(Map<String, dynamic> request, String status) {
    return Column(
      children: [
        if (['PENDING', 'HR_PENDING', 'WAITING_FOR_DRIVER', 'ASSIGNED', 'IN_PROGRESS'].contains(status))
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

        if (['PENDING', 'HR_PENDING', 'WAITING_FOR_DRIVER', 'ASSIGNED', 'IN_PROGRESS'].contains(status))
          const SizedBox(height: 8),

        if (['PENDING', 'HR_PENDING', 'WAITING_FOR_DRIVER', 'ASSIGNED', 'IN_PROGRESS'].contains(status))
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
}