import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../role_router_screen.dart';
import 'new_request_screen.dart'; // صفحة طلب جديد
import 'my_requests_screen.dart'; // صفحة طلباتي السابقة

class RequesterMainScreen extends StatefulWidget {
  const RequesterMainScreen({super.key});

  @override
  State<RequesterMainScreen> createState() => _RequesterMainScreenState();
}

class _RequesterMainScreenState extends State<RequesterMainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    // 1. طلب جديد
    const NewRequestScreen(),
    // 2. طلباتي السابقة / الطلب الحالي
    const MyRequestsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام طلب المركبات'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [
          // زر تسجيل الخروج
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const RoleRouterScreen()),
                      (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl,
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.add_location_alt),
              label: 'طلب جديد',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'طلباتي السابقة',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blueGrey,
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
