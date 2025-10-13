// File: lib/Screens/requester/new_request_screen.dart
// Description: شاشة إنشاء طلب خدمة سائق جديد، مع إمكانية تحديد موقعي الالتقاط والتسليم على الخريطة.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../models/request_model.dart';
import '../../services/database_service.dart';
import '../map/map_picker_screen.dart'; // تم إضافة استيراد شاشة الخريطة

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String _requesterName = '';
  String _department = '';
  String _purposeType = '';
  String _details = '';
  String _priority = 'عادي';
  DateTime _startTimeExpected = DateTime.now().add(const Duration(hours: 2));
  List<String> _departments = [];
  bool _isLoading = false;

  // متغيرات جديدة لتخزين إحداثيات الموقع
  GeoPoint? _pickupLocation;
  GeoPoint? _destinationLocation;

  // متغيرات لجلب البيانات من السياق
  String? _companyId;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchUserDataAndDepartments();
  }

  // دالة لجلب ID الشركة والأقسام واسم المستخدم
  Future<void> _fetchUserDataAndDepartments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // التعامل مع حالة عدم تسجيل الدخول إذا لزم الأمر
      return;
    }

    setState(() => _userId = user.uid);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final companyId = userData['companyId'] as String?;
        final userName = userData['name'] as String? ?? '';
        final userDepartment = userData['department'] as String? ?? '';

        if (companyId != null) {
          setState(() {
            _companyId = companyId;
            _requesterName = userName;
            _department = userDepartment;
          });
          // استخدمنا DatabaseService لجلب الأقسام
          _loadDepartments(companyId);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل بيانات المستخدم: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // دالة تحميل الأقسام باستخدام DatabaseService
  void _loadDepartments(String companyId) {
    DatabaseService.getDepartmentsStream(companyId).listen((departments) {
      if (mounted) {
        setState(() {
          _departments = departments;
          if (_department.isEmpty && departments.isNotEmpty) {
            _department = departments.first;
          }
        });
      }
    }).onError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الأقسام: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  // دالة لاختيار التاريخ والوقت
  Future<void> _selectTime(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startTimeExpected,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startTimeExpected),
      );

      if (pickedTime != null) {
        setState(() {
          _startTimeExpected = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  // دالة لفتح شاشة اختيار الموقع
  Future<void> _pickLocation(String type) async {
    final initialLocation = type == 'pickup' ? _pickupLocation : _destinationLocation;

    final result = await Navigator.of(context).push<GeoPoint>(
      MaterialPageRoute(
        builder: (ctx) => MapPickerScreen(
          locationType: type,
          initialLocation: initialLocation,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (type == 'pickup') {
          _pickupLocation = result;
        } else {
          _destinationLocation = result;
        }
      });
    }
  }


  Future<void> _submitRequest() async {
    // التحقق من صحة الفورم والـ IDs والمواقع
    if (!_formKey.currentState!.validate() || _companyId == null || _userId == null) {
      // رسالة خطأ عامة
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء التأكد من تعبئة جميع الحقول المطلوبة.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // التحقق من تحديد الموقعين
    if (_pickupLocation == null || _destinationLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء تحديد موقعي الالتقاط والتسليم على الخريطة.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _formKey.currentState!.save();

    try {
      setState(() => _isLoading = true);

      // ✨ تم التصحيح: استخدام final بدلاً من const لإنشاء ID في وقت التشغيل
      final requestId = const Uuid().v4();
      final now = DateTime.now();

      final request = Request(
        requestId: requestId,
        companyId: _companyId!,
        requesterId: _userId!,
        requesterName: _requesterName.trim(),
        department: _department,

        purposeType: _purposeType.trim(),
        details: _details.trim(),
        priority: _priority,

        // استخدام الإحداثيات المختارة
        pickupLocation: _pickupLocation!,
        destinationLocation: _destinationLocation!,

        startTimeExpected: _startTimeExpected,
        status: 'PENDING',

        createdAt: now,
      );

      // استخدام DatabaseService لإضافة الطلب
      await DatabaseService.addRequest(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _priority == 'عاجل'
                  ? 'تم إرسال الطلب للموافقة من قبل الموارد البشرية (PENDING)'
                  : 'تم إنشاء الطلب (PENDING) وسيتم توزيعه على سائق بعد الموافقة',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // إعادة تعيين الحالة (Reset Form)
        _formKey.currentState!.reset();
        setState(() {
          _purposeType = '';
          _details = '';
          _priority = 'عادي';
          _startTimeExpected = DateTime.now().add(const Duration(hours: 2));
          _pickupLocation = null; // إعادة تعيين المواقع
          _destinationLocation = null; // إعادة تعيين المواقع
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إرسال الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ويدجت مساعدة لعرض تفاصيل الموقع
  Widget _buildLocationCard(String title, GeoPoint? location, String type) {
    String subtitle = location == null
        ? 'اضغط للاختيار على الخريطة'
        : 'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}';

    return InkWell(
      onTap: () => _pickLocation(type),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: location == null ? Colors.orange : Colors.green),
          borderRadius: BorderRadius.circular(8),
          color: location == null ? Colors.orange.shade50 : Colors.green.shade50,
        ),
        child: Row(
          children: [
            Icon(
              type == 'pickup' ? Icons.directions_walk : Icons.location_pin,
              color: location == null ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: location == null ? Colors.red : Colors.grey[700]),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.map, color: Colors.blueGrey),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب خدمة سائق جديدة'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: _companyId == null
          ? const Center(child: CircularProgressIndicator(value: null, color: Colors.green))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // اسم المتقدم
              Text(
                'اسمك',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _requesterName,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'أدخل اسمك الكامل',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (val) =>
                val == null || val.isEmpty ? 'الاسم مطلوب' : null,
                onSaved: (val) => _requesterName = val!,
              ),
              const SizedBox(height: 20),

              // القسم
              Text(
                'القسم',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _departments.isEmpty
                  ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Text('لا توجد أقسام متاحة'),
              )
                  : DropdownButtonFormField<String>(
                value: _department.isEmpty
                    ? (_departments.isNotEmpty ? _departments.first : null)
                    : _department,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.apartment),
                ),
                items: _departments
                    .map((dept) => DropdownMenuItem(
                  value: dept,
                  child: Text(dept),
                ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _department = val);
                  }
                },
                validator: (val) =>
                val == null || val.isEmpty ? 'اختر القسم' : null,
              ),
              const SizedBox(height: 20),

              // غرض الطلب
              Text(
                'غرض الطلب',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'مثال: نقل مستندات، توصيل طلب',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.note),
                ),
                validator: (val) =>
                val == null || val.isEmpty ? 'غرض الطلب مطلوب' : null,
                onSaved: (val) => _purposeType = val!,
              ),
              const SizedBox(height: 20),

              // التفاصيل
              Text(
                'التفاصيل (اختياري)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'أضف تفاصيل إضافية عن الطلب',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
                onSaved: (val) => _details = val!,
              ),
              const SizedBox(height: 20),

              // الأولوية
              Text(
                'الأولوية',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('عادي'),
                      value: 'عادي',
                      groupValue: _priority,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _priority = val);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('عاجل'),
                      value: 'عاجل',
                      groupValue: _priority,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _priority = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // اختيار المواقع
              Text(
                'موقع الالتقاط والتسليم',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              // كرت موقع الالتقاط
              _buildLocationCard('موقع الالتقاط (البداية)', _pickupLocation, 'pickup'),
              const SizedBox(height: 12),

              // كرت موقع التسليم
              _buildLocationCard('موقع التسليم (الوجهة)', _destinationLocation, 'destination'),
              const SizedBox(height: 20),

              // الوقت المتوقع
              Text(
                'الوقت المتوقع للتنفيذ',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectTime(context),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.blue),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'التاريخ والوقت',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '${_startTimeExpected.day}/${_startTimeExpected.month}/${_startTimeExpected.year} - '
                                '${_startTimeExpected.hour}:${_startTimeExpected.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // زر الإرسال
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'إرسال الطلب',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ملاحظة
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _priority == 'عاجل'
                            ? 'الطلبات العاجلة تحتاج موافقة من الموارد البشرية'
                            : 'سيتم توزيع طلبك على أنسب سائق متاح',
                        style: TextStyle(color: Colors.blue[700], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
