import 'package:flutter/material.dart';

class DriverStatsWidget extends StatelessWidget {
  final int totalTrips;
  final double earnings;
  final double rating;
  
  const DriverStatsWidget({
    Key? key,
    required this.totalTrips,
    required this.earnings,
    required this.rating,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(label: 'Viajes', value: totalTrips.toString()),
            _StatItem(label: 'Ganancias', value: '\$${earnings.toStringAsFixed(2)}'),
            _StatItem(label: 'Rating', value: rating.toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  
  const _StatItem({required this.label, required this.value});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
