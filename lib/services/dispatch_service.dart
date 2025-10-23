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
          .where('status', whereIn: ['PENDING', 'WAITING_FOR_DRIVER'])
          .get();

      if (pendingRequests.docs.isNotEmpty) {
        print('🔄 معالجة ${pendingRequests.docs.length} طلب معلق...');

        for (var doc in pendingRequests.docs) {
          final requestData = doc.data();
          final request = Request.fromMap({
            ...requestData,
            'requestId': doc.id,
          });
          await _tryAutoAssign(request);
        }
      }
    } catch (e) {
      print('❌ خطأ في المعالجة الدورية: $e');
    }
  }

  // ✨ مستمع للطلبات الجديدة
  StreamSubscription<void> _setupRequestsListener(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('requests')
        .where('status', isEqualTo: 'PENDING')
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

      if (request.priority == 'Urgent') {
        await _sendToHRApproval(request);
      } else {
        await _tryAutoAssign(request);
      }

      print('✅ تمت معالجة الطلب بنجاح');
    } catch (e) {
      print('❌ خطأ في معالجة الطلب: $e');
    }
  }

  // ✨ محاولة التعيين التلقائي
  Future<void> _tryAutoAssign(Request request) async {
    try {
      print('🎯 محاولة التعيين التلقائي للطلب: ${request.requestId}');

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

      List<Driver> availableDrivers = [];
      List<Driver> busyDrivers = [];

      for (var doc in allDriversSnap.docs) {
        try {
          final driverData = doc.data();

          final driver = Driver.fromMap({
            ...driverData,
            'driverId': doc.id,
          });

          // تصنيف السائقين
          if (driver.isAvailable == true) {
            availableDrivers.add(driver);
            print('✅ سائق متاح: ${driver.name} (مشاوير: ${driver.completedRides})');
          } else {
            busyDrivers.add(driver);
            print('⏳ سائق مشغول: ${driver.name} (مشاوير: ${driver.completedRides})');
          }
        } catch (e) {
          print('❌ خطأ في تحميل سائق ${doc.id}: $e');
        }
      }

      print('📊 إحصائيات السائقين:');
      print('   - إجمالي السائقين: ${allDriversSnap.docs.length}');
      print('   - السائقون المتاحون: ${availableDrivers.length}');
      print('   - السائقون المشغولون: ${busyDrivers.length}');

      Driver? selectedDriver;

      // الأولوية للسائقين المتاحين حالياً
      if (availableDrivers.isNotEmpty) {
        print('🎯 اختيار من السائقين المتاحين حالياً...');

        // ترتيب حسب عدد المشاوير (الأقل مشاوير أولاً)
        availableDrivers.sort((a, b) {
          return a.completedRides.compareTo(b.completedRides);
        });

        selectedDriver = availableDrivers.first;
        print('🚗 تم اختيار سائق متاح: ${selectedDriver.name}');

      } else if (busyDrivers.isNotEmpty) {
        // إذا لم يوجد سائقون متاحون، نختار من المشغولين بناءً على عدد المشاوير
        print('🎯 اختيار من السائقين المشغولين (نظام الانتظار الذكي)...');

        busyDrivers.sort((a, b) {
          return a.completedRides.compareTo(b.completedRides);
        });

        selectedDriver = busyDrivers.first;
        print('⏰ تم اختيار سائق مشغول (في قائمة الانتظار): ${selectedDriver.name}');

        // تحديث حالة الطلب إلى الانتظار
        await _updateRequestStatus(
          request.companyId,
          request.requestId,
          'WAITING_FOR_DRIVER',
          'بانتظار انتهاء مهمة السائق ${selectedDriver.name}',
        );

        // إضافة الطلب إلى قائمة انتظار السائق
        await _addToDriverQueue(request, selectedDriver);
        return;
      }

      if (selectedDriver != null) {
        await _assignToDriver(request, selectedDriver);
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

    } catch (e) {
      print('❌ خطأ في إضافة الطلب إلى قائمة الانتظار: $e');
    }
  }

  // ✨ دالة مساعدة للحصول على عنوان الطلب
  String _getRequestTitle(Request request) {
    // محاولة الحصول على العنوان من الحقول المختلفة
    final titleFromData = _getTitleFromRequestData(request);
    if (titleFromData.isNotEmpty) {
      return titleFromData;
    }

    // إذا لم يكن هناك عنوان، ننشئ واحداً وصفياً
    final from = request.fromLocation ?? 'موقع غير محدد';
    final to = request.toLocation ?? 'موقع غير محدد';
    return 'نقل من $from إلى $to';
  }

  // ✨ دالة مساعدة لاستخراج العنوان من بيانات الطلب
  String _getTitleFromRequestData(Request request) {
    // محاولة الحصول على العنوان من الحقول المختلفة
    if (request.details.isNotEmpty) {
      return request.details;
    }

    // يمكن إضافة المزيد من الحقول هنا إذا كانت موجودة في الـ Model
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
          'status': 'PENDING', // نعيده لـ PENDING ليتم معالجته تلقائياً
          'hrApproverId': hrManagerId,
          'hrApproverName': hrManagerName,
          'hrApprovalTime': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // معالجة الطلب فوراً بعد الموافقة
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

  // ✨ معالجة قوائم الانتظار عندما يصبح السائق متاحاً
  Future<void> processDriverQueue(String companyId, String driverId) async {
    try {
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

        // حذف الطلب من قائمة الانتظار
        await queuedRequest.reference.delete();

        // جلب بيانات الطلب الكاملة
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

          // جلب بيانات السائق
          final driverDoc = await _firestore
              .collection('companies')
              .doc(companyId)
              .collection('drivers')
              .doc(driverId)
              .get();

          if (driverDoc.exists) {
            final driverData = driverDoc.data()!;
            final driver = Driver.fromMap({
              ...driverData,
              'driverId': driverId,
            });

            // تعيين الطلب للسائق
            await _assignToDriver(request, driver);
            print('✅ تم تعيين طلب من قائمة الانتظار: $requestId');
          }
        }
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

      // معالجة قائمة الانتظار فوراً
      await processDriverQueue(companyId, driverId);

      print('✅ تم تحرير السائق $driverId ومعالجة قائمة الانتظار');
    } catch (e) {
      print('❌ خطأ في تحرير السائق: $e');
    }
  }

  // ✨ دالة تشخيص النظام
  Future<void> debugDispatchSystem(String companyId) async {
    try {
      print('🔍 فحص نظام التوزيع...');

      // فحص السائقين المتاحين
      final availableDrivers = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .where('isAvailable', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .get();

      print('👥 عدد السائقين المتاحين: ${availableDrivers.docs.length}');
      for (var driver in availableDrivers.docs) {
        print('   - ${driver['name']} (${driver.id}) - مشاوير: ${driver['completedRides'] ?? 0}');
      }

      // فحص الطلبات المنتظرة
      final pendingRequests = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .where('status', whereIn: ['PENDING', 'WAITING_FOR_DRIVER'])
          .get();

      print('📋 عدد الطلبات المنتظرة: ${pendingRequests.docs.length}');
      for (var request in pendingRequests.docs) {
        print('   - ${request.id} (${request['status']}) - ${request['requesterName']}');
      }

      // فحص قوائم الانتظار
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