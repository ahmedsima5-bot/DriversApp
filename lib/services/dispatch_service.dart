import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request_model.dart';
import '../models/driver_model.dart';
import 'dart:async';

class DispatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _requestsSubscription;

  // ✨ بدء الاستماع للطلبات الجديدة
  void startListening(String companyId) {
    _requestsSubscription = _setupRequestsListener(companyId);
    print('🎯 بدء الاستماع للطلبات الجديدة للشركة: $companyId');
  }

  // ✨ إيقاف الاستماع
  void stopListening() {
    _requestsSubscription?.cancel();
    _requestsSubscription = null;
    print('🛑 توقف الاستماع للطلبات الجديدة');
  }

  // ✨ مستمع للطلبات الجديدة
  StreamSubscription<void> _setupRequestsListener(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('requests')
        .where('status', whereIn: ['NEW', 'PENDING'])
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added || doc.type == DocumentChangeType.modified) {
          final requestData = doc.doc.data()!;
          // التصحيح: إضافة requestId من doc.id
          final request = Request.fromMap({
            ...requestData,
            'requestId': doc.doc.id, // ← هذا هو التصحيح
          });
          print('🆕 طلب جديد/معدل تم اكتشافه: ${request.requestId} - الحالة: ${request.status}');
          processNewRequest(request);
        }
      }
    });
  }

  // ✨ دالة معالجة الطلب الجديد
  Future<void> processNewRequest(Request request) async {
    try {
      print('🚀 بدء معالجة الطلب: ${request.requestId} - الأولوية: ${request.priority}');

      // ✅ التحقق من أن الطلب جاهز للمعالجة
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
        await _autoAssignDriver(request);
      }

      print('✅ تمت معالجة الطلب بنجاح');
    } catch (e) {
      print('❌ خطأ في معالجة الطلب: $e');
      rethrow;
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
      rethrow;
    }
  }

  // ✨ التوزيع التلقائي للسائقين
  // ✨ التوزيع التلقائي للسائقين
  // ✨ التوزيع التلقائي للسائقين
  // ✨ التوزيع التلقائي للسائقين (مصححة)
  Future<void> _autoAssignDriver(Request request) async {
    try {
      print('🎯 بدء التوزيع التلقائي للطلب: ${request.requestId}');

      final driversSnap = await _firestore
          .collection('companies')
          .doc(request.companyId)
          .collection('drivers')
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .get();

      // تشخيص البيانات
      _debugDriverData(driversSnap);

      if (driversSnap.docs.isEmpty) {
        print('❌ لا يوجد سائقون متاحون');
        await _updateRequestStatus(
          request.companyId,
          request.requestId,
          'PENDING',
          'بانتظار سائق متاح',
        );
        return;
      }

      List<Driver> availableDrivers = [];

      for (var doc in driversSnap.docs) {
        try {
          final data = doc.data();

          // تحويل البيانات إلى Map بشكل آمن
          Map<String, dynamic> driverData = {};

          if (data is Map<String, dynamic>) {
            driverData = data;
          } else if (data is Map) {
            // إذا كانت Map عادية، تحويلها إلى Map<String, dynamic>
            driverData = data.cast<String, dynamic>();
          } else {
            print('❌ نوع بيانات غير متوقع للسائق ${doc.id}: ${data.runtimeType}');
            continue;
          }

          final driver = Driver.fromMap({
            ...driverData,
            'driverId': doc.id, // إضافة driverId من doc.id
          });
          availableDrivers.add(driver);
          print('✅ تم تحميل السائق: ${driver.name} (${driver.driverId})');
        } catch (e) {
          print('❌ خطأ في تحميل سائق ${doc.id}: $e');
          print('   البيانات: ${doc.data()}');
        }
      }

      print('✅ عدد السائقين المتاحين بعد التصفية: ${availableDrivers.length}');

      if (availableDrivers.isEmpty) {
        print('❌ لا يوجد سائقون صالحون للتعيين');
        await _updateRequestStatus(
          request.companyId,
          request.requestId,
          'PENDING',
          'لا يوجد سائقون صالحون',
        );
        return;
      }

      availableDrivers.sort((a, b) {
        return a.completedRides.compareTo(b.completedRides);
      });

      final bestDriver = availableDrivers.first;
      print('🎯 أفضل سائق: ${bestDriver.name} (مشاوير: ${bestDriver.completedRides})');

      await _assignToDriver(request, bestDriver);

    } catch (e) {
      print('❌ خطأ في التوزيع التلقائي: $e');
      rethrow;
    }
  }
  // ✨ تعيين طلب معين لسائق معين (من قبل الموارد البشرية)
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
      });

      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(driverId)
          .update({
        'isAvailable': false,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
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
        });

        final requestDoc = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('requests')
            .doc(requestId)
            .get();

        if (requestDoc.exists) {
          // التصحيح: إضافة requestId من doc.id
          final request = Request.fromMap({
            ...requestDoc.data()!,
            'requestId': requestDoc.id,
          });
          await _autoAssignDriver(request);
        }
      }

      print('✅ تمت موافقة الموارد البشرية بنجاح');
    } catch (e) {
      print('❌ خطأ في موافقة الموارد البشرية: $e');
      rethrow;
    }
  }

  // ✨ رفض الطلب العاجل
  Future<void> rejectUrgentRequest(
      String companyId,
      String requestId,
      String hrManagerId,
      String hrManagerName,
      String rejectionReason,
      ) async {
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
        'hrApprovalTime': FieldValue.serverTimestamp(),
        'rejectionReason': rejectionReason,
      });

      print('✅ تم رفض الطلب بنجاح');
    } catch (e) {
      print('❌ خطأ في رفض الطلب: $e');
      rethrow;
    }
  }

  // ✨ دالة تشخيص النظام
  // ✨ دالة تشخيص النظام
  Future<void> debugDispatchSystem(String companyId) async {
    try {
      print('🔍 فحص نظام التوزيع...');

      final drivers = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .get();

      print('👥 عدد السائقين المتاحين: ${drivers.docs.length}');
      drivers.docs.forEach((driver) {
        print('   - ${driver['name']} (${driver.id})');
      });

      final pendingRequests = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .where('status', whereIn: ['NEW', 'PENDING', 'HR_APPROVED'])
          .get();

      print('📋 عدد الطلبات المنتظرة: ${pendingRequests.docs.length}');
      pendingRequests.docs.forEach((request) {
        print('   - ${request.id} (${request['status']})');
      });

      for (var doc in pendingRequests.docs) {
        try {
          // التصحيح: إضافة requestId من doc.id ومعالجة القيم الفارغة
          final requestData = doc.data();
          final safeRequestData = _createSafeRequestData(requestData, doc.id);

          final request = Request.fromMap(safeRequestData);
          print('🔄 معالجة الطلب: ${request.requestId}');
          await processNewRequest(request);
        } catch (e) {
          print('⚠️ خطأ في معالجة الطلب ${doc.id}: $e');
          // استمر في معالجة الطلبات الأخرى
          continue;
        }
      }

      print('✅ تم فحص النظام بنجاح');
    } catch (e) {
      print('❌ خطأ في فحص النظام: $e');
    }
  }
