import 'package:flutter/material.dart';

// لوحة تحكم السائق
class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شاشة السائق - مهامي اليومية'),
        backgroundColor: Colors.orange,
      ),
      body: const Center(
        child: Text(
          'مرحباً بك أيها السائق! هنا ستظهر مهامك اليومية.',
          style: TextStyle(fontSize: 22),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
