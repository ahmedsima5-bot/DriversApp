import 'package:flutter/material.dart';

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  final _responsiblePhoneController = TextEditingController();

  // ✅ التصحيح: تغيير القيمة الافتراضية لتتوافق مع القائمة
  String _selectedType = 'طلب'; // كانت 'عاجل' ولكن القائمة تحتوي على 'طلب' و 'طلب عاجل'

  DateTime _selectedDate = DateTime.now();

  // ... باقي الدوال تبقى كما هي

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

              // نوع الطلب - ✅ التصحيح هنا
              const Text('نوع الطلب:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                value: _selectedType,
                // ✅ التأكد من أن القائمة تحتوي على القيمة الافتراضية
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

              // ... باقي الكود يبقى كما هو
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
              const Text('الموقع:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                label: const Text('اختيار الموقع من الخرائط'),
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
              const Text('تفاصيل الطلب:', style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _detailsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'أدخل تفاصيل الطلب (يرجى اضافة الموقع وتفاصيل التسليم او الشحنة او وصف المشوار)',
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
    // TODO: فتح خرائط جوجل لاختيار الموقع
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم فتح خرائط جوجل لاختيار الموقع')),
    );
  }

  void _submitRequest() {
    if (_formKey.currentState!.validate()) {
      // TODO: تنفيذ إرسال الطلب إلى Firebase
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الطلب بنجاح')),
      );
      _detailsController.clear();
      _responsiblePhoneController.clear();
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _responsiblePhoneController.dispose();
    super.dispose();
  }
}