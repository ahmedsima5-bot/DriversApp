// hr_dashboard.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HRDashboard extends StatefulWidget {
  final String companyId;
  const HRDashboard({required this.companyId, super.key});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Vehicle> _vehicles = [];
  final _formKey = GlobalKey<FormState>();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  // 🔥 تحميل السيارات من Firebase
  Future<void> _loadVehicles() async {
    try {
      final snapshot = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('vehicles')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _vehicles.clear();
        _vehicles.addAll(snapshot.docs.map((doc) {
          final data = doc.data();
          return Vehicle(
            id: doc.id,
            model: data['model'] ?? '',
            plateNumber: data['plateNumber'] ?? '',
            type: data['type'] ?? 'سيارة',
            isAvailable: data['isAvailable'] ?? true,
          );
        }));
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading vehicles: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  // 🔥 إضافة سيارة إلى Firebase
  Future<void> _addVehicle() async {
    if (_formKey.currentState!.validate()) {
      try {
        final newVehicle = {
          'model': _modelController.text,
          'plateNumber': _plateController.text,
          'type': 'سيارة',
          'isAvailable': true,
          'createdAt': FieldValue.serverTimestamp(),
        };

        // إضافة السيارة إلى Firebase
        await _firestore
            .collection('companies')
            .doc(widget.companyId)
            .collection('vehicles')
            .add(newVehicle);

        // تنظيف الحقول
        _modelController.clear();
        _plateController.clear();

        // إعادة تحميل القائمة
        await _loadVehicles();

        // إشعار بنجاح الإضافة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إضافة السيارة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة السيارة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔥 حذف سيارة من Firebase
  Future<void> _deleteVehicle(String vehicleId) async {
    try {
      await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('vehicles')
          .doc(vehicleId)
          .delete();

      await _loadVehicles();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف السيارة'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في حذف السيارة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الموارد البشرية'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // نموذج إضافة سيارة
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إضافة سيارة جديدة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _modelController,
                        decoration: const InputDecoration(
                          labelText: 'موديل السيارة',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.directions_car),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال موديل السيارة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _plateController,
                        decoration: const InputDecoration(
                          labelText: 'رقم اللوحة',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.confirmation_number),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال رقم اللوحة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _addVehicle,
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة السيارة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // قائمة السيارات
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _vehicles.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'لا توجد سيارات مضافة',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'أسطول السيارات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _vehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = _vehicles[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.directions_car,
                                color: Colors.blue),
                            title: Text(
                              vehicle.model,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                                'رقم اللوحة: ${vehicle.plateNumber}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              onPressed: () =>
                                  _deleteVehicle(vehicle.id!),
                            ),
                          ),
                        );
                      },
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

  @override
  void dispose() {
    _modelController.dispose();
    _plateController.dispose();
    super.dispose();
  }
}

class Vehicle {
  final String? id;
  final String model;
  final String plateNumber;
  final String type;
  final bool isAvailable;

  Vehicle({
    this.id,
    required this.model,
    required this.plateNumber,
    this.type = 'سيارة',
    this.isAvailable = true,
  });
}