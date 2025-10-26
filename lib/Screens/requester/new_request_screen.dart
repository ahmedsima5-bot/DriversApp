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

  String _selectedPriority = 'Normal';
  bool _isUrgent = false;
  bool _isScheduled = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
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

      setState(() {
        _userDepartment = 'Maintenance';
      });
      debugPrint('⚠️ Using default department: $_userDepartment');

    } catch (e) {
      debugPrint('❌ Error loading user department: $e');
      setState(() {
        _userDepartment = 'Maintenance';
      });
    }
  }

  // دالة اختيار تاريخ الجدولة
  Future<void> _selectScheduledDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _scheduledDate = picked;
      });
      await _selectScheduledTime(context);
    }
  }

  // دالة اختيار وقت الجدولة
  Future<void> _selectScheduledTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _scheduledTime = picked;
      });
    }
  }

  // دالة إرسال الطلب
  void _submitRequest() {
    if (_formKey.currentState!.validate()) {
      if (_isScheduled && (_scheduledDate == null || _scheduledTime == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_translate('schedule_date_required', languageProvider.currentLanguage)),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      _showPriorityConfirmationDialog(context, languageProvider.currentLanguage);
    }
  }

  // حوار تأكيد الأولوية
  void _showPriorityConfirmationDialog(BuildContext context, String currentLanguage) {
    String message = _isUrgent
        ? _translate('urgent_request_message', currentLanguage)
        : _translate('normal_request_message', currentLanguage);

    if (_isScheduled && _scheduledDate != null && _scheduledTime != null) {
      final scheduledDateTime = DateTime(
        _scheduledDate!.year,
        _scheduledDate!.month,
        _scheduledDate!.day,
        _scheduledTime!.hour,
        _scheduledTime!.minute,
      );
      final formatter = DateFormat('yyyy-MM-dd HH:mm');
      message += '\n\n${_translate('scheduled_for', currentLanguage)}: ${formatter.format(scheduledDateTime)}';
      message += '\n${_translate('needs_hr_approval', currentLanguage)}';
    }

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
            const SizedBox(height: 12),
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
      String status;
      if (_isScheduled) {
        status = 'HR_PENDING';
      } else {
        status = _isUrgent ? 'HR_PENDING' : 'PENDING';
      }

      String priority = _isUrgent ? 'Urgent' : 'Normal';
      String requestId = 'req_${DateTime.now().millisecondsSinceEpoch}';
      final department = _userDepartment ?? 'Maintenance';

      Timestamp? startTimeExpected;
      if (_isScheduled && _scheduledDate != null && _scheduledTime != null) {
        final scheduledDateTime = DateTime(
          _scheduledDate!.year,
          _scheduledDate!.month,
          _scheduledDate!.day,
          _scheduledTime!.hour,
          _scheduledTime!.minute,
        );
        startTimeExpected = Timestamp.fromDate(scheduledDateTime);
      } else {
        startTimeExpected = Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1)));
      }

      Map<String, dynamic> requestData = {
        'requestId': requestId,
        'companyId': widget.companyId,
        'requesterId': widget.userId,
        'requesterName': widget.userName,
        'department': department,
        'purposeType': _translate('transfer', languageProvider.currentLanguage),
        'details': _descriptionController.text,
        'fromLocation': _fromLocationController.text,
        'toLocation': _toLocationController.text,
        'priority': priority,
        'status': status,
        'isScheduled': _isScheduled,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'startTimeExpected': startTimeExpected,
        'title': _requestTitleController.text.isNotEmpty
            ? _requestTitleController.text
            : _translate('transfer_request', languageProvider.currentLanguage),
        'responsibleName': _responsibleNameController.text.isEmpty
            ? null
            : _responsibleNameController.text,
        'responsiblePhone': _responsiblePhoneController.text.isEmpty
            ? null
            : _responsiblePhoneController.text,
        'assignedDriverId': null,
        'assignedDriverName': null,
        'assignedTime': null,
        'pickupLocation': const GeoPoint(24.7136, 46.6753),
        'destinationLocation': const GeoPoint(24.7136, 46.6753),
      };

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .doc(requestId)
          .set(requestData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isScheduled
                ? _translate('scheduled_request_sent', languageProvider.currentLanguage)
                : _isUrgent
                ? _translate('urgent_request_sent', languageProvider.currentLanguage)
                : _translate('normal_request_sent', languageProvider.currentLanguage),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

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
                            const SizedBox(width: 8),
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
                    const SizedBox(height: 16),
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

                  // قسم واحد مدمج: تحديد نوع الطلب
                  _buildSectionTitle(_translate('اختر نوع الطلب', currentLanguage), currentLanguage),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // خيارات الأولوية والجدولة معاً


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

                          const SizedBox(height: 12),

                          // خيار جدولة الطلب
                          _buildPriorityOption(
                            title: _translate('جدولة طلب', currentLanguage),
                            subtitle: _translate('schedule_request_desc', currentLanguage),
                            icon: Icons.schedule,
                            color: Colors.purple,
                            isSelected: _isScheduled,
                            onTap: () {
                              setState(() {
                                _isScheduled = true;
                                _isUrgent = false; // إلغاء اختيار العاجل عند اختيار الجدولة
                              });
                            },
                            currentLanguage: currentLanguage,
                          ),

                          // حقل اختيار التاريخ والوقت للطلبات المجدولة
                          if (_isScheduled) ...[
                            const SizedBox(height: 16),
                            _buildDateTimeSelector(currentLanguage),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // وصف الطلب والتفاصيل الإضافية (مدمج)
                  _buildSectionTitle(_translate('request_details', currentLanguage), currentLanguage),
                  _buildTextField(
                    controller: _descriptionController,
                    label: '${_translate('تفاصيل الطلب', currentLanguage)} *',
                    hintText: _translate('وضح نوع السيارة المطلوب للشحنة وتفاصيل الطلب كاملة', currentLanguage),
                    maxLines: 6,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _translate('details_required', currentLanguage);
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

  // واجهة اختيار التاريخ والوقت
  Widget _buildDateTimeSelector(String currentLanguage) {
    final dateText = _scheduledDate != null
        ? DateFormat('yyyy-MM-dd').format(_scheduledDate!)
        : _translate('select_date', currentLanguage);

    final timeText = _scheduledTime != null
        ? _scheduledTime!.format(context)
        : _translate('select_time', currentLanguage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _translate('اختر التاريخ والوقت المطلوب', currentLanguage),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _selectScheduledDate(context),
                icon: const Icon(Icons.calendar_today),
                label: Text(dateText),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _scheduledDate != null ? () => _selectScheduledTime(context) : null,
                icon: const Icon(Icons.access_time),
                label: Text(timeText),
              ),
            ),
          ],
        ),
        if (_scheduledDate != null && _scheduledTime != null) ...[
          const SizedBox(height: 8),
          Text(
            '${_translate('مجدول بتاريخ', currentLanguage)}: ${DateFormat('yyyy-MM-dd, الساعة : HH:mm').format(DateTime(
              _scheduledDate!.year,
              _scheduledDate!.month,
              _scheduledDate!.day,
              _scheduledTime!.hour,
              _scheduledTime!.minute,
            ))}',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  // واجهة خيار الأولوية والجدولة
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
          backgroundColor: _getButtonColor(),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getButtonIcon()),
            const SizedBox(width: 8),
            Text(
              _getButtonText(currentLanguage),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Color _getButtonColor() {
    if (_isScheduled) return Colors.purple;
    if (_isUrgent) return Colors.orange;
    return Colors.green;
  }

  IconData _getButtonIcon() {
    if (_isScheduled) return Icons.schedule;
    if (_isUrgent) return Icons.warning_amber;
    return Icons.send;
  }

  String _getButtonText(String currentLanguage) {
    if (_isScheduled) return _translate('send_scheduled', currentLanguage);
    if (_isUrgent) return _translate('send_urgent', currentLanguage);
    return _translate('send_normal', currentLanguage);
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
}