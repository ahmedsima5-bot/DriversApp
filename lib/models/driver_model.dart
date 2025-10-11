import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  final String driverId;
  final String name;
  final String phone;
  final String vehicleType;
  final String vehicleNumber;
  final bool isOnline;
  final bool isAvailable;
  final DateTime? lastStatusUpdate;
  final Map<String, double>? currentLocation;
  final int completedRides;
  final double performanceScore;
  final String? department;
  final String companyId;

  Driver({
    required this.driverId,
    required this.name,
    required this.phone,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.isOnline,
    required this.isAvailable,
    this.lastStatusUpdate,
    this.currentLocation,
    this.completedRides = 0,
    this.performanceScore = 0.0,
    this.department,
    required this.companyId,
  });

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'name': name,
      'phone': phone,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'isOnline': isOnline,
      'isAvailable': isAvailable,
      'lastStatusUpdate': lastStatusUpdate != null ? Timestamp.fromDate(lastStatusUpdate!) : null,
      'currentLocation': currentLocation,
      'completedRides': completedRides,
      'performanceScore': performanceScore,
      'department': department,
      'companyId': companyId,
    };
  }

  factory Driver.fromMap(Map<String, dynamic> map) {
    DateTime? lastUpdate;
    if (map['lastStatusUpdate'] != null && map['lastStatusUpdate'] is Timestamp) {
      lastUpdate = (map['lastStatusUpdate'] as Timestamp).toDate();
    }

    return Driver(
      driverId: map['driverId'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      vehicleType: map['vehicleType'] ?? '',
      vehicleNumber: map['vehicleNumber'] ?? '',
      isOnline: map['isOnline'] ?? false,
      isAvailable: map['isAvailable'] ?? false,
      lastStatusUpdate: lastUpdate,
      currentLocation: map['currentLocation'] != null
          ? Map<String, double>.from(map['currentLocation'])
          : null,
      completedRides: map['completedRides'] ?? 0,
      performanceScore: (map['performanceScore'] ?? 0.0).toDouble(),
      department: map['department']?.toString(),
      companyId: map['companyId'] ?? '',
    );
  }
}