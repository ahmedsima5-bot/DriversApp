import 'package:cloud_firestore/cloud_firestore.dart';

class Request {
  final String requestId;
  final String requesterId;
  final String requesterName;
  final String department;
  final String purpose;
  final String details;
  final String priority;
  final String status;
  final DateTime requestedTime;
  final DateTime expectedTime;
  final String? assignedDriverId;
  final String? assignedDriverName;
  final String? hrApproverId;
  final DateTime? hrApprovalTime;
  final DateTime? rejectionTime;
  final DateTime? completedTime;
  final double? rating;

  Request({
    required this.requestId,
    required this.requesterId,
    required this.requesterName,
    required this.department,
    required this.purpose,
    required this.details,
    required this.priority,
    required this.status,
    required this.requestedTime,
    required this.expectedTime,
    this.assignedDriverId,
    this.assignedDriverName,
    this.hrApproverId,
    this.hrApprovalTime,
    this.rejectionTime,
    this.completedTime,
    this.rating,
  });

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'department': department,
      'purpose': purpose,
      'details': details,
      'priority': priority,
      'status': status,
      'requestedTime': Timestamp.fromDate(requestedTime),
      'expectedTime': Timestamp.fromDate(expectedTime),
      'assignedDriverId': assignedDriverId,
      'assignedDriverName': assignedDriverName,
      'hrApproverId': hrApproverId,
      'hrApprovalTime': hrApprovalTime != null ? Timestamp.fromDate(hrApprovalTime!) : null,
      'rejectionTime': rejectionTime != null ? Timestamp.fromDate(rejectionTime!) : null,
      'completedTime': completedTime != null ? Timestamp.fromDate(completedTime!) : null,
      'rating': rating,
    };
  }

  factory Request.fromMap(Map<String, dynamic> map) {
    return Request(
      requestId: map['requestId']?.toString() ?? '',
      requesterId: map['requesterId']?.toString() ?? '',
      requesterName: map['requesterName']?.toString() ?? 'مستخدم',
      department: map['department']?.toString() ?? 'غير محدد',
      purpose: map['purpose']?.toString() ?? 'غير محدد',
      details: map['details']?.toString() ?? 'لا توجد تفاصيل',
      priority: map['priority']?.toString() ?? 'عادي',
      status: map['status']?.toString() ?? 'معلق',
      requestedTime: map['requestedTime'] != null
          ? (map['requestedTime'] as Timestamp).toDate()
          : DateTime.now(),
      expectedTime: map['expectedTime'] != null
          ? (map['expectedTime'] as Timestamp).toDate()
          : DateTime.now().add(Duration(hours: 2)),
      assignedDriverId: map['assignedDriverId']?.toString(),
      assignedDriverName: map['assignedDriverName']?.toString(),
      hrApproverId: map['hrApproverId']?.toString(),
      hrApprovalTime: map['hrApprovalTime'] != null
          ? (map['hrApprovalTime'] as Timestamp).toDate()
          : null,
      rejectionTime: map['rejectionTime'] != null
          ? (map['rejectionTime'] as Timestamp).toDate()
          : null,
      completedTime: map['completedTime'] != null
          ? (map['completedTime'] as Timestamp).toDate()
          : null,
      rating: map['rating']?.toDouble(),
    );
  }
}