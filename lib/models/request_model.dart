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
  final String toLocation;
  final String fromLocation;

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
    required this.toLocation,
    required this.fromLocation,
  });

  String get purpose => purposeType;
  DateTime get expectedTime => startTimeExpected;

  factory Request.fromMap(Map<String, dynamic> data) {
    // دالة مساعدة لتحويل أي قيمة إلى DateTime
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now().add(const Duration(hours: 1));
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now().add(const Duration(hours: 1));
        }
      }
      return DateTime.now().add(const Duration(hours: 1));
    }

    // دالة مساعدة لتحويل أي قيمة إلى GeoPoint
    GeoPoint parseGeoPoint(dynamic value) {
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

    // دالة مساعدة لتحويل أي قيمة إلى String
    String parseString(dynamic value, String defaultValue) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    return Request(
      requestId: parseString(data['requestId'], ''),
      companyId: parseString(data['companyId'], 'C001'),
      requesterId: parseString(data['requesterId'], ''),
      requesterName: parseString(data['requesterName'], 'غير معروف'),
      department: data['department']?.toString(),
      purposeType: parseString(data['purposeType'], 'عمل'),
      details: parseString(data['details'], ''),
      priority: parseString(data['priority'], 'Normal'),
      assignedDriverId: data['assignedDriverId']?.toString(),
      assignedDriverName: data['assignedDriverName']?.toString(),

      hrApproverId: data['hrApproverId']?.toString(),
      hrApproverName: data['hrApproverName']?.toString(),
      hrApprovalTime: data['hrApprovalTime'] != null ? parseDateTime(data['hrApprovalTime']) : null,
      rejectionReason: data['rejectionReason']?.toString(),

      pickupLocation: parseGeoPoint(data['pickupLocation']),
      destinationLocation: parseGeoPoint(data['destinationLocation']),
      startTimeExpected: parseDateTime(data['startTimeExpected']),
      status: parseString(data['status'], 'NEW'),
      createdAt: parseDateTime(data['createdAt']),
      toLocation: parseString(data['toLocation'], 'الموقع غير محدد'),
      fromLocation: parseString(data['fromLocation'], 'الموقع غير محدد'),
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
      'toLocation': toLocation,
      'fromLocation': fromLocation,
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
   - من: $fromLocation (${pickupLocation.latitude}, ${pickupLocation.longitude})
   - إلى: $toLocation (${destinationLocation.latitude}, ${destinationLocation.longitude})
''');
  }
}