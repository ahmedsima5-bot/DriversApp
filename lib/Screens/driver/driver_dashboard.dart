import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/simple_notification_service.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverDashboard extends StatefulWidget {
  final String userName;
  final String companyId;

  const DriverDashboard({
    super.key,
    required this.userName,
    required this.companyId,
  });

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  // 🏢 Services
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 📊 Data States
  List<Map<String, dynamic>> _activeRequests = [];
  List<Map<String, dynamic>> _completedRequests = [];
  bool _loading = true;
  String? _driverId;
  bool _driverProfileExists = false;

  // 📍 Location
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isLocationServiceEnabled = true;

  // 🚗 Vehicles
  List<Map<String, dynamic>> _availableVehicles = [];
  bool _loadingVehicles = false;

  // ⏱️ Ride Timers
  final Map<String, Timer> _activeTimers = {};
  final Map<String, Duration> _rideDurations = {};
  final Map<String, DateTime> _rideStartTimes = {};

  // 📈 Statistics
  int _totalCompletedRides = 0;
  int _totalAssignedRides = 0;
  bool _loadingStatistics = false;

  // 📰 Traffic News
  List<Map<String, dynamic>> _trafficNews = [];
  bool _loadingNews = false;

  // ✍️ Manual Vehicle Input
  final TextEditingController _manualModelController = TextEditingController();
  final TextEditingController _manualPlateController = TextEditingController();
  final TextEditingController _manualTypeController = TextEditingController(text: 'Car');

  // 🔄 Transfer
  bool _transferringRequest = false;

  // 📡 Stream Subscriptions
  StreamSubscription? _requestsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeDriver();
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  // 🧹 Cleanup all resources
  void _cleanupResources() {
    _requestsSubscription?.cancel();
    _positionStreamSubscription?.cancel();

    _activeTimers.forEach((key, timer) => timer.cancel());
    _activeTimers.clear();

    _manualModelController.dispose();
    _manualPlateController.dispose();
    _manualTypeController.dispose();
  }

  // 🎯 Initialize driver data
  Future<void> _initializeDriver() async {
    try {
      await _checkDriverProfile();
      if (_driverProfileExists) {
        await _loadInitialData();
        _startRealTimeListeners();
      }
      setState(() => _loading = false);
    } catch (e) {
      debugPrint('❌ Error initializing driver: $e');
      setState(() => _loading = false);
    }
  }

  // 👤 Check if driver profile exists
  Future<void> _checkDriverProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _driverProfileExists = false);
        return;
      }

      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (driversSnapshot.docs.isNotEmpty) {
        final driverDoc = driversSnapshot.docs.first;
        setState(() {
          _driverId = driverDoc.id;
          _driverProfileExists = true;
        });
      } else {
        setState(() => _driverProfileExists = false);
      }
    } catch (e) {
      debugPrint('❌ Error checking driver profile: $e');
      setState(() => _driverProfileExists = false);
    }
  }

  // 📥 Load initial data
  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        _loadDriverRequests(),
        _loadAvailableVehicles(),
        _loadTotalStatistics(),
        _checkLocationPermissionsAndStart(),
      ]);
    } catch (e) {
      debugPrint('❌ Error loading initial data: $e');
    }
  }

  // 🔊 Start real-time listeners
  void _startRealTimeListeners() {
    _startRequestsListener();
  }

  // ==============================================
  // 📍 LOCATION SERVICES
  // ==============================================

  Future<void> _checkLocationPermissionsAndStart() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocationServiceEnabled = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        _startLocationUpdates();
        setState(() => _isLocationServiceEnabled = true);
      }
    } catch (e) {
      debugPrint('❌ Location permission error: $e');
    }
  }

  void _startLocationUpdates() {
    if (_driverId == null) return;

    _positionStreamSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
          (Position position) {
        _updateDriverLocationInFirestore(position);
      },
      onError: (e) {
        debugPrint('📍 Location stream error: $e');
      },
    );
  }

  Future<void> _updateDriverLocationInFirestore(Position position) async {
    if (_driverId == null) return;

    try {
      await _firestore
          .collection('companies')
          .doc(widget.companyId)
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

  // ==============================================
  // 📋 REQUESTS MANAGEMENT
  // ==============================================

  // 🎧 Listen for real-time request updates
  void _startRequestsListener() {
    _requestsSubscription = _firestore
        .collection('companies')
        .doc(widget.companyId)
        .collection('requests')
        .where('assignedDriverId', isEqualTo: _driverId)
        .where('status', whereIn: ['ASSIGNED', 'IN_PROGRESS', 'COMPLETED'])
        .snapshots()
        .listen((snapshot) {
      _processRequestsSnapshot(snapshot);
    }, onError: (error) {
      debugPrint('❌ Requests listener error: $error');
    });
  }

  void _processRequestsSnapshot(QuerySnapshot snapshot) {
    final List<Map<String, dynamic>> activeRequests = [];
    final List<Map<String, dynamic>> completedRequests = [];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final requestId = doc.id;
      final status = data['status'] as String? ?? 'UNKNOWN';

      final requestData = {
        'id': requestId,
        ...data,
      };

      if (status == 'COMPLETED') {
        completedRequests.add(requestData);
      } else {
        activeRequests.add(requestData);

        // Start timer for in-progress rides
        if (status == 'IN_PROGRESS' && data['rideStartTime'] != null) {
          final startTime = (data['rideStartTime'] as Timestamp).toDate();
          _startRideTimer(requestId, startTime);
        }
      }
    }

    if (mounted) {
      setState(() {
        _activeRequests = activeRequests;
        _completedRequests = completedRequests;
      });
    }
  }

  // 📥 Load driver requests
  Future<void> _loadDriverRequests() async {
    try {
      if (_driverId == null) return;

      final requestsSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .where('assignedDriverId', isEqualTo: _driverId)
          .where('status', whereIn: ['ASSIGNED', 'IN_PROGRESS', 'COMPLETED'])
          .orderBy('createdAt', descending: true)
          .get();

      _processRequestsSnapshot(requestsSnapshot);
    } catch (e) {
      debugPrint('❌ Error loading driver requests: $e');
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

  // ==============================================
  // ⏱️ RIDE TIMER MANAGEMENT
  // ==============================================

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

    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  // ==============================================
  // 🚗 VEHICLE MANAGEMENT
  // ==============================================

  Future<void> _loadAvailableVehicles() async {
    try {
      setState(() => _loadingVehicles = true);

      final vehiclesSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
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
    } catch (e) {
      debugPrint('❌ Error loading vehicles: $e');
      setState(() => _loadingVehicles = false);
    }
  }

  // 🚀 Start ride with vehicle selection
  Future<void> _startRide(String requestId) async {
    await _showVehicleSelectionDialog(requestId);
  }

  Future<void> _showVehicleSelectionDialog(String requestId) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.directions_car, color: Colors.blue),
            SizedBox(width: 8),
            Text('Select Vehicle'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
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
                _buildNoVehiclesContent()
              else
                _buildVehiclesList(requestId),

              const SizedBox(height: 8),
              const Divider(),
              _buildManualVehicleOption(requestId),
            ],
          ),
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

  Widget _buildNoVehiclesContent() {
    return const Column(
      children: [
        Icon(Icons.car_repair, size: 50, color: Colors.grey),
        SizedBox(height: 8),
        Text(
          'No available vehicles',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildVehiclesList(String requestId) {
    return Column(
      children: _availableVehicles.map((vehicle) => ListTile(
        leading: const Icon(Icons.directions_car, color: Colors.green),
        title: Text(vehicle['model'] ?? 'N/A'),
        subtitle: Text('${vehicle['plateNumber'] ?? 'N/A'} - ${vehicle['type'] ?? 'N/A'}'),
        onTap: () {
          Navigator.pop(context);
          _startRideWithVehicle(requestId, vehicle);
        },
      )).toList(),
    );
  }

  Widget _buildManualVehicleOption(String requestId) {
    return ListTile(
      leading: const Icon(Icons.add, color: Colors.orange),
      title: const Text('Other vehicle'),
      onTap: () {
        Navigator.pop(context);
        _showManualVehicleDialog(requestId);
      },
    );
  }

  Future<void> _showManualVehicleDialog(String requestId) async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.directions_car, color: Colors.orange),
                SizedBox(width: 8),
                Text('Enter Vehicle Information'),
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
    try {
      final startTime = DateTime.now();
      final vehicleId = vehicle['id'] ?? 'N/A';
      final model = vehicle['model'] ?? 'Not specified';
      final plateNumber = vehicle['plateNumber'] ?? 'Not specified';
      final type = vehicle['type'] ?? 'Car';

      await _firestore.collection('companies').doc(widget.companyId).collection('requests').doc(requestId).update({
        'status': 'IN_PROGRESS',
        'rideStartTime': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'vehicleInfo': {
          'vehicleId': vehicleId,
          'model': model,
          'plateNumber': plateNumber,
          'type': type,
          'source': 'fleet',
        },
      });

      if (vehicleId != 'N/A' && !vehicleId.startsWith('manual_')) {
        await _firestore.collection('companies').doc(widget.companyId).collection('vehicles').doc(vehicleId).update({
          'isAvailable': false,
          'currentRequestId': requestId,
        });
      }

      _startRideTimer(requestId, startTime);
      SimpleNotificationService.notifyRideStarted(context, requestId);
      _loadDriverRequests();
      _loadAvailableVehicles();

    } catch (e) {
      debugPrint('❌ Error starting ride: $e');
      SimpleNotificationService.notifyError(context, 'Error starting ride: $e');
    }
  }

  Future<void> _startRideWithManualVehicle(String requestId) async {
    try {
      final startTime = DateTime.now();

      await _firestore.collection('companies').doc(widget.companyId).collection('requests').doc(requestId).update({
        'status': 'IN_PROGRESS',
        'rideStartTime': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'vehicleInfo': {
          'vehicleId': 'manual_${DateTime.now().millisecondsSinceEpoch}',
          'model': _manualModelController.text,
          'plateNumber': _manualPlateController.text,
          'type': _manualTypeController.text,
          'source': 'manual',
        },
      });

      _startRideTimer(requestId, startTime);
      SimpleNotificationService.notifyRideStarted(context, requestId);

      _manualModelController.clear();
      _manualPlateController.clear();
      _manualTypeController.text = 'Car';

      _loadDriverRequests();

    } catch (e) {
      debugPrint('❌ Error starting ride with manual vehicle: $e');
      SimpleNotificationService.notifyError(context, 'Error starting ride: $e');
    }
  }

  // ✅ Complete ride
  Future<void> _completeRide(String requestId) async {
    if (_driverId == null) return;

    try {
      _stopRideTimer(requestId);
      final endTime = DateTime.now();
      final startTime = _rideStartTimes[requestId];
      final totalDuration = startTime != null ? endTime.difference(startTime) : Duration.zero;

      final requestDoc = await _firestore.collection('companies').doc(widget.companyId).collection('requests').doc(requestId).get();
      final requestData = requestDoc.data() ?? {};
      final vehicleInfo = requestData['vehicleInfo'] as Map<String, dynamic>? ?? {};
      final vehicleId = vehicleInfo['vehicleId'] as String?;
      final source = vehicleInfo['source'] as String?;

      await _firestore.collection('companies').doc(widget.companyId).collection('requests').doc(requestId).update({
        'status': 'COMPLETED',
        'rideEndTime': FieldValue.serverTimestamp(),
        'rideDuration': totalDuration.inSeconds,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (source == 'fleet' && vehicleId != null && !vehicleId.startsWith('manual_')) {
        await _firestore.collection('companies').doc(widget.companyId).collection('vehicles').doc(vehicleId).update({
          'isAvailable': true,
          'currentRequestId': null,
        });
      }

      await _firestore.collection('companies').doc(widget.companyId).collection('drivers').doc(_driverId).update({
        'isAvailable': true,
        'completedRides': FieldValue.increment(1),
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });

      SimpleNotificationService.notifyRideCompleted(context, requestId);

      await Future.wait([
        _loadDriverRequests(),
        _loadAvailableVehicles(),
        _loadTotalStatistics(),
      ]);

    } catch (e) {
      debugPrint('❌ Error completing ride: $e');
      SimpleNotificationService.notifyError(context, 'Error completing ride: $e');
    }
  }

  // ==============================================
  // 🔄 REQUEST TRANSFER
  // ==============================================

  Future<void> _transferRequestToAnotherDriver(String requestId, Map<String, dynamic> requestData) async {
    if (_driverId == null) return;

    try {
      setState(() => _transferringRequest = true);

      final availableDrivers = await _getAllActiveDriversForTransfer();

      if (availableDrivers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No other drivers in system'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await _showDriverTransferDialog(requestId, requestData, availableDrivers);

    } catch (e) {
      debugPrint('❌ Error in transfer request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transfer error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _transferringRequest = false);
    }
  }

  Future<List<Map<String, dynamic>>> _getAllActiveDriversForTransfer() async {
    try {
      final driversSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .where('driverId', isNotEqualTo: _driverId)
          .get();

      return driversSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'isAvailable': data['isAvailable'] ?? false,
          'isOnline': data['isOnline'] ?? false,
          'completedRides': data['completedRides'] ?? 0,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _showDriverTransferDialog(
      String requestId,
      Map<String, dynamic> requestData,
      List<Map<String, dynamic>> availableDrivers
      ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.orange),
            SizedBox(width: 8),
            Text('Transfer Request'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose driver to transfer request to:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (availableDrivers.isEmpty)
              const Text('No available drivers')
            else
              ...availableDrivers.map((driver) => ListTile(
                leading: Icon(
                  Icons.person,
                  color: driver['isAvailable'] == true ? Colors.green : Colors.orange,
                ),
                title: Text(driver['name']),
                trailing: const Icon(Icons.arrow_forward, color: Colors.blue),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${driver['completedRides']} completed rides'),
                    Text(
                      driver['isAvailable'] == true ? '🟢 Available' : '🔴 Busy',
                      style: TextStyle(
                        color: driver['isAvailable'] == true ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmTransfer(requestId, requestData, driver);
                },
              )).toList(),
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

  Future<void> _confirmTransfer(
      String requestId,
      Map<String, dynamic> requestData,
      Map<String, dynamic> newDriver
      ) async {
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Transfer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to transfer request to:'),
            const SizedBox(height: 8),
            Text(
              newDriver['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text('Request ID: ${requestId.substring(0, 8)}'),
            const SizedBox(height: 8),
            if (newDriver['isAvailable'] != true)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '⚠️ Note: This driver is currently busy',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Confirm Transfer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _executeTransfer(requestId, requestData, newDriver);
    }
  }

  Future<void> _executeTransfer(
      String requestId,
      Map<String, dynamic> requestData,
      Map<String, dynamic> newDriver
      ) async {
    try {
      if (requestData['status'] == 'IN_PROGRESS') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Cannot transfer request after starting'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await _firestore.collection('companies').doc(widget.companyId).collection('requests').doc(requestId).update({
        'previousDriverId': _driverId,
        'previousDriverName': widget.userName,
        'assignedDriverId': newDriver['id'],
        'assignedDriverName': newDriver['name'],
        'status': 'ASSIGNED',
        'transferReason': 'Transferred by driver',
        'transferredAt': FieldValue.serverTimestamp(),
        'transferredBy': _driverId,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('companies').doc(widget.companyId).collection('drivers').doc(_driverId).update({
        'isAvailable': true,
        'currentRequestId': null,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('companies').doc(widget.companyId).collection('drivers').doc(newDriver['id']).update({
        'isAvailable': false,
        'currentRequestId': requestId,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });

      await _notifyNewDriverAboutTransfer(requestId, newDriver, requestData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Request transferred to ${newDriver['name']}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await Future.wait([
        _loadDriverRequests(),
        _loadTotalStatistics(),
      ]);

    } catch (e) {
      debugPrint('❌ Error executing transfer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transfer error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _notifyNewDriverAboutTransfer(
      String requestId,
      Map<String, dynamic> newDriver,
      Map<String, dynamic> requestData
      ) async {
    try {
      final notificationData = {
        'type': 'request_transfer',
        'requestId': requestId,
        'fromDriver': widget.userName,
        'fromLocation': requestData['fromLocation'] ?? 'Not specified',
        'toLocation': requestData['toLocation'] ?? 'Not specified',
        'priority': requestData['priority'] ?? 'Normal',
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .doc(newDriver['id'])
          .collection('notifications')
          .add(notificationData);
    } catch (e) {
      debugPrint('❌ Error sending transfer notification: $e');
    }
  }

  // ==============================================
  // 📊 STATISTICS
  // ==============================================

  Future<void> _loadTotalStatistics() async {
    if (_driverId == null) return;

    try {
      setState(() => _loadingStatistics = true);

      final completedSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .where('assignedDriverId', isEqualTo: _driverId)
          .where('status', isEqualTo: 'COMPLETED')
          .get();

      final assignedSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .where('assignedDriverId', isEqualTo: _driverId)
          .where('status', whereIn: ['ASSIGNED', 'IN_PROGRESS', 'COMPLETED'])
          .get();

      setState(() {
        _totalCompletedRides = completedSnapshot.docs.length;
        _totalAssignedRides = assignedSnapshot.docs.length;
        _loadingStatistics = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading total statistics: $e');
      setState(() => _loadingStatistics = false);
    }
  }

  // ==============================================
  // 👤 DRIVER PROFILE
  // ==============================================

  Future<void> _createDriverProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final driverId = 'driver_${user.uid.substring(0, 8)}';

      await _firestore
          .collection('companies')
          .doc(widget.companyId)
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
      });

      await _loadInitialData();
      _startRealTimeListeners();

      SimpleNotificationService.notifySuccess(context, 'Driver account activated successfully');

    } catch (e) {
      debugPrint('❌ Error creating driver record: $e');
      SimpleNotificationService.notifyError(context, 'Error activating account: $e');
    }
  }

  // ==============================================
  // 🎨 UI COMPONENTS - ACTIVE REQUESTS
  // ==============================================

  Widget _buildActiveRequestCard(Map<String, dynamic> request) {
    final requestId = request['id'];
    final status = request['status'] as String? ?? 'UNKNOWN';
    final from = request['fromLocation'] as String? ?? 'N/A';
    final to = request['toLocation'] as String? ?? 'N/A';
    final department = request['department'] as String? ?? 'N/A';
    final priority = request['priority'] as String? ?? 'Normal';
    final isUrgent = priority == 'Urgent';
    final notes = request['details'] as String? ?? request['additionalDetails'] as String? ?? '';
    final requesterName = request['requesterName'] as String? ?? 'Unknown';
    final isInProgress = status == 'IN_PROGRESS';
    final isAssigned = status == 'ASSIGNED';
    final createdAt = request['createdAt'] as Timestamp?;
    final requestDateTime = createdAt != null ? createdAt.toDate() : DateTime.now();
    final formattedDate = '${requestDateTime.day}/${requestDateTime.month}/${requestDateTime.year}';
    final formattedTime = '${requestDateTime.hour}:${requestDateTime.minute.toString().padLeft(2, '0')}';

    Color statusColor = Colors.blue.shade600;
    IconData statusIcon = Icons.assignment_turned_in;
    String statusText = 'Assigned';

    if (isInProgress) {
      statusColor = Colors.orange.shade700;
      statusIcon = Icons.schedule;
      statusText = 'In Progress';
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
            Text('#${requestId.substring(0, 8)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.blue.shade700, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Requested by: $requesterName',
                    style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Icon(Icons.business, color: Colors.blue.shade700, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Department: $department',
                    style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const Divider(),

            _buildTripDetailRow(Icons.location_on, 'From', from, color: Colors.green),
            _buildTripDetailRow(Icons.flag, 'To', to, color: Colors.red, copyable: true),

            if (notes.isNotEmpty)
              _buildTripDetailRow(Icons.speaker_notes_outlined, 'Notes', notes, copyable: true),

            if (isInProgress)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.purple, size: 20),
                    const SizedBox(width: 8),
                    const Text('Ride Duration: ', style: TextStyle(fontWeight: FontWeight.bold)),
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
                if (isAssigned)
                  Row(
                    children: [
                      if (!_transferringRequest)
                        IconButton(
                          onPressed: () => _transferRequestToAnotherDriver(requestId, request),
                          icon: const Icon(Icons.swap_horiz, color: Colors.orange),
                          tooltip: 'Transfer to another driver',
                        ),
                      ElevatedButton.icon(
                        onPressed: _loading ? null : () => _startRide(requestId),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Ride'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
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
              ],
            ),

            if (_transferringRequest)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.orangeAccent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // 🎨 UI COMPONENTS - COMPLETED REQUESTS
  // ==============================================

  Widget _buildCompletedRequestCard(Map<String, dynamic> request) {
    final requestId = request['id'];
    final from = request['fromLocation'] as String? ?? 'N/A';
    final to = request['toLocation'] as String? ?? 'N/A';
    final department = request['department'] as String? ?? 'N/A';
    final requesterName = request['requesterName'] as String? ?? 'Unknown';
    final rideDuration = request['rideDuration'] != null
        ? '${(request['rideDuration'] as int) ~/ 60} minutes'
        : 'N/A';

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 1,
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: const Text(
                    'Completed',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  avatar: Icon(Icons.check_circle, color: Colors.grey.shade600, size: 18),
                  backgroundColor: Colors.grey.shade300,
                ),
              ],
            ),

            const SizedBox(height: 10),
            Text('#${requestId.substring(0, 8)}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Completed by: $requesterName',
                    style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Icon(Icons.business, color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Department: $department',
                    style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const Divider(),

            _buildTripDetailRow(Icons.location_on, 'From', from, color: Colors.green, completed: true),
            _buildTripDetailRow(Icons.flag, 'To', to, color: Colors.red, copyable: true, completed: true),
            _buildTripDetailRow(Icons.timer, 'Duration', rideDuration, color: Colors.purple, completed: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTripDetailRow(
      IconData icon,
      String label,
      String value, {
        Color color = Colors.blueGrey,
        bool copyable = false,
        bool completed = false,
      }) {
    final hasMapLink = copyable && _isMapLink(value);
    final textColor = completed ? Colors.grey.shade600 : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: completed ? Colors.grey : color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label: ', style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textColor,
                )),
                GestureDetector(
                  onLongPress: copyable ? () => _copyToClipboardEnhanced(value, label) : null,
                  onTap: hasMapLink ? () => _openMapLink(value) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 14,
                              color: hasMapLink ? Colors.blue : textColor,
                              decoration: hasMapLink ? TextDecoration.underline : TextDecoration.none,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (copyable) ...[
                          const SizedBox(width: 8),
                          Icon(
                            hasMapLink ? Icons.map : Icons.content_copy,
                            size: 16,
                            color: hasMapLink ? Colors.blue : Colors.grey.shade500,
                          ),
                        ],
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
  }

  // ==============================================
  // 📊 DASHBOARD CONTENT
  // ==============================================

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _loadDriverRequests,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 20),

          // Active Requests Section
          _buildActiveRequestsSection(),
          const SizedBox(height: 20),

          // Performance Metrics
          _buildPerformanceMetrics(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      color: Colors.green.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome', style: TextStyle(fontSize: 14, color: Colors.green)),
            const SizedBox(height: 4),
            Text(widget.userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('Online', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Requests',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
        const SizedBox(height: 10),

        if (_activeRequests.isEmpty)
          _buildNoActiveRequests()
        else
          ..._activeRequests.map((request) => _buildActiveRequestCard(request)).toList(),
      ],
    );
  }

  Widget _buildNoActiveRequests() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.assignment_turned_in, size: 50, color: Colors.blue.shade300),
          const SizedBox(height: 12),
          const Text(
            'No Active Requests',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          const Text(
            'You will see new ride requests here when they are assigned to you.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Performance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Active Rides',
                _activeRequests.length.toString(),
                Icons.directions_car,
                Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                'Completed Today',
                _completedRequests.length.toString(),
                Icons.check_circle,
                Colors.green.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
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
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
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

  // ==============================================
  // 📋 REQUESTS BOTTOM SHEET
  // ==============================================

  void _showMyRequests() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
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
            ),
            body: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Active Requests'),
                      Tab(text: 'Completed Requests'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildActiveRequestsList(),
                        _buildCompletedRequestsList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveRequestsList() {
    if (_activeRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No active requests',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _activeRequests.length,
      itemBuilder: (context, index) {
        final request = _activeRequests[index];
        return _buildActiveRequestCard(request);
      },
    );
  }

  Widget _buildCompletedRequestsList() {
    if (_completedRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No completed rides',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _completedRequests.length,
      itemBuilder: (context, index) {
        final request = _completedRequests[index];
        return _buildCompletedRequestCard(request);
      },
    );
  }

  // ==============================================
  // 🛠️ UTILITY FUNCTIONS
  // ==============================================

  bool _isMapLink(String text) {
    final mapPatterns = [
      RegExp(r'https?://(maps\.google|goo\.gl/maps|maps\.app\.goo\.gl|waze\.com)'),
      RegExp(r'https?://.*google.*maps'),
      RegExp(r'https?://.*waze\.com'),
      RegExp(r'geo:[-0-9.,]+'),
    ];
    return mapPatterns.any((pattern) => pattern.hasMatch(text.toLowerCase()));
  }

  Future<void> _copyToClipboardEnhanced(String text, String fieldName) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied $fieldName to clipboard'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copy error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openMapLink(String url) async {
    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link copied: $url'),
        ),
      );
    }
  }

  // ==============================================
  // 🎯 ACTIVATION VIEW
  // ==============================================

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

  // ==============================================
  // 🔐 LOGOUT & PROFILE
  // ==============================================

  Future<void> _logout() async {
    try {
      if (_driverId != null) {
        await _firestore.collection('companies').doc(widget.companyId).collection('drivers').doc(_driverId).update({
          'isOnline': false,
          'lastStatusUpdate': FieldValue.serverTimestamp(),
        });
      }

      await _auth.signOut();
      SimpleNotificationService.notifySuccess(context, 'Logged out successfully');

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint('❌ Error logging out: $e');
      SimpleNotificationService.notifyError(context, 'Error logging out: $e');
    }
  }

  void _showProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person, color: Colors.orange),
            SizedBox(width: 8),
            Text('My Profile'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileRow('Name:', widget.userName),
            _buildProfileRow('Email:', _auth.currentUser?.email ?? ''),
            _buildProfileRow('Driver ID:', _driverId ?? 'Not specified'),
            _buildProfileRow('Status:', 'Active'),
            if (_driverProfileExists) ...[
              _buildProfileRow('Active Rides:', _activeRequests.length.toString()),
              _buildProfileRow('Completed Today:', _completedRequests.length.toString()),
              _buildProfileRow('Total Completed:', _totalCompletedRides.toString()),
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

  // ==============================================
  // 🏗️ MAIN BUILD
  // ==============================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Driver Dashboard'),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          actions: [
            if (_activeRequests.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                onPressed: () {
                  _showQuickTransferDialog();
                },
                tooltip: 'Quick Transfer',
              ),
          ],
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

  Future<void> _showQuickTransferDialog() async {
    final transferableRequests = _activeRequests.where((request) {
      return request['status'] == 'ASSIGNED';
    }).toList();

    if (transferableRequests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transferable requests available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.orange),
            SizedBox(width: 8),
            Text('Transfer Requests'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose request to transfer:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...transferableRequests.map((request) {
              return ListTile(
                leading: const Icon(Icons.assignment, color: Colors.blue),
                title: Text('Request #${request['id'].substring(0, 8)}'),
                subtitle: Text('${request['fromLocation']} → ${request['toLocation']}'),
                onTap: () {
                  Navigator.pop(context);
                  _transferRequestToAnotherDriver(request['id'], request);
                },
              );
            }).toList(),
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

  // 🧭 Navigation Drawer
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
            decoration: BoxDecoration(color: Colors.blue.shade800),
          ),

          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Driver Dashboard'),
            onTap: () => Navigator.pop(context),
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

          if (_activeRequests.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.orange),
              title: const Text('Transfer Requests'),
              onTap: () {
                Navigator.pop(context);
                _showQuickTransferDialog();
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