import 'package:flutter/material.dart';

class UrgentRequestAlert extends StatelessWidget {
  final int urgentCount;

  const UrgentRequestAlert({
    super.key,
    required this.urgentCount,
  });

  @override
  Widget build(BuildContext context) {
    if (urgentCount == 0) {
      return const SizedBox.shrink(); // لا تظهر إذا لم توجد طلبات عاجلة
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'يوجد $urgentCount طلبات عاجلة تحتاج موافقة',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'يرجى مراجعة هذه الطلبات بأولوية',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}