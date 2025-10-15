import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  final _responsiblePhoneController = TextEditingController();
  final _destinationController = TextEditingController(); // ✨ حقل جديد للوجهة

  String _selectedType = 'طلب';
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب نقل جديد'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'نموذج طلب النقل',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // نوع الطلب
              const Text('نوع الطلب:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: ['طلب', 'طلب عاجل'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedType = newValue!;
                  });
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                ),
              ),

              const SizedBox(height: 20),

              // ✨ حقل الوجهة الجديد - مطلوب للـ HR
              const Text('الوجهة:', style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _destinationController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'أدخل الوجهة أو الموقع النهائي',
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال الوجهة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 5),
              const Text(
                'هذا الحقل مطلوب لعرض الطلب في إدارة الموارد البشرية',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),

              const SizedBox(height: 20),

              // تاريخ الطلب
              const Text('التاريخ المطلوب:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // اختيار الموقع من الخرائط
              const Text('موقع الالتقاء:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _openMapPicker,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade800,
                  side: BorderSide(color: Colors.blue.shade200),
                ),
                icon: const Icon(Icons.location_on),
                label: const Text('اختيار موقع الالتقاء من الخرائط'),
              ),
              const SizedBox(height: 5),
              const Text(
                'اضغط لاختيار موقع الالتقاء من خرائط جوجل',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),

              const SizedBox(height: 20),

              // رقم الشخص المسؤول
              const Text('رقم الهاتف المسؤول:', style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _responsiblePhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'أدخل رقم الهاتف للشخص المسؤول',
                  prefixText: '+966 ',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال رقم الهاتف';
                  }
                  if (value.length < 9) {
                    return 'رقم الهاتف يجب أن يكون 9 أرقام على الأقل';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // تفاصيل الطلب
              const Text('تفاصيل إضافية:', style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _detailsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'أدخل تفاصيل إضافية عن الطلب (الأشخاص، المعدات، المتطلبات الخاصة)',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال تفاصيل الطلب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 5),
              const Text(
                'اذكر أسماء الأشخاص، المعدات، المتطلبات الخاصة، وأي تفاصيل أخرى مهمة',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),

              const SizedBox(height: 30),

              // زر الإرسال
              ElevatedButton(
                onPressed: _submitRequest,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: const Text('إرسال الطلب', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _openMapPicker() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم فتح خرائط جوجل لاختيار الموقع')),
    );
  }

  void _submitRequest() async {
    if (_formKey.currentState!.validate()) {
      try {
        // إظهار تحميل
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // جلب بيانات المستخدم الحالي
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
          );
          return;
        }

        // جلب بيانات المستخدم الإضافية
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final userData = userDoc.data();
        final companyId = userData?['company_id'] ?? 'unknown';
        final userName = userData?['name'] ?? 'غير معروف';
        final department = userData?['department'] ?? 'غير محدد';

        // تحديد الأولوية بناءً على نوع الطلب
        final priority = _selectedType == 'طلب عاجل' ? 'Urgent' : 'Normal';

        // ✨ إنشاء الطلب مع الحقول المطلوبة للـ HR
        final requestData = {
          'companyId': companyId,
          'requesterId': user.uid,
          'requesterName': userName,
          'department': department,

          // الحقول الأساسية للـ HR
          'toLocation': _destinationController.text, // ✨ الحقل الجديد المهم
          'fromLocation': 'المقر الرئيسي',

          // الحقول الإضافية
          'purposeType': _selectedType,
          'details': _detailsController.text,
          'priority': priority,
          'responsiblePhone': _responsiblePhoneController.text,
          'status': priority == 'Urgent' ? 'HR_PENDING' : 'PENDING',
          'expectedTime': Timestamp.fromDate(_selectedDate),
          'createdAt': FieldValue.serverTimestamp(),
        };

        print('📤 إرسال الطلب إلى Firebase: $requestData');

        // إرسال الطلب لـ Firebase
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('requests')
            .add(requestData);

        // إغلاق التحمل
        Navigator.pop(context);

        // رسالة نجاح
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال الطلب بنجاح - سيظهر في إدارة الطلبات'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // تنظيف الحقول
        _detailsController.clear();
        _responsiblePhoneController.clear();
        _destinationController.clear(); // ✨ تنظيف الحقل الجديد
        setState(() {
          _selectedType = 'طلب';
          _selectedDate = DateTime.now();
        });

        // العودة للصفحة السابقة بعد ثانيتين
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });

      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إرسال الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _responsiblePhoneController.dispose();
    _destinationController.dispose(); // ✨ تنظيف الحقل الجديد
    super.dispose();
  }
}