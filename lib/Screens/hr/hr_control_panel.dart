// hr_dashboard.dart
import 'package:flutter/material.dart';

class HRDashboard extends StatefulWidget {
  final String companyId;
  const HRDashboard({required this.companyId, super.key});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
  final List<Vehicle> _vehicles = [];
  final _formKey = GlobalKey<FormState>();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();

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
              child: _vehicles.isEmpty
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
                              onPressed: () => _deleteVehicle(index),
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

  void _addVehicle() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _vehicles.add(Vehicle(
          model: _modelController.text,
          plateNumber: _plateController.text,
        ));
        _modelController.clear();
        _plateController.clear();
      });

      // إشعار بنج الإضافة
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت إضافة السيارة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _deleteVehicle(int index) {
    setState(() {
      _vehicles.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف السيارة'),
        backgroundColor: Colors.red,
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
  final String model;
  final String plateNumber;

  Vehicle({required this.model, required this.plateNumber});
}