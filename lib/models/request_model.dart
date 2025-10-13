import 'package:cloud_firestore/cloud_firestore.dart';

class Request {
  final String requestId;
  final String companyId;
  final String requesterId;
  final String requesterName;
  final String? department;

  // ✨ تم تعديل الحقول لتتوافق مع شاشة العرض
  final String purposeType; // هذا هو 'purpose'
  final String details;
  final String priority; // ✨ حقل جديد للأولوية (مثلاً: Urgent, Normal)
  final String? assignedDriverId;
  final String? assignedDriverName; // ✨ حقل جديد لاسم السائق المعين

  final GeoPoint pickupLocation;
  final GeoPoint destinationLocation;
  final DateTime startTimeExpected; // هذا هو 'expectedTime'
  final String status; // PENDING, HR_APPROVED, DISPATCHED, COMPLETED, REJECTED

  final DateTime createdAt;

  Request({
    required this.requestId,
    required this.companyId,
    required this.requesterId,
    required this.requesterName,
    this.department,
    required this.purposeType,
    required this.details,
    required this.priority, // ✨ حقل جديد
    this.assignedDriverId,
    this.assignedDriverName, // ✨ حقل جديد
    required this.pickupLocation,
    required this.destinationLocation,
    required this.startTimeExpected,
    required this.status,
    required this.createdAt,
  });

  // ========== Getters Helpers ==========

  // ✨ حل خطأ 'purpose' (نستخدم purposeType كـ purpose)
  String get purpose => purposeType;

  // ✨ حل خطأ 'expectedTime' (نستخدم startTimeExpected كـ expectedTime)
  DateTime get expectedTime => startTimeExpected;

  // ========== Constructor & Map Conversion ==========

  factory Request.fromMap(Map<String, dynamic> data) {
    return Request(
      requestId: data['requestId'] ?? '',
      companyId: data['companyId'] ?? '',
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'] ?? 'غير معروف',
      department: data['department'],

      purposeType: data['purposeType'] ?? 'Normal',
      details: data['details'] ?? '',
      priority: data['priority'] ?? 'Normal', // ✨ قراءة الحقل الجديد
      assignedDriverId: data['assignedDriverId'],
      assignedDriverName: data['assignedDriverName'], // ✨ قراءة الحقل الجديد

      pickupLocation: data['pickupLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      destinationLocation: data['destinationLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      startTimeExpected: (data['startTimeExpected'] as Timestamp).toDate(),
      status: data['status'] ?? 'PENDING',

      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'companyId': companyId,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'department': department,

      'purposeType': purposeType,
      'details': details,
      'priority': priority, // ✨ كتابة الحقل الجديد
      'assignedDriverId': assignedDriverId,
      'assignedDriverName': assignedDriverName, // ✨ كتابة الحقل الجديد

      'pickupLocation': pickupLocation,
      'destinationLocation': destinationLocation,
      'startTimeExpected': Timestamp.fromDate(startTimeExpected),
      'status': status,

      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
