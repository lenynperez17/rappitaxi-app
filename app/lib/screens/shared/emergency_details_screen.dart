import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/emergency_provider.dart';
import '../../utils/error_messages.dart';

/// Emergency details screen - shows info about an active emergency
class EmergencyDetailsScreen extends StatefulWidget {
  final String emergencyId;
  const EmergencyDetailsScreen({super.key, required this.emergencyId});
  @override
  State<EmergencyDetailsScreen> createState() => _EmergencyDetailsScreenState();
}

class _EmergencyDetailsScreenState extends State<EmergencyDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Emergencia Activa'), backgroundColor: AppColors.error, foregroundColor: Colors.white),
      body: Consumer<EmergencyProvider>(builder: (context, provider, _) {
        final emergency = provider.activeAlert;
        if (emergency == null) return _buildEmptyState();
        // Ronda 214: SafeArea previene que el contenido quede tapado por
        // notch/home indicator en iPhones nuevos.
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildAlertBanner(emergency), const SizedBox(height: 24),
              _buildUserInfo(emergency), const SizedBox(height: 16),
              _buildLocationInfo(emergency), const SizedBox(height: 16),
              _buildEmergencyType(emergency), const SizedBox(height: 16),
              if (emergency.tripId != null) ...[_buildTripInfo(emergency), const SizedBox(height: 16)],
              if (emergency.description != null && emergency.description!.isNotEmpty) ...[_buildNotes(emergency), const SizedBox(height: 16)],
              _buildEmergencyContacts(emergency), const SizedBox(height: 16),
              _buildTimeline(emergency), const SizedBox(height: 16),
              _buildActions(emergency),
            ]),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 80, color: AppColors.getTextSecondary(context)),
      const SizedBox(height: 16),
      Text('Emergencia no encontrada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextSecondary(context))),
    ]));
  }

  Widget _buildAlertBanner(dynamic emergency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.white),
        const SizedBox(height: 12),
        Text('EMERGENCIA ACTIVA', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(emergency.status == 'active' ? 'Emergencia en curso' : 'Emergencia finalizada', style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 12),
        _buildTimer(emergency.createdAt),
      ]),
    );
  }

  Widget _buildTimer(DateTime createdAt) {
    final elapsed = DateTime.now().difference(createdAt);
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: AppColors.getSurface(context).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
      child: Text('Tiempo transcurrido: ${minutes}m ${seconds.toString().padLeft(2, '0')}s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildUserInfo(dynamic emergency) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Informacion del Usuario', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(height: 24),
        Row(children: [
          CircleAvatar(radius: 32, backgroundImage: emergency.userPhoto != null ? NetworkImage(emergency.userPhoto!) : null, child: emergency.userPhoto == null ? const Icon(Icons.person, size: 32) : null),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emergency.userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(emergency.userRole == 'passenger' ? 'Pasajero' : 'Conductor', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 14)),
            if (emergency.userPhone != null) ...[const SizedBox(height: 4), Row(children: [Icon(Icons.phone, size: 16, color: AppColors.getTextSecondary(context)), const SizedBox(width: 4), Text(emergency.userPhone!, style: TextStyle(color: AppColors.getTextSecondary(context)))])],
          ])),
          IconButton(onPressed: () => _makePhoneCall(emergency.userPhone), icon: const Icon(Icons.phone, color: AppColors.success), iconSize: 32),
        ]),
      ])),
    );
  }

  Widget _buildLocationInfo(dynamic emergency) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ubicación', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(height: 24),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.location_on, color: AppColors.error), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emergency.locationAddress ?? 'Ubicacion no disponible', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Lat: ${emergency.locationLat?.toStringAsFixed(6) ?? 'N/A'}\nLng: ${emergency.locationLng?.toStringAsFixed(6) ?? 'N/A'}', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () => _openInMaps(emergency.locationLat, emergency.locationLng),
          icon: const Icon(Icons.map), label: Text('Abrir en Google Maps'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.rappiOrange, foregroundColor: Colors.white),
        )),
      ])),
    );
  }

  Widget _buildEmergencyType(dynamic emergency) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tipo de Emergencia', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(height: 24),
        Container(
          padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [Icon(_getEmergencyIcon(emergency.type), color: AppColors.error, size: 32), const SizedBox(width: 12), Text(_getEmergencyTypeText(emergency.type), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
        ),
      ])),
    );
  }

  Widget _buildTripInfo(dynamic emergency) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Informacion del Viaje', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(height: 24),
        _buildInfoRow('ID del viaje', emergency.tripId ?? 'N/A'),
        if (emergency.driverName != null) _buildInfoRow('Conductor', emergency.driverName!),
        if (emergency.vehiclePlate != null) _buildInfoRow('Placa', emergency.vehiclePlate!),
      ])),
    );
  }

  Widget _buildNotes(dynamic emergency) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Notas Adicionales', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(height: 24),
        Text(emergency.description!, style: const TextStyle(fontSize: 16)),
      ])),
    );
  }

  Widget _buildEmergencyContacts(dynamic emergency) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Contactos de Emergencia', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(height: 24),
        _buildContactButton(icon: Icons.local_police, label: 'Policía - 105', phone: '105', color: Colors.blue),
        const SizedBox(height: 8),
        _buildContactButton(icon: Icons.local_hospital, label: 'SAMU - 106', phone: '106', color: AppColors.error),
        const SizedBox(height: 8),
        _buildContactButton(icon: Icons.fire_truck, label: 'Bomberos - 116', phone: '116', color: Colors.orange),
      ])),
    );
  }

  Widget _buildContactButton({required IconData icon, required String label, required String phone, required Color color}) {
    return InkWell(
      onTap: () => _makePhoneCall(phone), borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [Icon(icon, color: color), const SizedBox(width: 12), Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))), Icon(Icons.phone, color: color)]),
      ),
    );
  }

  Widget _buildTimeline(dynamic emergency) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Linea de Tiempo', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(height: 24),
        _buildTimelineItem(icon: Icons.add_alert, label: 'Emergencia reportada', time: emergency.createdAt, isFirst: true),
        if (emergency.respondedAt != null) _buildTimelineItem(icon: Icons.support_agent, label: 'Respuesta iniciada', time: emergency.respondedAt),
        if (emergency.resolvedAt != null) _buildTimelineItem(icon: Icons.check_circle, label: 'Emergencia resuelta', time: emergency.resolvedAt, isLast: true),
      ])),
    );
  }

  Widget _buildTimelineItem({required IconData icon, required String label, required DateTime time, bool isFirst = false, bool isLast = false}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        if (!isFirst) Container(width: 2, height: 20, color: AppColors.getBorder(context)),
        Icon(icon, color: AppColors.rappiOrange),
        if (!isLast) Container(width: 2, height: 20, color: AppColors.getBorder(context)),
      ]),
      const SizedBox(width: 12),
      Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(_formatDateTime(time), style: TextStyle(color: Colors.grey[600], fontSize: 14)),
      ]))),
    ]);
  }

  Widget _buildActions(dynamic emergency) {
    if (emergency.status != 'active') return const SizedBox.shrink();
    return Column(children: [
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: () => _resolveEmergency(emergency.id),
        icon: const Icon(Icons.check_circle), label: Text('Marcar como Resuelta'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: () => _shareEmergency(emergency),
        icon: const Icon(Icons.share), label: Text('Compartir Informacion'),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.rappiOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
    ]);
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 14)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
    ]));
  }

  IconData _getEmergencyIcon(String type) {
    switch (type) { case 'accident': return Icons.car_crash; case 'assault': return Icons.warning; case 'medical': return Icons.medical_services; case 'other': return Icons.report_problem; default: return Icons.emergency; }
  }

  String _getEmergencyTypeText(String type) {
    switch (type) { case 'accident': return 'Accidente'; case 'assault': return 'Asalto'; case 'medical': return 'Emergencia Medica'; case 'other': return 'Otro'; default: return 'Emergencia'; }
  }

  String _formatDateTime(DateTime dateTime) { return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}'; }

  Future<void> _makePhoneCall(String? phone) async { if (phone == null) return; final uri = Uri.parse('tel:$phone'); if (await canLaunchUrl(uri)) { await launchUrl(uri); } }

  Future<void> _openInMaps(double? lat, double? lng) async { if (lat == null || lng == null) return; final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'); if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); } }

  Future<void> _resolveEmergency(String emergencyId) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('Resolver Emergencia'), content: Text('Estás seguro de que deseas marcar esta emergencia como resuelta?'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('Si, resolver'))],
    ));
    if (confirmed == true && mounted) {
      final provider = Provider.of<EmergencyProvider>(context, listen: false);
      try {
        await provider.deactivateSOS(resolution: 'Resuelta manualmente');
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Emergencia resuelta exitosamente'))); Navigator.pop(context); }
      } catch (e) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyError(e, fallback: 'Error al resolver')), backgroundColor: AppColors.error)); } }
    }
  }

  Future<void> _shareEmergency(dynamic emergency) async {
    final text = '''EMERGENCIA ACTIVA\n\nUsuario: ${emergency.userName}\nTipo: ${_getEmergencyTypeText(emergency.type)}\nUbicacion: ${emergency.locationAddress ?? 'No disponible'}\nCoordenadas: ${emergency.locationLat}, ${emergency.locationLng}\nTelefono: ${emergency.userPhone ?? 'No disponible'}\nHora: ${_formatDateTime(emergency.createdAt)}''';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Informacion copiada al portapapeles'))); }
  }
}
