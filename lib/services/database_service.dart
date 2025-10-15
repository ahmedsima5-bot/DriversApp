import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ دالة محسنة لجلب الأقسام
  static Stream<List<String>> getDepartmentsStream(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data.containsKey('departments')) {
          final departments = data['departments'] as List<dynamic>;
          return departments.map((dept) => dept.toString()).toList();
        }
      }
      return []; // إرجاع قائمة فارغة إذا لم توجد بيانات
    });
  }

  // ✅ دالة بديلة باستخدام Future
  static Future<List<String>> getDepartments(String companyId) async {
    try {
      final doc = await _firestore
          .collection('companies')
          .doc(companyId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('departments')) {
          final departments = data['departments'] as List<dynamic>;
          return departments.map((dept) => dept.toString()).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching departments: $e');
      return [];
    }
  }

}
