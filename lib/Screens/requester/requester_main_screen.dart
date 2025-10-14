import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'new_request_screen.dart';
import 'my_requests_screen.dart';
import 'requester_dashboard.dart';

class RequesterMainScreen extends StatelessWidget {
  const RequesterMainScreen({super.key});

  void _logout(BuildContext context) async {
    try {
      await AuthService().signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تسجيل الخروج: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نظام طلبات النقل'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
              onPressed: () => _logout(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'الرئيسية'),
              Tab(icon: Icon(Icons.list_alt), text: 'طلباتي'),
              Tab(icon: Icon(Icons.add_circle), text: 'طلب جديد'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: const TabBarView(
          children: [
            RequesterDashboard(),
            MyRequestsScreen(),
            NewRequestScreen(),
          ],
        ),
      ),
    );
  }
}