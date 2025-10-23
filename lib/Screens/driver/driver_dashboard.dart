import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/dispatch_service.dart';
import '../../services/simple_notification_service.dart'; // 🔥 استيراد خدمة الإشعارات
import '../../providers/language_provider.dart';
import '../../locales/app_localizations.dart';
import 'dart:async'; //

class DriverDashboard extends StatefulWidget {
  final String userName;

  const DriverDashboard({super.key, required this.userName});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<QueryDocumentSnapshot> _requests = [];
  bool _loading = true;
  String? _driverId;
  String? _companyId;
  bool _driverProfileExists = false;
  StreamSubscription? _requestsSubscription; // 🔥 للاستماع للطلبات الجديدة

  String _translate(String key, String languageCode) {
    return AppLocalizations.getTranslatedValue(key, languageCode);
  }

  @override
  void initState() {
    super.initState();
    _checkDriverProfile();
    _loadDriverRequests();
    _startRequestsListener(); // 🔥 بدء الاستماع للطلبات الجديدة
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel(); // 🔥 تنظيف الـ subscription
    super.dispose();
  }

  // 🔥 الاستماع للطلبات الجديدة المخصصة للسائق
  void _startRequestsListener() {
    _requestsSubscription = _firestore
        .collection('companies')
        .doc('C001')
        .collection('requests')
        .where('status', whereIn: ['ASSIGNED', 'IN_PROGRESS'])
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final request = change.doc.data() as Map<String, dynamic>;
          final requestId = change.doc.id;
          final assignedDriverId = request['assignedDriverId'];
          final status = request['status'];

          // إذا كان الطلب مخصص لهذا السائق
          if (assignedDriverId == _driverId) {
            _handleRequestNotification(requestId, request, status, change.type);
          }
        }
      }
    });
  }

  // 🔥 معالجة إشعارات الطلبات
  void _handleRequestNotification(String requestId, Map<String, dynamic> request, String status, DocumentChangeType changeType) {
    final currentLanguage = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;

    if (changeType == DocumentChangeType.added && status == 'ASSIGNED') {
      // 🔥 إشعار طلب جديد
      SimpleNotificationService.notifyNewRequest(context, requestId);

      // تحديث القائمة تلقائياً
      _loadDriverRequests();

    } else if (changeType == DocumentChangeType.modified) {
      if (status == 'IN_PROGRESS') {
        // 🔥 إشعار بدء الرحلة (يمكن إضافته إذا كان هناك تحديث من النظام)
        // SimpleNotificationService.notifyRideStarted(context, requestId);
      } else if (status == 'COMPLETED') {
        // 🔥 إشعار انتهاء الرحلة
        SimpleNotificationService.notifyRideCompleted(context, requestId);
        _loadDriverRequests();
      }
    }
  }

  Future<void> _checkDriverProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        debugPrint('👤 Checking driver existence...');

        final companyId = 'C001';
        final driversSnapshot = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('drivers')
            .where('email', isEqualTo: user.email)
            .get();

        if (driversSnapshot.docs.isNotEmpty) {
          final driverDoc = driversSnapshot.docs.first;
          _driverId = driverDoc.id;
          _companyId = companyId;
          _driverProfileExists = true;

          debugPrint('✅ Driver found: $_driverId');
        } else {
          setState(() {
            _driverProfileExists = false;
          });
          debugPrint('❌ No driver record found - needs activation');
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking driver: $e');
    }
  }

  Future<void> _createDriverProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final companyId = 'C001';
        final driverId = 'driver_${user.uid.substring(0, 8)}';

        await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('drivers')
            .doc(driverId)
            .set({
          'driverId': driverId,
          'name': widget.userName,
          'email': user.email,
          'phone': user.phoneNumber ?? '+966000000000',
          'isOnline': true,
          'isAvailable': true,
          'isActive': true,
          'completedRides': 0,
          'vehicleInfo': {
            'type': 'سيارة',
            'model': '2024',
            'plate': 'غير محدد'
          },
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        setState(() {
          _driverProfileExists = true;
          _driverId = driverId;
          _companyId = companyId;
        });

        // 🔥 إشعار نجاح التفعيل
        SimpleNotificationService.notifySuccess(
            context,
            'تم تفعيل حساب السائق بنجاح'
        );

        debugPrint('✅ Driver record created: $driverId');
        _loadDriverRequests();

        // 🔥 إعادة تشغيل الـ listener بعد إنشاء البروفايل
        _startRequestsListener();
      }
    } catch (e) {
      debugPrint('❌ Error creating driver record: $e');
      // 🔥 إشعار خطأ
      SimpleNotificationService.notifyError(
          context,
          'خطأ في تفعيل الحساب: $e'
      );
    }
  }

  Future<void> _loadDriverRequests() async {
    try {
      setState(() { _loading = true; });

      final user = _auth.currentUser;
      if (user != null) {
        debugPrint('👤 Current user: ${user.email}');

        final companyId = 'C001';
        final driversSnapshot = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('drivers')
            .where('email', isEqualTo: user.email)
            .get();

        debugPrint('🔍 Matching drivers count: ${driversSnapshot.docs.length}');

        if (driversSnapshot.docs.isNotEmpty) {
          final driverDoc = driversSnapshot.docs.first;
          final driverId = driverDoc.id;
          final driverData = driverDoc.data();

          _driverId = driverId;
          _companyId = companyId;

          debugPrint('🎯 Driver found: $driverId');
          debugPrint('📋 Driver data: ${driverData['name']} - ${driverData['email']}');

          final requestsSnapshot = await _firestore
              .collection('companies')
              .doc(companyId)
              .collection('requests')
              .where('assignedDriverId', isEqualTo: driverId)
              .where('status', whereIn: ['ASSIGNED', 'IN_PROGRESS', 'COMPLETED'])
              .orderBy('createdAt', descending: true)
              .get();

          setState(() {
            _requests = requestsSnapshot.docs;
            _loading = false;
          });

          debugPrint('✅ Assigned requests count: ${_requests.length}');
        } else {
          setState(() { _loading = false; });
          debugPrint('❌ Driver data not found in company C001');
        }
      }
    } catch (e) {
      setState(() { _loading = false; });
      debugPrint('❌ Error loading requests: $e');
      // 🔥 إشعار خطأ في تحميل الطلبات
      SimpleNotificationService.notifyError(
          context,
          'خطأ في تحميل الطلبات: $e'
      );
    }
  }

  Future<void> _startRide(String requestId) async {
    try {
      await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('requests')
          .doc(requestId)
          .update({
        'status': 'IN_PROGRESS',
        'rideStartTime': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // 🔥 إشعار بدء الرحلة
      SimpleNotificationService.notifyRideStarted(context, requestId);

      debugPrint('🚗 Ride started: $requestId');
      _loadDriverRequests();
    } catch (e) {
      debugPrint('❌ Error starting ride: $e');
      // 🔥 إشعار خطأ في بدء الرحلة
      SimpleNotificationService.notifyError(
          context,
          'خطأ في بدء الرحلة: $e'
      );
    }
  }

  Future<void> _completeRide(String requestId) async {
    try {
      await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('requests')
          .doc(requestId)
          .update({
        'status': 'COMPLETED',
        'rideEndTime': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('drivers')
          .doc(_driverId)
          .update({
        'isAvailable': true,
        'completedRides': FieldValue.increment(1),
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });

      // 🔥 إشعار انتهاء الرحلة
      SimpleNotificationService.notifyRideCompleted(context, requestId);

      debugPrint('✅ Ride completed: $requestId');
      _loadDriverRequests();
    } catch (e) {
      debugPrint('❌ Error completing ride: $e');
      // 🔥 إشعار خطأ في إنهاء الرحلة
      SimpleNotificationService.notifyError(
          context,
          'خطأ في إنهاء الرحلة: $e'
      );
    }
  }

  Future<void> _logout() async {
    try {
      if (_driverId != null && _companyId != null) {
        await _firestore
            .collection('companies')
            .doc(_companyId)
            .collection('drivers')
            .doc(_driverId)
            .update({
          'isOnline': false,
          'lastStatusUpdate': FieldValue.serverTimestamp(),
        });
      }

      await _auth.signOut();

      // 🔥 إشعار تسجيل الخروج
      SimpleNotificationService.notifySuccess(
          context,
          'تم تسجيل الخروج بنجاح'
      );

      Navigator.pushReplacementNamed(context, '/login');

    } catch (e) {
      debugPrint('❌ Error logging out: $e');
      // 🔥 إشعار خطأ في تسجيل الخروج
      SimpleNotificationService.notifyError(
          context,
          'خطأ في تسجيل الخروج: $e'
      );
    }
  }

  void _showProfile(BuildContext context, String currentLanguage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person, color: Colors.orange),
            SizedBox(width: 8),
            Text(_translate('profile', currentLanguage)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileRow('${_translate('name', currentLanguage)}:', widget.userName),
            _buildProfileRow('${_translate('email', currentLanguage)}:', _auth.currentUser?.email ?? ''),
            _buildProfileRow('${_translate('driver_id', currentLanguage)}:', _driverId ?? _translate('not_specified', currentLanguage)),
            _buildProfileRow('${_translate('status', currentLanguage)}:', _translate('driver_linked_to_hr', currentLanguage)),
            if (_driverProfileExists)
              _buildProfileRow('${_translate('completed_rides', currentLanguage)}:',
                  _requests.where((r) => r['status'] == 'COMPLETED').length.toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_translate('ok', currentLanguage)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text('$label ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showMyRequests(BuildContext context, String currentLanguage) {
    if (_requests.isEmpty) {
      _showNoRequestsDialog(context, currentLanguage);
    } else {
      _showRequestsBottomSheet(context, currentLanguage);
    }
  }

  void _showNoRequestsDialog(BuildContext context, String currentLanguage) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.inventory_2, color: Colors.orange),
              SizedBox(width: 8),
              Text(_translate('no_requests', currentLanguage)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_translate('no_assigned_requests', currentLanguage)),
              SizedBox(height: 16),
              if (!_driverProfileExists)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _createDriverProfile();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_translate('activate_driver_account', currentLanguage)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_translate('ok', currentLanguage)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequestCard(String requestId, Map<String, dynamic> data, String currentLanguage) {
    final status = data['status'] ?? 'ASSIGNED';

    // الحصول على بيانات طالب الخدمة (الموظف)
    final requesterName = data['requesterName'] ??
        data['userName'] ??
        data['employeeName'] ??
        _translate('not_specified', currentLanguage);

    // قسم طالب الخدمة (الموظف)
    final requesterDepartment = data['department'] ??
        data['requesterDepartment'] ??
        data['employeeDepartment'] ??
        _translate('not_specified', currentLanguage);

    final fromLocation = _translateLocation(data['fromLocation'] ?? '', currentLanguage);
    final toLocation = _translateLocation(data['toLocation'] ?? '', currentLanguage);
    final priority = _translatePriority(data['priority'] ?? 'Normal', currentLanguage);

    // الحصول على تفاصيل إضافية
    final description = data['details'] ?? data['description'] ?? '';
    final phoneNumber = data['phoneNumber'] ?? data['requesterPhone'] ?? '';

    Color statusColor = Colors.orange;
    String statusText = _translate('assigned', currentLanguage);

    if (status == 'IN_PROGRESS') {
      statusColor = Colors.blue;
      statusText = _translate('in_progress', currentLanguage);
    } else if (status == 'COMPLETED') {
      statusColor = Colors.green;
      statusText = _translate('completed', currentLanguage);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with request number and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_translate('request', currentLanguage)} #${requestId.length > 6 ? requestId.substring(0, 6) : requestId}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange.shade800),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 8),

            // Requester Information
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    requesterName,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),

            SizedBox(height: 4),

            // Department Information
            Row(
              children: [
                Icon(Icons.business, size: 16, color: Colors.grey.shade600),
                SizedBox(width: 6),
                Text(
                  '${_translate('department', currentLanguage)}: ',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                ),
                Text(
                  requesterDepartment,
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                ),
              ],
            ),

            SizedBox(height: 8),

            // Locations
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place, size: 16, color: Colors.grey.shade600),
                SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_translate('from', currentLanguage)}: $fromLocation'),
                      Text('${_translate('to', currentLanguage)}: $toLocation'),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 8),

            // Description
            if (description.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.description, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      description,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
            ],

            // Priority and Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priority == 'Urgent' ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: priority == 'Urgent' ? Colors.red.shade300 : Colors.green.shade300,
                    ),
                  ),
                  child: Text(
                    priority,
                    style: TextStyle(
                      fontSize: 12,
                      color: priority == 'Urgent' ? Colors.red.shade800 : Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildActionButtons(requestId, status, currentLanguage),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _translateLocation(String location, String language) {
    final locationTranslations = {
      'المصنع': {
        'en': 'Factory',
        'ar': 'المصنع',
      },
      'Takhasusi': {
        'en': 'Takhasusi',
        'ar': 'التخصصي',
      },
      'Factory': {
        'en': 'Factory',
        'ar': 'المصنع',
      },
      'الدرس العزيزية': {
        'en': 'Al-Dars Al-Aziziya',
        'ar': 'الدرس العزيزية',
      },
    };

    return locationTranslations[location]?[language] ?? location;
  }

  String _translatePriority(String priority, String language) {
    final priorityTranslations = {
      'Normal': {
        'en': 'Normal',
        'ar': 'عادي',
      },
      'Urgent': {
        'en': 'Urgent',
        'ar': 'عاجل',
      },
    };

    return priorityTranslations[priority]?[language] ?? priority;
  }

  Widget _buildActionButtons(String requestId, String status, String currentLanguage) {
    if (status == 'ASSIGNED') {
      return ElevatedButton(
        onPressed: () => _startRide(requestId),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: Size(0, 30),
        ),
        child: Text(
          _translate('start_ride', currentLanguage),
          style: TextStyle(fontSize: 12),
        ),
      );
    } else if (status == 'IN_PROGRESS') {
      return ElevatedButton(
        onPressed: () => _completeRide(requestId),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: Size(0, 30),
        ),
        child: Text(
          _translate('complete_ride', currentLanguage),
          style: TextStyle(fontSize: 12),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.green),
        ),
        child: Icon(Icons.check, size: 16, color: Colors.green),
      );
    }
  }

  void _showRequestDetails(String requestId, Map<String, dynamic> data, String currentLanguage) {
    final status = data['status'] ?? 'ASSIGNED';

    // الحصول على جميع بيانات طالب الخدمة (الموظف)
    final requesterName = data['requesterName'] ??
        data['userName'] ??
        data['employeeName'] ??
        _translate('not_specified', currentLanguage);

    // قسم طالب الخدمة (الموظف)
    final requesterDepartment = data['department'] ??
        data['requesterDepartment'] ??
        data['employeeDepartment'] ??
        _translate('not_specified', currentLanguage);

    final fromLocation = _translateLocation(data['fromLocation'] ?? '', currentLanguage);
    final toLocation = _translateLocation(data['toLocation'] ?? '', currentLanguage);
    final priority = _translatePriority(data['priority'] ?? 'Normal', currentLanguage);

    final description = data['details'] ?? data['description'] ?? _translate('no_description', currentLanguage);
    final phoneNumber = data['phoneNumber'] ?? data['requesterPhone'] ?? _translate('not_specified', currentLanguage);
    final address = data['address'] ?? data['locationDetails'] ?? _translate('not_specified', currentLanguage);

    String statusText = _translate('assigned', currentLanguage);
    Color statusColor = Colors.orange;

    if (status == 'IN_PROGRESS') {
      statusText = _translate('in_progress', currentLanguage);
      statusColor = Colors.blue;
    } else if (status == 'COMPLETED') {
      statusText = _translate('completed', currentLanguage);
      statusColor = Colors.green;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: statusColor),
              SizedBox(width: 8),
              Text(_translate('request_details', currentLanguage)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Request Information
                _buildDetailRow('${_translate('request_number', currentLanguage)}:', requestId),

                SizedBox(height: 12),

                // Requester Information Section
                Text(
                  _translate('requester_info', currentLanguage),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade800),
                ),
                SizedBox(height: 8),
                _buildDetailRow('${_translate('requester_name', currentLanguage)}:', requesterName),
                _buildDetailRow('${_translate('department', currentLanguage)}:', requesterDepartment),
                _buildDetailRow('${_translate('phone_number', currentLanguage)}:', phoneNumber),

                SizedBox(height: 12),

                // Trip Information Section
                Text(
                  _translate('trip_info', currentLanguage),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade800),
                ),
                SizedBox(height: 8),
                _buildDetailRow('${_translate('from', currentLanguage)}:', fromLocation),
                _buildDetailRow('${_translate('to', currentLanguage)}:', toLocation),
                _buildDetailRow('${_translate('address', currentLanguage)}:', address),

                SizedBox(height: 12),

                // Additional Information Section
                Text(
                  _translate('additional_info', currentLanguage),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade800),
                ),
                SizedBox(height: 8),
                _buildDetailRow('${_translate('description', currentLanguage)}:', description),
                _buildDetailRow('${_translate('status', currentLanguage)}:', statusText),
                _buildDetailRow('${_translate('priority', currentLanguage)}:', priority),
                SizedBox(height: 16),

                // Action Button
                if (status == 'ASSIGNED')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _startRide(requestId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(_translate('start_ride', currentLanguage)),
                    ),
                  )
                else if (status == 'IN_PROGRESS')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _completeRide(requestId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(_translate('complete_ride', currentLanguage)),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_translate('close', currentLanguage)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 12),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.black87, fontSize: 12),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestsBottomSheet(BuildContext context, String currentLanguage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _translate('my_requests', currentLanguage),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list_alt, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      '${_translate('total_requests', currentLanguage)}: ${_requests.length}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: _requests.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(_translate('no_requests', currentLanguage), style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    final data = request.data() as Map<String, dynamic>;
                    return _buildRequestCard(request.id, data, currentLanguage);
                  },
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(_translate('close', currentLanguage)),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loadDriverRequests,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: Text(_translate('refresh', currentLanguage)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final currentLanguage = languageProvider.currentLanguage;

        return Scaffold(
          appBar: AppBar(
            title: Text(_translate('driver_dashboard', currentLanguage)),
            backgroundColor: Colors.orange,
            actions: [
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _loadDriverRequests,
                tooltip: _translate('refresh_requests', currentLanguage),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'logout') {
                    _logout();
                  } else if (value == 'profile') {
                    _showProfile(context, currentLanguage);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(_translate('profile', currentLanguage)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 8),
                        Text(_translate('logout', currentLanguage)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Welcome Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.orange.shade50, Colors.orange.shade100],
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '${_translate('welcome', currentLanguage)} ${widget.userName}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _driverProfileExists
                          ? _translate('account_active_ready', currentLanguage)
                          : _translate('activate_account_to_start', currentLanguage),
                      style: TextStyle(
                          fontSize: 16,
                          color: _driverProfileExists ? Colors.green : Colors.orange
                      ),
                    ),
                  ],
                ),
              ),

              if (!_driverProfileExists)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _createDriverProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                    ),
                    child: Text(
                      _translate('activate_driver_account', currentLanguage),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: Colors.orange))
                    : _requests.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 20),
                      Text(
                        _translate('no_requests_currently', currentLanguage),
                        style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _translate('requests_will_appear_here_when_assigned', currentLanguage),
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    final data = request.data() as Map<String, dynamic>;
                    return _buildRequestCard(request.id, data, currentLanguage);
                  },
                ),
              ),

              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showMyRequests(context, currentLanguage),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 55),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.list_alt),
                            SizedBox(width: 8),
                            Text(_translate('show_my_requests', currentLanguage), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}