import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../providers/language_provider.dart';
import '../../locales/app_localizations.dart';
import 'new_request_screen.dart';
import 'my_requests_screen.dart';
import 'requester_dashboard.dart';

class RequesterMainScreen extends StatelessWidget {
  final String companyId;
  final String userId;
  final String userName;

  const RequesterMainScreen({
    super.key,
    required this.companyId,
    required this.userId,
    required this.userName,
  });

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

  String _translate(String key, String languageCode) {
    return AppLocalizations.getTranslatedValue(key, languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(_translate('transport_requests_system', languageProvider.currentLanguage)),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: _translate('logout', languageProvider.currentLanguage),
                  onPressed: () => _logout(context),
                ),
              ],
              bottom: TabBar(
                tabs: [
                  Tab(icon: const Icon(Icons.dashboard), text: _translate('home', languageProvider.currentLanguage)),
                  Tab(icon: const Icon(Icons.list_alt), text: _translate('my_requests', languageProvider.currentLanguage)),
                  Tab(icon: const Icon(Icons.add_circle), text: _translate('new_request', languageProvider.currentLanguage)),
                ],
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
              ),
            ),
            body: TabBarView(
              children: [
                RequesterDashboard(
                  companyId: companyId,
                  userId: userId,
                  userName: userName,
                ),
                MyRequestsScreen(
                  companyId: companyId,
                  userId: userId,
                  userName: userName,
                ),
                NewRequestScreen(
                  companyId: companyId,
                  userId: userId,
                  userName: userName,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}