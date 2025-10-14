import 'package:flutter/material.dart';
import 'new_request_screen.dart'; // إضافة استيراد الصفحة

class RequesterDashboard extends StatelessWidget {
  const RequesterDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'لوحة التحكم',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // بطاقة ترحيبية
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.person, size: 60, color: Colors.indigo),
                    const SizedBox(height: 10),
                    const Text(
                      'مرحباً بك',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text('يمكنك إنشاء طلبات نقل جديدة ومتابعة طلباتك السابقة'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const NewRequestScreen()),
                        );
                      },
                      child: const Text('إنشاء طلب جديد'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // إحصائيات سريعة
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _buildStatCard('الطلبات النشطة', '5', Colors.blue),
                _buildStatCard('الطلبات المكتملة', '12', Colors.green),
                _buildStatCard('في الانتظار', '3', Colors.orange),
                _buildStatCard('ملغاة', '2', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}