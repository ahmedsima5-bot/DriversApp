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

  // ✨ معالجة الطلبات المعلقة دورياً - النسخة المحسنة
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

          // 🔥 الجديد: تجاهل حالة الانتظار ونعالج كل الطلبات
          print('🎯 معالجة الطلب: ${request.requestId} - الحالة: ${request.status}');

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
      await _tryAutoAssign(request);
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

      if (request.status == 'COMPLETED' || request.status == 'CANCELLED') {
        print('⚠️ الطلب في حالة ${request.status}، لا يمكن معالجته');
        return;
      }

      if (request.assignedDriverId != null && request.assignedDriverId!.isNotEmpty) {
        print('⚠️ الطلب مُعين مسبقاً للسائق: ${request.assignedDriverName}');
        return;
      }

      // 🔥 الجديد: تجاهل إرسال الطلبات العاجلة للموارد البشرية ونوزع مباشرة
      await _tryAutoAssign(request);

      print('✅ تمت معالجة الطلب بنجاح');
    } catch (e) {
      print('❌ خطأ في معالجة الطلب: $e');
    }
  }

  // ✨ محاولة التعيين التلقائي - النسخة الجذرية
  Future<void> _tryAutoAssign(Request request) async {
    try {
      print('🎯 محاولة التعيين التلقائي للطلب: ${request.requestId}');

      // جلب جميع السائقين النشطين - بدون شرط التوفر
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

      print('📊 إحصائيات السائقين: ${allDriversList.length} سائق');

      // 🔥 الجديد: نعطي الطلب لأي سائق نشط بغض النظر عن حالته
      if (allDriversList.isNotEmpty) {
        // 🔥 ترتيب السائقين حسب الأولوية المحسنة
        final selectedDriver = await _selectBestDriver(allDriversList, request.companyId);

        if (selectedDriver != null) {
          print('🎯 السائق المختار: ${selectedDriver.name}');
          print('   - متاح: ${selectedDriver.isAvailable}');
          print('   - مشاوير مكتملة: ${selectedDriver.completedRides}');

          // 🔥 الجديد: نعطي الطلب مباشرة بغض النظر عن حالة السائق
          await _assignToDriverDirectly(request, selectedDriver);
        } else {
          print('❌ لا يوجد سائقون مناسبون للتعيين');
          await _updateRequestStatus(
            request.companyId,
            request.requestId,
            'PENDING',
            'لا يوجد سائقون مناسبون',
          );
        }
      } else {
        print('❌ لا يوجد سائقون نشطون');
        await _updateRequestStatus(
          request.companyId,
          request.requestId,
          'PENDING',
          'لا يوجد سائقون نشطون',
        );
      }

    } catch (e) {
      print('❌ خطأ في التعيين التلقائي: $e');
    }
  }

  // ✨ دالة جديدة لاختيار أفضل سائق - بسيطة وفعالة
  Future<Driver?> _selectBestDriver(List<Driver> drivers, String companyId) async {
    if (drivers.isEmpty) return null;

    // 🔥 الجديد: نفضل السائقين المتاحين، لكن إذا مافيش نأخذ أي سائق
    Driver? bestDriver;
    int minQueueCount = 999999;

    for (var driver in drivers) {
      final queueCount = await _getDriverQueueCount(driver.driverId, companyId);

      // إذا وجدنا سائق متاح بدون طلبات انتظار، نأخذه مباشرة
      if (driver.isAvailable && queueCount == 0) {
        return driver;
      }

      // نبحث عن السائق بأقل طلبات انتظار
      if (queueCount < minQueueCount) {
        minQueueCount = queueCount;
        bestDriver = driver;
      }
    }

    return bestDriver ?? drivers.first;
  }

  // ✨ دالة جديدة للتعيين المباشر بدون قوائم انتظار
  Future<void> _assignToDriverDirectly(Request request, Driver driver) async {
    try {
      print('🚗 تعيين مباشر للطلب ${request.requestId} للسائق ${driver.name}');

      // تحديث حالة الطلب
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

      // تحديث حالة السائق
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

      print('✅ تم التعيين المباشر بنجاح للسائق: ${driver.name}');

    } catch (e) {
      print('❌ خطأ في التعيين المباشر: $e');
      // 🔥 الجديد: نحاول مع سائق آخر إذا فشل التعيين
      await _tryAlternativeDriver(request, driver.driverId);
    }
  }

  // ✨ دالة جديدة لمحاولة سائق بديل
  Future<void> _tryAlternativeDriver(Request request, String failedDriverId) async {
    try {
      print('🔄 محاولة سائق بديل بعد فشل التعيين مع: $failedDriverId');

      final allDriversSnap = await _firestore
          .collection('companies')
          .doc(request.companyId)
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .get();

      for (var doc in allDriversSnap.docs) {
        if (doc.id != failedDriverId) {
          try {
            final driverData = doc.data();
            final driver = Driver.fromMap({
              ...driverData,
              'driverId': doc.id,
            });

            print('🔄 محاولة التعيين مع السائق البديل: ${driver.name}');
            await _assignToDriverDirectly(request, driver);
            return;
          } catch (e) {
            print('❌ فشل التعيين مع السائق البديل: ${doc.id}');
            continue;
          }
        }
      }

      print('❌ لم يتم العثور على سائق بديل');
    } catch (e) {
      print('❌ خطأ في البحث عن سائق بديل: $e');
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
        // 🔥 الجديد: نوزع مباشرة بدون تغيير الحالة أولاً
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

          // نوزع مباشرة
          await _tryAutoAssign(request);
        }

        print('✅ تمت الموافقة والتوزيع التلقائي للطلب');
      }
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

    } catch (e) {
      print('❌ خطأ في تحرير السائق: $e');
    }
  }

  // ✨ دالة تشخيص النظام
  Future<void> debugDispatchSystem(String companyId) async {
    try {
      print('🔍 فحص نظام التوزيع...');

      final allDrivers = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .get();

      print('👥 عدد السائقين النشطين: ${allDrivers.docs.length}');
      for (var driver in allDrivers.docs) {
        final queueCount = await _getDriverQueueCount(driver.id, companyId);
        print('   - ${driver['name']} (${driver.id}) - متاح: ${driver['isAvailable'] ?? true} - طلبات انتظار: $queueCount');
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

      print('✅ تم فحص النظام بنجاح');

    } catch (e) {
      print('❌ خطأ في فحص النظام: $e');
    }
  }

  // ✨ دالة جديدة: إصلاح حالات السائقين المعطلة
  Future<void> fixDriversAvailability(String companyId) async {
    try {
      print('🛠️ جاري إصلاح حالات السائقين...');

      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .get();

      int fixedCount = 0;

      for (var driverDoc in driversSnapshot.docs) {
        final driverData = driverDoc.data();
        final isAvailable = driverData['isAvailable'] ?? true;
        final currentRequestId = driverData['currentRequestId'] as String?;

        // إذا السائق مشغول لكن مافيه طلب حالية
        if (isAvailable == false && (currentRequestId == null || currentRequestId.isEmpty)) {
          await driverDoc.reference.update({
            'isAvailable': true,
            'lastStatusUpdate': FieldValue.serverTimestamp(),
          });
          fixedCount++;
          print('✅ تم إصلاح حالة السائق: ${driverData['name']}');
        }
      }

      print('🛠️ تم إصلاح حالة $fixedCount سائق');

    } catch (e) {
      print('❌ خطأ في إصلاح حالات السائقين: $e');
    }
  }
}