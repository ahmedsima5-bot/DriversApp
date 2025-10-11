import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request_model.dart';
import '../models/driver_model.dart';

class DispatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // التوزيع العادل للسائقين
  Future<void> autoAssignDriverFair(String companyId, Request request) async {
    try {
      print('🚀 بدء التوزيع العادل للطلب: ${request.requestId}');

      // جلب السائقين المتاحين
      final driversSnap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();

      if (driversSnap.docs.isEmpty) {
        print('❌ لا يوجد سائقون متاحون');
        await _updateRequestStatus(
          companyId,
          request.requestId,
          'بانتظار سائق',
        );
        return;
      }

      List<Driver> availableDrivers = driversSnap.docs
          .map((doc) => Driver.fromMap(doc.data()))
          .toList();

      print('✅ عدد السائقين المتاحين: ${availableDrivers.length}');

      // ترتيب السائقين حسب العدالة
      availableDrivers.sort((a, b) {
        // 1. الأقل في عدد المشاوير
        if (a.completedRides != b.completedRides) {
          return a.completedRides.compareTo(b.completedRides);
        }
        // 2. الأعلى في الأداء (إذا تساوى عدد المشاوير)
        return b.performanceScore.compareTo(a.performanceScore);
      });

      final bestDriver = availableDrivers.first;
      print('🎯 أفضل سائق: ${bestDriver.name} (مشاوير: ${bestDriver.completedRides}, أداء: ${bestDriver.performanceScore})');

      // تحديث الطلب
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .doc(request.requestId)
          .update({
        'assignedDriverId': bestDriver.driverId,
        'assignedDriverName': bestDriver.name,
        'status': 'مُعين للسائق',
        'assignedTime': FieldValue.serverTimestamp(),
      });

      // تحديث حالة السائق
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(bestDriver.driverId)
          .update({
        'isAvailable': false,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });

      print('🎉 تم توزيع الطلب بنجاح على السائق: ${bestDriver.name}');
    } catch (e) {
      print('💥 خطأ في التوزيع: $e');
      rethrow;
    }
  }

  // الموافقة على الطلب العاجل وتوزيعه
  Future<void> approveAndDispatchUrgentRequest(
      String companyId,
      Request request,
      String hrManagerId,
      ) async {
    try {
      print('🔄 بدء موافقة وتوزيع الطلب العاجل: ${request.requestId}');

      // 1. تحديث حالة الطلب إلى موافق
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .doc(request.requestId)
          .update({
        'status': 'موافق',
        'hrApproverId': hrManagerId,
        'hrApprovalTime': FieldValue.serverTimestamp(),
      });

      // 2. توزيع الطلب على سائق
      await autoAssignDriverFair(companyId, request);

      print('✅ تمت الموافقة والتوزيع بنجاح');
    } catch (e) {
      print('❌ خطأ في الموافقة والتوزيع: $e');
      rethrow;
    }
  }

  // إكمال الطلب
  Future<void> completeRequest(
      String companyId,
      String requestId,
      String driverId,
      double rating,
      ) async {
    try {
      final now = FieldValue.serverTimestamp();

      // تحديث الطلب
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .doc(requestId)
          .update({
        'status': 'مكتمل',
        'completedTime': now,
        'rating': rating,
      });

      // تحديث إحصائيات السائق
      await _updateDriverStats(companyId, driverId, rating);

      // جعل السائق متاحاً مرة أخرى
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(driverId)
          .update({
        'isAvailable': true,
        'lastStatusUpdate': now,
      });

      print('✅ تم إكمال الطلب بنجاح');
    } catch (e) {
      print('❌ خطأ في إكمال الطلب: $e');
      rethrow;
    }
  }

  // تحديث إحصائيات السائق
  Future<void> _updateDriverStats(
      String companyId,
      String driverId,
      double rating,
      ) async {
    try {
      final driverRef = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(driverId);

      final driverDoc = await driverRef.get();
      if (driverDoc.exists) {
        final currentData = driverDoc.data()!;
        final completedRides = (currentData['completedRides'] ?? 0) + 1;
        final currentPerformance = (currentData['performanceScore'] ?? 0.0).toDouble();

        // حساب الأداء الجديد (متوسط مرجح)
        final newPerformance = ((currentPerformance * (completedRides - 1)) + rating) / completedRides;

        await driverRef.update({
          'completedRides': completedRides,
          'performanceScore': double.parse(newPerformance.toStringAsFixed(2)),
        });
      }
    } catch (e) {
      print('❌ خطأ في تحديث إحصائيات السائق: $e');
    }
  }

  Future<void> _updateRequestStatus(
      String companyId,
      String requestId,
      String status,
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
    } catch (e) {
      print('❌ خطأ في تحديث حالة الطلب: $e');
      rethrow;
    }
  }
}