import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class NewTransferRequestScreen extends StatefulWidget {
  final String companyId;
  final String userId;
  final String userName;

  const NewTransferRequestScreen({
    super.key,
    required this.companyId,
    required this.userId,
    required this.userName,
  });

  @override
  State<NewTransferRequestScreen> createState() => _NewTransferRequestScreenState();
}

class _NewTransferRequestScreenState extends State<NewTransferRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _requestTitleController = TextEditingController(text: 'طلب نقل');
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _responsibleNameController = TextEditingController();
  final TextEditingController _responsiblePhoneController = TextEditingController();
  final TextEditingController _additionalDetailsController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // متغيرات جديدة لإدارة الأولوية
  String _selectedPriority = 'MEDIUM'; // MEDIUM, HIGH
  bool _isUrgent = false;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // دالة لاختيار الصورة
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  // دالة لفتح حوار الموقع
  void _openLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إدخال الموقع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'أدخل العنوان أو الموقع',
                border: OutlineInputBorder(),
                hintText: 'مثال: الرياض - حي الملز - شارع الملك فهد',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_locationController.text.isNotEmpty) {
                setState(() {});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حفظ الموقع بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // دالة إرسال الطلب
  void _submitRequest() {
    if (_formKey.currentState!.validate()) {
      _showPriorityConfirmationDialog();
    }
  }

  // حوار تأكيد الأولوية
  void _showPriorityConfirmationDialog() {
    String message = _isUrgent
        ? '⚠️ هذا الطلب عاجل وسيتم إرساله إلى إدارة الموارد البشرية للموافقة عليه أولاً قبل تعيينه للسائقين.'
        : '✅ هذا الطلب عادي وسيتم تعيينه تلقائياً للسائقين المتاحين حسب أدائهم وعدد مشاويرهم.';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _isUrgent ? Icons.warning_amber : Icons.check_circle,
              color: _isUrgent ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(_isUrgent ? 'طلب عاجل' : 'طلب عادي'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تعديل'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveRequestToFirestore();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isUrgent ? Colors.orange : Colors.green,
            ),
            child: Text(_isUrgent ? 'تأكيد كطلب عاجل' : 'تأكيد كطلب عادي'),
          ),
        ],
      ),
    );
  }

  // دالة حفظ الطلب في Firestore
  Future<void> _saveRequestToFirestore() async {
    try {
      // تحديد حالة الطلب بناءً على الأولوية
      String status = _isUrgent ? 'PENDING_HR_APPROVAL' : 'ASSIGNING_DRIVER';
      String priority = _isUrgent ? 'HIGH' : 'MEDIUM';

      // تحديد المسار بناءً على الأولوية
      String collectionPath = _isUrgent
          ? 'artifacts/${widget.companyId}/public/data/hr_pending_requests'
          : 'artifacts/${widget.companyId}/public/data/active_requests';

      await FirebaseFirestore.instance
          .collection(collectionPath)
          .add({
        'title': _requestTitleController.text,
        'description': _descriptionController.text,
        'responsibleName': _responsibleNameController.text.isEmpty ? null : _responsibleNameController.text,
        'responsiblePhone': _responsiblePhoneController.text.isEmpty ? null : _responsiblePhoneController.text,
        'location': _locationController.text.isEmpty ? null : _locationController.text,
        'additionalDetails': _additionalDetailsController.text.isEmpty ? null : _additionalDetailsController.text,

        // الحقول الأساسية
        'status': status,
        'priority': priority,
        'isUrgent': _isUrgent,
        'createdAt': Timestamp.now(),
        'userId': widget.userId,
        'userName': widget.userName,
        'companyId': widget.companyId,

        // معلومات إضافية للتتبع
        'assignedDepartment': _isUrgent ? 'HR' : 'OPERATIONS',
        'requiredApproval': _isUrgent,
        'autoAssign': !_isUrgent,

        // معلومات الأداء (للتوزيع العادل)
        'assignmentScore': 0, // سيتم حسابه عند التوزيع
        'estimatedCompletionTime': _isUrgent ? 2 : 24, // ساعات
      });

      // أيضًا حفظ في السجل العام
      await FirebaseFirestore.instance
          .collection('artifacts/${widget.companyId}/public/data/requests')
          .add({
        'title': _requestTitleController.text,
        'description': _descriptionController.text,
        'location': _locationController.text.isEmpty ? null : _locationController.text,
        'status': status,
        'priority': priority,
        'isUrgent': _isUrgent,
        'createdAt': Timestamp.now(),
        'userId': widget.userId,
        'userName': widget.userName,
        'assignedDepartment': _isUrgent ? 'HR' : 'OPERATIONS',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isUrgent
                ? 'تم إرسال الطلب العاجل للموارد البشرية للموافقة'
                : 'تم إرسال الطلب وسيتم تعيينه للسائقين قريباً',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إرسال الطلب: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب نقل جديد'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // عنوان الطلب
              _buildSectionTitle('طلب نقل جديد'),
              _buildReadOnlyField('عنوان الطلب', _requestTitleController),
              const SizedBox(height: 20),

              // مستوى الأولوية
              _buildSectionTitle('مستوى الأولوية'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'اختر مستوى الأولوية',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 10),

                      // خيار الطلب العادي
                      _buildPriorityOption(
                        title: 'طلب عادي',
                        subtitle: 'سيتم تعيينه تلقائياً للسائقين حسب الأداء والعدالة',
                        icon: Icons.timelapse,
                        color: Colors.blue,
                        isSelected: !_isUrgent,
                        onTap: () {
                          setState(() {
                            _isUrgent = false;
                            _selectedPriority = 'MEDIUM';
                          });
                        },
                      ),

                      const SizedBox(height: 12),

                      // خيار الطلب العاجل
                      _buildPriorityOption(
                        title: 'طلب عاجل ⚡',
                        subtitle: 'يتطلب موافقة إدارة الموارد البشرية أولاً',
                        icon: Icons.warning_amber,
                        color: Colors.orange,
                        isSelected: _isUrgent,
                        onTap: () {
                          setState(() {
                            _isUrgent = true;
                            _selectedPriority = 'HIGH';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // وصف الطلب
              _buildSectionTitle('وصف الطلب'),
              _buildTextField(
                controller: _descriptionController,
                label: 'وصف الطلب',
                hintText: 'أدخل وصف الطلب هنا',
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال وصف الطلب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // التاريخ
              _buildSectionTitle('التاريخ'),
              _buildReadOnlyField('التاريخ', TextEditingController(text: _getCurrentDate())),
              const SizedBox(height: 20),

              // اختيار الموقع
              _buildSectionTitle('موقع الأهداف'),
              _buildLocationSection(),
              const SizedBox(height: 20),

              // المسؤول - خانات اختيارية
              _buildSectionTitle('المسؤول'),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _responsibleNameController,
                      label: 'اسم المسؤول (اختياري)',
                      hintText: 'أدخل اسم المسؤول',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _responsiblePhoneController,
                      label: 'رقم الهاتف (اختياري)',
                      hintText: 'أدخل رقم الهاتف',
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // تفاصيل إضافية
              _buildSectionTitle('تفاصيل إضافية'),
              _buildTextField(
                controller: _additionalDetailsController,
                label: 'التفاصيل الإضافية (اختياري)',
                hintText: 'أدخل تفاصيل إضافية عن الطلب (الأشخاص، المعدات، المتطلبات الخاصة)',
                maxLines: 4,
              ),
              const SizedBox(height: 30),

              // زر إرسال الطلب
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  // واجهة خيار الأولوية
  Widget _buildPriorityOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.grey[700],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isSelected ? color : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  // قسم الموقع
  Widget _buildLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الموقع',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            // زر إدخال الموقع
            ElevatedButton.icon(
              onPressed: _openLocationDialog,
              icon: const Icon(Icons.location_on),
              label: const Text('إدخال الموقع'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[50],
                foregroundColor: Colors.blue[800],
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 10),

            // الموقع المدخل
            if (_locationController.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationController.text,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: _openLocationDialog,
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'لم يتم إدخال موقع',
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // زر الإرسال
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isUrgent ? Colors.orange : Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_isUrgent ? Icons.warning_amber : Icons.send),
            const SizedBox(width: 8),
            Text(
              _isUrgent ? 'إرسال كطلب عاجل' : 'إرسال كطلب عادي',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd');
    return formatter.format(now);
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blue[800],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              validator: validator,
              decoration: InputDecoration(
                hintText: hintText,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, TextEditingController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              readOnly: true,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(12),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ],
        ),
      ),
    );
  }
}