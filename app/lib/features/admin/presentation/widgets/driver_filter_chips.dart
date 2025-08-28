import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class DriverFilterChips extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;

  const DriverFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = [
      FilterOption('all', 'Todos', Icons.group, null),
      FilterOption('online', 'En línea', Icons.circle, AppTheme.onlineColor),
      FilterOption('offline', 'Desconectados', Icons.circle_outlined, AppTheme.offlineColor),
      FilterOption('in_ride', 'En viaje', Icons.directions_car, AppTheme.inRideColor),
      FilterOption('suspended', 'Suspendidos', Icons.pause_circle, AppTheme.warningColor),
      FilterOption('blocked', 'Bloqueados', Icons.block, AppTheme.errorColor),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = selectedFilter == filter.value;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (filter.color != null)
                    Icon(
                      filter.icon,
                      size: 16,
                      color: isSelected 
                          ? Colors.white 
                          : filter.color,
                    )
                  else
                    Icon(
                      filter.icon,
                      size: 16,
                      color: isSelected 
                          ? Colors.white 
                          : AppTheme.primaryColor,
                    ),
                  const SizedBox(width: 6),
                  Text(filter.label),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onFilterChanged(filter.value);
                }
              },
              selectedColor: filter.color ?? AppTheme.primaryColor,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.grey[100],
              side: BorderSide(
                color: isSelected 
                    ? (filter.color ?? AppTheme.primaryColor)
                    : Colors.grey[300]!,
                width: 1,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FilterOption {
  final String value;
  final String label;
  final IconData icon;
  final Color? color;

  FilterOption(this.value, this.label, this.icon, this.color);
}