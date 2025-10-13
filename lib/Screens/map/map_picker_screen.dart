// File: lib/screens/map/map_picker_screen.dart
// Description: شاشة تسمح للمستخدم باختيار موقع (GeoPoint) على خريطة جوجل، سواء كان موقع التقاط أو تسليم.
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // لاستخدام GeoPoint

// سنستخدم إحداثيات افتراضية للمنطقة العربية، مثل الرياض
const LatLng _initialCameraPosition = LatLng(24.7136, 46.6753); // الرياض

class MapPickerScreen extends StatefulWidget {
  // النوع المطلوب: إما 'pickup' أو 'destination'
  final String locationType;
  final GeoPoint? initialLocation;

  const MapPickerScreen({
    super.key,
    required this.locationType,
    this.initialLocation,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _selectedPosition;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    // إذا كان هناك موقع ابتدائي، ابدأ منه
    if (widget.initialLocation != null) {
      _selectedPosition = LatLng(
        widget.initialLocation!.latitude,
        widget.initialLocation!.longitude,
      );
      _updateMarker();
    } else {
      // وإلا، ابدأ من الموقع الافتراضي (الرياض)
      _selectedPosition = _initialCameraPosition;
    }
  }

  // تحديث علامة الخريطة بناءً على الموقع المحدد
  void _updateMarker() {
    if (_selectedPosition == null) return;

    final marker = Marker(
      markerId: const MarkerId('selectedLocation'),
      position: _selectedPosition!,
      infoWindow: InfoWindow(
        title: widget.locationType == 'pickup' ? 'موقع الالتقاط' : 'موقع التسليم',
        snippet: 'Lat: ${_selectedPosition!.latitude.toStringAsFixed(4)}, Lng: ${_selectedPosition!.longitude.toStringAsFixed(4)}',
      ),
    );

    setState(() {
      _markers = {marker};
    });
  }

  // دالة تُستدعى عند النقر على أي مكان في الخريطة
  void _onMapTap(LatLng position) {
    setState(() {
      _selectedPosition = position;
    });
    // تحديث العلامة مباشرة بعد النقر
    _updateMarker();
  }

  // إرجاع الإحداثيات المحددة إلى الشاشة السابقة
  void _confirmSelection() {
    if (_selectedPosition != null) {
      // تحويل LatLng إلى GeoPoint وإرجاعه
      final resultGeoPoint = GeoPoint(_selectedPosition!.latitude, _selectedPosition!.longitude);
      Navigator.of(context).pop(resultGeoPoint);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تحديد موقع على الخريطة أولاً.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.locationType == 'pickup' ? 'تحديد موقع الالتقاط' : 'تحديد موقع التسليم'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedPosition ?? _initialCameraPosition,
              zoom: 12,
            ),
            onMapCreated: (controller) {
              // إذا كان هناك موقع محدد مسبقًا، قم بتحريك الكاميرا إليه
              if (_selectedPosition != _initialCameraPosition) {
                controller.animateCamera(
                    CameraUpdate.newLatLng(_selectedPosition!)
                );
              }
            },
            markers: _markers,
            // تحديد الموقع يتم بالنقر على الخريطة
            onTap: _onMapTap,
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _selectedPosition != null ? _confirmSelection : null,
              icon: const Icon(Icons.check, color: Colors.white),
              label: Text(
                'تأكيد الموقع (${widget.locationType == 'pickup' ? 'الالتقاط' : 'التسليم'})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          // مؤشر مرئي لمركز الشاشة (يساعد في حالة عدم وجود علامات مباشرة)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 50.0),
              child: Icon(Icons.location_on, size: 40, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
