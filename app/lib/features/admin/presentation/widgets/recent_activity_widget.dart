import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';

class RecentActivityWidget extends StatelessWidget {
  const RecentActivityWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final activities = _getMockActivities();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _buildActivityItem(context, activity);
      },
    );
  }

  Widget _buildActivityItem(BuildContext context, ActivityItem activity) {
    return Row(
      children: [
        // Icono con color de estado
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: activity.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            activity.icon,
            color: activity.color,
            size: 20,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Contenido
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                activity.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
        
        // Hora
        Text(
          activity.time,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
        ),
      ],
    );
  }

  List<ActivityItem> _getMockActivities() {
    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm');

    return [
      ActivityItem(
        title: 'Nuevo conductor registrado',
        description: 'Carlos Mendoza completó su registro',
        time: timeFormat.format(now.subtract(const Duration(minutes: 15))),
        icon: Icons.person_add,
        color: AppTheme.successColor,
      ),
      ActivityItem(
        title: 'Viaje completado',
        description: 'Viaje de San Isidro a Miraflores - S/ 25.50',
        time: timeFormat.format(now.subtract(const Duration(minutes: 28))),
        icon: Icons.check_circle,
        color: AppTheme.primaryColor,
      ),
      ActivityItem(
        title: 'Reporte de problema',
        description: 'Usuario reportó problema con el pago',
        time: timeFormat.format(now.subtract(const Duration(minutes: 42))),
        icon: Icons.warning,
        color: AppTheme.warningColor,
      ),
      ActivityItem(
        title: 'Pico de demanda',
        description: '25 solicitudes en la última hora',
        time: timeFormat.format(now.subtract(const Duration(hours: 1, minutes: 5))),
        icon: Icons.trending_up,
        color: AppTheme.infoColor,
      ),
      ActivityItem(
        title: 'Conductor desconectado',
        description: 'María López terminó su jornada',
        time: timeFormat.format(now.subtract(const Duration(hours: 1, minutes: 18))),
        icon: Icons.logout,
        color: Colors.grey,
      ),
    ];
  }
}

class ActivityItem {
  final String title;
  final String description;
  final String time;
  final IconData icon;
  final Color color;

  ActivityItem({
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    required this.color,
  });
}