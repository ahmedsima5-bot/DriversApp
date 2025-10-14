import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: "AIzaSyD_h_qWxfsVcgV4zBQv9xDmI3OAnOzOKLw",
      authDomain: "dra-logistics.firebaseapp.com",
      projectId: "dra-logistics",
      storageBucket: "dra-logistics.firebasestorage.app",
      messagingSenderId: "271222119081",
      appId: "1:271222119081:web:3995ed9c19ea9bfe6967b8",
    );
  }
}