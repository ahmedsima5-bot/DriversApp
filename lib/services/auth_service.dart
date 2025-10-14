import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> signIn(String email, String password) async {
    try {
      print('🔐 محاولة تسجيل الدخول: $email');
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ تسجيل الدخول ناجح: ${result.user?.uid}');
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('❌ خطأ في تسجيل الدخول: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ AuthService Error during sign in: $e');
      return null;
    }
  }

  // ✅ إضافة دالة signUp المفقودة
  Future<User?> signUp(
      String email,
      String password,
      String name,
      String role,
      String department,
      String companyId,
      ) async {
    try {
      print('👤 محاولة إنشاء حساب: $email');
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        // تحديث اسم العرض للمستخدم في Firebase Auth
        await user.updateDisplayName(name);

        // حفظ البيانات في Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'user_id': user.uid,
          'email': email,
          'display_name': name,
          'role': role,
          'department': department,
          'company_id': companyId,
          'created_at': FieldValue.serverTimestamp(),
        });

        print('✅ إنشاء حساب ناجح: ${user.uid}');
        print('📋 بيانات المستخدم: {role: $role, department: $department, company: $companyId}');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ خطأ في إنشاء الحساب: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ AuthService Error during sign up: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserRoleAndCompanyId(String userId) async {
    try {
      print('🔍 جلب بيانات المستخدم: $userId');
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        print('📋 بيانات المستخدم: $data');

        return {
          'role': data['role'] as String? ?? 'Requester',
          'company_id': data['company_id'] as String? ?? 'C001',
          'department': data['department'] as String? ?? 'عام',
        };
      } else {
        print('❌ المستخدم غير موجود في Firestore');
        return null;
      }
    } catch (e) {
      print('❌ AuthService Error fetching user role: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('✅ تسجيل الخروج ناجح');
    } catch (e) {
      print('❌ خطأ في تسجيل الخروج: $e');
      rethrow;
    }
  }

  Stream<User?> get user => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;
}