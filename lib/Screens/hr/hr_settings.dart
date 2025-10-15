// hr_settings.dart
import 'package:flutter/material.dart';
import 'widgets/company_settings.dart';

class HRSettings extends StatelessWidget {
  const HRSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: ListView(
        children: [
          // إعدادات التوزيع التلقائي
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('إعدادات التوزيع التلقائي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),

          _buildSettingSwitch('التوزيع التلقائي للطلبات العادية', true),
          _buildSettingSwitch('إشعارات الطلبات العاجلة', true),
          _buildSettingSwitch('التوزيع حسب مجهود السائقين', true),

          const SizedBox(height: 24),

          // إعدادات الشركة
          const CompanySettings(),
        ],
      ),
    );
  }

  Widget _buildSettingSwitch(String title, bool value) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: (bool newValue) {
        // حفظ الإعدادات
      },
    );
  }
}