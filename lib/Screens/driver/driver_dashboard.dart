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

  // ✍️ Manual Vehicle Input
  final TextEditingController _manualModelController = TextEditingController();
  final TextEditingController _manualPlateController = TextEditingController();
  final TextEditingController _manualTypeController = TextEditingController(text: 'Car');

  // 🔄 Transfer
  bool _transferringRequest = false;

  // 📡 Stream Subscriptions
  StreamSubscription? _requestsSubscription;

  // 🎨 Theme & Design
  final Color _primaryColor = Colors.blue.shade800;
  final Color _secondaryColor = Colors.orange.shade600;
  final Color _successColor = Colors.green.shade600;
  final Color _warningColor = Colors.orange.shade600;
  final Color _errorColor = Colors.red.shade600;

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

  void _cleanupResources() {
    _requestsSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    _activeTimers.forEach((key, timer) => timer.cancel());
    _activeTimers.clear();
    _manualModelController.dispose();
    _manualPlateController.dispose();
    _manualTypeController.dispose();
  }

  // ==============================================
  // 🔧 CORE METHODS
  // ==============================================

  Future<void> _initializeDriver() async {
    try {
      await _checkDriverProfile();
      if (_driverProfileExists) {
        await _loadInitialData();
        _startRealTimeListeners();
      }
      setState(() => _loading = false);
    } catch (e) {
      _showErrorSnackBar('Error initializing driver: $e');
      setState(() => _loading = false);
    }
  }

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

  Future<void> _loadDriverRequests() async {
    try {
      if (_driverId == null) return;

      setState(() => _loading = true);

      final requestsSnapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .where('assignedDriverId', isEqualTo: _driverId)
          .where('status', whereIn: ['ASSIGNED', 'IN_PROGRESS', 'COMPLETED'])
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 30));

      _processRequestsSnapshot(requestsSnapshot);

    } catch (e) {
      debugPrint('❌ Error loading driver requests: $e');
      _showErrorSnackBar('Failed to load requests: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
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

  // ==============================================
  // 📅 SCHEDULED REQUESTS VALIDATION
  // ==============================================

  bool _isScheduledRequestToday(Map<String, dynamic> request) {
    final isScheduled = request['isScheduled'] as bool? ?? false;
    final scheduledDate = request['scheduledDate'] as Timestamp?;

    if (!isScheduled || scheduledDate == null) {
      return true;
    }

    final now = DateTime.now();
    final scheduledDateTime = scheduledDate.toDate();

    return now.year == scheduledDateTime.year &&
        now.month == scheduledDateTime.month &&
        now.day == scheduledDateTime.day;
  }

  bool _isStartButtonEnabled(Map<String, dynamic> request) {
    final status = request['status'] as String? ?? 'UNKNOWN';
    final isAssigned = status == 'ASSIGNED';

    if (!isAssigned) {
      return false;
    }

    final isScheduled = request['isScheduled'] as bool? ?? false;

    if (!isScheduled) {
      return true;
    }

    return _isScheduledRequestToday(request);
  }

  // ==============================================
  // 🚀 RIDE MANAGEMENT
  // ==============================================

  Future<void> _startRide(String requestId) async {
    final request = _activeRequests.firstWhere((req) => req['id'] == requestId);

    if (!_isStartButtonEnabled(request)) {
      final scheduledDate = request['scheduledDate'] as Timestamp?;
      if (scheduledDate != null) {
        _showScheduledDateError(scheduledDate.toDate());
      }
      return;
    }

    await _showVehicleSelectionDialog(requestId);
  }

// ❌ هذا مكرر - احذف السطور المكررة
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

      // ✅ الكود الصحيح بدون تكرار
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

      _showSuccessSnackBar('Ride completed successfully!');
      await _refreshData();

    } catch (e) {
      debugPrint('❌ Error completing ride: $e');
      _showErrorSnackBar('Error completing ride: $e');
    }
  }  // ==============================================
  // 🔄 REQUEST TRANSFER
  // ==============================================

  Future<void> _transferRequestToAnotherDriver(String requestId, Map<String, dynamic> requestData) async {
    if (_driverId == null) return;

    try {
      setState(() => _transferringRequest = true);

      final availableDrivers = await _getAllActiveDriversForTransfer();

      if (availableDrivers.isEmpty) {
        _showInfoSnackBar('No other drivers in system');
        return;
      }

      await _showDriverTransferDialog(requestId, requestData, availableDrivers);

    } catch (e) {
      debugPrint('❌ Error in transfer request: $e');
      _showErrorSnackBar('Transfer error: $e');
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
        _showErrorSnackBar('Cannot transfer request after starting');
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

      _showSuccessSnackBar('Request transferred to ${newDriver['name']}');

      await _refreshData();

    } catch (e) {
      debugPrint('❌ Error executing transfer: $e');
      _showErrorSnackBar('Transfer error: $e');
    }
  }

  // ==============================================
  // 📊 STATISTICS
  // ==============================================

  Future<void> _loadTotalStatistics() async {
    if (_driverId == null) return;

    try {
      setState(() => _loadingStatistics = true);

      final totalCompletedSnapshot = await _firestore
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
        _totalCompletedRides = totalCompletedSnapshot.docs.length;
        _totalAssignedRides = assignedSnapshot.docs.length;
        _loadingStatistics = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading total statistics: $e');
      setState(() => _loadingStatistics = false);
    }
  }

  // ==============================================
  // 🎨 ENHANCED UI COMPONENTS
  // ==============================================

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildWelcomeSection()),
          SliverToBoxAdapter(child: _buildPerformanceMetrics()),
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              title: 'Active Requests',
              icon: Icons.directions_car,
              count: _activeRequests.length,
            ),
          ),
          if (_activeRequests.isEmpty)
            SliverToBoxAdapter(
              child: _buildEmptyState(
                icon: Icons.assignment_turned_in_outlined,
                title: 'No Active Requests',
                description: 'You will see new ride requests here when they are assigned to you.',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildActiveRequestCard(_activeRequests[index]),
                childCount: _activeRequests.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Icon(Icons.person, size: 30, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.circle, color: Colors.green.shade300, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      'Online & Active',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: _showNotifications,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              _buildMetricCard(
                title: 'Active Rides',
                value: _activeRequests.length.toString(),
                icon: Icons.directions_car_filled,
                color: _primaryColor,
                gradient: [Colors.blue.shade600, Colors.blue.shade800],
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                title: 'Completed Today',
                value: _completedRequests.length.toString(),
                icon: Icons.check_circle,
                color: _successColor,
                gradient: [Colors.green.shade500, Colors.green.shade700],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard(
                title: 'Total Completed',
                value: _loadingStatistics ? '...' : _totalCompletedRides.toString(),
                icon: Icons.verified,
                color: Colors.purple.shade600,
                gradient: [Colors.purple.shade500, Colors.purple.shade700],
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                title: 'Success Rate',
                value: _calculateSuccessRate(),
                icon: Icons.trending_up,
                color: Colors.teal.shade600,
                gradient: [Colors.teal.shade500, Colors.teal.shade700],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required List<Color> gradient,
  }) {
    return Expanded(
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                icon,
                size: 60,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const Spacer(),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon, int? count}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (count != null && count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: Icon(Icons.refresh, color: _primaryColor),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showRequestDetails(request),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildStatusChip(status, request),
                    if (isUrgent) _buildUrgentChip(),
                    const Spacer(),
                    _buildActionButtons(requestId, request, isAssigned, isInProgress),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRequesterInfo(requesterName, department),
                const SizedBox(height: 12),
                _buildTripDetails(from, to, notes),
                if (isInProgress) _buildRideTimer(requestId),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, Map<String, dynamic> request) {
    final isScheduled = request['isScheduled'] as bool? ?? false;

    Map<String, dynamic> statusConfig = {
      'ASSIGNED': {'color': Colors.blue, 'icon': Icons.assignment_turned_in, 'text': 'Assigned'},
      'IN_PROGRESS': {'color': Colors.orange, 'icon': Icons.schedule, 'text': 'In Progress'},
      'COMPLETED': {'color': Colors.green, 'icon': Icons.check_circle, 'text': 'Completed'},
    };

    if (isScheduled) {
      statusConfig = {
        'ASSIGNED': {'color': Colors.purple, 'icon': Icons.calendar_today, 'text': 'Scheduled'},
        'IN_PROGRESS': {'color': Colors.orange, 'icon': Icons.schedule, 'text': 'In Progress'},
      };
    }

    final config = statusConfig[status] ?? statusConfig['ASSIGNED']!;

    return Chip(
      label: Text(
        config['text'],
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
      avatar: Icon(config['icon'], color: Colors.white, size: 16),
      backgroundColor: config['color'],
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildUrgentChip() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: Chip(
        label: const Text('Urgent'),
        backgroundColor: _errorColor,
        labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildActionButtons(String requestId, Map<String, dynamic> request, bool isAssigned, bool isInProgress) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isAssigned) ...[
          IconButton(
            onPressed: () => _transferRequestToAnotherDriver(requestId, request),
            icon: Icon(Icons.swap_horiz, color: _warningColor, size: 20),
            tooltip: 'Transfer Request',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isStartButtonEnabled(request) ? () => _startRide(requestId) : null,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
        if (isInProgress)
          ElevatedButton.icon(
            onPressed: () => _completeRide(requestId),
            icon: const Icon(Icons.stop, size: 18),
            label: const Text('Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ],
    );
  }

  Widget _buildRequesterInfo(String requesterName, String department) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: _primaryColor.withOpacity(0.1),
          child: Icon(Icons.person, size: 16, color: _primaryColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                requesterName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                department,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
// دالة نسخ النص إلى الحافظة
  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    _showCopySnackBar(message);
  }

// دالة لعرض تأكيد النسخ
  void _showCopyDialog(String text, String label) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Copy $label'),
        content: SelectableText(
          text,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _copyToClipboard(text, '$label copied to clipboard');
              Navigator.pop(context);
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

// دالة لعرض رسالة النسخ
  void _showCopySnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: _successColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

// دالة فتح رابط الخرائط
  Future<void> _openMapLink(String url) async {
    try {
      // تنظيف الرابط إذا كان يحتوي على مسافات
      String cleanUrl = url.trim();

      // إضافة https:// إذا لم يكن موجوداً
      if (!cleanUrl.startsWith('http')) {
        cleanUrl = 'https://$cleanUrl';
      }

      if (await canLaunchUrl(Uri.parse(cleanUrl))) {
        await launchUrl(Uri.parse(cleanUrl));
      } else {
        _copyToClipboard(url, 'Map link copied to clipboard');
      }
    } catch (e) {
      _copyToClipboard(url, 'Map link copied to clipboard');
    }
  }
  Widget _buildTripDetails(String from, String to, String notes) {
    return Column(
      children: [
        _buildLocationRow(Icons.location_on, 'From', from, Colors.green),
        _buildLocationRow(Icons.flag, 'To', to, Colors.red),
        if (notes.isNotEmpty)
          _buildLocationRow(Icons.notes, 'Notes', notes, Colors.blue),
      ],
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String value, Color color) {
    if (value.isEmpty || value == 'N/A') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // تحقق إذا النص يحتوي على رابط خرائط
    final bool isMapLink = value.toLowerCase().contains('maps.') ||
        value.toLowerCase().contains('google.') ||
        value.toLowerCase().contains('goo.gl') ||
        value.toLowerCase().contains('openstreetmap') ||
        value.toLowerCase().startsWith('http');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label:',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onLongPress: () {
                    _copyToClipboard(value, '$label copied to clipboard');
                  },
                  onTap: isMapLink ? () => _openMapLink(value) : () {
                    _showCopyDialog(value, label);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: isMapLink ? Colors.blue.shade50 : Colors.grey.shade50,
                      border: Border.all(
                        color: isMapLink ? Colors.blue.shade200 : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 14,
                              color: isMapLink ? Colors.blue.shade700 : Colors.black87,
                              decoration: isMapLink ? TextDecoration.underline : TextDecoration.none,
                              fontWeight: isMapLink ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isMapLink ? Icons.open_in_new : Icons.content_copy,
                          size: 16,
                          color: isMapLink ? Colors.blue.shade600 : Colors.grey.shade600,
                        ),
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
  }  Widget _buildRideTimer(String requestId) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: Colors.orange.shade700, size: 16),
          const SizedBox(width: 8),
          Text(
            'Ride Duration: ${_formatDuration(_rideDurations[requestId] ?? Duration.zero)}',
            style: TextStyle(
              color: Colors.orange.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String description}) {
    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // 🚀 VEHICLE SELECTION DIALOGS
  // ==============================================

  Future<void> _showVehicleSelectionDialog(String requestId) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.directions_car, color: _primaryColor, size: 30),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select Vehicle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loadingVehicles)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )
              else if (_availableVehicles.isEmpty)
                _buildNoVehiclesContent()
              else
                _buildVehiclesList(requestId),

              const SizedBox(height: 16),
              _buildManualVehicleOption(requestId),
            ],
          ),
        ),
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
    return Container(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          _showManualVehicleDialog(requestId);
        },
        icon: Icon(Icons.add, color: _secondaryColor),
        label: Text('Other Vehicle', style: TextStyle(color: _secondaryColor)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: _secondaryColor),
        ),
      ),
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

      // ✅ استخدم Timestamp.fromDate بدلاً من FieldValue.serverTimestamp()
      await _firestore.collection('companies').doc(widget.companyId).collection('requests').doc(requestId).update({
        'status': 'IN_PROGRESS',
        'rideStartTime': Timestamp.fromDate(startTime), // ✅ تغيير مهم
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
      _showSuccessSnackBar('Ride started successfully!');
      await _refreshData();

    } catch (e) {
      debugPrint('❌ Error starting ride: $e');
      _showErrorSnackBar('Error starting ride: $e');
    }
  }
  Future<void> _startRideWithManualVehicle(String requestId) async {
    try {
      final startTime = DateTime.now();

      // ✅ استخدم Timestamp.fromDate هنا أيضاً
      await _firestore.collection('companies').doc(widget.companyId).collection('requests').doc(requestId).update({
        'status': 'IN_PROGRESS',
        'rideStartTime': Timestamp.fromDate(startTime), // ✅ تغيير مهم
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
      _showSuccessSnackBar('Ride started with manual vehicle!');

      _manualModelController.clear();
      _manualPlateController.clear();
      _manualTypeController.text = 'Car';

      await _refreshData();

    } catch (e) {
      debugPrint('❌ Error starting ride with manual vehicle: $e');
      _showErrorSnackBar('Error starting ride: $e');
    }
  }
  // ==============================================
  // 🔧 UTILITY METHODS
  // ==============================================

  Future<void> _refreshData() async {
    await Future.wait<void>([
      _loadDriverRequests(),
      _loadAvailableVehicles(),
      _loadTotalStatistics(),
    ]);
  }

  String _calculateSuccessRate() {
    if (_totalAssignedRides == 0) return '100%';
    final rate = (_totalCompletedRides / _totalAssignedRides * 100).toInt();
    return '$rate%';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showScheduledDateError(DateTime scheduledDate) {
    final formattedDate = '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}';
    final formattedTime = '${scheduledDate.hour.toString().padLeft(2, '0')}:${scheduledDate.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.schedule, color: Colors.orange),
            SizedBox(width: 8),
            Text('Scheduled Request'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cannot start this ride now',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('This request is scheduled for:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date: $formattedDate', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Time: $formattedTime', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can start the ride only on the scheduled date',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
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

  void _showRequestDetails(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailItem('Request ID', request['id'].substring(0, 8)),
              _buildDetailItem('Status', request['status']),
              _buildDetailItem('Priority', request['priority'] ?? 'Normal'),
              _buildDetailItem('From', request['fromLocation'] ?? 'N/A'),
              _buildDetailItem('To', request['toLocation'] ?? 'N/A'),
              _buildDetailItem('Department', request['department'] ?? 'N/A'),
              if (request['details'] != null)
                _buildDetailItem('Details', request['details']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // ==============================================
  // 👤 DRIVER PROFILE & ACTIVATION
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

      _showSuccessSnackBar('Driver account activated successfully');

    } catch (e) {
      debugPrint('❌ Error creating driver record: $e');
      _showErrorSnackBar('Error activating account: $e');
    }
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
                  onPressed: _refreshData,
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
      return _buildEmptyState(
        icon: Icons.assignment_turned_in_outlined,
        title: 'No Active Requests',
        description: 'You will see new ride requests here when they are assigned to you.',
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
      return _buildEmptyState(
        icon: Icons.history,
        title: 'No Completed Rides',
        description: 'Completed rides will appear here.',
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

  Widget _buildCompletedRequestCard(Map<String, dynamic> request) {
    final requestId = request['id'];
    final from = request['fromLocation'] as String? ?? 'N/A';
    final to = request['toLocation'] as String? ?? 'N/A';
    final department = request['department'] as String? ?? 'N/A';
    final requesterName = request['requesterName'] as String? ?? 'Unknown';
    final rideDuration = request['rideDuration'] != null
        ? '${(request['rideDuration'] as int) ~/ 60} minutes'
        : 'N/A';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
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
              _buildRequesterInfo(requesterName, department),
              const SizedBox(height: 8),
              _buildLocationRow(Icons.location_on, 'From', from, Colors.green),
              _buildLocationRow(Icons.flag, 'To', to, Colors.red),
              _buildLocationRow(Icons.timer, 'Duration', rideDuration, Colors.purple),
            ],
          ),
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
      _showSuccessSnackBar('Logged out successfully');

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint('❌ Error logging out: $e');
      _showErrorSnackBar('Error logging out: $e');
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
  // 🎯 QUICK TRANSFER DIALOG
  // ==============================================

  Future<void> _showQuickTransferDialog() async {
    final transferableRequests = _activeRequests.where((request) {
      return request['status'] == 'ASSIGNED';
    }).toList();

    if (transferableRequests.isEmpty) {
      _showInfoSnackBar('No transferable requests available');
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

  // ==============================================
  // 📱 ADDITIONAL FEATURES
  // ==============================================

  void _showNotifications() {
    _showInfoSnackBar('Notifications feature coming soon!');
  }

  void _showRideHistory() {
    _showInfoSnackBar('Ride history feature coming soon!');
  }

  void _showStatistics() {
    _showInfoSnackBar('Detailed statistics feature coming soon!');
  }

  void _showSettings() {
    _showInfoSnackBar('Settings feature coming soon!');
  }

  void _showHelp() {
    _showInfoSnackBar('Help & support feature coming soon!');
  }

  // ==============================================
  // 🏗️ MAIN BUILD
  // ==============================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Driver Dashboard'),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (_activeRequests.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                onPressed: _showQuickTransferDialog,
                tooltip: 'Quick Transfer',
              ),
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: _showStatistics,
              tooltip: 'Statistics',
            ),
          ],
        ),
        drawer: _buildModernDrawer(),
        body: Column(
          children: [
            if (!_isLocationServiceEnabled && _driverProfileExists)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: _warningColor,
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location services disabled - Manager cannot track your location',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? _buildLoadingScreen()
                  : _driverProfileExists
                  ? _buildDashboardContent()
                  : _buildActivationView(),
            ),
          ],
        ),
        floatingActionButton: _activeRequests.isNotEmpty ? _buildFloatingActionButton() : null,
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: _primaryColor),
        const SizedBox(height: 16),
        Text(
          'Loading your dashboard...',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _showMyRequests,
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      child: Badge(
        label: Text(_activeRequests.length.toString()),
        isLabelVisible: _activeRequests.isNotEmpty,
        child: const Icon(Icons.list_alt),
      ),
    );
  }

  Drawer _buildModernDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryColor, Colors.blue.shade600],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Icon(Icons.person, size: 30, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.userName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _auth.currentUser?.email ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            icon: Icons.dashboard,
            title: 'Dashboard',
            onTap: () => Navigator.pop(context),
          ),
          _buildDrawerItem(
            icon: Icons.assignment,
            title: 'My Requests',
            badge: _activeRequests.length,
            onTap: () {
              Navigator.pop(context);
              _showMyRequests();
            },
          ),
          _buildDrawerItem(
            icon: Icons.history,
            title: 'Ride History',
            onTap: _showRideHistory,
          ),
          _buildDrawerItem(
            icon: Icons.bar_chart,
            title: 'Statistics',
            onTap: _showStatistics,
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.settings,
            title: 'Settings',
            onTap: _showSettings,
          ),
          _buildDrawerItem(
            icon: Icons.help,
            title: 'Help & Support',
            onTap: _showHelp,
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Logout',
            color: _errorColor,
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    int? badge,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? _primaryColor),
      title: Text(title, style: TextStyle(color: color ?? Colors.black87)),
      trailing: badge != null && badge > 0
          ? Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _primaryColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          badge.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      )
          : null,
      onTap: onTap,
    );
  }
}