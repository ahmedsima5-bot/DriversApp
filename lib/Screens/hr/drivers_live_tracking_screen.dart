// drivers_live_tracking_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart'; // لإضافة Clipboard

import '../../models/driver_model.dart';
import '../../models/request_model.dart';

class DriversLiveTrackingScreen extends StatefulWidget {
  const DriversLiveTrackingScreen({super.key});

  @override
  State<DriversLiveTrackingScreen> createState() => _DriversLiveTrackingScreenState();
}

class _DriversLiveTrackingScreenState extends State<DriversLiveTrackingScreen> {
  GoogleMapController? mapController;
  Set<Marker> markers = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تتبع السائقين المباشر'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: _buildDriversMap(),
          ),
          const Divider(height: 1),
          Expanded(
            flex: 1,
            child: _buildDriversCommitmentSummary(),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversMap() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('drivers')
          .where('isOnline', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا يوجد سائقين متصلين حالياً'));
        }

        final drivers = snapshot.data!.docs
            .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Driver.fromMap({...data, 'driverId': doc.id});
        })
            .where((d) => d.currentLocation != null)
            .toList();

        markers = drivers.map((d) => Marker(
          markerId: MarkerId(d.driverId),
          position: LatLng(
            d.currentLocation!['lat'] ?? 0.0,
            d.currentLocation!['lng'] ?? 0.0,
          ),
          infoWindow: InfoWindow(
            title: d.name,
            snippet: 'الحالة: ${d.isAvailable ? "متاح" : "مشغول"}\nآخر تحديث: ${_formatTime(d.lastStatusUpdate)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            d.isAvailable ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
          ),
        )).toSet();

        return GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(24.7136, 46.6753), // الرياض
            zoom: 10,
          ),
          markers: markers,
          onMapCreated: (controller) => mapController = controller,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          mapType: MapType.normal,
        );
      },
    );
  }

  Widget _buildDriversCommitmentSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('requests')
          .where('status', isEqualTo: 'مُعين للسائق')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final now = DateTime.now();
        final requests = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Request.fromMap({...data, 'requestId': doc.id});
        }).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('drivers')
              .where('isOnline', isEqualTo: true)
              .snapshots(),
          builder: (context, driverSnap) {
            if (!driverSnap.hasData) return const Center(child: CircularProgressIndicator());

            final drivers = driverSnap.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Driver.fromMap({...data, 'driverId': doc.id});
            }).toList();

            final monitoredDrivers = <Map<String, dynamic>>[];

            for (var req in requests) {
              final driver = drivers.firstWhere(
                    (d) => d.driverId == req.assignedDriverId,
                orElse: () => Driver(
                  driverId: '',
                  name: '',
                  phone: '',
                  isOnline: false,
                  isAvailable: false,
                  lastStatusUpdate: DateTime.now(),
                  completedRides: 0,
                  performanceScore: 0.0,
                  createdAt: DateTime.now(),
                ),
              );

              if (driver.driverId.isEmpty) continue;

              final delayMinutes = now.difference(req.expectedTime).inMinutes;
              final lastUpdateMinutes = now.difference(driver.lastStatusUpdate).inMinutes;

              String statusText = "ملتزم";
              Color cardColor = Colors.green[50]!;

              if (lastUpdateMinutes > 20) {
                statusText = "تحديث الموقع قديم";
                cardColor = Colors.orange[50]!;
              } else if (delayMinutes > 10 && !driver.isAvailable) {
                statusText = "السائق متأخر عن الموعد";
                cardColor = Colors.red[50]!;
              }

              monitoredDrivers.add({
                'driver': driver,
                'request': req,
                'delay': delayMinutes,
                'lastUpdate': lastUpdateMinutes,
                'statusText': statusText,
                'cardColor': cardColor,
              });
            }

            if (monitoredDrivers.isEmpty) {
              return const Center(child: Text('لا يوجد مشاوير جارية حالياً'));
            }

            return ListView.builder(
              itemCount: monitoredDrivers.length,
              itemBuilder: (context, idx) {
                final d = monitoredDrivers[idx]['driver'] as Driver;
                final r = monitoredDrivers[idx]['request'] as Request;
                final delay = monitoredDrivers[idx]['delay'] as int;
                final lastUpdate = monitoredDrivers[idx]['lastUpdate'] as int;
                final statusText = monitoredDrivers[idx]['statusText'] as String;
                final cardColor = monitoredDrivers[idx]['cardColor'] as Color;

                return Card(
                  color: cardColor,
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    leading: Icon(
                      statusText == "ملتزم"
                          ? Icons.check_circle
                          : statusText == "تحديث الموقع قديم"
                          ? Icons.history
                          : Icons.warning,
                      color: statusText == "ملتزم"
                          ? Colors.green
                          : statusText == "تحديث الموقع قديم"
                          ? Colors.orange
                          : Colors.red,
                    ),
                    title: Text('${d.name} (${d.phone})'),
                    subtitle: Text(
                      'القسم: ${r.department} | الغرض: ${r.purpose}\n'
                          'موعد الوصول: ${_formatDateTime(r.expectedTime)}\n'
                          'آخر تحديث للموقع: ${_formatTime(d.lastStatusUpdate)} ($lastUpdate دقيقة مضت)\n'
                          'تأخير عن الموعد: ${delay > 0 ? '$delay دقيقة' : "لا يوجد"}',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.message, color: Colors.blue),
                          tooltip: 'تنبيه السائق',
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('تم إرسال التنبيه للسائق ${d.name}')),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          tooltip: 'اتصال بالسائق',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: d.phone));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم نسخ رقم السائق')),
                            );
                          },
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    dense: false,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} - ${_formatTime(date)}';
  }
}