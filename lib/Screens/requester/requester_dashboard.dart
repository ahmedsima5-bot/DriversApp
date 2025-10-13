import 'package:flutter/material.dart';

// لوحة تحكم المستخدم العادي (الطالب)
class RequesterDashboard extends StatelessWidget {
  const RequesterDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شاشة طالب الخدمة'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('مرحباً بك كطالب خدمة!', style: TextStyle(fontSize: 22)),
            const SizedBox(height: 20),
            // هنا سيتم وضع زر 'طلب جديد' وزر 'طلباتي السابقة'
            ElevatedButton(onPressed: () {}, child: const Text('طلب جديد')),
            ElevatedButton(onPressed: () {}, child: const Text('طلباتي السابقة')),
          ],
        ),
      ),
    );
  }
}