// في DispatchService - دالة لإنشاء Request آمن مع تشخيص
  Request _createSafeRequestWithDebug(Map<String, dynamic> data, String docId) {
    try {
      print('🔍 تحليل بيانات الطلب $docId:');
      print('   - startTimeExpected: ${data['startTimeExpected']} (نوع: ${data['startTimeExpected']?.runtimeType})');
      print('   - createdAt: ${data['createdAt']} (نوع: ${data['createdAt']?.runtimeType})');
      print('   - pickupLocation: ${data['pickupLocation']} (نوع: ${data['pickupLocation']?.runtimeType})');

      final request = Request.fromMap({
        ...data,
        'requestId': docId,
      });

      request.printDebugInfo();
      return request;

    } catch (e) {
      print('❌ خطأ في تحليل الطلب $docId: $e');
      print('📋 البيانات الأصلية: $data');

      // إرجاع Request افتراضي آمن
      return Request(
        requestId: docId,
        companyId: data['companyId']?.toString() ?? 'C001',
        requesterId: data['requesterId']?.toString() ?? 'unknown',
        requesterName: data['requesterName']?.toString() ?? 'مستخدم',
        purposeType: data['purposeType']?.toString() ?? 'عمل',
        details: data['details']?.toString() ?? 'تفاصيل غير متاحة',
        priority: data['priority']?.toString() ?? 'Normal',
        pickupLocation: const GeoPoint(24.7136, 46.6753),
        destinationLocation: const GeoPoint(24.7136, 46.6753),
        startTimeExpected: DateTime.now().add(Duration(hours: 1)),
        status: data['status']?.toString() ?? 'NEW',
        createdAt: DateTime.now(),
      );
    }
  }
