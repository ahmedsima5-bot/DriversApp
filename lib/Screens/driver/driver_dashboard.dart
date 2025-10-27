import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/simple_notification_service.dart';
import '../../providers/language_provider.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart'; // 🔥 مضافة

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

  // 🔥 متغيرات تتبع الموقع الجديدة
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isLocationServiceEnabled = true; // نفترض أنها تعمل حتى نتحقق

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

  // 🔥 دالة الترجمة الأساسية
  String _translate(String key, BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final String language = languageProvider.currentLanguage;

    final Map<String, Map<String, String>> translations = {
      'location_service_disabled': {'ar': '⚠️ خدمة الموقع مغلقة. لن يتمكن المدير من تتبعك.', 'en': '⚠️ Location service is disabled. The manager will not be able to track you.'},
      'notes': {'ar': 'ملاحظات', 'en': 'Notes'},
      'welcome': {'ar': 'مرحباً بك', 'en': 'Welcome'},
      'account_active_ready': {'ar': 'Online', 'en': 'Account active and ready'},
      'trip_route': {'ar': 'مسار الرحلة', 'en': 'Trip Route'},
      'from': {'ar': 'من', 'en': 'From'},
      'to': {'ar': 'إلى', 'en': 'To'},
      'urgent': {'ar': 'عاجل', 'en': 'Urgent'},
      'performance_report': {'ar': 'تقرير الأداء', 'en': 'Performance Report'},
      'show_my_requests': {'ar': 'عرض طلباتي', 'en': 'Show My Requests'},
      'request': {'ar': 'طلب', 'en': 'Request'},
      'assigned': {'ar': 'مُعيّن', 'en': 'Assigned'},
      'in_progress': {'ar': 'قيد التنفيذ', 'en': 'In Progress'},
      'completed': {'ar': 'مكتمل', 'en': 'Completed'},
      'ride_duration': {'ar': 'مدة الرحلة', 'en': 'Ride Duration'},
      'department': {'ar': 'القسم', 'en': 'Department'},
      'start_ride': {'ar': 'بدء الرحلة', 'en': 'Start Ride'},
      'complete_ride': {'ar': 'إنهاء الرحلة', 'en': 'Complete Ride'},
      'driver_dashboard': {'ar': 'لوحة السائق', 'en': 'Driver Dashboard'},
      'activate_driver_account': {'ar': 'تفعيل حساب السائق', 'en': 'Activate Driver Account'},
      'activate_account_to_start': {'ar': 'قم بتفعيل الحساب لبدء العمل', 'en': 'Activate account to start working'},
      'refresh_requests': {'ar': 'تحديث الطلبات', 'en': 'Refresh Requests'},
      'profile': {'ar': 'بياناتي', 'en': 'Profile'},
      'logout': {'ar': 'تسجيل الخروج', 'en': 'Logout'},
      'manual': {'ar': 'يدوي', 'en': 'Manual'},
      'select_vehicle': {'ar': 'اختر المركبة', 'en': 'Select Vehicle'},
      'choose_vehicle_for_ride': {'ar': 'اختر المركبة للرحلة', 'en': 'Choose vehicle for ride'},
      'no_vehicles_available': {'ar': 'لا توجد مركبات متاحة', 'en': 'No vehicles available'},
      'other_vehicle': {'ar': 'مركبة أخرى', 'en': 'Other Vehicle'},
      'enter_vehicle_info': {'ar': 'أدخل معلومات المركبة', 'en': 'Enter Vehicle Info'},
      'vehicle_model': {'ar': 'موديل المركبة', 'en': 'Vehicle Model'},
      'plate_number': {'ar': 'رقم اللوحة', 'en': 'Plate Number'},
      'vehicle_type': {'ar': 'نوع المركبة', 'en': 'Vehicle Type'},
      'cancel': {'ar': 'إلغاء', 'en': 'Cancel'},
      'enter_vehicle_info_required': {'ar': 'يرجى إدخال معلومات المركبة', 'en': 'Please enter vehicle information'},
      'no_requests': {'ar': 'لا توجد طلبات', 'en': 'No Requests'},
      'no_assigned_requests': {'ar': 'لا توجد طلبات مخصصة لك حالياً', 'en': 'No requests assigned to you currently'},
      'my_requests': {'ar': 'طلباتي', 'en': 'My Requests'},
      'total_requests': {'ar': 'إجمالي الطلبات', 'en': 'Total Requests'},
      'close': {'ar': 'إغلاق', 'en': 'Close'},
      'refresh': {'ar': 'تحديث', 'en': 'Refresh'},
      'no_requests_currently': {'ar': 'لا توجد طلبات حالياً', 'en': 'No requests currently'},
      'requests_will_appear_here_when_assigned': {'ar': 'ستظهر الطلبات هنا عندما يتم تعيينها لك', 'en': 'Requests will appear here when assigned to you'},
      'name': {'ar': 'الاسم', 'en': 'Name'},
      'email': {'ar': 'البريد الإلكتروني', 'en': 'Email'},
      'driver_id': {'ar': 'رقم السائق', 'en': 'Driver ID'},
      'status': {'ar': 'الحالة', 'en': 'Status'},
      'driver_linked_to_hr': {'ar': 'الموارد البشرية', 'en': 'Driver linked to HR'},
      'completed_rides': {'ar': 'الرحلات المكتملة', 'en': 'Completed Rides'},
      'not_specified': {'ar': 'غير محدد', 'en': 'Not specified'},
      'ok': {'ar': 'موافق', 'en': 'OK'},
    };

    return translations[key]?[language] ?? key;
  }

  // 🔥 دالة الترجمة التلقائية الحقيقية
  Future<String> _translateDynamicContent(String text, BuildContext context) async {
    if (text.isEmpty) return text;

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final String targetLanguage = languageProvider.currentLanguage;

    if (targetLanguage == 'ar' || text.trim().isEmpty) {
      return text;
    }

    try {
      // 🔥 استخدام LibreTranslate API المجاني
      final url = Uri.parse('https://libretranslate.de/translate');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'q': text, 'source': 'en', 'target': 'ar', 'format': 'text'}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        // تم تأمين الوصول إلى `data` باستخدام `?[]` و `??`
        final translatedText = data['translatedText'] ?? text;
        debugPrint('✅ Translated: "$text" -> "$translatedText"');
        return translatedText;
      } else {
        debugPrint('❌ Translation error: ${response.statusCode}');
        return text;
      }
    } catch (e) {
      debugPrint('❌ Translation failed: $e');
      return text;
    }
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
    _positionStreamSubscription?.cancel(); // 🔥 إيقاف تتبع الموقع
    _activeTimers.forEach((key, timer) => timer.cancel());
    _activeTimers.clear();
    _manualModelController.dispose();
    _manualPlateController.dispose();
    _manualTypeController.dispose();
    super.dispose();
  }

  // ===================================================================
  // 🔥 دوال تتبع الموقع
  // ===================================================================

  // 🔥 التحقق من أذونات الموقع وتفعيل التتبع
  Future<void> _checkLocationPermissionsAndStart() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. التحقق من تفعيل خدمة الموقع في الجهاز
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLocationServiceEnabled = false);
      return;
    }
    setState(() => _isLocationServiceEnabled = true);

    // 2. التحقق من الأذونات
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        // فشل في الحصول على الإذن
        return;
      }
    }

    // 3. بدء التحديث إذا كانت الأذونات جيدة
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      _startLocationUpdates();
    }
  }

  // 🔥 بدء الاستماع وتحديث الموقع في Firestore
  void _startLocationUpdates() {
    if (_driverId == null || _companyId == null) return;

    // ❌ إيقاف أي اشتراك سابق لتجنب التكرار
    _positionStreamSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // تحديث الموقع كل 10 أمتار تحرك
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

  // 🔥 دالة تحديث الموقع في Firestore
  Future<void> _updateDriverLocationInFirestore(Position position) async {
    if (_driverId == null || _companyId == null) return;

    try {
      await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('drivers')
          .doc(_driverId)
          .update({
        // 🔥 هذا هو الحقل الذي تبحث عنه صفحة الإدارة
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
  // 🔥 بقية الدوال
  // ===================================================================

  // 🔥 تحميل السيارات المتاحة
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
          // تأمين تحويل البيانات
          final data = doc.data() as Map<String, dynamic>? ?? {};
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
  String _formatDuration(Duration duration, BuildContext context) {
    final currentLanguage = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (currentLanguage == 'ar') {
      if (hours > 0) {
        return '$hours ساعة $minutes دقيقة $seconds ثانية';
      } else if (minutes > 0) {
        return '$minutes دقيقة $seconds ثانية';
      } else {
        return '$seconds ثانية';
      }
    } else {
      if (hours > 0) {
        return '${hours}h ${minutes}m ${seconds}s';
      } else if (minutes > 0) {
        return '${minutes}m ${seconds}s';
      } else {
        return '${seconds}s';
      }
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
          // تأمين تحويل البيانات
          final request = change.doc.data() as Map<String, dynamic>? ?? {};
          final requestId = change.doc.id;
          // استخدام `?[]` و `??` للوصول الآمن
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

          // 🔥 بدأ تتبع الموقع هنا
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

        SimpleNotificationService.notifySuccess(context, 'تم تفعيل حساب السائق بنجاح');

        debugPrint('✅ Driver record created: $driverId');
        _loadDriverRequests();
        _startRequestsListener();

        // 🔥 بدأ تتبع الموقع بعد الإنشاء
        _checkLocationPermissionsAndStart();
      }
    } catch (e) {
      debugPrint('❌ Error creating driver record: $e');
      SimpleNotificationService.notifyError(context, 'خطأ في تفعيل الحساب: $e');
    }
  }

  // 🔥 عرض اختيار السيارة
  Future<void> _showVehicleSelectionDialog(String requestId, BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.directions_car, color: Colors.blue),
            const SizedBox(width: 8),
            Text(_translate('select_vehicle', context)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _translate('choose_vehicle_for_ride', context),
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
                    _translate('no_vehicles_available', context),
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
                    // استخدام الوصول الآمن للبيانات
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
              title: Text(_translate('other_vehicle', context)),
              onTap: () {
                Navigator.pop(context);
                _showManualVehicleDialog(requestId, context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_translate('cancel', context)),
          ),
        ],
      ),
    );
  }

  // 🔥 عرض نافذة إدخال السيارة يدوياً
  Future<void> _showManualVehicleDialog(String requestId, BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.directions_car, color: Colors.orange),
                const SizedBox(width: 8),
                Text(_translate('enter_vehicle_info', context)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _manualModelController,
                    decoration: InputDecoration(
                      labelText: _translate('vehicle_model', context),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.directions_car),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _manualPlateController,
                    decoration: InputDecoration(
                      labelText: _translate('plate_number', context),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.confirmation_number),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _manualTypeController,
                    decoration: InputDecoration(
                      labelText: _translate('vehicle_type', context),
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
                child: Text(_translate('cancel', context)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_manualModelController.text.isEmpty || _manualPlateController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_translate('enter_vehicle_info_required', context)),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  _startRideWithManualVehicle(requestId);
                },
                child: Text(_translate('start_ride', context)),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🔥 بدء الرحلة مع سيارة محددة
  Future<void> _startRideWithVehicle(String requestId, Map<String, dynamic> vehicle) async {
    if (_companyId == null) return;
    try {
      final startTime = DateTime.now();

      // تأمين الوصول باستخدام `?? 'N/A'`
      final vehicleId = vehicle['id'] ?? 'N/A';
      final model = vehicle['model'] ?? 'غير محدد';
      final plateNumber = vehicle['plateNumber'] ?? 'غير محدد';
      final type = vehicle['type'] ?? 'سيارة';

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

      // التحقق من صلاحية vehicleId قبل التحديث
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
      SimpleNotificationService.notifyError(context, 'خطأ في بدء الرحلة: $e');
    }
  }

  // 🔥 بدء الرحلة مع سيارة يدوية
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
      _manualTypeController.text = 'سيارة';

      debugPrint('🚗 Ride started: $requestId with manual vehicle');
      _loadDriverRequests();
    } catch (e) {
      debugPrint('❌ Error starting ride with manual vehicle: $e');
      SimpleNotificationService.notifyError(context, 'خطأ في بدء الرحلة: $e');
    }
  }

  // 🔥 بدء الرحلة (الدالة الرئيسية)
  Future<void> _startRide(String requestId) async {
    await _showVehicleSelectionDialog(requestId, context);
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
          // إذا لم يتم تحديد الشركة، توقف عن التحميل.
          setState(() { _loading = false; });
          return;
        }

        // 🔥 الحصول على تاريخ اليوم فقط
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
          // تأمين تحويل البيانات
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
            content: Text('خطأ في تحميل الطلبات: $e'),
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

      // تأمين تحويل البيانات
      final requestData = requestDoc.data() as Map<String, dynamic>? ?? {};
      // استخدام `?[]` و `?? {}` للوصول الآمن للـ Map
      final vehicleInfo = requestData['vehicleInfo'] as Map<String, dynamic>? ?? {};
      // استخدام `?[]` و `??` للوصول الآمن للحقول
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

      // التحقق من vehicleId و source قبل التحديث
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
      SimpleNotificationService.notifyError(context, 'خطأ في إنهاء الرحلة: $e');
    }
  }

  Future<void> _logout() async {
    try {
      // التحقق من القيمة الفارغة قبل استخدامها
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

      SimpleNotificationService.notifySuccess(context, 'تم تسجيل الخروج بنجاح');

      // يجب استخدام Navigator.pushReplacementNamed لضمان العودة لصفحة تسجيل الدخول
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      debugPrint('❌ Error logging out: $e');
      SimpleNotificationService.notifyError(context, 'خطأ في تسجيل الخروج: $e');
    }
  }

  void _showProfile(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person, color: Colors.orange),
            const SizedBox(width: 8),
            Text(_translate('profile', context)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileRow('${_translate('name', context)}:', widget.userName),
            _buildProfileRow('${_translate('email', context)}:', _auth.currentUser?.email ?? ''),
            _buildProfileRow('${_translate('driver_id', context)}:', _driverId ?? _translate('not_specified', context)),
            _buildProfileRow('${_translate('status', context)}:', _translate('driver_linked_to_hr', context)),
            if (_driverProfileExists)
              _buildProfileRow(
                  '${_translate('completed_rides', context)}:',
                  // استخدام `r.data()` بأمان ثم الوصول إلى `['status']`
                  _requests
                      .where((r) {
                    final data = r.data() as Map<String, dynamic>? ?? {};
                    return data['status'] == 'COMPLETED';
                  })
                      .length
                      .toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_translate('ok', context)),
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

  void _showMyRequests(BuildContext context) {
    if (_requests.isEmpty) {
      _showNoRequestsDialog(context);
    } else {
      _showRequestsBottomSheet(context);
    }
  }

  void _showNoRequestsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.inventory_2, color: Colors.orange),
              const SizedBox(width: 8),
              Text(_translate('no_requests', context)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_translate('no_assigned_requests', context)),
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
                  child: Text(_translate('activate_driver_account', context)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_translate('close', context)),
            ),
          ],
        );
      },
    );
  }

  void _showRequestsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        // فلترة الطلبات التي لم تكتمل بعد
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
                title: Text(_translate('my_requests', context)),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadDriverRequests,
                    tooltip: _translate('refresh', context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: _translate('close', context),
                  ),
                ],
                bottom: TabBar(
                  tabs: [
                    Tab(text: 'الطلبات النشطة (${activeRequests.length})'),
                    Tab(text: 'الطلبات المكتملة (${completedRequests.length})'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  _buildRequestsList(activeRequests, context),
                  _buildRequestsList(completedRequests, context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestsList(List<QueryDocumentSnapshot> requests, BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assignment_turned_in_outlined, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _translate('no_requests_currently', context),
                style: const TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _translate('requests_will_appear_here_when_assigned', context),
                style: const TextStyle(fontSize: 14, color: Colors.grey),
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
        return _buildRequestCard(doc.id, data, context);
      },
    );
  }

  Widget _buildRequestCard(String requestId, Map<String, dynamic> requestData, BuildContext context) {
    final status = requestData['status'] as String? ?? 'UNKNOWN';

    // 🔥 تم التعديل: استخدام fromLocation بدلاً من fromLocationName
    final from = requestData['fromLocation'] as String? ?? 'N/A';

    // 🔥 تم التعديل: استخدام toLocation بدلاً من toLocationName
    final to = requestData['toLocation'] as String? ?? 'N/A';

    // 🔥 تم التعديل: استخدام department بدلاً من requesterDepartment
    final department = requestData['department'] as String? ?? 'N/A';

    // حقل isUrgent غير موجود في بياناتك، لكن priority موجود.
    // سنعتمد على priority:
    final priority = requestData['priority'] as String? ?? 'Normal';
    final isUrgent = priority == 'Urgent';

    // حقل notes غير موجود، لكن details موجود:
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
        statusText = _translate('assigned', context);
        break;
      case 'IN_PROGRESS':
        statusColor = Colors.orange.shade700;
        statusIcon = Icons.schedule;
        statusText = _translate('in_progress', context);
        break;
      case 'COMPLETED':
        statusColor = Colors.green.shade700;
        statusIcon = Icons.check_circle;
        statusText = _translate('completed', context);
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
                    label: Text(_translate('urgent', context)),
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
            _buildTripDetailRow(Icons.location_on, _translate('from', context), from, context, color: Colors.green),
            _buildTripDetailRow(Icons.flag, _translate('to', context), to, context, color: Colors.red),
            _buildTripDetailRow(Icons.business, _translate('department', context), department, context),
            if (notes.isNotEmpty)
              _buildTripDetailRow(Icons.notes, _translate('notes', context), notes, context),

            if (isInProgress)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.purple, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_translate('ride_duration', context)}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // 🔥 عرض مدة الرحلة المُحدّثة
                    Text(
                      _formatDuration(_rideDurations[requestId] ?? Duration.zero, context),
                      style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            // ------------------------------------------------------------------
            // أزرار الإجراءات
            // ------------------------------------------------------------------
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == 'ASSIGNED')
                  ElevatedButton.icon(
                    onPressed: _loading ? null : () => _startRide(requestId),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(_translate('start_ride', context)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (isInProgress)
                  ElevatedButton.icon(
                    onPressed: _loading ? null : () => _completeRide(requestId),
                    icon: const Icon(Icons.stop),
                    label: Text(_translate('complete_ride', context)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (isCompleted)
                  TextButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.history, color: Colors.grey),
                    label: Text(_translate('completed', context)),
                  ),
              ],
            ),
            // ------------------------------------------------------------------
          ],
        ),
      ),
    );
  }

  Widget _buildTripDetailRow(IconData icon, String label, String value, BuildContext context, {Color color = Colors.blueGrey}) {
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
                FutureBuilder<String>(
                  future: _translateDynamicContent(value, context),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Text(value); // عرض النص الأصلي أثناء التحميل
                    }
                    return Text(
                      snapshot.data ?? value,
                      style: const TextStyle(fontSize: 14),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_translate('driver_dashboard', context)),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      drawer: _buildDrawer(context),
      body: Column(
        children: [
          // 🔥 شريط حالة الموقع
          if (!_isLocationServiceEnabled && _driverProfileExists)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.yellow.shade800,
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _translate('location_service_disabled', context),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.start,
                    ),
                  ),
                ],
              ),
            ),
          // ------------------------------------

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _driverProfileExists
                ? _buildDashboardContent(context)
                : _buildActivationView(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context) {
    final activeRequestsCount = _requests.where((r) {
      final data = r.data() as Map<String, dynamic>? ?? {};
      return data['status'] != 'COMPLETED';
    }).length;

    return RefreshIndicator(
      onRefresh: _loadDriverRequests,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.green.shade50,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.green.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_translate('welcome', context), style: TextStyle(fontSize: 14, color: Colors.green.shade800)),
                  const SizedBox(height: 4),
                  Text(
                    widget.userName,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _translate('account_active_ready', context),
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            _translate('my_requests', context),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 10),

          // عرض زر طلباتي
          ListTile(
            leading: const Icon(Icons.assignment, color: Colors.blue),
            title: Text(_translate('show_my_requests', context)),
            trailing: Chip(
              label: Text(
                activeRequestsCount.toString(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: activeRequestsCount > 0 ? Colors.orange : Colors.grey,
            ),
            onTap: () => _showMyRequests(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.blue.shade100),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            _translate('performance_report', context),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 10),

          // كروت الأداء
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  context,
                  _translate('total_requests', context),
                  _requests.length.toString(),
                  Icons.all_inbox,
                  Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  context,
                  _translate('completed_rides', context),
                  _requests.where((r) {
                    final data = r.data() as Map<String, dynamic>? ?? {};
                    return data['status'] == 'COMPLETED';
                  }).length.toString(),
                  Icons.check_circle,
                  Colors.green.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivationView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 80, color: Colors.red.shade400),
            const SizedBox(height: 20),
            Text(
              _translate('activate_driver_account', context),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _translate('activate_account_to_start', context),
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _loading ? null : _createDriverProfile,
              icon: const Icon(Icons.power_settings_new),
              label: Text(_translate('activate_driver_account', context)),
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

  Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, Color color) {
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

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(_auth.currentUser?.email ?? 'N/A'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.blue.shade800, size: 50),
            ),
            decoration: BoxDecoration(
              color: Colors.blue.shade800,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: Text(_translate('driver_dashboard', context)),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(_translate('profile', context)),
            onTap: () {
              Navigator.pop(context);
              _showProfile(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: Text(_translate('my_requests', context)),
            onTap: () {
              Navigator.pop(context);
              _showMyRequests(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(_translate('logout', context), style: const TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}