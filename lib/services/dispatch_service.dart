import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request_model.dart';
import '../models/driver_model.dart';
import 'dart:async';

class DispatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _requestsSubscription;
  Timer? _processingTimer;

  // ✨ بدء الاستماع للطلبات الجديدة
  void startListening(String companyId) {
    _requestsSubscription = _setupRequestsListener(companyId);
    _startBackgroundProcessing(companyId);
    print('🎯 بدء الاستماع للطلبات الجديدة للشركة: $companyId');
  }

  // ✨ إيقاف الاستماع
  void stopListening() {
    _requestsSubscription?.cancel();
    _processingTimer?.cancel();
    _requestsSubscription = null;
    _processingTimer = null;
    print('🛑 توقف الاستماع للطلبات الجديدة');
  }

  // ✨ بدء المعالجة الخلفية الدورية
  void _startBackgroundProcessing(String companyId) {
    _processingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _processPendingRequests(companyId);
    });
  }

  // ✨ معالجة الطلبات المعلقة دورياً
  Future<void> _processPendingRequests(String companyId) async {
    try {
      final pendingRequests = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .where('status', whereIn: ['PENDING', 'WAITING_FOR_DRIVER', 'HR_APPROVED'])
          .get();

      if (pendingRequests.docs.isNotEmpty) {
        print('🔄 معالجة ${pendingRequests.docs.length} طلب معلق...');

        for (var doc in pendingRequests.docs) {
          final requestData = doc.data();
          final request = Request.fromMap({
            ...requestData,
            'requestId': doc.id,
          });

          // 🔥 تحقق إذا كان الطلب مضافاً مسبقاً لقائمة الانتظار
          if (request.status == 'WAITING_FOR_DRIVER') {
            if (await _isRequestInAnyQueue(request.requestId, request.companyId)) {
              print('⏳ الطلب ${request.requestId} في حالة انتظار ومضاف مسبقاً، تخطي...');
              continue;
            }
          }

          // معالجة خاصة للطلبات الموافق عليها من الموارد البشرية
          if (request.status == 'HR_APPROVED') {
            await _processHRApprovedRequest(request);
          } else {
            await _tryAutoAssign(request);
          }
        }
      }
    } catch (e) {
      print('❌ خطأ في المعالجة الدورية: $e');
    }
  }

  // ✨ معالجة الطلبات الموافق عليها من الموارد البشرية
  Future<void> _processHRApprovedRequest(Request request) async {
    try {
      print('🎯 معالجة طلب موافق عليه من الموارد البشرية: ${request.requestId}');

      // إذا لم يكن هناك سائق معين، نقوم بالتوزيع التلقائي
      if (request.assignedDriverId == null || request.assignedDriverId!.isEmpty) {
        print('🔄 لم يتم تعيين سائق، جاري التوزيع التلقائي...');
        await _tryAutoAssign(request);
      } else {
        print('✅ الطلب معين مسبقاً للسائق: ${request.assignedDriverName}');
      }
    } catch (e) {
      print('❌ خطأ في معالجة الطلب الموافق عليه: $e');
    }
  }

  // ✨ مستمع للطلبات الجديدة
  StreamSubscription<void> _setupRequestsListener(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('requests')
        .where('status', whereIn: ['PENDING', 'HR_APPROVED'])
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added || doc.type == DocumentChangeType.modified) {
          final requestData = doc.doc.data()!;
          final request = Request.fromMap({
            ...requestData,
            'requestId': doc.doc.id,
          });
          print('🆕 طلب جديد/معدل تم اكتشافه: ${request.requestId} - الحالة: ${request.status}');
          _processNewRequest(request);
        }
      }
    });
  }

  // ✨ دالة معالجة الطلب الجديد
  Future<void> _processNewRequest(Request request) async {
    try {
      print('🚀 بدء معالجة الطلب: ${request.requestId} - الأولوية: ${request.priority}');

      if (request.status == 'COMPLETED' || request.status == 'CANCELLED' || request.status == 'ASSIGNED') {
        print('⚠️ الطلب في حالة ${request.status}، لا يمكن معالجته');
        return;
      }

      if (request.assignedDriverId != null && request.assignedDriverId!.isNotEmpty) {
        print('⚠️ الطلب مُعين مسبقاً للسائق: ${request.assignedDriverName}');
        return;
      }

      if (request.priority == 'Urgent' && request.status != 'HR_APPROVED') {
        await _sendToHRApproval(request);
      } else {
        await _tryAutoAssign(request);
      }

      print('✅ تمت معالجة الطلب بنجاح');
    } catch (e) {
      print('❌ خطأ في معالجة الطلب: $e');
    }
  }

  // ✨ محاولة التعيين التلقائي - النسخة المحسنة
  Future<void> _tryAutoAssign(Request request) async {
    try {
      print('🎯 محاولة التعيين التلقائي للطلب: ${request.requestId}');

      // 🔥 تحقق إذا كان الطلب مضافاً مسبقاً لقائمة الانتظار
      if (await _isRequestInAnyQueue(request.requestId, request.companyId)) {
        print('⚠️ الطلب ${request.requestId} مضاف مسبقاً لقائمة الانتظار، تخطي...');
        return;
      }

      // جلب جميع السائقين النشطين
      final allDriversSnap = await _firestore
          .collection('companies')
          .doc(request.companyId)
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .get();

      if (allDriversSnap.docs.isEmpty) {
        print('❌ لا يوجد سائقون نشطون');
        await _updateRequestStatus(
          request.companyId,
          request.requestId,
          'PENDING',
          'بانتظار سائق متاح',
        );
        return;
      }

      List<Driver> allDriversList = [];

      for (var doc in allDriversSnap.docs) {
        try {
          final driverData = doc.data();
          final driver = Driver.fromMap({
            ...driverData,
            'driverId': doc.id,
          });
          allDriversList.add(driver);
        } catch (e) {
          print('❌ خطأ في تحميل سائق ${doc.id}: $e');
        }
      }

      print('📊 إحصائيات السائقين:');
      print('   - إجمالي السائقين: ${allDriversList.length}');

      // 🔥 الجديد: نعطي الطلب لأي سائق نشط بغض النظر إذا كان مشغول أو لا
      if (allDriversList.isNotEmpty) {
        // 🔥 ترتيب السائقين حسب الأولوية
        final sortedDrivers = await _sortDriversByPriority(allDriversList, request.companyId);

        final selectedDriver = sortedDrivers.first;
        final queueCount = await _getDriverQueueCount(selectedDriver.driverId, request.companyId);

        print('🎯 أفضل سائق مختار: ${selectedDriver.name}');
        print('   - متاح: ${selectedDriver.isAvailable}');
        print('   - طلبات في الانتظار: $queueCount');
        print('   - مشاوير مكتملة: ${selectedDriver.completedRides}');

        if (selectedDriver.isAvailable) {
          // إذا السائق متاح، نعطيه الطلب مباشرة
          print('🚗 تم اختيار سائق متاح: ${selectedDriver.name}');
          await _assignToDriver(request, selectedDriver);
        } else {
          // إذا السائق مشغول، نضيف الطلب لقائمته
          print('📝 تم اختيار سائق مشغول: ${selectedDriver.name} (طلبات في الانتظار: $queueCount)');

          // تحديث حالة الطلب إلى الانتظار
          await _updateRequestStatus(
            request.companyId,
            request.requestId,
            'WAITING_FOR_DRIVER',
            'مضاف لقائمة انتظار السائق ${selectedDriver.name}',
          );

          // إضافة الطلب إلى قائمة انتظار السائق
          await _addToDriverQueue(request, selectedDriver);

          // 🔥 إشعار السائق بوجود طلب جديد في الانتظار
          await _notifyDriverNewQueueItem(selectedDriver, request, queueCount + 1);
        }

      } else {
        print('❌ لا يوجد سائقون مناسبون للتعيين');
        await _updateRequestStatus(
          request.companyId,
          request.requestId,
          'PENDING',
          'لا يوجد سائقون مناسبون',
        );
      }

    } catch (e) {
      print('❌ خطأ في التعيين التلقائي: $e');
    }
  }

  // ✨ ترتيب السائقين حسب الأولوية
  Future<List<Driver>> _sortDriversByPriority(List<Driver> drivers, String companyId) async {
    // إنشاء قائمة ببيانات السائقين مع معلومات إضافية
    List<Map<String, dynamic>> driversWithInfo = [];

    for (var driver in drivers) {
      final queueCount = await _getDriverQueueCount(driver.driverId, companyId);
      driversWithInfo.add({
        'driver': driver,
        'queueCount': queueCount,
        'isAvailable': driver.isAvailable,
        'completedRides': driver.completedRides,
      });
    }

    // ترتيب السائقين حسب:
    // 1. المتاحين أولاً
    // 2. ثم الأقل في عدد الطلبات المنتظرة
    // 3. ثم الأقل في عدد المشاوير (للتوزيع العادل)
    driversWithInfo.sort((a, b) {
      // المتاحين أولاً
      if (a['isAvailable'] == true && b['isAvailable'] != true) return -1;
      if (a['isAvailable'] != true && b['isAvailable'] == true) return 1;

      // ثم عدد الطلبات في الانتظار (الأقل أولاً)
      final aQueue = a['queueCount'] as int;
      final bQueue = b['queueCount'] as int;
      if (aQueue != bQueue) {
        return aQueue.compareTo(bQueue);
      }

      // ثم عدد المشاوير المكتملة (الأقل أولاً للتوزيع العادل)
      final aRides = a['completedRides'] as int;
      final bRides = b['completedRides'] as int;
      return aRides.compareTo(bRides);
    });

    // إرجاع قائمة السائقين فقط
    return driversWithInfo.map((item) => item['driver'] as Driver).toList();
  }

  // ✨ دالة جديدة للتحقق إذا كان الطلب مضافاً لقائمة الانتظار
  Future<bool> _isRequestInAnyQueue(String requestId, String companyId) async {
    try {
      final allDrivers = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .get();

      for (var driverDoc in allDrivers.docs) {
        final queueDoc = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('drivers')
            .doc(driverDoc.id)
            .collection('pendingRequests')
            .doc(requestId)
            .get();

        if (queueDoc.exists) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ خطأ في التحقق من قوائم الانتظار: $e');
      return false;
    }
  }

  // ✨ دالة مساعدة لجلب عدد الطلبات في انتظار سائق
  Future<int> _getDriverQueueCount(String driverId, String companyId) async {
    try {
      final queueSnapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(driverId)
          .collection('pendingRequests')
          .get();

      return queueSnapshot.docs.length;
    } catch (e) {
      print('❌ خطأ في جلب عدد طلبات الانتظار: $e');
      return 0;
    }
  }

  // ✨ دالة جديدة لإشعار السائق بطلب جديد في الانتظار
  Future<void> _notifyDriverNewQueueItem(Driver driver, Request request, int newQueueCount) async {
    try {
      await _firestore
          .collection('companies')
          .doc(request.companyId)
          .collection('drivers')
          .doc(driver.driverId)
          .update({
        'hasPendingNotifications': true,
        'lastNotificationTime': FieldValue.serverTimestamp(),
        'pendingRequestsCount': newQueueCount,
      });

      print('🔔 تم إشعار السائق ${driver.name} بطلب جديد في الانتظار');

    } catch (e) {
      print('❌ خطأ في إشعار السائق: $e');
    }
  }

  // ✨ إرسال الطلب العاجل للموارد البشرية
  Future<void> _sendToHRApproval(Request request) async {
    try {
      await _firestore
          .collection('companies')
          .doc(request.companyId)
          .collection('requests')
          .doc(request.requestId)
          .update({
        'status': 'HR_PENDING',
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('📋 تم إرسال الطلب العاجل للموارد البشرية للموافقة');
    } catch (e) {
      print('❌ خطأ في إرسال الطلب للموارد البشرية: $e');
    }
  }

  // ✨ إضافة الطلب إلى قائمة انتظار السائق
  Future<void> _addToDriverQueue(Request request, Driver driver) async {
    try {
      // الحصول على عنوان الطلب من البيانات
      final requestTitle = _getRequestTitle(request);

      await _firestore
          .collection('companies')
          .doc(request.companyId)
          .collection('drivers')
          .doc(driver.driverId)
          .collection('pendingRequests')
          .doc(request.requestId)
          .set({
        'requestId': request.requestId,
        'requesterName': request.requesterName,
        'priority': request.priority,
        'fromLocation': request.fromLocation,
        'toLocation': request.toLocation,
        'title': requestTitle,
        'addedToQueueAt': FieldValue.serverTimestamp(),
        'estimatedWaitTime': 15,
      });

      print('📥 تم إضافة الطلب ${request.requestId} إلى قائمة انتظار السائق ${driver.name}');

      // 🔥 تحديث عداد الطلبات المنتظرة للسائق
      await _updateDriverQueueCount(driver.driverId, request.companyId);

    } catch (e) {
      print('❌ خطأ في إضافة الطلب إلى قائمة الانتظار: $e');
    }
  }

  // ✨ دالة جديدة لتحديث عداد الطلبات المنتظرة
  Future<void> _updateDriverQueueCount(String driverId, String companyId) async {
    try {
      final queueSnapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(driverId)
          .collection('pendingRequests')
          .get();

      final queueCount = queueSnapshot.docs.length;

      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(driverId)
          .update({
        'pendingRequestsCount': queueCount,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });

      print('📊 تم تحديث عداد طلبات الانتظار للسائق $driverId إلى: $queueCount');
    } catch (e) {
      print('❌ خطأ في تحديث عداد الطلبات: $e');
    }
  }

  // ✨ دالة مساعدة للحصول على عنوان الطلب
  String _getRequestTitle(Request request) {
    final titleFromData = _getTitleFromRequestData(request);
    if (titleFromData.isNotEmpty) {
      return titleFromData;
    }

    final from = request.fromLocation ?? 'موقع غير محدد';
    final to = request.toLocation ?? 'موقع غير محدد';
    return 'نقل من $from إلى $to';
  }

  // ✨ دالة مساعدة لاستخراج العنوان من بيانات الطلب
  String _getTitleFromRequestData(Request request) {
    if (request.details.isNotEmpty) {
      return request.details;
    }
    return '';
  }

  // ✨ تعيين الطلب للسائق
  Future<void> _assignToDriver(Request request, Driver driver) async {
    try {
      print('🚗 تعيين الطلب ${request.requestId} للسائق ${driver.name}');

      await _firestore
          .collection('companies')
          .doc(request.companyId)
          .collection('requests')
          .doc(request.requestId)
          .update({
        'assignedDriverId': driver.driverId,
        'assignedDriverName': driver.name,
        'status': 'ASSIGNED',
        'assignedTime': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('companies')
          .doc(request.companyId)
          .collection('drivers')
          .doc(driver.driverId)
          .update({
        'isAvailable': false,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
        'currentRequestId': request.requestId,
      });

      print('✅ تم تعيين الطلب بنجاح للسائق: ${driver.name}');

    } catch (e) {
      print('❌ خطأ في تعيين الطلب للسائق: $e');
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
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .doc(requestId)
          .update({
        'assignedDriverId': driverId,
        'assignedDriverName': driverName,
        'status': 'ASSIGNED',
        'hrApproverId': hrManagerId,
        'hrApproverName': hrManagerName,
        'hrApprovalTime': FieldValue.serverTimestamp(),
        'assignedTime': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(driverId)
          .update({
        'isAvailable': false,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
        'currentRequestId': requestId,
      });

      print('✅ تم التعيين اليدوي بنجاح للسائق: $driverName');
    } catch (e) {
      print('❌ خطأ في التعيين اليدوي: $e');
      rethrow;
    }
  }

  // ✨ موافقة الموارد البشرية على الطلب العاجل
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
        await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('requests')
            .doc(requestId)
            .update({
          'status': 'HR_APPROVED',
          'hrApproverId': hrManagerId,
          'hrApproverName': hrManagerName,
          'hrApprovalTime': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        print('✅ تمت الموافقة على الطلب وسيتم التوزيع تلقائياً');

        final requestDoc = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('requests')
            .doc(requestId)
            .get();

        if (requestDoc.exists) {
          final request = Request.fromMap({
            ...requestDoc.data()!,
            'requestId': requestDoc.id,
          });
          await _tryAutoAssign(request);
        }
      }

      print('✅ تمت موافقة الموارد البشرية بنجاح');
    } catch (e) {
      print('❌ خطأ في موافقة الموارد البشرية: $e');
      rethrow;
    }
  }

  // ✨ رفض الطلب من قبل الموارد البشرية
  Future<void> rejectRequest(
      String companyId,
      String requestId,
      String hrManagerId,
      String hrManagerName,
      String rejectionReason) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .doc(requestId)
          .update({
        'status': 'HR_REJECTED',
        'hrApproverId': hrManagerId,
        'hrApproverName': hrManagerName,
        'hrRejectionTime': FieldValue.serverTimestamp(),
        'rejectionReason': rejectionReason,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('❌ تم رفض الطلب من قبل الموارد البشرية: $rejectionReason');
    } catch (e) {
      print('❌ خطأ في رفض الطلب: $e');
      rethrow;
    }
  }

  // ✨ تحويل الطلب من سائق إلى آخر
  Future<void> reassignDriver(
      String companyId,
      String requestId,
      String newDriverId,
      String newDriverName,
      String hrManagerId,
      String hrManagerName,
      String reassignmentReason) async {
    try {
      final requestDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('الطلب غير موجود');
      }

      final requestData = requestDoc.data()!;
      final String? oldDriverId = requestData['assignedDriverId'] as String?;

      if (oldDriverId != null && oldDriverId.isNotEmpty) {
        await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('drivers')
            .doc(oldDriverId)
            .update({
          'isAvailable': true,
          'currentRequestId': null,
          'lastStatusUpdate': FieldValue.serverTimestamp(),
        });
        print('✅ تم تحرير السائق القديم: $oldDriverId');
      }

      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .doc(requestId)
          .update({
        'assignedDriverId': newDriverId,
        'assignedDriverName': newDriverName,
        'previousDriverId': oldDriverId,
        'previousDriverName': requestData['assignedDriverName'],
        'reassignmentReason': reassignmentReason,
        'reassignedBy': hrManagerId,
        'reassignedByName': hrManagerName,
        'reassignmentTime': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(newDriverId)
          .update({
        'isAvailable': false,
        'currentRequestId': requestId,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });

      print('✅ تم تحويل الطلب بنجاح من $oldDriverId إلى $newDriverName');
    } catch (e) {
      print('❌ خطأ في تحويل السائق: $e');
      rethrow;
    }
  }

  // ✨ معالجة قوائم الانتظار عندما يصبح السائق متاحاً
  Future<void> processDriverQueue(String companyId, String driverId) async {
    try {
      final driverDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(driverId)
          .get();

      if (!driverDoc.exists) return;

      final driverData = driverDoc.data()!;
      final driver = Driver.fromMap({
        ...driverData,
        'driverId': driverId,
      });

      if (driver.isAvailable == true) {
        final queueSnapshot = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('drivers')
            .doc(driverId)
            .collection('pendingRequests')
            .orderBy('addedToQueueAt')
            .limit(1)
            .get();

        if (queueSnapshot.docs.isNotEmpty) {
          final queuedRequest = queueSnapshot.docs.first;
          final requestId = queuedRequest.id;

          await queuedRequest.reference.delete();

          final requestDoc = await _firestore
              .collection('companies')
              .doc(companyId)
              .collection('requests')
              .doc(requestId)
              .get();

          if (requestDoc.exists) {
            final requestData = requestDoc.data()!;
            final request = Request.fromMap({
              ...requestData,
              'requestId': requestDoc.id,
            });

            await _assignToDriver(request, driver);
            print('✅ تم تعيين طلب من قائمة الانتظار: $requestId');

            await _updateDriverQueueCount(driverId, companyId);
          }
        }
      } else {
        print('⏳ السائق $driverId لا يزال مشغولاً، انتظار حتى يصبح متاحاً');
      }
    } catch (e) {
      print('❌ خطأ في معالجة قائمة الانتظار: $e');
    }
  }

  // ✨ تحرير السائق بعد إكمال المهمة
  Future<void> releaseDriver(String companyId, String driverId, String requestId) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(driverId)
          .update({
        'isAvailable': true,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
        'currentRequestId': null,
        'completedRides': FieldValue.increment(1),
      });

      print('✅ تم تحرير السائق $driverId');

      await processDriverQueue(companyId, driverId);

      final queueCount = await _getDriverQueueCount(driverId, companyId);
      if (queueCount > 0) {
        print('🔔 السائق $driverId لديه $queueCount طلب في الانتظار');
        await _notifyDriverAboutPendingRequests(driverId, companyId, queueCount);
      }

    } catch (e) {
      print('❌ خطأ في تحرير السائق: $e');
    }
  }

  // ✨ دالة جديدة لإشعار السائق بالطلبات المنتظرة
  Future<void> _notifyDriverAboutPendingRequests(String driverId, String companyId, int queueCount) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(driverId)
          .update({
        'hasPendingRequests': queueCount > 0,
        'pendingRequestsCount': queueCount,
        'lastNotificationTime': FieldValue.serverTimestamp(),
      });

      print('🔔 تم إشعار السائق $driverId بوجود $queueCount طلب في الانتظار');

    } catch (e) {
      print('❌ خطأ في إشعار السائق بالطلبات المنتظرة: $e');
    }
  }

  // ✨ دالة تشخيص النظام
  Future<void> debugDispatchSystem(String companyId) async {
    try {
      print('🔍 فحص نظام التوزيع...');

      final availableDrivers = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .where('isAvailable', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .get();

      print('👥 عدد السائقين المتاحين: ${availableDrivers.docs.length}');
      for (var driver in availableDrivers.docs) {
        final queueCount = await _getDriverQueueCount(driver.id, companyId);
        print('   - ${driver['name']} (${driver.id}) - مشاوير: ${driver['completedRides'] ?? 0} - طلبات انتظار: $queueCount');
      }

      final pendingRequests = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .where('status', whereIn: ['PENDING', 'WAITING_FOR_DRIVER', 'HR_APPROVED'])
          .get();

      print('📋 عدد الطلبات المنتظرة: ${pendingRequests.docs.length}');
      for (var request in pendingRequests.docs) {
        print('   - ${request.id} (${request['status']}) - ${request['requesterName']}');
      }

      final allDrivers = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .get();

      for (var driver in allDrivers.docs) {
        final queue = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('drivers')
            .doc(driver.id)
            .collection('pendingRequests')
            .get();

        if (queue.docs.isNotEmpty) {
          print('📥 قائمة انتظار السائق ${driver['name']}: ${queue.docs.length} طلب');
          for (var request in queue.docs) {
            print('   - ${request.id}');
          }
        }
      }

      print('✅ تم فحص النظام بنجاح');

    } catch (e) {
      print('❌ خطأ في فحص النظام: $e');
    }
  }
}