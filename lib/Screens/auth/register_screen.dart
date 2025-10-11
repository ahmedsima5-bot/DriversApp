    import 'package:flutter/material.dart';
    import 'package:cloud_firestore/cloud_firestore.dart';

    class RegisterScreen extends StatefulWidget {
      final String companyId;
      const RegisterScreen({required this.companyId, super.key});

      @override
      State<RegisterScreen> createState() => _RegisterScreenState();
    }

    class _RegisterScreenState extends State<RegisterScreen> {
      final _formKey = GlobalKey<FormState>();
      String? _role; // 'موظف' أو 'سائق'
      String _name = '';
      String _phone = '';
      String _department = '';
      String _vehicleNumber = '';
      String _vehicleType = '';

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          appBar: AppBar(title: Text('تسجيل مستخدم جديد')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: InputDecoration(labelText: 'الدور'),
                    items: ['موظف', 'سائق'].map((role) =>
                        DropdownMenuItem(value: role, child: Text(role))
                    ).toList(),
                    onChanged: (val) => setState(() => _role = val),
                    validator: (val) => val == null ? 'اختر الدور' : null,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'الاسم'),
                    onChanged: (val) => _name = val,
                    validator: (val) => val == null || val.isEmpty ? 'الاسم مطلوب' : null,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'رقم الجوال'),
                    onChanged: (val) => _phone = val,
                    validator: (val) => val == null || val.isEmpty ? 'رقم الجوال مطلوب' : null,
                  ),
                  if (_role == 'موظف')
                    TextFormField(
                      decoration: InputDecoration(labelText: 'القسم'),
                      onChanged: (val) => _department = val,
                    ),
                  if (_role == 'سائق') ...[
                    TextFormField(
                      decoration: InputDecoration(labelText: 'رقم السيارة'),
                      onChanged: (val) => _vehicleNumber = val,
                    ),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'نوع السيارة'),
                      onChanged: (val) => _vehicleType = val,
                    ),
                  ],
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _register,
                    child: Text('تسجيل'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      Future<void> _register() async {
        if (!_formKey.currentState!.validate()) return;
        final data = {
          'name': _name,
          'phone': _phone,
          'companyId': widget.companyId,
        };
        if (_role == 'موظف') {
          data['department'] = _department;
          await FirebaseFirestore.instance.collection('employees').add(data);
        } else if (_role == 'سائق') {
          data['vehicleNumber'] = _vehicleNumber;
          data['vehicleType'] = _vehicleType;
          data['isOnline'] = false as String;
          data['isAvailable'] = true as String;
          await FirebaseFirestore.instance.collection('drivers').add(data);
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم التسجيل بنجاح!')));
        Navigator.pop(context);
      }
    }