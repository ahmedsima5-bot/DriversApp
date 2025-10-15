import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDriverRequests();
  }

  Future<void> _loadDriverRequests() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // البحث عن السائق في جميع الشركات
        final driversSnapshot = await _firestore
            .collectionGroup('drivers')
            .where('email', isEqualTo: user.email)
            .get();

        if (driversSnapshot.docs.isNotEmpty) {
          final driverDoc = driversSnapshot.docs.first;
          final driverId = driverDoc.id;
          final pathParts = driverDoc.reference.path.split('/');
          final companyId = pathParts[1];

          print('🎯 تم العثور على السائق: $driverId في الشركة: $companyId');

          // جلب طلبات السائق
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

          print('✅ عدد الطلبات: ${_requests.length}');
        } else {
          setState(() { _loading = false; });
          print('❌ لم يتم العثور على بيانات السائق');
        }
      }
    } catch (e) {
      setState(() { _loading = false; });
      print('❌ خطأ في جلب الطلبات: $e');
    }
  }

  // دالة عرض الطلبات - معدلة تماماً
  void _showMyRequests(BuildContext context) {
    print('🎯 TEST: تم النقر على زر عرض طلباتي');
    print('📊 عدد الطلبات: ${_requests.length}');

    // اختبار بسيط أولاً
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('الزر شغال! عدد الطلبات: ${_requests.length}'),
        duration: Duration(seconds: 2),
      ),
    );

    if (_requests.isEmpty) {
      print('📝 فتح نافذة لا توجد طلبات');
      _showNoRequestsDialog(context);
    } else {
      print('📝 فتح صفحة الطلبات');
      _showRequestsBottomSheet(context);
    }
  }

  void _showNoRequestsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: Text('لا توجد طلبات'),
          content: Text('لا توجد طلبات مخصصة لك حالياً.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                print('✅ تم إغلاق النافذة');
              },
              child: Text('حسناً'),
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'طلباتي',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      Navigator.pop(context);
                      print('✅ تم إغلاق صفحة الطلبات');
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Requests Count
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list_alt, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'إجمالي الطلبات: ${_requests.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Requests List
              Expanded(
                child: ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    final data = request.data() as Map<String, dynamic>;

                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getStatusColor(data['status']).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getStatusIcon(data['status']),
                            color: _getStatusColor(data['status']),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'طلب #${request.id.substring(0, 6)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text('📍 ${data['fromLocation'] ?? 'غير محدد'}'),
                            Text('🎯 ${data['toLocation'] ?? 'غير محدد'}'),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(data['status']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                data['status'] ?? 'معلق',
                                style: TextStyle(
                                  color: _getStatusColor(data['status']),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey,
                          size: 16,
                        ),
                        onTap: () {
                          print('📋 فتح تفاصيل الطلب: ${request.id}');
                          _showRequestDetails(context, request.id, data);
                        },
                      ),
                    );
                  },
                ),
              ),

              // Close Button
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    print('✅ تم إغلاق صفحة الطلبات');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'إغلاق',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRequestDetails(BuildContext context, String requestId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('تفاصيل الطلب'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('رقم الطلب:', '${requestId.substring(0, 8)}'),
                _buildDetailRow('العميل:', data['customerName'] ?? 'غير محدد'),
                _buildDetailRow('من:', data['fromLocation'] ?? 'غير محدد'),
                _buildDetailRow('إلى:', data['toLocation'] ?? 'غير محدد'),
                _buildDetailRow('الحالة:', data['status'] ?? 'معلق'),
                if (data['assignedTime'] != null)
                  _buildDetailRow('وقت التعيين:', _formatDate(data['assignedTime'].toDate())),
                SizedBox(height: 16),

                // Action Buttons based on status
                if (data['status'] == 'مُعين للسائق')
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _acceptRequest(requestId);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('قبول الطلب'),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم قبول الطلب بنجاح'),
            backgroundColor: Colors.green,
          )
      );
      _loadDriverRequests();
    } catch (e) {
      print('❌ خطأ في قبول الطلب: $e');
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'مُعين للسائق': return Icons.assignment;
      case 'مقبول': return Icons.check_circle;
      case 'قيد التنفيذ': return Icons.directions_car;
      case 'مكتمل': return Icons.done_all;
      default: return Icons.pending;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'مُعين للسائق': return Colors.orange;
      case 'مقبول': return Colors.blue;
      case 'قيد التنفيذ': return Colors.purple;
      case 'مكتمل': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('شاشة السائق - مهامي اليومية'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDriverRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          // Welcome Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.orange[50]!, Colors.orange[100]!],
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.orange,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'مرحباً بك ${widget.userName}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'هنا ستظهر طلبات النقل المخصصة لك',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Notifications
          if (_requests.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              color: Colors.green[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_active, color: Colors.green),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لديك ${_requests.length} طلب',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      Text(
                        'اضغط على "عرض طلباتي" لمشاهدتها',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Main Content
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: Colors.orange))
                : _requests.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 20),
                  Text(
                    'لا توجد طلبات حالياً',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'سيتم عرض الطلبات هنا عندما يتم تخصيصها لك',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
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
                return Container(
                  margin: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getStatusColor(data['status']).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getStatusIcon(data['status']),
                        color: _getStatusColor(data['status']),
                      ),
                    ),
                    title: Text(
                      'طلب #${request.id.substring(0, 6)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        Text('${data['fromLocation']} → ${data['toLocation']}'),
                        SizedBox(height: 4),
                        Text(
                          data['status'] ?? 'معلق',
                          style: TextStyle(
                            color: _getStatusColor(data['status']),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showRequestDetails(context, request.id, data);
                    },
                  ),
                );
              },
            ),
          ),

          // Show Requests Button - WORKING VERSION
          Container(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                print('🎯 الزر تم النقر عليه!');
                _showMyRequests(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 55),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'عرض طلباتي',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}