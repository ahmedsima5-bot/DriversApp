// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String role; // مثل: requester, hr, driver, admin
  final String companyId;
  final String? department;
  final String? profileImageUrl;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.companyId,
    this.department,
    this.profileImageUrl,
  });

  // Factory constructor to create a UserModel from a Firestore Map
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'مستخدم جديد',
      role: data['role'] ?? 'requester', // الدور الافتراضي هو طالب خدمة
      companyId: data['companyId'] ?? '',
      department: data['department'],
      profileImageUrl: data['profileImageUrl'],
    );
  }

  // Convert UserModel object to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'companyId': companyId,
      'department': department,
      'profileImageUrl': profileImageUrl,
    };
  }
}