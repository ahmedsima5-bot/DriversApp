import 'package:flutter/material.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  String _selectedFilter = 'الكل';
  final List<String> _filters = ['الكل', 'قيد الانتظار', 'مقبول', 'مرفوض', 'مكتمل'];

  final List<Map<String, dynamic>> _allRequests = [
    {
      'type': 'طلب عاجل',
      'status': 'مقبول',
      'color': Colors.green,
      'date': '2024-01-15',
      'details': 'نقل موظفين من المقر الرئيسي إلى فرع المدينة',
      'location': 'الرياض - المقر الرئيسي'
    },
    {
      'type': 'طلب',
      'status': 'قيد الانتظار',
      'color': Colors.orange,
      'date': '2024-01-14',
      'details': 'نقل معدات مكتبية إلى الفرع الجديد',
      'location': 'جدة - الفرع الجديد'
    },
    {
      'type': 'طلب عاجل',
      'status': 'مرفوض',
      'color': Colors.red,
      'date': '2024-01-13',
      'details': 'نقل وثائق مهمة للاجتماع',
      'location': 'الدمام - مركز المؤتمرات'
    },
    {
      'type': 'طلب',
      'status': 'مكتمل',
      'color': Colors.blue,
      'date': '2024-01-12',
      'details': 'نقل فريق العمل لموقع المشروع',
      'location': 'الرياض - موقع المشروع'
    },
    {
      'type': 'طلب عاجل',
      'status': 'قيد الانتظار',
      'color': Colors.orange,
      'date': '2024-01-11',
      'details': 'نقل عينات للمختبر المركزي',
      'location': 'الرياض - المختبر المركزي'
    },
  ];

  List<Map<String, dynamic>> get _filteredRequests {
    if (_selectedFilter == 'الكل') {
      return _allRequests;
    }
    return _allRequests.where((request) => request['status'] == _selectedFilter).toList();
  }

  void _refreshData() {
    setState(() {
      // محاكاة تحديث البيانات
      // في التطبيق الحقيقي، هنا ستجلب البيانات من Firebase
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تحديث البيانات'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تصفية الطلبات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _filters.map((filter) {
            return RadioListTile<String>(
              title: Text(filter),
              value: filter,
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() {
                  _selectedFilter = value!;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRequestCard(int index) {
    final request = _filteredRequests[index];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${request['type']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.indigo
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: request['color'] as Color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    request['status'] as String,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${request['date']}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${request['location']}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${request['details']}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (request['status'] == 'مقبول') ...[
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.directions_car, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  const Text('السائق: أحمد محمد'),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      // TODO: الاتصال بالسائق
                    },
                    child: const Text('اتصال'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // زر التصفية
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'تصفية الطلبات',
          ),
          // زر التحديث
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط الفلاتر السريعة
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.grey.shade50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          _selectedFilter = selected ? filter : 'الكل';
                        });
                      },
                      selectedColor: Colors.indigo.shade100,
                      checkmarkColor: Colors.indigo,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.indigo : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // عدد النتائج
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'عدد الطلبات: ${_filteredRequests.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                if (_selectedFilter != 'الكل')
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedFilter = 'الكل';
                      });
                    },
                    child: const Text('إلغاء التصفية'),
                  ),
              ],
            ),
          ),

          // قائمة الطلبات
          Expanded(
            child: _filteredRequests.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد طلبات',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'جرب تغيير عوامل التصفية',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _filteredRequests.length,
              itemBuilder: (context, index) {
                return _buildRequestCard(index);
              },
            ),
          ),
        ],
      ),
    );
  }
}