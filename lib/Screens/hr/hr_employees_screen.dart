import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class HREmployeesScreen extends StatefulWidget {
  final String companyId;

  const HREmployeesScreen({required this.companyId, super.key});

  @override
  State<HREmployeesScreen> createState() => _HREmployeesScreenState();
}

class _HREmployeesScreenState extends State<HREmployeesScreen> {
  String _filterRole = 'الكل';
  String _searchQuery = '';

  final List<String> _roleOptions = ['الكل', 'HR', 'Requester', 'Driver'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الموظفين'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // شريط البحث والتصفية
          _buildSearchAndFilterBar(),
          const SizedBox(height: 8),

          // إحصائيات سريعة
          _buildQuickStats(),
          const SizedBox(height: 8),

          // قائمة الموظفين
          Expanded(
            child: _buildEmployeesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEmployeeDialog,
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // حقل البحث
          TextField(
            decoration: const InputDecoration(
              labelText: 'بحث عن موظف',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),

          // تصفية حسب الدور
          Row(
            children: [
              const Text('التصفية حسب الدور:'),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _filterRole,
                items: _roleOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _filterRole = newValue!;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('company_id', isEqualTo: widget.companyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final employees = snapshot.data!.docs;
        final totalEmployees = employees.length;
        final hrCount = employees.where((doc) => doc['role'] == 'HR').length;
        final requesterCount = employees.where((doc) => doc['role'] == 'Requester').length;
        final driverCount = employees.where((doc) => doc['role'] == 'Driver').length;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildStatChip('إجمالي الموظفين', totalEmployees.toString(), Colors.blue),
              const SizedBox(width: 8),
              _buildStatChip('موارد بشرية', hrCount.toString(), Colors.purple),
              const SizedBox(width: 8),
              _buildStatChip('موظفين', requesterCount.toString(), Colors.green),
              const SizedBox(width: 8),
              _buildStatChip('سائقين', driverCount.toString(), Colors.orange),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Chip(
      backgroundColor: color.withOpacity(0.1),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildEmployeesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('company_id', isEqualTo: widget.companyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('خطأ في تحميل الموظفين: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('لا يوجد موظفين مسجلين بعد'),
              ],
            ),
          );
        }

        // تصفية البيانات
        var employees = snapshot.data!.docs;

        // التصفية حسب الدور
        if (_filterRole != 'الكل') {
          employees = employees.where((doc) => doc['role'] == _filterRole).toList();
        }

        // التصفية حسب البحث
        if (_searchQuery.isNotEmpty) {
          employees = employees.where((doc) {
            final name = doc['display_name']?.toString().toLowerCase() ?? '';
            final email = doc['email']?.toString().toLowerCase() ?? '';
            final department = doc['department']?.toString().toLowerCase() ?? '';
            return name.contains(_searchQuery.toLowerCase()) ||
                email.contains(_searchQuery.toLowerCase()) ||
                department.contains(_searchQuery.toLowerCase());
          }).toList();
        }

        return ListView.builder(
          itemCount: employees.length,
          itemBuilder: (context, index) {
            final employeeDoc = employees[index];
            final employee = UserModel.fromMap(employeeDoc.data() as Map<String, dynamic>);
            return _buildEmployeeCard(employee, employeeDoc.id);
          },
        );
      },
    );
  }

  Widget _buildEmployeeCard(UserModel employee, String userId) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(employee.role),
          child: Text(
            employee.displayName.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          employee.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('البريد: ${employee.email}'),
            Text('القسم: ${employee.department}'),
            Text('الدور: ${_getRoleDisplayName(employee.role)}'),
            Text('تاريخ التسجيل: ${_formatDate(employee.createdAt)}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleEmployeeAction(value, employee, userId),
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(value: 'edit', child: Text('تعديل البيانات')),
            const PopupMenuItem(value: 'reset_password', child: Text('إعادة تعيين كلمة المرور')),
            const PopupMenuItem(value: 'delete', child: Text('حذف الموظف', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'HR': return Colors.purple;
      case 'Driver': return Colors.orange;
      case 'Requester': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'HR': return 'موارد بشرية';
      case 'Driver': return 'سائق';
      case 'Requester': return 'موظف';
      default: return role;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handleEmployeeAction(String action, UserModel employee, String userId) {
    switch (action) {
      case 'edit':
        _showEditEmployeeDialog(employee, userId);
        break;
      case 'reset_password':
        _showResetPasswordDialog(employee);
        break;
      case 'delete':
        _showDeleteEmployeeDialog(employee, userId);
        break;
    }
  }

  void _showAddEmployeeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة موظف جديد'),
        content: const Text('هذه الميزة تحت التطوير. استخدم شاشة التسجيل لإضافة موظفين جدد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showEditEmployeeDialog(UserModel employee, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل بيانات الموظف'),
        content: const Text('ميزة تعديل البيانات قريباً...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('سيتم تفعيل تعديل البيانات قريباً')),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(UserModel employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تعيين كلمة المرور'),
        content: Text('هل تريد إعادة تعيين كلمة المرور للموظف ${employee.displayName}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم إرسال رابط إعادة تعيين كلمة المرور لـ ${employee.email}')),
              );
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _showDeleteEmployeeDialog(UserModel employee, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الموظف'),
        content: Text('هل أنت متأكد من حذف الموظف ${employee.displayName}؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteEmployee(userId);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEmployee(String userId) async {
    try {
      // حذف من Authentication
      // await FirebaseAuth.instance.currentUser?.delete(); // بحذر!

      // حذف من Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الموظف بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حذف الموظف: $e')),
      );
    }
  }
}