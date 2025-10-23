import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  final String driverId;
  final String name;
  final String email;
  final String phone;
  final bool isOnline;
  final bool isAvailable;
  final bool isActive;
  final int completedRides;
  final DateTime? lastStatusUpdate;
  final String? currentVehicle;
  final String? licenseNumber;

  Driver({
    required this.driverId,
    required this.name,
    required this.email,
    required this.phone,
    required this.isOnline,
    required this.isAvailable,
    required this.isActive,
    required this.completedRides,
    this.lastStatusUpdate,
    this.currentVehicle,
    this.licenseNumber,
  });

  factory Driver.fromMap(Map<String, dynamic> data) {
    // دالة مساعدة لتحويل أي قيمة إلى DateTime
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    // دالة مساعدة لتحويل أي قيمة إلى int
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        try {
          return int.parse(value);
        } catch (e) {
          return 0;
        }
      }
      return 0;
    }

    // دالة مساعدة لتحويل أي قيمة إلى bool
    bool parseBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      if (value is int) return value > 0;
      return false;
    }

    return Driver(
      driverId: data['driverId']?.toString() ?? '',
      name: data['name']?.toString() ?? 'سائق غير معروف',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      isOnline: parseBool(data['isOnline']),
      isAvailable: parseBool(data['isAvailable']),
      isActive: parseBool(data['isActive']),
      completedRides: parseInt(data['completedRides']),
      lastStatusUpdate: parseDateTime(data['lastStatusUpdate']),
      currentVehicle: data['currentVehicle']?.toString(),
      licenseNumber: data['licenseNumber']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'name': name,
      'email': email,
      'phone': phone,
      'isOnline': isOnline,
      'isAvailable': isAvailable,
      'isActive': isActive,
      'completedRides': completedRides,
      'lastStatusUpdate': lastStatusUpdate != null
          ? Timestamp.fromDate(lastStatusUpdate!)
          : null,
      'currentVehicle': currentVehicle,
      'licenseNumber': licenseNumber,
    };
  }
}