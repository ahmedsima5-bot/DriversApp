// widgets/stats_cards.dart
import 'package:flutter/material.dart';

class StatsCards extends StatelessWidget {
  const StatsCards({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard('الطلبات المعلقة', '15', Colors.orange),
          const SizedBox(width: 8),
          _buildStatCard('الطلبات الجارية', '8', Colors.blue),
          const SizedBox(width: 8),
          _buildStatCard('الطلبات المكتملة', '32', Colors.green),
          const SizedBox(width: 8),
          _buildStatCard('طلبات عاجلة', '3', Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}