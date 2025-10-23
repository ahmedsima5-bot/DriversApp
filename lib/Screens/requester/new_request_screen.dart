import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../providers/language_provider.dart';
import '../../locales/app_localizations.dart';

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

  String _translate(String key, String languageCode) {
    return AppLocalizations.getTranslatedValue(key, languageCode);
  }

  // دالة محسنة لتحميل قسم المستخدم تلقائياً
  Future<void> _loadUserDepartment() async {
    try {
      // البحث في مجموعة companies/C001/users أولاً
      final userDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists && userDoc.data()?['department'] != null) {
        setState(() {
          _userDepartment = userDoc.data()?['department']?.toString();
        });
        debugPrint('✅ Found department in companies: $_userDepartment');
        return;
      }

      // إذا لم يوجد، البحث في المجموعة العامة users
      final globalUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (globalUserDoc.exists && globalUserDoc.data()?['department'] != null) {
        setState(() {
          _userDepartment = globalUserDoc.data()?['department']?.toString();
        });
        debugPrint('✅ Found department in global users: $_userDepartment');
        return;
      }

      // إذا لم يوجد قسم، نستخدم القيمة الافتراضية من بيانات المستخدم
      setState(() {
        _userDepartment = 'Maintenance'; // القيمة الافتراضية الصحيحة
      });
      debugPrint('⚠️ Using default department: $_userDepartment');

    } catch (e) {
      debugPrint('❌ Error loading user department: $e');
      setState(() {
        _userDepartment = 'Maintenance'; // القيمة الافتراضية الصحيحة
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
      debugPrint('Error picking image: $e');
    }
  }

  // دالة إرسال الطلب
  void _submitRequest() {
    if (_formKey.currentState!.validate()) {
      _showPriorityConfirmationDialog(context, languageProvider.currentLanguage);
    }
  }

  // حوار تأكيد الأولوية
  void _showPriorityConfirmationDialog(BuildContext context, String currentLanguage) {
    String message = _isUrgent
        ? _translate('urgent_request_message', currentLanguage)
        : _translate('normal_request_message', currentLanguage);

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
            Text(_isUrgent ? _translate('urgent_request', currentLanguage) : _translate('normal_request', currentLanguage)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            SizedBox(height: 12),
            Text(
              '${_translate('department', currentLanguage)}: $_userDepartment',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_translate('edit', currentLanguage)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveRequestToFirestore();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isUrgent ? Colors.orange : Colors.green,
            ),
            child: Text(_isUrgent ? _translate('confirm_urgent', currentLanguage) : _translate('confirm_normal', currentLanguage)),
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

      // التأكد من أن القسم ليس null
      final department = _userDepartment ?? 'Maintenance';

      debugPrint('💾 Saving request with department: $department');

      // البيانات الأساسية للطلب - مطابقة لهيكل النظام
      Map<String, dynamic> requestData = {
        // المعلومات الأساسية (مطلوبة للنظام)
        'requestId': requestId,
        'companyId': widget.companyId,
        'requesterId': widget.userId,
        'requesterName': widget.userName,
        'department': department, // استخدام القسم الصحيح

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
            : 'طلب نقل',
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
        'pickupLocation': const GeoPoint(24.7136, 46.6753),
        'destinationLocation': const GeoPoint(24.7136, 46.6753),
      };

      // حفظ في المسار الصحيح للنظام
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .doc(requestId)
          .set(requestData);

      debugPrint('✅ Request saved successfully with department: $department');

      // إشعار نجاح
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isUrgent
                ? _translate('urgent_request_sent', languageProvider.currentLanguage)
                : _translate('normal_request_sent', languageProvider.currentLanguage),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // العودة للشاشة السابقة
      Navigator.pop(context);

    } catch (e) {
      debugPrint('❌ Error saving request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_translate('request_error', languageProvider.currentLanguage)}: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  late LanguageProvider languageProvider;

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        this.languageProvider = languageProvider;
        final currentLanguage = languageProvider.currentLanguage;

        return Scaffold(
          appBar: AppBar(
            title: Text(_translate('new_transfer_request', currentLanguage)),
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
                  // قسم المستخدم (للإظهار فقط)
                  if (_userDepartment != null) ...[
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.business, color: Colors.blue.shade700),
                            SizedBox(width: 8),
                            Text(
                              '${_translate('department', currentLanguage)}: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            Text(
                              _userDepartment!,
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],

                  // عنوان الطلب
                  _buildSectionTitle(_translate('request_title', currentLanguage), currentLanguage),
                  _buildTextField(
                    controller: _requestTitleController,
                    label: '${_translate('request_title', currentLanguage)} *',
                    hintText: _translate('request_title_hint', currentLanguage),
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _translate('title_required', currentLanguage);
                      }
                      return null;
                    },
                    currentLanguage: currentLanguage,
                  ),
                  const SizedBox(height: 20),

                  // مستوى الأولوية
                  _buildSectionTitle(_translate('priority_level', currentLanguage), currentLanguage),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _translate('choose_priority', currentLanguage),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 10),

                          // خيار الطلب العادي
                          _buildPriorityOption(
                            title: _translate('normal_request', currentLanguage),
                            subtitle: _translate('normal_request_desc', currentLanguage),
                            icon: Icons.timelapse,
                            color: Colors.blue,
                            isSelected: !_isUrgent,
                            onTap: () {
                              setState(() {
                                _isUrgent = false;
                                _selectedPriority = 'Normal';
                              });
                            },
                            currentLanguage: currentLanguage,
                          ),

                          const SizedBox(height: 12),

                          // خيار الطلب العاجل
                          _buildPriorityOption(
                            title: _translate('urgent_request', currentLanguage),
                            subtitle: _translate('urgent_request_desc', currentLanguage),
                            icon: Icons.warning_amber,
                            color: Colors.orange,
                            isSelected: _isUrgent,
                            onTap: () {
                              setState(() {
                                _isUrgent = true;
                                _selectedPriority = 'Urgent';
                              });
                            },
                            currentLanguage: currentLanguage,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // وصف الطلب
                  _buildSectionTitle(_translate('request_description', currentLanguage), currentLanguage),
                  _buildTextField(
                    controller: _descriptionController,
                    label: '${_translate('request_description', currentLanguage)} *',
                    hintText: _translate('description_hint', currentLanguage),
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _translate('description_required', currentLanguage);
                      }
                      return null;
                    },
                    currentLanguage: currentLanguage,
                  ),
                  const SizedBox(height: 20),

                  // مواقع الرحلة
                  _buildSectionTitle(_translate('trip_locations', currentLanguage), currentLanguage),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _translate('specify_locations', currentLanguage),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 16),

                          // مكان الانطلاق
                          _buildLocationField(
                            controller: _fromLocationController,
                            label: '${_translate('from_location', currentLanguage)} *',
                            hintText: _translate('from_location_hint', currentLanguage),
                            icon: Icons.location_on,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return _translate('from_location_required', currentLanguage);
                              }
                              return null;
                            },
                            currentLanguage: currentLanguage,
                          ),
                          const SizedBox(height: 16),

                          // الوجهة
                          _buildLocationField(
                            controller: _toLocationController,
                            label: '${_translate('to_location', currentLanguage)} *',
                            hintText: _translate('to_location_hint', currentLanguage),
                            icon: Icons.flag,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return _translate('to_location_required', currentLanguage);
                              }
                              return null;
                            },
                            currentLanguage: currentLanguage,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // التاريخ
                  _buildSectionTitle(_translate('date_time', currentLanguage), currentLanguage),
                  _buildReadOnlyField(_translate('request_date', currentLanguage), TextEditingController(text: _getCurrentDate()), currentLanguage),
                  const SizedBox(height: 20),

                  // المسؤول - خانات اختيارية
                  _buildSectionTitle(_translate('contact_info', currentLanguage), currentLanguage),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _responsibleNameController,
                          label: _translate('responsible_name_optional', currentLanguage),
                          hintText: _translate('responsible_name_hint', currentLanguage),
                          currentLanguage: currentLanguage,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: _responsiblePhoneController,
                          label: _translate('phone_optional', currentLanguage),
                          hintText: _translate('phone_hint', currentLanguage),
                          keyboardType: TextInputType.phone,
                          currentLanguage: currentLanguage,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // تفاصيل إضافية
                  _buildSectionTitle(_translate('additional_details', currentLanguage), currentLanguage),
                  _buildTextField(
                    controller: _additionalDetailsController,
                    label: _translate('additional_details_optional', currentLanguage),
                    hintText: _translate('additional_details_hint', currentLanguage),
                    maxLines: 4,
                    currentLanguage: currentLanguage,
                  ),
                  const SizedBox(height: 30),

                  // زر إرسال الطلب
                  _buildSubmitButton(currentLanguage),
                ],
              ),
            ),
          ),
        );
      },
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
    required String currentLanguage,
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
    required String currentLanguage,
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
  Widget _buildSubmitButton(String currentLanguage) {
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
              _isUrgent ? _translate('send_urgent', currentLanguage) : _translate('send_normal', currentLanguage),
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

  Widget _buildSectionTitle(String title, String currentLanguage) {
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
    required String currentLanguage,
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

  Widget _buildReadOnlyField(String label, TextEditingController controller, String currentLanguage) {
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