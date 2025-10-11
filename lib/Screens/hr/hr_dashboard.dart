import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/request_model.dart';
import '../../models/driver_model.dart';
import '../../services/dispatch_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HRDashboard extends StatefulWidget {
  final String companyId;
  const HRDashboard({required this.companyId, super.key});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
  late GoogleMapController mapController;
  Set<Marker> driverMarkers = {};
  final DispatchService _dispatchService = DispatchService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الموارد البشرية'),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildUrgentRequestsSection(context),
            const Divider(height: 30),
            _buildDriversOnlineSection(),
            const Divider(height: 30),
            _buildSummaryReportsSection(),
            const Divider(height: 30),
            _buildDepartmentsDemandSection(),
            const Divider(height: 30),
            _buildDriversMapSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentRequestsSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .where('priority', isEqualTo: 'عاجل')
          .where('status', isEqualTo: 'بانتظار موافقة الموارد البشرية')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('خطأ في تحميل البيانات'),
          );
        }

        final requests = snapshot.data!.docs
            .map((doc) => Request.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ExpansionTile(
            title: Text(
              'طلبات عاجلة تحتاج موافقة (${requests.length})',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            children: requests.isEmpty
                ? [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا توجد طلبات عاجلة'),
              )
            ]
                : requests
                .map((r) => Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text(
                  r.purpose,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'القسم: ${r.department}\nبواسطة: ${r.requesterName}\nالتفاصيل: ${r.details}',
                ),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      tooltip: 'الموافقة',
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('companies')
                              .doc(widget.companyId)
                              .collection('requests')
                              .doc(r.requestId)
                              .update({
                            'status': 'معلق',
                            'hrApprovalTime': DateTime.now(),
                          });

                          final approvedRequestSnap =
                          await FirebaseFirestore.instance
                              .collection('companies')
                              .doc(widget.companyId)
                              .collection('requests')
                              .doc(r.requestId)
                              .get();

                          if (approvedRequestSnap.exists) {
                            final approvedRequest = Request.fromMap(
                                approvedRequestSnap.data()
                                as Map<String, dynamic>);
                            await _dispatchService.autoAssignDriverFair(
                                widget.companyId, approvedRequest);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'تمت الموافقة وتوزيع الطلب على السائق'),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('خطأ: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      tooltip: 'الرفض',
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('companies')
                              .doc(widget.companyId)
                              .collection('requests')
                              .doc(r.requestId)
                              .update({
                            'status': 'مرفوض',
                            'rejectionTime': DateTime.now(),
                          });

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم رفض الطلب'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('خطأ: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildDriversOnlineSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('drivers')
          .where('isOnline', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('خطأ في تحميل البيانات'),
          );
        }

        final drivers = snapshot.data!.docs
            .map((doc) => Driver.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ExpansionTile(
            title: Text(
              'السائقون المتصلون (${drivers.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            children: drivers.isEmpty
                ? [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا يوجد سائقون متصلون'),
              )
            ]
                : drivers
                .map((d) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(
                  d.isAvailable ? Icons.check_circle : Icons.directions_car,
                  color: d.isAvailable ? Colors.green : Colors.orange,
                ),
                title: Text(
                  d.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'الحالة: ${d.isAvailable ? "متاح" : "مشغول"} | '
                      'المشاوير: ${d.completedRides} | '
                      'الأداء: ${d.performanceScore.toStringAsFixed(2)}/5',
                ),
              ),
            ))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildSummaryReportsSection() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('خطأ في تحميل البيانات'),
          );
        }

        final requests = snapshot.data!.docs
            .map((doc) => Request.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        final today = DateTime.now();
        final todayRequests = requests.where((r) {
          final reqDate = r.requestedTime;
          return reqDate.year == today.year &&
              reqDate.month == today.month &&
              reqDate.day == today.day;
        }).length;

        final monthRequests = requests.where((r) {
          final reqDate = r.requestedTime;
          return reqDate.year == today.year && reqDate.month == today.month;
        }).length;

        final completedRequests =
            requests.where((r) => r.status == 'مكتمل').length;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ExpansionTile(
            title: const Text(
              'التقارير اليومية والشهرية',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.today, color: Colors.blue),
                  title: const Text('طلبات اليوم'),
                  trailing: Text(
                    todayRequests.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_month, color: Colors.green),
                  title: const Text('طلبات هذا الشهر'),
                  trailing: Text(
                    monthRequests.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.purple),
                  title: const Text('الطلبات المكتملة'),
                  trailing: Text(
                    completedRequests.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
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

  Widget _buildDepartmentsDemandSection() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('خطأ في تحميل البيانات'),
          );
        }

        final requests = snapshot.data!.docs
            .map((doc) => Request.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        final Map<String, int> departmentCounts = {};
        for (var r in requests) {
          departmentCounts[r.department] =
              (departmentCounts[r.department] ?? 0) + 1;
        }

        final sortedDept = departmentCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ExpansionTile(
            title: const Text(
              'ملخص طلبات الأقسام',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            children: sortedDept.isEmpty
                ? [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا توجد طلبات'),
              )
            ]
                : sortedDept
                .map((e) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.business, color: Colors.teal),
                title: Text(e.key),
                trailing: Text(
                  '${e.value} طلب',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildDriversMapSection() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('drivers')
            .where('isOnline', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا يوجد سائقون متصلون'));
          }

          final drivers = snapshot.data!.docs
              .map((doc) => Driver.fromMap(doc.data() as Map<String, dynamic>))
              .where((d) => d.currentLocation != null)
              .toList();

          if (drivers.isEmpty) {
            return const Center(child: Text('لا توجد بيانات موقع للسائقين'));
          }

          Set<Marker> markers = {};
          for (var d in drivers) {
            markers.add(
              Marker(
                markerId: MarkerId(d.driverId),
                position: LatLng(
                  d.currentLocation!['lat']!,
                  d.currentLocation!['lng']!,
                ),
                infoWindow: InfoWindow(
                  title: d.name,
                  snippet: d.isAvailable ? 'متاح' : 'مشغول',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  d.isAvailable
                      ? BitmapDescriptor.hueGreen
                      : BitmapDescriptor.hueOrange,
                ),
              ),
            );
          }

          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: markers.first.position,
              zoom: 12,
            ),
            markers: markers,
            onMapCreated: (controller) => mapController = controller,
            myLocationEnabled: false,
          );
        },
      ),
    );
  }
}