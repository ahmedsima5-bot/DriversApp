import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// فئة خدمة المصادقة للتعامل مع Firebase Auth وقراءة دور المستخدم
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ********* 1. دالة تسجيل الدخول بالبريد وكلمة المرور *********
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      print('AuthService Error during sign in: $e');
      return null;
    }
  }

  // ********* 2. دالة تسجيل مستخدم جديد (Sign Up) *********
  Future<User?> signUp(
      String email,
      String password,
      String name,
      String role,
      String department,
      String companyId,
      ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        // تحديث اسم العرض للمستخدم في Firebase Auth
        await user.updateDisplayName(name);

        // حفظ الدور والقسم والاسم في Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'user_id': user.uid,
          'email': email,
          'display_name': name,
          'role': role, // الدور: HR, Driver, Requester
          'department': department, // القسم الذي اختاره
          'company_id': companyId, // معرّف الشركة
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      return user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      print('AuthService Error during sign up: $e');
      return null;
    }
  }

  // ********* 3. دالة الحصول على دور المستخدم ومعرّف الشركة والقسم *********
  Future<Map<String, dynamic>?> getUserRoleAndCompanyId(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return {
          'role': data['role'] as String,
          'company_id': data['company_id'] as String,
          'department': data['department'] as String, // تم إضافة القسم
        };
      }
      return null;
    } catch (e) {
      print('AuthService Error fetching user role: $e');
      return null;
    }
  }

  // ********* 4. دالة تسجيل الخروج *********
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ********* 5. دفق حالة المصادقة *********
  Stream<User?> get user => _auth.authStateChanges();
}
