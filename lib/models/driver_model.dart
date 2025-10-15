import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  final String driverId;
  final String companyId;
  final String name;
  final String email;
  final String phone;
  final bool isOnline;
  final bool isAvailable;
  final int completedRides;
  final double performanceScore;
  final DateTime lastStatusUpdate;

  Driver({
    required this.driverId,
    required this.companyId,
    required this.name,
    required this.email,
    required this.phone,
    required this.isOnline,
    required this.isAvailable,
    required this.completedRides,
    required this.performanceScore,
    required this.lastStatusUpdate,
  });

  factory Driver.fromMap(Map<String, dynamic> data) {
    return Driver(
      driverId: data['driverId'] ?? '',
      companyId: data['companyId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      isOnline: data['isOnline'] ?? false,
      isAvailable: data['isAvailable'] ?? false,
      completedRides: data['completedRides'] ?? 0,
      performanceScore: (data['performanceScore'] ?? 0.0).toDouble(),
      lastStatusUpdate: (data['lastStatusUpdate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'companyId': companyId,
      'name': name,
      'email': email,
      'phone': phone,
      'isOnline': isOnline,
      'isAvailable': isAvailable,
      'completedRides': completedRides,
      'performanceScore': performanceScore,
      'lastStatusUpdate': Timestamp.fromDate(lastStatusUpdate),
    };
  }
}