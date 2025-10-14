//company_settings.dart

import 'package:flutter/material.dart';
import '../../services/database_service.dart';

// هذه الشاشة مخصصة لإداري الموارد البشرية (HR Admin) لإدارة إعدادات الشركة
class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  // final DatabaseService _databaseService = DatabaseService(); // ✨ تم حذف هذا المتغير لأنه غير ضروري
  final _newDepartmentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // قيمة ثابتة مؤقتة لمعرّف الشركة
  static const String _companyId = 'C001';

  @override
  void dispose() {
    _newDepartmentController.dispose();
    super.dispose();
  }

  // دالة لإضافة قسم جديد
  Future<void> _addDepartment() async {
    if (_formKey.currentState!.validate()) {
      final departmentName = _newDepartmentController.text.trim();
      try {
        // ✨ تصحيح الخطأ: استخدام DatabaseService.addDepartment مباشرة
        await DatabaseService.addDepartment(_companyId, departmentName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تمت إضافة القسم "$departmentName" بنجاح.')),
          );
          _newDepartmentController.clear();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في إضافة القسم: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الشركة'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إدارة أقسام الشركة',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple),
            ),
            const Divider(),

            // قسم إضافة قسم جديد
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(vertical: 15),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إضافة قسم جديد',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _newDepartmentController,
                        decoration: const InputDecoration(
                          labelText: 'اسم القسم',
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال اسم القسم.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton.icon(
                        onPressed: _addDepartment,
                        icon: const Icon(Icons.add_business),
                        label: const Text('إضافة القسم'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'الأقسام الحالية:',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple),
            ),
            const Divider(),

            // قسم عرض الأقسام الحالية
            // استخدام StreamBuilder للاستماع لتحديثات الأقسام في Firestore
            StreamBuilder<List<String>>(
              // ✨ تصحيح الخطأ: استخدام DatabaseService.getDepartmentsStream مباشرة
              stream: DatabaseService.getDepartmentsStream(_companyId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('خطأ في جلب الأقسام: ${snapshot.error}'));
                }

                final departments = snapshot.data ?? [];

                if (departments.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('لم يتم إضافة أي أقسام بعد. قم بإضافة القسم الأول.'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: departments.length,
                  itemBuilder: (context, index) {
                    final department = departments[index];
                    return ListTile(
                      leading: const Icon(Icons.label, color: Colors.purple),
                      title: Text(department, style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        onPressed: () {
                          // TODO: Implement department deletion logic
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('سيتم تفعيل حذف القسم "$department" لاحقاً.')),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
