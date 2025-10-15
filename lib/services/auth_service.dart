import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream لتتبع حالة المستخدم
  Stream<User?> get user {
    return _auth.authStateChanges();
  }

  // الحصول على المستخدم الحالي
  User? get currentUser {
    return _auth.currentUser;
  }

  // 🔐 تسجيل الدخول
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = result.user;
      if (user != null) {
        print('✅ تم تسجيل الدخول بنجاح: ${user.email}');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ خطأ في تسجيل الدخول: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ خطأ غير متوقع في تسجيل الدخول: $e');
      rethrow;
    }
  }

  // 📝 التسجيل
  Future<User?> signUp(
      String email,
      String password,
      String name,
      String role,
      String department,
      String companyId
      ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password.trim()
      );

      User? user = result.user;

      if (user != null) {
        // تحديث الملف الشخصي
        await user.updateDisplayName(name);

        // إضافة بيانات المستخدم إلى Firestore
        await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'role': role,
          'department': department,
          'companyId': companyId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });

        print('✅ تم إنشاء حساب المستخدم: ${user.uid} - الدور: $role');
        return user;
      }

      return null;
    } on FirebaseAuthException catch (e) {
      print('❌ خطأ في التسجيل: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ خطأ غير متوقع في التسجيل: $e');
      rethrow;
    }
  }

  // 🚪 تسجيل الخروج
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('✅ تم تسجيل الخروج بنجاح');
    } catch (e) {
      print('❌ خطأ في تسجيل الخروج: $e');
      rethrow;
    }
  }

  // 🔄 إعادة تعيين كلمة المرور
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      print('✅ تم إرسال رابط إعادة تعيين كلمة المرور إلى: $email');
    } on FirebaseAuthException catch (e) {
      print('❌ خطأ في إعادة تعيين كلمة المرور: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ خطأ غير متوقع في إعادة تعيين كلمة المرور: $e');
      rethrow;
    }
  }

  // 👤 تحديث الملف الشخصي
  Future<void> updateProfile(String name, String? phone) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(name);
        if (phone != null && phone.isNotEmpty) {
          // يمكن إضافة تحديث رقم الهاتف إذا كان مدعوماً
        }
        print('✅ تم تحديث الملف الشخصي: $name');
      }
    } catch (e) {
      print('❌ خطأ في تحديث الملف الشخصي: $e');
      rethrow;
    }
  }

  // 🔍 الحصول على بيانات المستخدم من Firestore
  Future<Map<String, dynamic>?> getUserData(String userId, String companyId) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ خطأ في جلب بيانات المستخدم: $e');
      return null;
    }
  }

  // 🎯 الحصول على دور المستخدم
  Future<String?> getUserRole(String userId, String companyId) async {
    try {
      Map<String, dynamic>? userData = await getUserData(userId, companyId);
      return userData?['role'] as String?;
    } catch (e) {
      print('❌ خطأ في جلب دور المستخدم: $e');
      return null;
    }
  }

  // 📧 التحقق من حالة البريد الإلكتروني
  Future<bool> isEmailVerified() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      return user.emailVerified;
    }
    return false;
  }

  // ✉️ إرسال تحقق البريد الإلكتروني
  Future<void> sendEmailVerification() async {
    User? user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
      print('✅ تم إرسال رابط التحقق إلى: ${user.email}');
    }
  }

}