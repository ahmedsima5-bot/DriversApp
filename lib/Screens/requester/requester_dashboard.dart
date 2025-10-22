import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'new_request_screen.dart';
import 'my_requests_screen.dart';
import '../../services/auth_service.dart';
import '../../providers/language_provider.dart';
import '../../locales/app_localizations.dart';
import '../auth/login_screen.dart';

class RequesterDashboard extends StatefulWidget {
  final String companyId;
  final String userId;
  final String userName;

  const RequesterDashboard({
    super.key,
    required this.companyId,
    required this.userId,
    required this.userName,
  });

  @override
  State<RequesterDashboard> createState() => _RequesterDashboardState();
}

class _RequesterDashboardState extends State<RequesterDashboard> {
  final AuthService _authService = AuthService();

  String _translate(String key, String languageCode) {
    return AppLocalizations.getTranslatedValue(key, languageCode);
  }

  Future<void> _signOut(BuildContext context) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translate('logout', languageProvider.currentLanguage)),
        content: Text(_translate('confirm_logout', languageProvider.currentLanguage)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_translate('cancel', languageProvider.currentLanguage)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_translate('yes', languageProvider.currentLanguage),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_translate('requester_dashboard', languageProvider.currentLanguage)),
            backgroundColor: Colors.green[800],
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => _signOut(context),
                tooltip: _translate('logout', languageProvider.currentLanguage),
              ),
            ],
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_task, size: 80, color: Colors.green),
                const SizedBox(height: 20),
                Text(
                  _translate('welcome_to_system', languageProvider.currentLanguage),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  '${_translate('company_id', languageProvider.currentLanguage)}: ${widget.companyId}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 30),

                // زر إنشاء طلب جديد
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => NewTransferRequestScreen(
                          companyId: widget.companyId,
                          userId: widget.userId,
                          userName: widget.userName,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 50),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _translate('create_new_request', languageProvider.currentLanguage),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 15),

                // زر متابعة الطلبات
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MyRequestsScreen(
                          companyId: widget.companyId,
                          userId: widget.userId,
                          userName: widget.userName,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 50),
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _translate('track_my_requests', languageProvider.currentLanguage),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 20),

                // معلومات المستخدم
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _translate('user_information', languageProvider.currentLanguage),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${_translate('user_id', languageProvider.currentLanguage)}: ${widget.userId}'),
                      Text('${_translate('user_name', languageProvider.currentLanguage)}: ${widget.userName}'),
                      Text('${_translate('company_id', languageProvider.currentLanguage)}: ${widget.companyId}'),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // زر تسجيل خروج إضافي في الجسم
                TextButton(
                  onPressed: () => _signOut(context),
                  child: Text(
                    _translate('logout', languageProvider.currentLanguage),
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}