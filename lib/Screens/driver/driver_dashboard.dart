import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/dispatch_service.dart';
import '../../services/simple_notification_service.dart';
import '../../providers/language_provider.dart';
import '../../locales/app_localizations.dart';
import 'dart:async';

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
  StreamSubscription? _requestsSubscription;

  // 🔥 نظام السيارات
  List<Map<String, dynamic>> _availableVehicles = [];
  bool _loadingVehicles = false;

  // 🔥 مؤقتات للطلبات قيد التنفيذ
  final Map<String, Timer> _activeTimers = {};
  final Map<String, Duration> _rideDurations = {};
  final Map<String, DateTime> _rideStartTimes = {};

  // 🔥 تحكمات لإدخال السيارة يدوياً
  final TextEditingController _manualModelController = TextEditingController();
  final TextEditingController _manualPlateController = TextEditingController();
  final TextEditingController _manualTypeController = TextEditingController(text: 'سيارة');

  String _translate(String key, String languageCode) {
    return AppLocalizations.getTranslatedValue(key, languageCode);
  }

  @override
  void initState() {
    super.initState();
    _checkDriverProfile();
    _loadDriverRequests();
    _startRequestsListener();
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _activeTimers.forEach((key, timer) => timer.cancel());
    _activeTimers.clear();
    _manualModelController.dispose();
    _manualPlateController.dispose();
    _manualTypeController.dispose();
    super.dispose();
  }

  // 🔥 تحميل السيارات المتاحة
  Future<void> _loadAvailableVehicles() async {
    try {
      setState(() {
        _loadingVehicles = true;
      });

      final vehiclesSnapshot = await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('vehicles')
          .where('isAvailable', isEqualTo: true)
          .get();

      setState(() {
        _availableVehicles = vehiclesSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'model': data['model'] ?? 'غير محدد',
            'plateNumber': data['plateNumber'] ?? 'غير محدد',
            'type': data['type'] ?? 'سيارة',
          };
        }).toList();
        _loadingVehicles = false;
      });

      debugPrint('✅ Loaded ${_availableVehicles.length} available vehicles');
    } catch (e) {
      setState(() {
        _loadingVehicles = false;
      });
      debugPrint('❌ Error loading vehicles: $e');
    }
  }

  // 🔥 بدء مؤقت للرحلة
  void _startRideTimer(String requestId, DateTime startTime) {
    _activeTimers[requestId]?.cancel();
    _rideStartTimes[requestId] = startTime;

    _activeTimers[requestId] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          final now = DateTime.now();
          _rideDurations[requestId] = now.difference(startTime);
        });
      }
    });
  }

  // 🔥 إيقاف مؤقت الرحلة
  void _stopRideTimer(String requestId) {
    _activeTimers[requestId]?.cancel();
    _activeTimers.remove(requestId);
    _rideDurations.remove(requestId);
    _rideStartTimes.remove(requestId);
  }

  // 🔥 تنسيق مدة الرحلة لعرضها
  String _formatDuration(Duration duration, String currentLanguage) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return currentLanguage == 'ar'
          ? '$hours ساعة $minutes دقيقة $seconds ثانية'
          : '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return currentLanguage == 'ar'
          ? '$minutes دقيقة $seconds ثانية'
          : '${minutes}m ${seconds}s';
    } else {
      return currentLanguage == 'ar'
          ? '$seconds ثانية'
          : '${seconds}s';
    }
  }

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
          final request = change.doc.data() as Map<String, dynamic>? ?? {};
          final requestId = change.doc.id;
          final assignedDriverId = request['assignedDriverId'] as String?;
          final status = request['status'] as String?;

          if (assignedDriverId == _driverId) {
            _handleRequestNotification(requestId, request, status ?? 'ASSIGNED', change.type);
          }
        }
      }
    });
  }

  void _handleRequestNotification(String requestId, Map<String, dynamic> request, String status, DocumentChangeType changeType) {
    final currentLanguage = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;

    if (changeType == DocumentChangeType.added && status == 'ASSIGNED') {
      SimpleNotificationService.notifyNewRequest(context, requestId);
      _loadDriverRequests();

    } else if (changeType == DocumentChangeType.modified) {
      if (status == 'IN_PROGRESS') {
        final rideStartTime = request['rideStartTime'] != null
            ? (request['rideStartTime'] as Timestamp).toDate()
            : DateTime.now();
        _startRideTimer(requestId, rideStartTime);

        SimpleNotificationService.notifyRideStarted(context, requestId);

      } else if (status == 'COMPLETED') {
        _stopRideTimer(requestId);
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

        const companyId = 'C001';
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

          _loadAvailableVehicles();
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
        const companyId = 'C001';
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
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        setState(() {
          _driverProfileExists = true;
          _driverId = driverId;
          _companyId = companyId;
        });

        _loadAvailableVehicles();

        SimpleNotificationService.notifySuccess(
            context,
            'تم تفعيل حساب السائق بنجاح'
        );

        debugPrint('✅ Driver record created: $driverId');
        _loadDriverRequests();
        _startRequestsListener();
      }
    } catch (e) {
      debugPrint('❌ Error creating driver record: $e');
      SimpleNotificationService.notifyError(
          context,
          'خطأ في تفعيل الحساب: $e'
      );
    }
  }

  // 🔥 عرض اختيار السيارة
  Future<void> _showVehicleSelectionDialog(String requestId, String currentLanguage) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.directions_car, color: Colors.blue),
            const SizedBox(width: 8),
            Text(_translate('select_vehicle', currentLanguage)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _translate('choose_vehicle_for_ride', currentLanguage),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (_loadingVehicles)
              const CircularProgressIndicator()
            else if (_availableVehicles.isEmpty)
              Column(
                children: [
                  const Icon(Icons.car_repair, size: 50, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    _translate('no_vehicles_available', currentLanguage),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            else
              Column(
                children: [
                  ..._availableVehicles.map((vehicle) => ListTile(
                    leading: const Icon(Icons.directions_car, color: Colors.green),
                    title: Text(vehicle['model']),
                    subtitle: Text('${vehicle['plateNumber']} - ${vehicle['type']}'),
                    onTap: () {
                      Navigator.pop(context);
                      _startRideWithVehicle(requestId, vehicle);
                    },
                  )).toList(),
                  const SizedBox(height: 8),
                  const Divider(),
                ],
              ),

            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.add, color: Colors.orange),
              title: Text(_translate('other_vehicle', currentLanguage)),
              onTap: () {
                Navigator.pop(context);
                _showManualVehicleDialog(requestId, currentLanguage);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_translate('cancel', currentLanguage)),
          ),
        ],
      ),
    );
  }

  // 🔥 عرض نافذة إدخال السيارة يدوياً
  Future<void> _showManualVehicleDialog(String requestId, String currentLanguage) async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.directions_car, color: Colors.orange),
                const SizedBox(width: 8),
                Text(_translate('enter_vehicle_info', currentLanguage)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _manualModelController,
                    decoration: InputDecoration(
                      labelText: _translate('vehicle_model', currentLanguage),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.directions_car),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _manualPlateController,
                    decoration: InputDecoration(
                      labelText: _translate('plate_number', currentLanguage),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.confirmation_number),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _manualTypeController,
                    decoration: InputDecoration(
                      labelText: _translate('vehicle_type', currentLanguage),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.category),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _manualModelController.clear();
                  _manualPlateController.clear();
                  _manualTypeController.text = 'سيارة';
                },
                child: Text(_translate('cancel', currentLanguage)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_manualModelController.text.isEmpty || _manualPlateController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_translate('enter_vehicle_info_required', currentLanguage)),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  _startRideWithManualVehicle(requestId);
                },
                child: Text(_translate('start_ride', currentLanguage)),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🔥 بدء الرحلة مع سيارة محددة
  Future<void> _startRideWithVehicle(String requestId, Map<String, dynamic> vehicle) async {
    try {
      final startTime = DateTime.now();

      await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('requests')
          .doc(requestId)
          .update({
        'status': 'IN_PROGRESS',
        'rideStartTime': FieldValue.serverTimestamp(),
        'vehicleInfo': {
          'vehicleId': vehicle['id'],
          'model': vehicle['model'],
          'plateNumber': vehicle['plateNumber'],
          'type': vehicle['type'],
          'source': 'fleet',
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('vehicles')
          .doc(vehicle['id'])
          .update({
        'isAvailable': false,
        'currentRequestId': requestId,
      });

      _startRideTimer(requestId, startTime);
      SimpleNotificationService.notifyRideStarted(context, requestId);

      debugPrint('🚗 Ride started: $requestId with vehicle: ${vehicle['plateNumber']}');
      _loadDriverRequests();
      _loadAvailableVehicles();
    } catch (e) {
      debugPrint('❌ Error starting ride: $e');
      SimpleNotificationService.notifyError(
          context,
          'خطأ في بدء الرحلة: $e'
      );
    }
  }

  // 🔥 بدء الرحلة مع سيارة يدوية
  Future<void> _startRideWithManualVehicle(String requestId) async {
    try {
      final startTime = DateTime.now();

      await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('requests')
          .doc(requestId)
          .update({
        'status': 'IN_PROGRESS',
        'rideStartTime': FieldValue.serverTimestamp(),
        'vehicleInfo': {
          'vehicleId': 'manual_${DateTime.now().millisecondsSinceEpoch}',
          'model': _manualModelController.text,
          'plateNumber': _manualPlateController.text,
          'type': _manualTypeController.text,
          'source': 'manual',
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      _startRideTimer(requestId, startTime);
      SimpleNotificationService.notifyRideStarted(context, requestId);

      _manualModelController.clear();
      _manualPlateController.clear();
      _manualTypeController.text = 'سيارة';

      debugPrint('🚗 Ride started: $requestId with manual vehicle');
      _loadDriverRequests();
    } catch (e) {
      debugPrint('❌ Error starting ride with manual vehicle: $e');
      SimpleNotificationService.notifyError(
          context,
          'خطأ في بدء الرحلة: $e'
      );
    }
  }

  // 🔥 بدء الرحلة (الدالة الرئيسية)
  Future<void> _startRide(String requestId) async {
    final currentLanguage = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
    await _showVehicleSelectionDialog(requestId, currentLanguage);
  }

  Future<void> _loadDriverRequests() async {
    try {
      setState(() {
        _loading = true;
        _requests = [];
      });

      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _loading = false;
        });
        return;
      }

      const companyId = 'C001';
      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('drivers')
          .where('email', isEqualTo: user.email)
          .get();

      if (driversSnapshot.docs.isNotEmpty) {
        final driverDoc = driversSnapshot.docs.first;
        final driverId = driverDoc.id;

        _driverId = driverId;
        _companyId = companyId;

        final requestsSnapshot = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('requests')
            .where('assignedDriverId', isEqualTo: driverId)
            .where('status', whereIn: ['ASSIGNED', 'IN_PROGRESS', 'COMPLETED'])
            .orderBy('createdAt', descending: true)
            .get();

        for (var doc in requestsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          if (data['status'] == 'IN_PROGRESS' && data['rideStartTime'] != null) {
            final startTime = (data['rideStartTime'] as Timestamp).toDate();
            _startRideTimer(doc.id, startTime);
          }
        }

        setState(() {
          _requests = requestsSnapshot.docs;
          _loading = false;
        });

        debugPrint('✅ Assigned requests count: ${_requests.length}');
      } else {
        setState(() {
          _loading = false;
          _requests = [];
        });
        debugPrint('❌ Driver data not found in company C001');
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _requests = [];
      });
      debugPrint('❌ Error loading requests: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الطلبات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeRide(String requestId) async {
    try {
      _stopRideTimer(requestId);

      final endTime = DateTime.now();
      final startTime = _rideStartTimes[requestId];
      final totalDuration = startTime != null ? endTime.difference(startTime) : Duration.zero;

      final requestDoc = await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('requests')
          .doc(requestId)
          .get();

      final requestData = requestDoc.data() as Map<String, dynamic>? ?? {};
      final vehicleInfo = requestData['vehicleInfo'] as Map<String, dynamic>?;
      final vehicleId = vehicleInfo?['vehicleId'] as String?;
      final source = vehicleInfo?['source'] as String?;

      await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('requests')
          .doc(requestId)
          .update({
        'status': 'COMPLETED',
        'rideEndTime': FieldValue.serverTimestamp(),
        'rideDuration': totalDuration.inSeconds,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (source == 'fleet' && vehicleId != null && !vehicleId.startsWith('manual_')) {
        await _firestore
            .collection('companies')
            .doc(_companyId)
            .collection('vehicles')
            .doc(vehicleId)
            .update({
          'isAvailable': true,
          'currentRequestId': null,
        });
      }

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

      SimpleNotificationService.notifyRideCompleted(context, requestId);

      debugPrint('✅ Ride completed: $requestId - Duration: ${totalDuration.inMinutes} minutes');
      _loadDriverRequests();
      _loadAvailableVehicles();
    } catch (e) {
      debugPrint('❌ Error completing ride: $e');
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

      SimpleNotificationService.notifySuccess(
          context,
          'تم تسجيل الخروج بنجاح'
      );

      Navigator.pushReplacementNamed(context, '/login');

    } catch (e) {
      debugPrint('❌ Error logging out: $e');
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
            const Icon(Icons.person, color: Colors.orange),
            const SizedBox(width: 8),
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
                  _requests.where((r) {
                    final data = r.data() as Map<String, dynamic>? ?? {};
                    return data['status'] == 'COMPLETED';
                  }).length.toString()),
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
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
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
              const Icon(Icons.inventory_2, color: Colors.orange),
              const SizedBox(width: 8),
              Text(_translate('no_requests', currentLanguage)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_translate('no_assigned_requests', currentLanguage)),
              const SizedBox(height: 16),
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
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.list_alt, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      '${_translate('total_requests', currentLanguage)}: ${_requests.length}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _requests.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox_outlined, size: 60, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(_translate('no_requests', currentLanguage), style: const TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    final data = request.data() as Map<String, dynamic>? ?? {};
                    return _buildRequestCard(request.id, data, currentLanguage);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(_translate('close', currentLanguage)),
                    ),
                  ),
                  const SizedBox(width: 12),
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

  Widget _buildActionButtons(String requestId, String status, String currentLanguage) {
    if (status == 'ASSIGNED') {
      return ElevatedButton(
        onPressed: () => _startRide(requestId),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: const Size(0, 30),
        ),
        child: Text(
          _translate('start_ride', currentLanguage),
          style: const TextStyle(fontSize: 12),
        ),
      );
    } else if (status == 'IN_PROGRESS') {
      return ElevatedButton(
        onPressed: () => _completeRide(requestId),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: const Size(0, 30),
        ),
        child: Text(
          _translate('complete_ride', currentLanguage),
          style: const TextStyle(fontSize: 12),
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
        child: const Icon(Icons.check, size: 16, color: Colors.green),
      );
    }
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
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87, fontSize: 12),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 الدوال المفقودة - أضفها هنا
  String _getSafeString(Map<String, dynamic> data, String key, String defaultValue) {
    try {
      final value = data[key];
      if (value is String) return value;
      if (value != null) return value.toString();
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  String _getRequesterName(Map<String, dynamic> data, String currentLanguage) {
    final names = [
      data['requesterName'],
      data['userName'],
      data['employeeName'],
      widget.userName
    ];

    for (final name in names) {
      if (name is String && name.isNotEmpty) return name;
    }

    return _translate('not_specified', currentLanguage);
  }

  String _getRequesterDepartment(Map<String, dynamic> data, String currentLanguage) {
    final departments = [
      data['department'],
      data['requesterDepartment'],
      data['employeeDepartment']
    ];

    for (final dept in departments) {
      if (dept is String && dept.isNotEmpty) return dept;
    }

    return _translate('not_specified', currentLanguage);
  }

  Widget _buildErrorCard(String errorMessage, String currentLanguage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
        ],
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

  // 🔥 دالة البناء الرئيسية - أضفها هنا
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (languageProvider == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جاري التحميل...'),
                ],
              ),
            ),
          );
        }

        final currentLanguage = languageProvider.currentLanguage;

        return Scaffold(
          appBar: AppBar(
            title: Text(_translate('driver_dashboard', currentLanguage)),
            backgroundColor: Colors.orange,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
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
                        const Icon(Icons.person, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(_translate('profile', currentLanguage)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(_translate('logout', currentLanguage)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: _buildBody(currentLanguage),
        );
      },
    );
  }

  Widget _buildBody(String currentLanguage) {
    return Column(
      children: [
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
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.orange,
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                '${_translate('welcome', currentLanguage)} ${widget.userName}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
              ),
              const SizedBox(height: 8),
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

        Expanded(
          child: _buildRequestsList(currentLanguage),
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
                      const Icon(Icons.list_alt),
                      const SizedBox(width: 8),
                      Text(_translate('show_my_requests', currentLanguage), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsList(String currentLanguage) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              _translate('no_requests_currently', currentLanguage),
              style: const TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _translate('requests_will_appear_here_when_assigned', currentLanguage),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        try {
          final request = _requests[index];
          if (!request.exists) {
            return _buildErrorCard('طلب غير موجود', currentLanguage);
          }

          final data = request.data() as Map<String, dynamic>? ?? {};
          return _buildRequestCard(request.id, data, currentLanguage);
        } catch (e) {
          return _buildErrorCard('خطأ في عرض الطلب: $e', currentLanguage);
        }
      },
    );
  }

  Widget _buildRequestCard(String requestId, Map<String, dynamic> data, String currentLanguage) {
    try {
      final status = _getSafeString(data, 'status', 'ASSIGNED');
      final requesterName = _getRequesterName(data, currentLanguage);
      final requesterDepartment = _getRequesterDepartment(data, currentLanguage);
      final fromLocation = _getSafeString(data, 'fromLocation', '');
      final toLocation = _getSafeString(data, 'toLocation', '');
      final priority = _getSafeString(data, 'priority', 'Normal');
      final description = _getSafeString(data, 'details', _getSafeString(data, 'description', ''));
      final vehicleInfo = data['vehicleInfo'] as Map<String, dynamic>?;

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

              const SizedBox(height: 8),

              // 🔥 معلومات السيارة
              if (vehicleInfo != null && status != 'ASSIGNED')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.directions_car, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${vehicleInfo['model']} - ${vehicleInfo['plateNumber']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                      if (vehicleInfo['source'] == 'manual')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _translate('manual', currentLanguage),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              // 🔥 عداد الوقت للرحلة قيد التنفيذ
              if (status == 'IN_PROGRESS' && _rideDurations.containsKey(requestId))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Text(
                        _translate('ride_duration', currentLanguage),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDuration(_rideDurations[requestId]!, currentLanguage),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // Requester Information
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      requesterName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Department Information
              Row(
                children: [
                  Icon(Icons.business, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
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

              const SizedBox(height: 8),

              // Locations
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
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

              const SizedBox(height: 8),

              // Description
              if (description.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.description, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
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
                const SizedBox(height: 8),
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
    } catch (e) {
      return _buildErrorCard('خطأ في عرض الطلب: $e', currentLanguage);
    }
  }
}