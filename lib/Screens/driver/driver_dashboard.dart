import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/simple_notification_service.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

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

  // 🔥 Location tracking variables
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isLocationServiceEnabled = true;

  // 🔥 Vehicles system
  List<Map<String, dynamic>> _availableVehicles = [];
  bool _loadingVehicles = false;

  // 🔥 Ride timers
  final Map<String, Timer> _activeTimers = {};
  final Map<String, Duration> _rideDurations = {};
  final Map<String, DateTime> _rideStartTimes = {};

  // 🔥 New overall statistics
  int _totalCompletedRides = 0;
  int _totalAssignedRides = 0;
  bool _loadingStatistics = false;

  // 🔥 Traffic news - NOW DYNAMIC
  List<Map<String, dynamic>> _trafficNews = [];
  bool _loadingNews = false;
  StreamSubscription? _trafficNewsSubscription;

  // 🔥 Manual vehicle input controllers
  final TextEditingController _manualModelController = TextEditingController();
  final TextEditingController _manualPlateController = TextEditingController();
  final TextEditingController _manualTypeController = TextEditingController(text: 'Car');

  @override
  void initState() {
    super.initState();
    _checkDriverProfile();
    _loadDriverRequests();
    _startRequestsListener();
    _startTrafficNewsListener();
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    _trafficNewsSubscription?.cancel();
    _activeTimers.forEach((key, timer) => timer.cancel());
    _activeTimers.clear();
    _manualModelController.dispose();
    _manualPlateController.dispose();
    _manualTypeController.dispose();
    super.dispose();
  }

  // ===================================================================
  // 🔥 DYNAMIC Traffic news functions - FROM FIRESTORE
  // ===================================================================

  void _startTrafficNewsListener() {
    _trafficNewsSubscription = _firestore
        .collection('trafficNews')
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _trafficNews = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            return {
              'id': doc.id,
              'title': data['title'] ?? 'Traffic Update',
              'description': data['description'] ?? 'No details available',
              'timestamp': data['timestamp'],
              'priority': data['priority'] ?? 'normal',
              'region': data['region'] ?? 'General',
            };
          }).toList();
          _loadingNews = false;
        });
      }
    }, onError: (error) {
      debugPrint('❌ Error listening to traffic news: $error');
      _loadMockTrafficNews();
    });
  }

  void _loadMockTrafficNews() {
    setState(() {
      _trafficNews = [
        {
          'id': '1',
          'title': 'Heavy Traffic Alert',
          'description': 'Heavy congestion on King Fahd Road heading North. Expect delays.',
          'timestamp': Timestamp.now(),
          'priority': 'high',
          'region': 'Riyadh'
        },
        {
          'id': '2',
          'title': 'Weather Warning',
          'description': 'Heavy rain expected in central regions. Drive carefully.',
          'timestamp': Timestamp.now(),
          'priority': 'medium',
          'region': 'Central'
        },
        {
          'id': '3',
          'title': 'Road Closure',
          'description': 'Temporary closure on Exit 12 for maintenance until 6 PM.',
          'timestamp': Timestamp.now(),
          'priority': 'high',
          'region': 'Riyadh'
        },
        {
          'id': '4',
          'title': 'Accident Reported',
          'description': 'Minor accident on Northern Ring Road. Use alternative routes.',
          'timestamp': Timestamp.now(),
          'priority': 'medium',
          'region': 'Riyadh'
        },
      ];
      _loadingNews = false;
    });
  }

  String _getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final time = timestamp.toDate();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    return '${difference.inDays} days ago';
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.info;
      case 'low':
        return Icons.traffic;
      default:
        return Icons.traffic;
    }
  }

  // ===================================================================
  // 🔥 Location tracking functions
  // ===================================================================

  Future<void> _checkLocationPermissionsAndStart() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLocationServiceEnabled = false);
      return;
    }
    setState(() => _isLocationServiceEnabled = true);

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      _startLocationUpdates();
    }
  }

  void _startLocationUpdates() {
    if (_driverId == null || _companyId == null) return;

    _positionStreamSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
        debugPrint('🌍 Location Updated: ${position.latitude}, ${position.longitude}');
        _updateDriverLocationInFirestore(position);
      },
      onError: (e) {
        debugPrint('❌ Location Stream Error: $e');
      },
    );
  }

  Future<void> _updateDriverLocationInFirestore(Position position) async {
    if (_driverId == null || _companyId == null) return;

    try {
      await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('drivers')
          .doc(_driverId)
          .update({
        'location': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error updating driver location: $e');
    }
  }

  // ===================================================================
  // 🔥 Overall statistics functions
  // ===================================================================

  Future<void> _loadTotalStatistics() async {
    if (_companyId == null || _driverId == null) return;

    try {
      setState(() {
        _loadingStatistics = true;
      });

      final completedSnapshot = await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('requests')
          .where('assignedDriverId', isEqualTo: _driverId)
          .where('status', isEqualTo: 'COMPLETED')
          .get();

      final assignedSnapshot = await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('requests')
          .where('assignedDriverId', isEqualTo: _driverId)
          .where('status', whereIn: ['ASSIGNED', 'IN_PROGRESS', 'COMPLETED'])
          .get();

      setState(() {
        _totalCompletedRides = completedSnapshot.docs.length;
        _totalAssignedRides = assignedSnapshot.docs.length;
        _loadingStatistics = false;
      });

      debugPrint('✅ Total Statistics - Completed: $_totalCompletedRides, Assigned: $_totalAssignedRides');
    } catch (e) {
      setState(() {
        _loadingStatistics = false;
      });
      debugPrint('❌ Error loading total statistics: $e');
    }
  }

  // ===================================================================
  // 🔥 Other functions
  // ===================================================================

  Future<void> _loadAvailableVehicles() async {
    if (_companyId == null) return;
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
          final data = doc.data() as Map<String, dynamic>? ?? {};
          return {
            'id': doc.id,
            'model': data['model'] ?? 'Not specified',
            'plateNumber': data['plateNumber'] ?? 'Not specified',
            'type': data['type'] ?? 'Car',
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

  void _stopRideTimer(String requestId) {
    _activeTimers[requestId]?.cancel();
    _activeTimers.remove(requestId);
    _rideDurations.remove(requestId);
    _rideStartTimes.remove(requestId);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
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
    if (changeType == DocumentChangeType.added && status == 'ASSIGNED') {
      SimpleNotificationService.notifyNewRequest(context, requestId);
      _loadDriverRequests();
      _loadTotalStatistics();
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
        _loadTotalStatistics();
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
          _loadTotalStatistics();

          _checkLocationPermissionsAndStart();

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
        _loadTotalStatistics();

        SimpleNotificationService.notifySuccess(context, 'Driver account activated successfully');

        debugPrint('✅ Driver record created: $driverId');
        _loadDriverRequests();
        _startRequestsListener();

        _checkLocationPermissionsAndStart();
      }
    } catch (e) {
      debugPrint('❌ Error creating driver record: $e');
      SimpleNotificationService.notifyError(context, 'Error activating account: $e');
    }
  }

  Future<void> _showVehicleSelectionDialog(String requestId) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.directions_car, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Select Vehicle'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose vehicle for the ride',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_loadingVehicles)
              const CircularProgressIndicator()
            else if (_availableVehicles.isEmpty)
              Column(
                children: [
                  const Icon(Icons.car_repair, size: 50, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text(
                    'No available vehicles',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            else
              Column(
                children: [
                  ..._availableVehicles
                      .map((vehicle) => ListTile(
                    leading: const Icon(Icons.directions_car, color: Colors.green),
                    title: Text(vehicle['model'] ?? 'N/A'),
                    subtitle: Text('${vehicle['plateNumber'] ?? 'N/A'} - ${vehicle['type'] ?? 'N/A'}'),
                    onTap: () {
                      Navigator.pop(context);
                      _startRideWithVehicle(requestId, vehicle);
                    },
                  ))
                      .toList(),
                  const SizedBox(height: 8),
                  const Divider(),
                ],
              ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.add, color: Colors.orange),
              title: const Text('Other vehicle'),
              onTap: () {
                Navigator.pop(context);
                _showManualVehicleDialog(requestId);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _showManualVehicleDialog(String requestId) async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.directions_car, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Enter Vehicle Information'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _manualModelController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Model',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.directions_car),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _manualPlateController,
                    decoration: const InputDecoration(
                      labelText: 'Plate Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.confirmation_number),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _manualTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Type',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
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
                  _manualTypeController.text = 'Car';
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_manualModelController.text.isEmpty || _manualPlateController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter vehicle information'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  _startRideWithManualVehicle(requestId);
                },
                child: const Text('Start Ride'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startRideWithVehicle(String requestId, Map<String, dynamic> vehicle) async {
    if (_companyId == null) return;
    try {
      final startTime = DateTime.now();

      final vehicleId = vehicle['id'] ?? 'N/A';
      final model = vehicle['model'] ?? 'Not specified';
      final plateNumber = vehicle['plateNumber'] ?? 'Not specified';
      final type = vehicle['type'] ?? 'Car';

      await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('requests')
          .doc(requestId)
          .update({
        'status': 'IN_PROGRESS',
        'rideStartTime': FieldValue.serverTimestamp(),
        'vehicleInfo': {
          'vehicleId': vehicleId,
          'model': model,
          'plateNumber': plateNumber,
          'type': type,
          'source': 'fleet',
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (vehicleId != 'N/A' && !vehicleId.startsWith('manual_')) {
        await _firestore
            .collection('companies')
            .doc(_companyId)
            .collection('vehicles')
            .doc(vehicleId)
            .update({
          'isAvailable': false,
          'currentRequestId': requestId,
        });
      }

      _startRideTimer(requestId, startTime);
      SimpleNotificationService.notifyRideStarted(context, requestId);

      debugPrint('🚗 Ride started: $requestId with vehicle: ${plateNumber}');
      _loadDriverRequests();
      _loadAvailableVehicles();
    } catch (e) {
      debugPrint('❌ Error starting ride: $e');
      SimpleNotificationService.notifyError(context, 'Error starting ride: $e');
    }
  }

  Future<void> _startRideWithManualVehicle(String requestId) async {
    if (_companyId == null) return;
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
      _manualTypeController.text = 'Car';

      debugPrint('🚗 Ride started: $requestId with manual vehicle');
      _loadDriverRequests();
    } catch (e) {
      debugPrint('❌ Error starting ride with manual vehicle: $e');
      SimpleNotificationService.notifyError(context, 'Error starting ride: $e');
    }
  }

  Future<void> _startRide(String requestId) async {
    await _showVehicleSelectionDialog(requestId);
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

        if (_companyId == null) {
          setState(() { _loading = false; });
          return;
        }

        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

        final requestsSnapshot = await _firestore
            .collection('companies')
            .doc(_companyId)
            .collection('requests')
            .where('assignedDriverId', isEqualTo: driverId)
            .where('status', whereIn: ['ASSIGNED', 'IN_PROGRESS', 'COMPLETED'])
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
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

        debugPrint('✅ Today\'s assigned requests count: ${_requests.length}');
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
            content: Text('Error loading requests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeRide(String requestId) async {
    if (_companyId == null || _driverId == null) return;
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
      final vehicleInfo = requestData['vehicleInfo'] as Map<String, dynamic>? ?? {};
      final vehicleId = vehicleInfo['vehicleId'] as String?;
      final source = vehicleInfo['source'] as String?;

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
      _loadTotalStatistics();
    } catch (e) {
      debugPrint('❌ Error completing ride: $e');
      SimpleNotificationService.notifyError(context, 'Error completing ride: $e');
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

      SimpleNotificationService.notifySuccess(context, 'Logged out successfully');

      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      debugPrint('❌ Error logging out: $e');
      SimpleNotificationService.notifyError(context, 'Error logging out: $e');
    }
  }

  void _showProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('My Profile'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileRow('Name:', widget.userName),
            _buildProfileRow('Email:', _auth.currentUser?.email ?? ''),
            _buildProfileRow('Driver ID:', _driverId ?? 'Not specified'),
            _buildProfileRow('Status:', 'Human Resources'),
            if (_driverProfileExists) ...[
              _buildProfileRow(
                'Today\'s Completed:',
                _requests
                    .where((r) {
                  final data = r.data() as Map<String, dynamic>? ?? {};
                  return data['status'] == 'COMPLETED';
                })
                    .length
                    .toString(),
              ),
              _buildProfileRow(
                'Total Completed:',
                _totalCompletedRides.toString(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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

  void _showMyRequests() {
    if (_requests.isEmpty) {
      _showNoRequestsDialog();
    } else {
      _showRequestsBottomSheet();
    }
  }

  void _showNoRequestsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.inventory_2, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('No Requests'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No requests assigned to you currently'),
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
                  child: const Text('Activate Driver Account'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showRequestsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final activeRequests = _requests.where((r) {
          final data = r.data() as Map<String, dynamic>? ?? {};
          return data['status'] != 'COMPLETED';
        }).toList();

        final completedRequests = _requests.where((r) {
          final data = r.data() as Map<String, dynamic>? ?? {};
          return data['status'] == 'COMPLETED';
        }).toList();

        return DefaultTabController(
          length: 2,
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
            child: Scaffold(
              appBar: AppBar(
                title: const Text('My Requests'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadDriverRequests,
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close',
                  ),
                ],
                bottom: TabBar(
                  tabs: [
                    Tab(text: 'Active Requests (${activeRequests.length})'),
                    Tab(text: 'Completed Requests (${completedRequests.length})'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  _buildRequestsList(activeRequests),
                  _buildRequestsList(completedRequests),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestsList(List<QueryDocumentSnapshot> requests) {
    if (requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assignment_turned_in_outlined, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No requests currently',
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Requests will appear here when assigned to you',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final doc = requests[index];
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return _buildRequestCard(doc.id, data);
      },
    );
  }

  Widget _buildRequestCard(String requestId, Map<String, dynamic> requestData) {
    final status = requestData['status'] as String? ?? 'UNKNOWN';
    final from = requestData['fromLocation'] as String? ?? 'N/A';
    final to = requestData['toLocation'] as String? ?? 'N/A';
    final department = requestData['department'] as String? ?? 'N/A';
    final priority = requestData['priority'] as String? ?? 'Normal';
    final isUrgent = priority == 'Urgent';
    final notes = requestData['details'] as String? ?? requestData['additionalDetails'] as String? ?? '';

    final isCompleted = status == 'COMPLETED';
    final isInProgress = status == 'IN_PROGRESS';

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;
    String statusText = '';

    switch (status) {
      case 'ASSIGNED':
        statusColor = Colors.blue.shade600;
        statusIcon = Icons.assignment_turned_in;
        statusText = 'Assigned';
        break;
      case 'IN_PROGRESS':
        statusColor = Colors.orange.shade700;
        statusIcon = Icons.schedule;
        statusText = 'In Progress';
        break;
      case 'COMPLETED':
        statusColor = Colors.green.shade700;
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
    }

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(
                    statusText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  avatar: Icon(statusIcon, color: Colors.white, size: 18),
                  backgroundColor: statusColor,
                ),
                if (isUrgent)
                  Chip(
                    label: const Text('Urgent'),
                    backgroundColor: Colors.red.shade600,
                    labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '#$requestId',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const Divider(),
            _buildTripDetailRow(Icons.location_on, 'From', from, color: Colors.green),
            _buildTripDetailRow(Icons.flag, 'To', to, color: Colors.red),
            _buildTripDetailRow(Icons.business, 'Department', department),
            if (notes.isNotEmpty)
              _buildTripDetailRow(Icons.notes, 'Notes', notes),

            if (isInProgress)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.purple, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Ride Duration: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatDuration(_rideDurations[requestId] ?? Duration.zero),
                      style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == 'ASSIGNED')
                  ElevatedButton.icon(
                    onPressed: _loading ? null : () => _startRide(requestId),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Ride'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (isInProgress)
                  ElevatedButton.icon(
                    onPressed: _loading ? null : () => _completeRide(requestId),
                    icon: const Icon(Icons.stop),
                    label: const Text('End Ride'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (isCompleted)
                  TextButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.history, color: Colors.grey),
                    label: const Text('Completed'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripDetailRow(IconData icon, String label, String value, {Color color = Colors.blueGrey}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsItem(Map<String, dynamic> news) {
    final priority = news['priority'] ?? 'normal';
    final color = _getPriorityColor(priority);
    final icon = _getPriorityIcon(priority);
    final timeAgo = news['timestamp'] != null
        ? _getTimeAgo(news['timestamp'] as Timestamp)
        : 'Recently';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  news['title'] ?? 'Traffic Update',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  news['description'] ?? 'No details available',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      news['region'] ?? 'General',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const Spacer(),
                    Text(
                      timeAgo,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTrafficNewsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.traffic, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Live Traffic News'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadMockTrafficNews,
              tooltip: 'Refresh News',
            ),
          ],
        ),
        content: _buildTrafficNewsContent(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficNewsContent() {
    if (_loadingNews) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Loading live traffic news...'),
            ],
          ),
        ),
      );
    }

    if (_trafficNews.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.traffic, color: Colors.grey, size: 50),
              const SizedBox(height: 16),
              const Text(
                'No traffic alerts currently',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadMockTrafficNews,
                child: const Text('Load Sample Alerts'),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.maxFinite,
      height: 400,
      child: Column(
        children: [
          Text(
            'Latest Traffic Updates',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _trafficNews.length,
              itemBuilder: (context, index) {
                final news = _trafficNews[index];
                return _buildNewsItem(news);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    final activeRequestsCount = _requests.where((r) {
      final data = r.data() as Map<String, dynamic>? ?? {};
      return data['status'] != 'COMPLETED';
    }).length;

    final todayCompletedCount = _requests.where((r) {
      final data = r.data() as Map<String, dynamic>? ?? {};
      return data['status'] == 'COMPLETED';
    }).length;

    return RefreshIndicator(
      onRefresh: _loadDriverRequests,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🔥 Welcome card
          Card(
            color: Colors.green.shade50,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.green.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welcome', style: TextStyle(fontSize: 14, color: Colors.green)),
                  const SizedBox(height: 4),
                  Text(
                    widget.userName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Online',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 🔥 My Requests
          const Text(
            'My Requests',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 10),

          ListTile(
            leading: const Icon(Icons.assignment, color: Colors.blue),
            title: const Text('View My Requests'),
            trailing: Chip(
              label: Text(
                activeRequestsCount.toString(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: activeRequestsCount > 0 ? Colors.orange : Colors.grey,
            ),
            onTap: _showMyRequests,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.blue.shade100),
            ),
          ),
          const SizedBox(height: 20),

          // 🔥 Performance Report
          const Text(
            'Performance Report',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 10),

          // 🔥 Today's Performance
          const Text(
            'Today\'s Performance',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Today\'s Requests',
                  _requests.length.toString(),
                  Icons.today,
                  Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'Today\'s Completed',
                  todayCompletedCount.toString(),
                  Icons.check_circle,
                  Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 🔥 Overall Statistics
          const Text(
            'Overall Statistics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Assigned',
                  _loadingStatistics ? '...' : _totalAssignedRides.toString(),
                  Icons.assignment,
                  Colors.purple.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'Total Completed',
                  _loadingStatistics ? '...' : _totalCompletedRides.toString(),
                  Icons.verified,
                  Colors.teal.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivationView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 80, color: Colors.red.shade400),
            const SizedBox(height: 20),
            const Text(
              'Driver Account Activation',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Activate your account to start working',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _loading ? null : _createDriverProfile,
              icon: const Icon(Icons.power_settings_new),
              label: const Text('Activate Driver Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: color.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 30),
                Text(
                  value,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Driver Dashboard'),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
        ),
        drawer: _buildDrawer(),
        body: Column(
          children: [
            if (!_isLocationServiceEnabled && _driverProfileExists)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.yellow.shade800,
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ Location service is disabled. Manager cannot track you.',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _driverProfileExists
                  ? _buildDashboardContent()
                  : _buildActivationView(),
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(_auth.currentUser?.email ?? 'N/A'),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.blue, size: 40),
            ),
            decoration: BoxDecoration(
              color: Colors.blue.shade800,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Driver Dashboard'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('My Profile'),
            onTap: () {
              Navigator.pop(context);
              _showProfile();
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('My Requests'),
            onTap: () {
              Navigator.pop(context);
              _showMyRequests();
            },
          ),
          ListTile(
            leading: const Icon(Icons.traffic),
            title: const Text('Traffic News'),
            onTap: () {
              Navigator.pop(context);
              _showTrafficNewsDialog();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}