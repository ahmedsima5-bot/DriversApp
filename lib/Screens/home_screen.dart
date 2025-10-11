import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedCompanyId = 'default-company';
  String _selectedRole = 'مدير موارد بشرية';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام إدارة السائقين'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة ترحيبية
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.directions_car, size: 60, color: Colors.blue),
                    const SizedBox(height: 16),
                    const Text(
                      'مرحباً بك في نظام إدارة السائقين',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الدور: $_selectedRole',
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // أزرار التنقل الرئيسية
            if (_selectedRole == 'مدير موارد بشرية') ...[
              _buildNavigationButton(
                'لوحة الموارد البشرية',
                Icons.dashboard,
                Colors.purple,
                    () => _navigateToHRDashboard(context),
              ),
              const SizedBox(height: 12),
              _buildNavigationButton(
                'الموافقات العاجلة',
                Icons.approval,
                Colors.red,
                    () => _navigateToApprovals(context),
              ),
            ],
            const SizedBox(height: 12),
            _buildNavigationButton(
              'طلباتي',
              Icons.list_alt,
              Colors.orange,
                  () => _navigateToMyRequests(context),
            ),
            const SizedBox(height: 12),
            _buildNavigationButton(
              'طلب جديد',
              Icons.add_circle,
              Colors.green,
                  () => _navigateToNewRequest(context),
            ),
            const SizedBox(height: 12),
            _buildNavigationButton(
              'إعدادات الشركة',
              Icons.settings,
              Colors.blue,
                  () => _navigateToCompanySettings(context),
            ),

            const Spacer(),

            // معلومات النظام
            Card(
              color: Colors.grey[100],
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'نظام توزيع عادل للمشاوير يراعي عدد المشاوير اليومية والأداء',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  void _navigateToHRDashboard(BuildContext context) {
    // سيتم تنفيذها لاحقاً
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم فتح لوحة الموارد البشرية')),
    );
  }

  void _navigateToApprovals(BuildContext context) {
    // سيتم تنفيذها لاحقاً
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم فتح شاشة الموافقات العاجلة')),
    );
  }

  void _navigateToMyRequests(BuildContext context) {
    // سيتم تنفيذها لاحقاً
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم فتح شاشة طلباتي')),
    );
  }

  void _navigateToNewRequest(BuildContext context) {
    // سيتم تنفيذها لاحقاً
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم فتح شاشة طلب جديد')),
    );
  }

  void _navigateToCompanySettings(BuildContext context) {
    // سيتم تنفيذها لاحقاً
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم فتح إعدادات الشركة')),
    );
  }
}