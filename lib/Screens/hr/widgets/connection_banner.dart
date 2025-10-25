// widgets/connection_banner.dart
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drivers/services/connectivity_service.dart';

class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({super.key});

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    ConnectivityService.connectivityStream.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    setState(() {
      _isConnected = result != ConnectivityResult.none;
    });
  }

  Future<void> _checkConnection() async {
    final connected = await ConnectivityService.isConnected();
    setState(() {
      _isConnected = connected;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: Colors.orange,
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'لا يوجد اتصال بالإنترنت',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}