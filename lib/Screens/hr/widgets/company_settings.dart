// widgets/company_settings.dart
import 'package:flutter/material.dart';

class CompanySettings extends StatelessWidget {
  const CompanySettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('إعدادات الشركة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),

        _buildSettingField('اسم الشركة', 'الصمنع العالمي للمفروضات والصناعات الخضبية'),
        _buildSettingField('وقت الدوام الرسمي', '08:00 ص - 05:00 م'),
        _buildSettingField('عدد السائقين', '15 سائق'),
        _buildSettingField('الإيميل الرسمي', 'hr@company.com'),

        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              // حفظ إعدادات الشركة
            },
            child: const Text('حفظ الإعدادات'),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}