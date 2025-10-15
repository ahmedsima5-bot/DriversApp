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
    // دالة مساعدة لتحويل أي قيمة إلى DateTime
    DateTime _parseDateTime(dynamic value) {
      if (value == null) return DateTime.now().add(Duration(hours: 1));
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now().add(Duration(hours: 1));
        }
      }
      return DateTime.now().add(Duration(hours: 1));
    }

    // دالة مساعدة لتحويل أي قيمة إلى GeoPoint
    GeoPoint _parseGeoPoint(dynamic value) {
      if (value == null) return const GeoPoint(24.7136, 46.6753); // الرياض
      if (value is GeoPoint) return value;
      if (value is Map && value['latitude'] != null && value['longitude'] != null) {
        return GeoPoint(
          (value['latitude'] as num).toDouble(),
          (value['longitude'] as num).toDouble(),
        );
      }
      return const GeoPoint(24.7136, 46.6753);
    }

    return Request(
      requestId: data['requestId']?.toString() ?? '',
      companyId: data['companyId']?.toString() ?? 'C001',
      requesterId: data['requesterId']?.toString() ?? '',
      requesterName: data['requesterName']?.toString() ?? 'غير معروف',
      department: data['department']?.toString(),
      purposeType: data['purposeType']?.toString() ?? 'عمل',
      details: data['details']?.toString() ?? '',
      priority: data['priority']?.toString() ?? 'Normal',
      assignedDriverId: data['assignedDriverId']?.toString(),
      assignedDriverName: data['assignedDriverName']?.toString(),

      hrApproverId: data['hrApproverId']?.toString(),
      hrApproverName: data['hrApproverName']?.toString(),
      hrApprovalTime: data['hrApprovalTime'] != null ? _parseDateTime(data['hrApprovalTime']) : null,
      rejectionReason: data['rejectionReason']?.toString(),

      pickupLocation: _parseGeoPoint(data['pickupLocation']),
      destinationLocation: _parseGeoPoint(data['destinationLocation']),
      startTimeExpected: _parseDateTime(data['startTimeExpected']),
      status: data['status']?.toString() ?? 'NEW',
      createdAt: _parseDateTime(data['createdAt']),
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

  // دالة مساعدة للتشخيص
  void printDebugInfo() {
    print('''
📋 معلومات الطلب:
   - ID: $requestId
   - الشركة: $companyId
   - مقدم الطلب: $requesterName
   - الحالة: $status
   - الأولوية: $priority
   - الوقت المتوقع: $startTimeExpected
   - وقت الإنشاء: $createdAt
   - السائق المعين: $assignedDriverName
   - من: (${pickupLocation.latitude}, ${pickupLocation.longitude})
   - إلى: (${destinationLocation.latitude}, ${destinationLocation.longitude})
''');
  }
}