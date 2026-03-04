import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/modern_theme.dart';
import '../../providers/emergency_provider.dart';

/// Pantalla de detalles de emergencia activa
/// Muestra información completa de una emergencia en curso
class EmergencyDetailsScreen extends StatefulWidget {
  final String emergencyId;

  const EmergencyDetailsScreen({
    super.key,
    required this.emergencyId,
  });

  @override
  State<EmergencyDetailsScreen> createState() => _EmergencyDetailsScreenState();
}

class _EmergencyDetailsScreenState extends State<EmergencyDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergencia Activa'),
        backgroundColor: ModernTheme.error,
      ),
      body: Consumer<EmergencyProvider>(
        builder: (context, provider, _) {
          final emergency = provider.activeAlert;

          if (emergency == null) {
            return _buildEmptyState();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Alerta principal
                _buildAlertBanner(emergency),
                const SizedBox(height: 24),

                // Información del usuario
                _buildUserInfo(emergency),
                const SizedBox(height: 24),

                // Ubicación
                _buildLocationInfo(emergency),
                const SizedBox(height: 24),

                // Tipo de emergencia
                _buildEmergencyType(emergency),
                const SizedBox(height: 24),

                // Información del viaje (si existe)
                if (emergency.tripId != null) ...[
                  _buildTripInfo(emergency),
                  const SizedBox(height: 24),
                ],

                // Notas adicionales
                if (emergency.description != null && emergency.description!.isNotEmpty) ...[
                  _buildNotes(emergency),
                  const SizedBox(height: 24),
                ],

                // Contactos de emergencia
                _buildEmergencyContacts(emergency),
                const SizedBox(height: 24),

                // Línea de tiempo
                _buildTimeline(emergency),
                const SizedBox(height: 24),

                // Acciones
                _buildActions(emergency),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Emergencia no encontrada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(dynamic emergency) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ModernTheme.error,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 60,
            color: theme.colorScheme.onError,
          ),
          const SizedBox(height: 12),
          Text(
            'EMERGENCIA ACTIVA',
            style: TextStyle(
              color: theme.colorScheme.onError,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            emergency.status == 'active' ? 'EN CURSO' : 'FINALIZADA',
            style: TextStyle(
              color: theme.colorScheme.onError,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildTimer(emergency.createdAt),
        ],
      ),
    );
  }

  Widget _buildTimer(DateTime createdAt) {
    final theme = Theme.of(context);
    final elapsed = DateTime.now().difference(createdAt);
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.onError.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Tiempo transcurrido: $minutes:${seconds.toString().padLeft(2, '0')}',
        style: TextStyle(
          color: theme.colorScheme.onError,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUserInfo(dynamic emergency) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información del usuario',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: emergency.userPhoto != null
                      ? NetworkImage(emergency.userPhoto!)
                      : null,
                  child: emergency.userPhoto == null
                      ? const Icon(Icons.person, size: 32)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emergency.userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        emergency.userRole == 'passenger'
                            ? 'Pasajero'
                            : 'Conductor',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      if (emergency.userPhone != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              emergency.userPhone!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _makePhoneCall(emergency.userPhone),
                  icon: Icon(Icons.phone, color: ModernTheme.success),
                  iconSize: 32,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo(dynamic emergency) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ubicación',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: ModernTheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emergency.locationAddress ?? 'Ubicación no disponible',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lat: ${emergency.locationLat?.toStringAsFixed(6) ?? 'N/A'}\n'
                        'Lng: ${emergency.locationLng?.toStringAsFixed(6) ?? 'N/A'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openInMaps(
                  emergency.locationLat,
                  emergency.locationLng,
                ),
                icon: const Icon(Icons.map),
                label: const Text('Abrir en Google Maps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.rappiOrange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyType(dynamic emergency) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tipo de emergencia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.error.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _getEmergencyIcon(emergency.type),
                    color: ModernTheme.error,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _getEmergencyTypeText(emergency.type),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripInfo(dynamic emergency) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información del viaje',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            _buildInfoRow('ID del viaje', emergency.tripId ?? 'N/A'),
            if (emergency.driverName != null)
              _buildInfoRow('Conductor', emergency.driverName!),
            if (emergency.vehiclePlate != null)
              _buildInfoRow('Placa del vehículo', emergency.vehiclePlate!),
          ],
        ),
      ),
    );
  }

  Widget _buildNotes(dynamic emergency) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notas adicionales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            Text(
              emergency.description!,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContacts(dynamic emergency) {
    final contacts = [
      {
        'icon': Icons.local_police,
        'label': 'Policía',
        'phone': '105',
        'color': Theme.of(context).colorScheme.primary,
      },
      {
        'icon': Icons.local_hospital,
        'label': 'SAMU - 106',
        'phone': '106',
        'color': ModernTheme.error,
      },
      {
        'icon': Icons.fire_truck,
        'label': 'Bomberos',
        'phone': '116',
        'color': Theme.of(context).colorScheme.tertiary,
      },
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contactos de emergencia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            // Chips horizontales scrolleables
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: contacts.map((contact) {
                  final icon = contact['icon'] as IconData;
                  final label = contact['label'] as String;
                  final phone = contact['phone'] as String;
                  final color = contact['color'] as Color;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ActionChip(
                      avatar: Icon(icon, color: color, size: 18),
                      label: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      backgroundColor: color.withValues(alpha: 0.1),
                      side: BorderSide(color: color.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      onPressed: () => _makePhoneCall(phone),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(dynamic emergency) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Línea de tiempo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            _buildTimelineItem(
              icon: Icons.add_alert,
              label: 'Emergencia reportada',
              time: emergency.createdAt,
              isFirst: true,
            ),
            if (emergency.respondedAt != null)
              _buildTimelineItem(
                icon: Icons.support_agent,
                label: 'Respuesta iniciada',
                time: emergency.respondedAt,
              ),
            if (emergency.resolvedAt != null)
              _buildTimelineItem(
                icon: Icons.check_circle,
                label: 'Emergencia resuelta',
                time: emergency.resolvedAt,
                isLast: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required String label,
    required DateTime time,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna izquierda: linea naranja con dots
        SizedBox(
          width: 40,
          child: Column(
            children: [
              // Linea superior (naranja)
              if (!isFirst)
                Container(
                  width: 3,
                  height: 16,
                  color: ModernTheme.rappiOrange.withValues(alpha: 0.5),
                ),
              // Dot circular naranja
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ModernTheme.rappiOrange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ModernTheme.rappiOrange,
                    width: 2,
                  ),
                ),
                child: Icon(icon, color: ModernTheme.rappiOrange, size: 18),
              ),
              // Linea inferior (naranja)
              if (!isLast)
                Container(
                  width: 3,
                  height: 20,
                  color: ModernTheme.rappiOrange.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20, top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(time),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(dynamic emergency) {
    if (emergency.status != 'active') {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _resolveEmergency(emergency.id),
            icon: const Icon(Icons.check_circle),
            label: const Text('Marcar como resuelta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.success,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _shareEmergency(emergency),
            icon: const Icon(Icons.share),
            label: const Text('Compartir información'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ModernTheme.rappiOrange,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getEmergencyIcon(String type) {
    switch (type) {
      case 'accident':
        return Icons.car_crash;
      case 'assault':
        return Icons.warning;
      case 'medical':
        return Icons.medical_services;
      case 'other':
        return Icons.report_problem;
      default:
        return Icons.emergency;
    }
  }

  String _getEmergencyTypeText(String type) {
    switch (type) {
      case 'accident':
        return 'Accidente';
      case 'assault':
        return 'Asalto/Agresión';
      case 'medical':
        return 'Emergencia médica';
      case 'other':
        return 'Otra emergencia';
      default:
        return 'Emergencia';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null) return;

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openInMaps(double? lat, double? lng) async {
    if (lat == null || lng == null) return;

    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _resolveEmergency(String emergencyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolver emergencia'),
        content: const Text(
          '¿Estás seguro de que la emergencia ha sido resuelta?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.success,
            ),
            child: const Text('Sí, resolver'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<EmergencyProvider>(context, listen: false);

      try {
        await provider.deactivateSOS(resolution: 'Resuelta manualmente');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergencia resuelta exitosamente'),
              backgroundColor: ModernTheme.success,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al resolver emergencia: $e'),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _shareEmergency(dynamic emergency) async {
    final text = '''
🚨 EMERGENCIA ACTIVA

Usuario: ${emergency.userName}
Tipo: ${_getEmergencyTypeText(emergency.type)}
Ubicación: ${emergency.locationAddress ?? 'No disponible'}
Coordenadas: ${emergency.locationLat}, ${emergency.locationLng}
Teléfono: ${emergency.userPhone ?? 'No disponible'}

Hora: ${_formatDateTime(emergency.createdAt)}
''';

    await Clipboard.setData(ClipboardData(text: text));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Información copiada al portapapeles'),
        ),
      );
    }
  }
}
