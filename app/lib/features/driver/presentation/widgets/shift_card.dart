import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/shift.dart';

/// Tarjeta que muestra la información de un turno
class ShiftCard extends StatelessWidget {
  final Shift shift;
  final bool showDetails;
  final VoidCallback? onStart;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ShiftCard({
    super.key,
    required this.shift,
    this.showDetails = false,
    this.onStart,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIndicator(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTimeRange(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, dd MMM yyyy', 'es').format(shift.startTime),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
            
            if (showDetails) ...[
              const Divider(height: 24),
              _buildDetails(context),
            ],

            const SizedBox(height: 12),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Color(shift.status.colorValue),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildStatusChip() {
    return Chip(
      label: Text(
        shift.status.displayName,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      backgroundColor: Color(shift.status.colorValue),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shift.notes != null) ...[
          Row(
            children: [
              Icon(Icons.note, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shift.notes!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // Horarios reales si el turno está activo o completado
        if (shift.actualStartTime != null) ...[
          Row(
            children: [
              Icon(Icons.play_circle, size: 16, color: Colors.green[600]),
              const SizedBox(width: 8),
              Text(
                'Iniciado: ${DateFormat('HH:mm').format(shift.actualStartTime!)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],

        if (shift.actualEndTime != null) ...[
          Row(
            children: [
              Icon(Icons.stop_circle, size: 16, color: Colors.red[600]),
              const SizedBox(width: 8),
              Text(
                'Finalizado: ${DateFormat('HH:mm').format(shift.actualEndTime!)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // Estadísticas del turno
        if (shift.status == ShiftStatus.completed) ...[
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  Icons.attach_money,
                  'Ganancias',
                  '\$${shift.actualEarnings.toStringAsFixed(2)}',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  Icons.directions_car,
                  'Viajes',
                  '${shift.completedRides}',
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (shift.actualStartTime != null && shift.actualEndTime != null) ...[
            _buildStatItem(
              Icons.access_time,
              'Duración',
              _formatDuration(shift.actualEndTime!.difference(shift.actualStartTime!)),
              Colors.orange,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final buttons = <Widget>[];

    // Botón para iniciar turno
    if (shift.status == ShiftStatus.scheduled && onStart != null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow, size: 16),
          label: const Text('Iniciar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    // Botón para editar
    if (shift.status == ShiftStatus.scheduled && onEdit != null) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Editar'),
        ),
      );
    }

    // Botón para eliminar
    if (shift.status == ShiftStatus.scheduled && onDelete != null) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete, size: 16),
          label: const Text('Eliminar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buttons,
    );
  }

  String _formatTimeRange() {
    final startTime = DateFormat('HH:mm').format(shift.startTime);
    final endTime = DateFormat('HH:mm').format(shift.endTime);
    return '$startTime - $endTime';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}