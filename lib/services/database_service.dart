import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/request_model.dart';
import '../models/user_model.dart';

class DatabaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // **********************************************
  //              Company Settings
  // **********************************************

  // جلب إعدادات الشركة (الرول، الأقسام)
  static Stream<DocumentSnapshot> getCompanySettings(String companyId) {
    return _db.collection('artifacts/$companyId/public/data/company_settings').doc('settings').snapshots();
  }

  // تحديث إعدادات الشركة
  static Future<void> updateCompanySettings(String companyId, Map<String, dynamic> data) async {
    try {
      await _db.collection('artifacts/$companyId/public/data/company_settings').doc('settings').set(
        data,
        SetOptions(merge: true), // دمج البيانات الموجودة
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error updating company settings: $e");
      }
      rethrow;
    }
  }

  // إضافة قسم جديد
  static Future<void> addDepartment(String companyId, String departmentName) async {
    try {
      await _db.collection('artifacts/$companyId/public/data/departments').doc(departmentName).set({
        'name': departmentName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error adding department: $e");
      }
      rethrow;
    }
  }

  // جلب قائمة الأقسام
  static Stream<List<String>> getDepartmentsStream(String companyId) {
    return _db.collection('artifacts/$companyId/public/data/departments')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  // **********************************************
  //              User Management
  // **********************************************

  // جلب بيانات مستخدم واحد
  static Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error getting user: $e");
      }
    }
    return null;
  }

  // **********************************************
  //              Request Management (Requester & HR Functions)
  // **********************************************

  // ✨ دالة جديدة: لإضافة طلب نقل جديد إلى Firestore
  static Future<void> addRequest(Request request) async {
    try {
      // نستخدم المسار الصحيح المعتمد على companyId
      await _db.collection('artifacts/${request.companyId}/public/data/requests').doc(request.requestId).set(
        request.toMap(),
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error adding new request: $e");
      }
      rethrow;
    }
  }

  // جلب طلبات مستخدم معين
  static Stream<List<Request>> getUserRequests(String companyId, String userId) {
    return _db.collection('artifacts/$companyId/public/data/requests')
        .where('requesterId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Request.fromMap(doc.data())).toList();
    });
  }

  // جلب طلبات النقل العاجلة المعلقة للموافقة
  static Stream<QuerySnapshot> getUrgentPendingRequests(String companyId) {
    return _db.collection('artifacts/$companyId/public/data/requests')
        .where('status', isEqualTo: 'PENDING')
        .where('purposeType', isEqualTo: 'Urgent')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // تحديث حالة الطلب بعد موافقة/رفض HR
  static Future<void> updateRequestStatusAndApprover({
    required String companyId,
    required String requestId,
    required String newStatus,
  }) async {
    try {
      await _db.collection('artifacts/$companyId/public/data/requests').doc(requestId).update({
        'status': newStatus,
        'hrApprovalAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error updating HR approval status for $requestId: $e");
      }
      rethrow;
    }
  }
}
