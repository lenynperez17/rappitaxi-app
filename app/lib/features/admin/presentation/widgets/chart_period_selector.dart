import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class ChartPeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final Function(String) onPeriodChanged;

  const ChartPeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final periods = [
      {'value': 'day', 'label': 'Día'},
      {'value': 'week', 'label': 'Semana'},
      {'value': 'month', 'label': 'Mes'},
      {'value': 'year', 'label': 'Año'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Período:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: periods.map((period) {
                  final isSelected = selectedPeriod == period['value'];
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(period['label']!),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          onPeriodChanged(period['value']!);
                        }
                      },
                      selectedColor: AppTheme.primaryColor,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: Colors.grey[100],
                      side: BorderSide(
                        color: isSelected 
                            ? AppTheme.primaryColor
                            : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}