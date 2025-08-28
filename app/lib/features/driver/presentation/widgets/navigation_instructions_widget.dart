import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_theme.dart';

class NavigationInstructionsWidget extends StatelessWidget {
  final String instruction;
  final double distance;
  final int estimatedTime;
  final bool isNavigatingToDestination;

  const NavigationInstructionsWidget({
    super.key,
    required this.instruction,
    required this.distance,
    required this.estimatedTime,
    required this.isNavigatingToDestination,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 50),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Estado de la navegación
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isNavigatingToDestination
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isNavigatingToDestination
                              ? Icons.location_on
                              : Icons.person_pin_circle,
                          size: 16,
                          color: isNavigatingToDestination
                              ? AppTheme.primaryColor
                              : AppTheme.warningColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isNavigatingToDestination
                              ? 'Hacia el destino'
                              : 'Hacia la recogida',
                          style: TextStyle(
                            color: isNavigatingToDestination
                                ? AppTheme.primaryColor
                                : AppTheme.warningColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Tiempo estimado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.infoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppTheme.infoColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${estimatedTime}min',
                          style: TextStyle(
                            color: AppTheme.infoColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Instrucción principal
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getInstructionIcon(),
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instruction,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getDistanceText(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2);
  }

  IconData _getInstructionIcon() {
    if (instruction.contains('norte')) return Icons.north;
    if (instruction.contains('sur')) return Icons.south;
    if (instruction.contains('este')) return Icons.east;
    if (instruction.contains('oeste')) return Icons.west;
    if (instruction.contains('noreste')) return Icons.north_east;
    if (instruction.contains('noroeste')) return Icons.north_west;
    if (instruction.contains('sureste')) return Icons.south_east;
    if (instruction.contains('suroeste')) return Icons.south_west;
    return Icons.straight;
  }

  String _getDistanceText() {
    if (distance > 1) {
      return '${distance.toStringAsFixed(1)} km restantes';
    } else {
      final meters = (distance * 1000).round();
      return '$meters metros restantes';
    }
  }
}