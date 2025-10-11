import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request_model.dart';
import '../models/driver_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // إنشاء طلب جديد
  Future<void> createRequest(String companyId, Request request) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .doc(request.requestId)
          .set(request.toMap());
    } catch (e) {
      print('خطأ في حفظ الطلب: $e');
      rethrow;
    }
  }

  // جلب طلبات المستخدم
  Stream<List<Request>> getUserRequests(String companyId, String userId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('requests')
        .where('requesterId', isEqualTo: userId)
        .orderBy('requestedTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Request.fromMap(doc.data()))
          .toList();
    });
  }

  // جلب الطلبات العاجلة التي تحتاج موافقة
  Stream<List<Request>> getUrgentRequestsForApproval(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('requests')
        .where('priority', isEqualTo: 'عاجل')
        .where('status', isEqualTo: 'بانتظار موافقة الموارد البشرية')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Request.fromMap(doc.data()))
          .toList();
    });
  }

  // تحديث حالة الطلب
  Future<void> updateRequestStatus({
    required String companyId,
    required String requestId,
    required String newStatus,
    String? hrApproverId,
    String? driverId,
    String? driverName,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (hrApproverId != null) {
        updateData['hrApproverId'] = hrApproverId;
        updateData['hrApprovalTime'] = FieldValue.serverTimestamp();
      }

      if (driverId != null) {
        updateData['assignedDriverId'] = driverId;
        updateData['assignedDriverName'] = driverName;
        updateData['assignedTime'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .doc(requestId)
          .update(updateData);
    } catch (e) {
      print('خطأ في تحديث حالة الطلب: $e');
      rethrow;
    }
  }

  // جلب السائقين المتاحين
  Future<List<Driver>> getAvailableDrivers(String companyId) async {
    try {
      final snapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => Driver.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('خطأ في جلب السائقين المتاحين: $e');
      return [];
    }
  }

  // تحديث حالة السائق
  Future<void> updateDriverStatus({
    required String companyId,
    required String driverId,
    required bool isAvailable,
    Map<String, double>? location,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'isAvailable': isAvailable,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      };

      if (location != null) {
        updateData['currentLocation'] = location;
      }

      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(driverId)
          .update(updateData);
    } catch (e) {
      print('خطأ في تحديث حالة السائق: $e');
      rethrow;
    }
  }

  // زيادة عدد مشاوير السائق
  Future<void> incrementDriverRides(String companyId, String driverId) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .doc(driverId)
          .update({
        'completedRides': FieldValue.increment(1),
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('خطأ في زيادة عدد مشاوير السائق: $e');
      rethrow;
    }
  }
}