// ✨ دالة مساعدة لإنشاء بيانات آمنة للطلب
  Map<String, dynamic> _createSafeRequestData(Map<String, dynamic>? originalData, String docId) {
    final data = originalData ?? {};

    return {
      ...data,
      'requestId': docId,
      'createdTime': data['createdTime'] ?? DateTime.now(),
      'lastUpdated': data['lastUpdated'] ?? DateTime.now(),
      'assignedTime': data['assignedTime'],
      'hrApprovalTime': data['hrApprovalTime'],
      // أضف حقول أخرى قد تكون null
    };
  }
  // ========== الدوال المساعدة ==========
// في DispatchService - دالة لفحص بيانات السائق
  // في DispatchService - دالة لفحص بيانات السائق (مصححة)
  void _debugDriverData(QuerySnapshot driversSnap) {
    print('🔍 فحص بيانات السائقين:');
    for (var doc in driversSnap.docs) {
      print('   - وثيقة السائق: ${doc.id}');

      final data = doc.data();
      print('     البيانات: $data');
      print('     نوع البيانات: ${data.runtimeType}');

      // تحقق إذا كانت البيانات Map
      if (data is Map<String, dynamic>) {
        print('     الأنواع:');
        data.forEach((key, value) {
          print('       $key: $value (${value.runtimeType})');
        });
      } else {
        print('     ⚠️ البيانات ليست Map، نوعها: ${data.runtimeType}');
      }
    }
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
      });

      print('✅ تم تعيين الطلب بنجاح للسائق: ${driver.name}');

    } catch (e) {
      print('❌ خطأ في تعيين الطلب للسائق: $e');
      rethrow;
    }
  }
  Future<void> _updateRequestStatus(
      String companyId,
      String requestId,
      String status,
      String logMessage,
      ) async {
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
  }
  // ✨ إرسال إشعار بدء الرحلة
  Future<void> _notifyRideStart(Request request, Driver driver) async {
    try {
      // إشعار لطالب الخدمة
      await _firestore
          .collection('companies')
          .doc(request.companyId)
          .collection('notifications')
          .add({
        'type': 'RIDE_STARTED',
        'title': 'بدأ السائق الرحلة',
        'message': 'السائق ${driver.name} بدأ الرحلة إلى ${request.destinationLocation}',
        'userId': request.requesterId,
        'requestId': request.requestId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // إشعار للموارد البشرية
      await _firestore
          .collection('companies')
          .doc(request.companyId)
          .collection('notifications')
          .add({
        'type': 'RIDE_STARTED',
        'title': 'بدأ السائق الرحلة',
        'message': 'السائق ${driver.name} بدأ تنفيذ الطلب ${request.requestId}',
        'department': 'HR',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      print('📢 تم إرسال إشعارات بدء الرحلة');
    } catch (e) {
      print('❌ خطأ في إرسال إشعارات بدء الرحلة: $e');
    }
  }

// ✨ إرسال إشعار انتهاء الرحلة
  Future<void> _notifyRideCompletion(Request request, Driver driver) async {
    try {
      // إشعار لطالب الخدمة
      await _firestore
          .collection('companies')
          .doc(request.companyId)
          .collection('notifications')
          .add({
        'type': 'RIDE_COMPLETED',
        'title': 'تم إنهاء الرحلة',
        'message': 'السائق ${driver.name} أنهى الرحلة بنجاح',
        'userId': request.requesterId,
        'requestId': request.requestId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // إشعار للموارد البشرية
      await _firestore
          .collection('companies')
          .doc(request.companyId)
          .collection('notifications')
          .add({
        'type': 'RIDE_COMPLETED',
        'title': 'تم إنهاء الرحلة',
        'message': 'السائق ${driver.name} أنهى الطلب ${request.requestId} بنجاح',
        'department': 'HR',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      print('📢 تم إرسال إشعارات انتهاء الرحلة');
    } catch (e) {
      print('❌ خطأ في إرسال إشعارات انتهاء الرحلة: $e');
    }
  }
}