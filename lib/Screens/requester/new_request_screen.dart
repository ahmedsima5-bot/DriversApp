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
  final TextEditingController _requestTitleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _fromLocationController = TextEditingController();
  final TextEditingController _toLocationController = TextEditingController();
  final TextEditingController _responsibleNameController = TextEditingController();
  final TextEditingController _responsiblePhoneController = TextEditingController();
  final TextEditingController _additionalDetailsController = TextEditingController();

  String _selectedPriority = 'Normal';
  bool _isUrgent = false;
  String? _userDepartment;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserDepartment();
  }

  // دالة لتحميل قسم المستخدم تلقائياً
  Future<void> _loadUserDepartment() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      setState(() {
        _userDepartment = userDoc.data()?['department']?.toString() ?? 'General';
      });
    } catch (e) {
      print('Error loading user department: $e');
      setState(() {
        _userDepartment = 'General';
      });
    }
  }

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
      String status = _isUrgent ? 'HR_PENDING' : 'PENDING';
      String priority = _isUrgent ? 'Urgent' : 'Normal';

      // إنشاء معرف فريد للطلب
      String requestId = 'req_${DateTime.now().millisecondsSinceEpoch}';

      // البيانات الأساسية للطلب - مطابقة لهيكل النظام
      Map<String, dynamic> requestData = {
        // المعلومات الأساسية (مطلوبة للنظام)
        'requestId': requestId,
        'companyId': widget.companyId,
        'requesterId': widget.userId,
        'requesterName': widget.userName,
        'department': _userDepartment ?? 'General',

        // معلومات الرحلة (مطلوبة للنظام)
        'purposeType': 'نقل',
        'details': _descriptionController.text,
        'fromLocation': _fromLocationController.text,
        'toLocation': _toLocationController.text,

        // الأولوية والحالة (مطلوبة للنظام)
        'priority': priority,
        'status': status,

        // التواريخ (مطلوبة للنظام)
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'startTimeExpected': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),

        // معلومات إضافية
        'title': _requestTitleController.text.isNotEmpty
            ? _requestTitleController.text
            : 'طلب نقل', // قيمة افتراضية إذا لم يدخل المستخدم عنوان
        'additionalDetails': _additionalDetailsController.text.isEmpty
            ? null
            : _additionalDetailsController.text,
        'responsibleName': _responsibleNameController.text.isEmpty
            ? null
            : _responsibleNameController.text,
        'responsiblePhone': _responsiblePhoneController.text.isEmpty
            ? null
            : _responsiblePhoneController.text,

        // حقول افتراضية للنظام
        'assignedDriverId': null,
        'assignedDriverName': null,
        'assignedTime': null,
        'pickupLocation': const GeoPoint(24.7136, 46.6753), // قيمة افتراضية
        'destinationLocation': const GeoPoint(24.7136, 46.6753), // قيمة افتراضية
      };

      // حفظ في المسار الصحيح للنظام
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .doc(requestId)
          .set(requestData);

      // إشعار نجاح
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isUrgent
                ? 'تم إرسال الطلب العاجل للموارد البشرية للموافقة'
                : 'تم إرسال الطلب وسيتم تعيين سائق قريباً',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // العودة للشاشة السابقة
      Navigator.pop(context);

    } catch (e) {
      print('Error saving request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إرسال الطلب: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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
              // عنوان الطلب (حقل إدخال حر)
              _buildSectionTitle('عنوان الطلب'),
              _buildTextField(
                controller: _requestTitleController,
                label: 'عنوان الطلب *',
                hintText: 'أدخل عنواناً وصفياً للطلب (مثال: نقل معدات مكتبية - نقل موظفين - إلخ)',
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال عنوان للطلب';
                  }
                  return null;
                },
              ),
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
                            _selectedPriority = 'Normal';
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
                            _selectedPriority = 'Urgent';
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
                label: 'وصف الطلب *',
                hintText: 'أدخل وصف تفصيلي للطلب',
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال وصف الطلب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // مواقع الرحلة
              _buildSectionTitle('مواقع الرحلة'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'حدد مواقع الرحلة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 16),

                      // مكان الانطلاق
                      _buildLocationField(
                        controller: _fromLocationController,
                        label: 'من (مكان الانطلاق) *',
                        hintText: 'أدخل مكان الانطلاق',
                        icon: Icons.location_on,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال مكان الانطلاق';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // الوجهة
                      _buildLocationField(
                        controller: _toLocationController,
                        label: 'إلى (الوجهة) *',
                        hintText: 'أدخل الوجهة',
                        icon: Icons.flag,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال الوجهة';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // التاريخ
              _buildSectionTitle('التاريخ والوقت'),
              _buildReadOnlyField('تاريخ الطلب', TextEditingController(text: _getCurrentDate())),
              const SizedBox(height: 20),

              // المسؤول - خانات اختيارية
              _buildSectionTitle('معلومات الاتصال'),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _responsibleNameController,
                      label: 'اسم المسؤول (اختياري)',
                      hintText: 'أدخل اسم المسؤول',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
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

  // حقل الموقع
  Widget _buildLocationField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    required String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(icon),
            contentPadding: const EdgeInsets.all(12),
          ),
          validator: validator,
        ),
      ],
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
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
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