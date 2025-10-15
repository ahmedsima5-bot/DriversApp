import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request_model.dart';
import '../models/driver_model.dart';

class DispatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✨ دالة معالجة الطلب الجديد
  Future<void> processNewRequest(Request request) async {
    try {
      print('🚀 بدء معالجة الطلب: ${request.requestId} - الأولوية: ${request.priority}');

      if (request.priority == 'Urgent') {
        // إذا كان الطلب عاجل، إرساله للموارد البشرية
        await _sendToHRApproval(request);
      } else {
        // إذا كان طلب عادي، توزيعه مباشرة
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
  Future<void> _autoAssignDriver(Request request) async {
    try {
      print('🎯 بدء التوزيع التلقائي للطلب: ${request.requestId}');

      // جلب السائقين المتاحين
      final driversSnap = await _firestore
          .collection('companies')
          .doc(request.companyId)
          .collection('drivers')
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();

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

      List<Driver> availableDrivers = driversSnap.docs
          .map((doc) => Driver.fromMap(doc.data()))
          .toList();

      print('✅ عدد السائقين المتاحين: ${availableDrivers.length}');

      // ترتيب السائقين بعدالة (الأقل مشاوير أولاً)
      availableDrivers.sort((a, b) {
        return a.completedRides.compareTo(b.completedRides);
      });

      final bestDriver = availableDrivers.first;
      print('🎯 أفضل سائق: ${bestDriver.name} (مشاوير: ${bestDriver.completedRides})');

      // تعيين الطلب للسائق
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

      // تحديث حالة السائق ليكون غير متاح
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
        String? specificDriverId, // إذا كان في سائق محدد
        String? specificDriverName,
      }) async {
    try {
      if (specificDriverId != null) {
        // إذا حددوا سائق معين
        await assignToSpecificDriver(
          companyId,
          requestId,
          specificDriverId,
          specificDriverName!,
          hrManagerId,
          hrManagerName,
        );
      } else {
        // إذا ما حددوا، توزيع تلقائي
        // أولاً: تحديث حالة الطلب لموافق
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

        // ثانياً: جلب الطلب وتوزيعه
        final requestDoc = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('requests')
            .doc(requestId)
            .get();

        if (requestDoc.exists) {
          final request = Request.fromMap(requestDoc.data()!);
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

  // ========== الدوال المساعدة ==========

  Future<void> _assignToDriver(Request request, Driver driver) async {
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
    });
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
}