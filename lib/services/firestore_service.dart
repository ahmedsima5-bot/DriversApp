// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> addDriver(String userId, Map<String, dynamic> driverData) async {
    try {
      await _firestore.collection('drivers').doc(userId).set({
        'uid': userId,
        'name': driverData['name'],
        'email': driverData['email'],
        'role': 'driver',
        'companyId': 'C001',  // نفس الشركة اللي في dispatch
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'phone': driverData['phone'] ?? '',
      });
      print('✅ تم إضافة السائق إلى Firestore بنجاح: $userId');
    } catch (e) {
      print('❌ خطأ في إضافة السائق إلى Firestore: $e');
      throw e;
    }
  }
}