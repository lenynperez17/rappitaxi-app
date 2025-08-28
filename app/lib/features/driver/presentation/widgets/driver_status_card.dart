import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_theme.dart';

class DriverStatusCard extends StatelessWidget {
  final String status;
  final double earnings;
  final double rating;
  final Function(String) onStatusChanged;

  const DriverStatusCard({
    super.key,
    required this.status,
    required this.earnings,
    required this.rating,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Switch de estado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getStatusText(status),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(status),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStatusDescription(status),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
              Switch(
                value: status == 'online',
                onChanged: (value) {
                  onStatusChanged(value ? 'online' : 'offline');
                },
                activeColor: AppTheme.onlineColor,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          // Estadísticas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                icon: Icons.monetization_on,
                value: 'S/ ${earnings.toStringAsFixed(2)}',
                label: 'Hoy',
                color: AppTheme.earningsColor,
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.grey[300],
              ),
              _buildStatItem(
                context,
                icon: Icons.star,
                value: rating.toStringAsFixed(1),
                label: 'Calificación',
                color: Colors.amber[700]!,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'online':
        return 'Conectado';
      case 'busy':
        return 'Ocupado';
      case 'in_ride':
        return 'En viaje';
      case 'offline':
      default:
        return 'Desconectado';
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'online':
        return 'Recibiendo solicitudes';
      case 'busy':
        return 'Temporalmente no disponible';
      case 'in_ride':
        return 'Viaje en progreso';
      case 'offline':
      default:
        return 'No estás recibiendo solicitudes';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online':
        return AppTheme.onlineColor;
      case 'busy':
        return AppTheme.busyColor;
      case 'in_ride':
        return AppTheme.inRideColor;
      case 'offline':
      default:
        return AppTheme.offlineColor;
    }
  }
}