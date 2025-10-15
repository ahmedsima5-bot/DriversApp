import 'package:cloud_firestore/cloud_firestore.dart';

class Request {
  final String requestId;
  final String companyId;
  final String requesterId;
  final String requesterName;
  final String? department;

  final String purposeType;
  final String details;
  final String priority;
  final String? assignedDriverId;
  final String? assignedDriverName;

  final String? hrApproverId;
  final String? hrApproverName;
  final DateTime? hrApprovalTime;
  final String? rejectionReason;

  final GeoPoint pickupLocation;
  final GeoPoint destinationLocation;
  final DateTime startTimeExpected;
  final String status;
  final DateTime createdAt;

  Request({
    required this.requestId,
    required this.companyId,
    required this.requesterId,
    required this.requesterName,
    this.department,
    required this.purposeType,
    required this.details,
    required this.priority,
    this.assignedDriverId,
    this.assignedDriverName,

    this.hrApproverId,
    this.hrApproverName,
    this.hrApprovalTime,
    this.rejectionReason,

    required this.pickupLocation,
    required this.destinationLocation,
    required this.startTimeExpected,
    required this.status,
    required this.createdAt,
  });

  String get purpose => purposeType;
  DateTime get expectedTime => startTimeExpected;

  factory Request.fromMap(Map<String, dynamic> data) {
    return Request(
      requestId: data['requestId'] ?? '',
      companyId: data['companyId'] ?? '',
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'] ?? 'غير معروف',
      department: data['department'],
      purposeType: data['purposeType'] ?? 'Normal',
      details: data['details'] ?? '',
      priority: data['priority'] ?? 'Normal',
      assignedDriverId: data['assignedDriverId'],
      assignedDriverName: data['assignedDriverName'],

      hrApproverId: data['hrApproverId'],
      hrApproverName: data['hrApproverName'],
      hrApprovalTime: data['hrApprovalTime'] != null
          ? (data['hrApprovalTime'] as Timestamp).toDate()
          : null,
      rejectionReason: data['rejectionReason'],

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
      'priority': priority,
      'assignedDriverId': assignedDriverId,
      'assignedDriverName': assignedDriverName,

      'hrApproverId': hrApproverId,
      'hrApproverName': hrApproverName,
      'hrApprovalTime': hrApprovalTime != null
          ? Timestamp.fromDate(hrApprovalTime!)
          : null,
      'rejectionReason': rejectionReason,

      'pickupLocation': pickupLocation,
      'destinationLocation': destinationLocation,
      'startTimeExpected': Timestamp.fromDate(startTimeExpected),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}