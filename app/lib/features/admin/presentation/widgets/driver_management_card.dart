import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../screens/admin_drivers_screen.dart';

class DriverManagementCard extends StatelessWidget {
  final AdminDriverInfo driver;
  final Function(String) onStatusChanged;
  final VoidCallback onViewDetails;
  final VoidCallback onSendMessage;

  const DriverManagementCard({
    super.key,
    required this.driver,
    required this.onStatusChanged,
    required this.onViewDetails,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header con información básica
            Row(
              children: [
                // Foto del conductor
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: driver.photoUrl != null
                      ? NetworkImage(driver.photoUrl!)
                      : null,
                  child: driver.photoUrl == null
                      ? Icon(
                          Icons.person,
                          color: Colors.grey[400],
                        )
                      : null,
                ),
                
                const SizedBox(width: 12),
                
                // Información del conductor
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${driver.licensePlate} • ${driver.vehicleModel}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                
                // Estado
                _buildStatusChip(),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Estadísticas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  'Calificación',
                  '${driver.rating}',
                  Icons.star,
                  Colors.amber[700]!,
                ),
                _buildStatItem(
                  context,
                  'Viajes',
                  '${driver.totalTrips}',
                  Icons.directions_car,
                  AppTheme.primaryColor,
                ),
                _buildStatItem(
                  context,
                  'Desde',
                  _formatJoinDate(driver.joinedDate),
                  Icons.calendar_today,
                  AppTheme.infoColor,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            
            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Ver detalles'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ),
                Container(
                  height: 20,
                  width: 1,
                  color: Colors.grey[300],
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onSendMessage,
                    icon: const Icon(Icons.message, size: 16),
                    label: const Text('Mensaje'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.infoColor,
                    ),
                  ),
                ),
                Container(
                  height: 20,
                  width: 1,
                  color: Colors.grey[300],
                ),
                PopupMenuButton<String>(
                  onSelected: onStatusChanged,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'active',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: AppTheme.successColor, size: 16),
                          SizedBox(width: 8),
                          Text('Activar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'suspended',
                      child: Row(
                        children: [
                          Icon(Icons.pause_circle, color: AppTheme.warningColor, size: 16),
                          SizedBox(width: 8),
                          Text('Suspender'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'blocked',
                      child: Row(
                        children: [
                          Icon(Icons.block, color: AppTheme.errorColor, size: 16),
                          SizedBox(width: 8),
                          Text('Bloquear'),
                        ],
                      ),
                    ),
                  ],
                  child: TextButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.more_vert, size: 16),
                    label: const Text('Más'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color backgroundColor;
    Color textColor;
    String text;

    switch (driver.status) {
      case 'online':
        backgroundColor = AppTheme.onlineColor.withOpacity(0.1);
        textColor = AppTheme.onlineColor;
        text = 'En línea';
        break;
      case 'offline':
        backgroundColor = AppTheme.offlineColor.withOpacity(0.1);
        textColor = AppTheme.offlineColor;
        text = 'Desconectado';
        break;
      case 'in_ride':
        backgroundColor = AppTheme.inRideColor.withOpacity(0.1);
        textColor = AppTheme.inRideColor;
        text = 'En viaje';
        break;
      case 'suspended':
        backgroundColor = AppTheme.warningColor.withOpacity(0.1);
        textColor = AppTheme.warningColor;
        text = 'Suspendido';
        break;
      case 'blocked':
        backgroundColor = AppTheme.errorColor.withOpacity(0.1);
        textColor = AppTheme.errorColor;
        text = 'Bloqueado';
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
        text = driver.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 16,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontSize: 10,
              ),
        ),
      ],
    );
  }

  String _formatJoinDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference < 30) {
      return '${difference}d';
    } else if (difference < 365) {
      return '${(difference / 30).round()}m';
    } else {
      return '${(difference / 365).round()}a';
    }
  }
}