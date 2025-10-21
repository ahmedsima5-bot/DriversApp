import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/dispatch_service.dart';

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

  @override
  void initState() {
    super.initState();
    _debugCheckDriverLocation();
    _checkDriverProfile();
    _loadDriverRequests();
  }

  Future<void> _checkDriverProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        debugPrint('👤 التحقق من وجود السائق...');

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

          debugPrint('✅ السائق موجود: $_driverId');
        } else {
          setState(() {
            _driverProfileExists = false;
          });
          debugPrint('❌ لا يوجد سجل للسائق - يحتاج التفعيل');
        }
      }
    } catch (e) {
      debugPrint('❌ خطأ في التحقق من السائق: $e');
    }
  }

  Future<void> _debugCheckDriverLocation() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        debugPrint('🔍 فحص مواقع السائق...');

        final rootDrivers = await _firestore
            .collection('drivers')
            .where('email', isEqualTo: user.email)
            .get();
        debugPrint('📍 السائقين في المستوى الرئيسي: ${rootDrivers.docs.length}');

        final correctDrivers = await _firestore
            .collection('companies')
            .doc('C001')
            .collection('drivers')
            .where('email', isEqualTo: user.email)
            .get();
        debugPrint('📍 السائقين في C001/drivers: ${correctDrivers.docs.length}');

        if (rootDrivers.docs.isNotEmpty) {
          debugPrint('⚠️ السائق موجود في المكان الخطأ!');
          debugPrint('💡 انقل السجل من /drivers إلى /companies/C001/drivers/');
        }
      }
    } catch (e) {
      debugPrint('❌ خطأ في الفحص: $e');
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 تم تفعيل حساب السائق بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );

        debugPrint('✅ تم إنشاء سجل السائق: $driverId');
        _loadDriverRequests();
      }
    } catch (e) {
      debugPrint('❌ خطأ في إنشاء سجل السائق: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تفعيل الحساب: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadDriverRequests() async {
    try {
      setState(() { _loading = true; });

      final user = _auth.currentUser;
      if (user != null) {
        debugPrint('👤 المستخدم الحالي: ${user.email}');

        final companyId = 'C001';
        final driversSnapshot = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('drivers')
            .where('email', isEqualTo: user.email)
            .get();

        debugPrint('🔍 عدد السائقين المطابقين: ${driversSnapshot.docs.length}');

        if (driversSnapshot.docs.isNotEmpty) {
          final driverDoc = driversSnapshot.docs.first;
          final driverId = driverDoc.id;
          final driverData = driverDoc.data();

          _driverId = driverId;
          _companyId = companyId;

          debugPrint('🎯 تم العثور على السائق: $driverId');
          debugPrint('📋 بيانات السائق: ${driverData['name']} - ${driverData['email']}');
          debugPrint('🟢 حالة السائق: online=${driverData['isOnline']}, available=${driverData['isAvailable']}');

          final requestsSnapshot = await _firestore
              .collection('companies')
              .doc(companyId)
              .collection('requests')
              .where('assignedDriverId', isEqualTo: driverId)
              .get();

          setState(() {
            _requests = requestsSnapshot.docs;
            _loading = false;
          });

          debugPrint('✅ عدد الطلبات المخصصة: ${_requests.length}');

          if (_requests.isEmpty) {
            debugPrint('🔍 فحص الطلبات المتاحة للتوزيع...');
            _checkAvailableRequests(companyId);
          }
        } else {
          setState(() { _loading = false; });
          debugPrint('❌ لم يتم العثور على بيانات السائق في الشركة C001');
        }
      }
    } catch (e) {
      setState(() { _loading = false; });
      debugPrint('❌ خطأ في جلب الطلبات: $e');
    }
  }

  Future<void> _checkAvailableRequests(String companyId) async {
    try {
      final availableRequests = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('requests')
          .where('status', whereIn: ['NEW', 'PENDING'])
          .get();

      debugPrint('🔍 الطلبات المتاحة للتوزيع: ${availableRequests.docs.length}');

      for (var doc in availableRequests.docs) {
        final data = doc.data();
        debugPrint('   - ${doc.id} : ${data['status']} (${data['fromLocation']} → ${data['toLocation']})');
      }
    } catch (e) {
      debugPrint('❌ خطأ في فحص الطلبات المتاحة: $e');
    }
  }

  Future<void> _debugDispatchSystem() async {
    try {
      debugPrint('🔍 تشغيل تشخيص نظام التوزيع...');
      final DispatchService dispatchService = DispatchService();
      await dispatchService.debugDispatchSystem('C001');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تشخيص نظام التوزيع - شاهد الـ logs'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      debugPrint('❌ خطأ في التشخيص: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التشخيص: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🚗 بدء الرحلة
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚗 بدأت الرحلة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      debugPrint('🚗 بدأت الرحلة: $requestId');
      _loadDriverRequests();
    } catch (e) {
      debugPrint('❌ خطأ في بدء الرحلة: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في بدء الرحلة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ إنهاء الرحلة
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إنهاء الرحلة بنجاح'),
          backgroundColor: Colors.blue,
        ),
      );

      debugPrint('✅ تم إنهاء الرحلة: $requestId');
      _loadDriverRequests();
    } catch (e) {
      debugPrint('❌ خطأ في إنهاء الرحلة: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إنهاء الرحلة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🚪 تسجيل الخروج
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

      Navigator.pushReplacementNamed(context, '/login');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الخروج بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('❌ خطأ في تسجيل الخروج: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تسجيل الخروج: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 👤 عرض الملف الشخصي
  void _showProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person, color: Colors.orange),
            SizedBox(width: 8),
            Text('الملف الشخصي'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileRow('الاسم:', widget.userName),
            _buildProfileRow('البريد:', _auth.currentUser?.email ?? ''),
            _buildProfileRow('رقم السائق:', _driverId ?? 'غير محدد'),
            _buildProfileRow('الحالة:', 'سائق - مرتبط بالموارد البشرية'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
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

  // 📋 عرض طلباتي
  void _showMyRequests() {
    debugPrint('🎯 تم النقر على زر عرض طلباتي');
    debugPrint('📊 عدد الطلبات: ${_requests.length}');

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
          title: const Row(
            children: [
              Icon(Icons.inventory_2, color: Colors.orange),
              SizedBox(width: 8),
              Text('لا توجد طلبات'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('لا توجد طلبات مخصصة لك حالياً.'),
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
                  child: const Text('تفعيل حساب السائق'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequestCard(String requestId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'ASSIGNED';
    final fromLocation = data['fromLocation'] ?? 'غير محدد';
    final toLocation = data['toLocation'] ?? 'غير محدد';

    Color statusColor = Colors.orange;
    String statusText = 'جديد';

    if (status == 'IN_PROGRESS') {
      statusColor = Colors.blue;
      statusText = 'قيد التنفيذ';
    } else if (status == 'COMPLETED') {
      statusColor = Colors.green;
      statusText = 'مكتمل';
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
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.local_shipping, color: statusColor, size: 20),
        ),
        title: Text(
          'طلب #${requestId.substring(0, 6)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('📍 $fromLocation'),
            Text('🎯 $toLocation'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
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
        trailing: _buildActionButtons(requestId, status),
        onTap: () => _showRequestDetails(requestId, data),
      ),
    );
  }

  Widget _buildActionButtons(String requestId, String status) {
    if (status == 'ASSIGNED') {
      return ElevatedButton(
        onPressed: () => _startRide(requestId),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text('بدء الرحلة'),
      );
    } else if (status == 'IN_PROGRESS') {
      return ElevatedButton(
        onPressed: () => _completeRide(requestId),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text('إنهاء الرحلة'),
      );
    } else {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
  }

  void _showRequestDetails(String requestId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'ASSIGNED';
    String statusText = 'مُعين';
    Color statusColor = Colors.orange;

    if (status == 'IN_PROGRESS') {
      statusText = 'قيد التنفيذ';
      statusColor = Colors.blue;
    } else if (status == 'COMPLETED') {
      statusText = 'مكتمل';
      statusColor = Colors.green;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: statusColor),
              const SizedBox(width: 8),
              const Text('تفاصيل الطلب'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('رقم الطلب:', requestId),
                _buildDetailRow('العميل:', data['customerName'] ?? 'غير محدد'),
                _buildDetailRow('من:', data['fromLocation'] ?? 'غير محدد'),
                _buildDetailRow('إلى:', data['toLocation'] ?? 'غير محدد'),
                _buildDetailRow('الحالة:', statusText),
                _buildDetailRow('الأولوية:', data['priority'] ?? 'عادي'),
                const SizedBox(height: 16),

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
                      ),
                      child: const Text('بدء الرحلة'),
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
                      ),
                      child: const Text('إنهاء الرحلة'),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
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
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  void _showRequestsBottomSheet() {
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
                  const Text(
                    'طلباتي',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
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
                      'إجمالي الطلبات: ${_requests.length}',
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
                      const Text('لا توجد طلبات', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    final data = request.data() as Map<String, dynamic>;
                    return _buildRequestCard(request.id, data);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إغلاق'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loadDriverRequests,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text('تحديث'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('شاشة السائق - مهامي اليومية'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDriverRequests,
            tooltip: 'تحديث الطلبات',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'profile') {
                _showProfile();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('الملف الشخصي'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('تسجيل خروج'),
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
                  child: const Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  'مرحباً بك ${widget.userName}',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                ),
                const SizedBox(height: 8),
                Text(
                  _driverProfileExists
                      ? 'حسابك مفعل وجاهز لاستقبال الطلبات'
                      : 'يجب تفعيل حساب السائق لبدء الاستخدام',
                  style: TextStyle(
                      fontSize: 16,
                      color: _driverProfileExists ? Colors.green : Colors.orange
                  ),
                ),
              ],
            ),
          ),

          // زر التفعيل إذا لم يكن السائق مفعل
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
                child: const Text(
                  'تفعيل حساب السائق',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // 🔥 زر تشخيص نظام التوزيع (للتطوير فقط)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ElevatedButton(
              onPressed: _debugDispatchSystem,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('تشخيص نظام التوزيع'),
            ),
          ),

          // باقي الواجهة...
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _requests.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text(
                    'لا توجد طلبات حالياً',
                    style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سيتم عرض الطلبات هنا عندما يتم تخصيصها لك',
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
                return _buildRequestCard(request.id, data);
              },
            ),
          ),

          // Buttons Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showMyRequests,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 55),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.list_alt),
                        SizedBox(width: 8),
                        Text('عرض طلباتي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
}