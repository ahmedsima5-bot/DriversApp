import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../models/request_model.dart';

class NewRequestScreen extends StatefulWidget {
  final String companyId;
  final String userId;
  const NewRequestScreen({
    required this.companyId,
    required this.userId,
    super.key,
  });

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String _requesterName = '';
  String _department = '';
  String _purpose = '';
  String _details = '';
  String _priority = 'عادي'; // عادي أو عاجل
  DateTime _expectedTime = DateTime.now().add(const Duration(hours: 2));
  List<String> _departments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final departments = List<String>.from(data['departments'] ?? []);
        setState(() {
          _departments = departments;
          if (departments.isNotEmpty) {
            _department = departments.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الأقسام: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _expectedTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      if (mounted) {
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_expectedTime),
        );

        if (pickedTime != null) {
          setState(() {
            _expectedTime = DateTime(
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
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      final requestId = const Uuid().v4();
      final now = DateTime.now();

      final request = Request(
        requestId: requestId,
        requesterId: widget.userId,
        requesterName: _requesterName.trim(),
        department: _department,
        purpose: _purpose.trim(),
        details: _details.trim(),
        priority: _priority,
        status: _priority == 'عاجل'
            ? 'بانتظار موافقة الموارد البشرية'
            : 'معلق',
        requestedTime: now,
        expectedTime: _expectedTime,
      );

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('requests')
          .doc(requestId)
          .set(request.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _priority == 'عاجل'
                  ? 'تم إرسال الطلب للموافقة من قبل الموارد البشرية'
                  : 'تم إنشاء الطلب وسيتم توزيعه على سائق',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب خدمة سائق جديدة'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
                decoration: InputDecoration(
                  hintText: 'أدخل اسمك الكامل',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (val) =>
                val == null || val.isEmpty ? 'الاسم مطلوب' : null,
                onChanged: (val) => _requesterName = val,
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
                value: _department,
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
                val == null ? 'اختر القسم' : null,
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
                onChanged: (val) => _purpose = val,
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
                onChanged: (val) => _details = val,
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
                            '${_expectedTime.day}/${_expectedTime.month}/${_expectedTime.year} - '
                                '${_expectedTime.hour}:${_expectedTime.minute.toString().padLeft(2, '0')}',
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