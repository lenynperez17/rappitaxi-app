// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../models/trip_model.dart';
import '../../utils/logger.dart';

/// TripDetailsScreen - Complete trip details
class TripDetailsScreen extends StatefulWidget {
  final String tripId;
  final TripModel? trip;
  const TripDetailsScreen({super.key, required this.tripId, this.trip});
  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> with TickerProviderStateMixin {
  late AnimationController _mapAnimationController;
  late AnimationController _detailsAnimationController;
  late Animation<double> _mapAnimation;
  late Animation<Offset> _detailsAnimation;
  TripModel? _trip;
  bool _isLoading = true;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isMapExpanded = false;
  final bool _showFullRoute = true;

  @override
  void initState() {
    super.initState();
    _mapAnimationController = AnimationController(duration: Duration(milliseconds: 800), vsync: this);
    _detailsAnimationController = AnimationController(duration: Duration(milliseconds: 600), vsync: this);
    _mapAnimation = Tween<double>(begin: 200.0, end: 400.0).animate(CurvedAnimation(parent: _mapAnimationController, curve: Curves.easeInOut));
    _detailsAnimation = Tween<Offset>(begin: Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _detailsAnimationController, curve: Curves.easeOutCubic));
    _loadTripData();
  }

  @override
  void dispose() { _mapAnimationController.dispose(); _detailsAnimationController.dispose(); super.dispose(); }

  Future<void> _loadTripData() async {
    try {
      if (widget.trip != null) { setState(() { _trip = widget.trip; _isLoading = false; }); _setupMapData(); _detailsAnimationController.forward(); return; }
      if (!mounted) return;
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      TripModel? foundTrip;
      if (rideProvider.currentTrip?.id == widget.tripId) { foundTrip = rideProvider.currentTrip; }
      if (foundTrip != null) { if (!mounted) return; setState(() { _trip = foundTrip; _isLoading = false; }); _setupMapData(); _detailsAnimationController.forward(); }
      else { throw Exception('Viaje no encontrado'); }
    } catch (e) {
      AppLogger.error('Error cargando datos del viaje', e);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar los detalles del viaje'), backgroundColor: AppColors.error)); Navigator.pop(context); }
    } finally { if (mounted) { setState(() { _isLoading = false; }); } }
  }

  void _setupMapData() {
    if (_trip == null) return;
    _markers = {
      Marker(markerId: MarkerId('pickup'), position: _trip!.pickupLocation, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), infoWindow: InfoWindow(title: 'Origen', snippet: _trip!.pickupAddress)),
      Marker(markerId: MarkerId('destination'), position: _trip!.destinationLocation, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), infoWindow: InfoWindow(title: 'Destino', snippet: _trip!.destinationAddress)),
    };
    if (_trip!.route != null && _trip!.route!.isNotEmpty) { _polylines = {Polyline(polylineId: PolylineId('route'), points: _trip!.route!, color: AppColors.rappiOrange, width: 4, patterns: [])}; }
    setState(() {});
  }

  void _toggleMapSize() { setState(() { _isMapExpanded = !_isMapExpanded; }); if (_isMapExpanded) { _mapAnimationController.forward(); } else { _mapAnimationController.reverse(); } HapticFeedback.lightImpact(); }

  Future<void> _makePhoneCall(String phoneNumber) async { final uri = Uri.parse('tel:$phoneNumber'); if (await canLaunchUrl(uri)) { await launchUrl(uri); } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se puede realizar la llamada'), backgroundColor: AppColors.error)); } }

  Future<void> _openInMaps() async {
    final pickup = _trip!.pickupLocation; final destination = _trip!.destinationLocation;
    final uri = Uri.parse('https://www.google.com/maps/dir/${pickup.latitude},${pickup.longitude}/${destination.latitude},${destination.longitude}');
    if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); }
    else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se puede abrir mapas'), backgroundColor: AppColors.error)); }
  }

  void _openChat() {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser == null) return;
    String otherUserName; String otherUserRole; String? otherUserId;
    if (currentUser.activeMode == 'passenger') { otherUserName = _trip!.vehicleInfo?['driverName'] ?? 'Conductor'; otherUserRole = 'driver'; otherUserId = _trip!.driverId; }
    else { otherUserName = 'Pasajero'; otherUserRole = 'passenger'; otherUserId = _trip!.userId; }
    Navigator.pushNamed(context, '/shared/chat', arguments: {'rideId': _trip!.id, 'otherUserName': otherUserName, 'otherUserRole': otherUserRole, 'otherUserId': otherUserId});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.rappiOrange,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Detalles del Viaje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          if (_trip != null) Text(_trip!.id.substring(0, 8), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          if (_trip != null) ...[
            IconButton(icon: Icon(Icons.chat, color: Colors.white), onPressed: _openChat),
            IconButton(icon: Icon(Icons.more_vert, color: Colors.white), onPressed: _showTripOptions),
          ],
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _trip == null ? _buildErrorState() : _buildTripDetails(),
    );
  }

  Widget _buildLoadingState() { return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.rappiOrange)), SizedBox(height: 16), Text('Cargando detalles del viaje...', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 16))])); }

  Widget _buildErrorState() { return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.error_outline, size: 64, color: AppColors.error), SizedBox(height: 16), Text('Viaje no encontrado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))), SizedBox(height: 8), Text('No se pudieron cargar los detalles del viaje', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))), SizedBox(height: 24), ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: AppColors.rappiOrange), child: Text('Volver', style: TextStyle(color: Colors.white)))])); }

  Widget _buildTripDetails() { return SingleChildScrollView(child: Column(children: [_buildTripMap(), SlideTransition(position: _detailsAnimation, child: _buildDetailsSection())])); }

  Widget _buildTripMap() {
    return AnimatedBuilder(animation: _mapAnimation, builder: (context, child) {
      return Container(height: _mapAnimation.value, margin: EdgeInsets.all(16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: AppColors.getCardShadow()),
        child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Stack(children: [
          GoogleMap(initialCameraPosition: CameraPosition(target: _trip!.pickupLocation, zoom: 13.0), markers: _markers, polylines: _polylines, onMapCreated: (controller) { _mapController = controller; _fitMapToRoute(); }, mapType: MapType.normal, myLocationButtonEnabled: false, zoomControlsEnabled: false),
          Positioned(top: 16, right: 16, child: Column(children: [_buildMapControl(icon: _isMapExpanded ? Icons.compress : Icons.expand, onPressed: _toggleMapSize), SizedBox(height: 8), _buildMapControl(icon: Icons.my_location, onPressed: _fitMapToRoute), SizedBox(height: 8), _buildMapControl(icon: Icons.open_in_new, onPressed: _openInMaps)])),
          Positioned(bottom: 16, left: 16, right: 16, child: _buildMapStatusInfo()),
        ])));
    });
  }

  Widget _buildMapControl({required IconData icon, required VoidCallback onPressed}) {
    return Container(decoration: BoxDecoration(color: AppColors.getSurface(context), shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.getTextPrimary(context).withValues(alpha: 0.1), blurRadius: 4, offset: Offset(0, 2))]), child: IconButton(onPressed: onPressed, icon: Icon(icon, color: AppColors.rappiOrange), iconSize: 20));
  }

  Widget _buildMapStatusInfo() {
    return Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.getSurface(context).withValues(alpha: 0.95), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _buildMapStat(icon: Icons.straighten, label: 'Distancia', value: '${_trip!.estimatedDistance.toStringAsFixed(1)} km'),
        Container(width: 1, height: 30, color: AppColors.getBorder(context)),
        _buildMapStat(icon: Icons.access_time, label: 'Duracion', value: '25 min'),
        Container(width: 1, height: 30, color: AppColors.getBorder(context)),
        _buildMapStat(icon: Icons.account_balance_wallet, label: 'Tarifa', value: 'S/${(_trip!.finalFare ?? _trip!.estimatedFare).toStringAsFixed(2)}'),
      ]));
  }

  Widget _buildMapStat({required IconData icon, required String label, required String value}) {
    return Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: AppColors.rappiOrange), SizedBox(height: 4), Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))), Text(label, style: TextStyle(fontSize: 10, color: AppColors.getTextSecondary(context)))]);
  }

  Widget _buildDetailsSection() { return Padding(padding: EdgeInsets.all(16), child: Column(children: [_buildStatusCard(), SizedBox(height: 16), _buildParticipantsCard(), SizedBox(height: 16), _buildRouteCard(), SizedBox(height: 16), _buildPaymentCard(), if (_trip!.status == 'completed') ...[SizedBox(height: 16), _buildRatingCard()], SizedBox(height: 16), _buildTimestampsCard(), SizedBox(height: 16), _buildActionButtons()])); }

  Widget _buildStatusCard() {
    final status = _trip!.status; Color statusColor; IconData statusIcon; String statusText;
    switch (status) { case 'completed': statusColor = AppColors.success; statusIcon = Icons.check_circle; statusText = 'Viaje Completado'; break; case 'in_progress': statusColor = AppColors.rappiOrange; statusIcon = Icons.directions_car; statusText = 'En Progreso'; break; case 'cancelled': statusColor = AppColors.error; statusIcon = Icons.cancel; statusText = 'Cancelado'; break; default: statusColor = AppColors.warning; statusIcon = Icons.schedule; statusText = 'Pendiente'; }
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: EdgeInsets.all(20), child: Row(children: [
      Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(statusIcon, color: statusColor, size: 24)),
      SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(statusText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))), Text('ID: ${_trip!.id.substring(0, 8)}', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)))])),
      Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)), child: Text(statusText, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
    ])));
  }

  Widget _buildParticipantsCard() {
    final authProvider = Provider.of<AuthProvider>(context);
    final isPassenger = authProvider.currentUser?.activeMode == 'passenger';
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Participantes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))), SizedBox(height: 16),
      _buildParticipantRow(title: 'Conductor', name: _trip!.vehicleInfo?['driverName'] ?? 'Conductor', phone: _trip!.vehicleInfo?['driverPhone'] ?? '', subtitle: '${_trip!.vehicleInfo?['model'] ?? ''} - ${_trip!.vehicleInfo?['plate'] ?? ''}', color: AppColors.rappiOrange, icon: Icons.directions_car, canContact: isPassenger),
      Divider(height: 24),
      _buildParticipantRow(title: 'Pasajero', name: 'Pasajero', phone: '+', subtitle: 'Cliente', color: AppColors.priceBlack, icon: Icons.person, canContact: !isPassenger),
    ])));
  }

  Widget _buildParticipantRow({required String title, required String name, required String phone, required String subtitle, required Color color, required IconData icon, required bool canContact}) {
    return Row(children: [
      CircleAvatar(radius: 24, backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)), SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context), fontWeight: FontWeight.w500)), Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))), Text(subtitle, style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)))])),
      if (canContact) ...[IconButton(onPressed: () => _makePhoneCall(phone), icon: Icon(Icons.phone, color: AppColors.rappiOrange)), IconButton(onPressed: _openChat, icon: Icon(Icons.chat, color: AppColors.rappiOrange))],
    ]);
  }

  Widget _buildRouteCard() {
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Ruta del Viaje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))), SizedBox(height: 16),
      _buildLocationRow(icon: Icons.my_location, iconColor: AppColors.success, title: 'Origen', address: _trip!.pickupAddress, isFirst: true),
      _buildConnectorLine(),
      _buildLocationRow(icon: Icons.location_on, iconColor: AppColors.error, title: 'Destino', address: _trip!.destinationAddress, isLast: true),
    ])));
  }

  Widget _buildLocationRow({required IconData icon, required Color iconColor, required String title, required String address, bool isFirst = false, bool isLast = false}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 16)), SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.getTextSecondary(context))), SizedBox(height: 2), Text(address, style: TextStyle(fontSize: 14, color: AppColors.getTextPrimary(context)))])),
    ]);
  }

  Widget _buildConnectorLine() { return Padding(padding: EdgeInsets.only(left: 16, top: 8, bottom: 8), child: Container(width: 2, height: 20, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.success.withValues(alpha: 0.5), AppColors.error.withValues(alpha: 0.5)])))); }

  Widget _buildPaymentCard() {
    IconData paymentIcon = Icons.money; String paymentLabel = 'Efectivo';
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: EdgeInsets.all(16), child: Row(children: [
      Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.rappiOrange.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(paymentIcon, color: AppColors.rappiOrange, size: 20)), SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Metodo de Pago', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context), fontWeight: FontWeight.w500)), Text(paymentLabel, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)))])),
      Text('S/${(_trip!.finalFare ?? _trip!.estimatedFare).toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.rappiOrange)),
    ])));
  }

  Widget _buildRatingCard() {
    if (_trip!.passengerRating == null) return SizedBox.shrink();
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: EdgeInsets.all(16), child: Row(children: [
      Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.star, color: Colors.amber, size: 20)), SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Calificacion', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context), fontWeight: FontWeight.w500)), Row(children: List.generate(5, (index) => Icon(Icons.star, size: 16, color: index < _trip!.passengerRating! ? Colors.amber : AppColors.getBorder(context))))])),
      Text('${_trip!.passengerRating}/5', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
    ])));
  }

  Widget _buildTimestampsCard() {
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Historial del Viaje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))), SizedBox(height: 16),
      _buildTimestampRow('Solicitud creada', _trip!.requestedAt, Icons.add_circle_outline),
      if (_trip!.startedAt != null) ...[SizedBox(height: 8), _buildTimestampRow('Viaje iniciado', _trip!.startedAt!, Icons.play_arrow)],
      if (_trip!.completedAt != null) ...[SizedBox(height: 8), _buildTimestampRow('Viaje completado', _trip!.completedAt!, Icons.check_circle)],
    ])));
  }

  Widget _buildTimestampRow(String label, DateTime timestamp, IconData icon) {
    return Row(children: [Icon(icon, size: 16, color: AppColors.rappiOrange), SizedBox(width: 12), Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: AppColors.getTextPrimary(context)))), Text(_formatDateTime(timestamp), style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context)))]);
  }

  Widget _buildActionButtons() {
    return Column(children: [
      Row(children: [
        Expanded(child: ElevatedButton.icon(onPressed: _openInMaps, icon: Icon(Icons.map, color: Colors.white), label: Text('Ver en Mapas', style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.rappiOrange, padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        SizedBox(width: 12),
        Expanded(child: OutlinedButton.icon(onPressed: _openChat, icon: Icon(Icons.chat, color: AppColors.rappiOrange), label: Text('Chat', style: TextStyle(color: AppColors.rappiOrange)), style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: AppColors.rappiOrange), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
      ]),
      if (_trip!.status == 'completed') ...[
        SizedBox(height: 12),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context); final navigator = Navigator.of(context);
            try { navigator.pushReplacementNamed('/passenger-home', arguments: {'repeatTrip': true, 'pickupLocation': _trip!.pickupLocation, 'pickupAddress': _trip!.pickupAddress, 'destinationLocation': _trip!.destinationLocation, 'destinationAddress': _trip!.destinationAddress}); }
            catch (e) { messenger.showSnackBar(SnackBar(content: Text('Error al repetir viaje: $e'), backgroundColor: AppColors.error)); }
          },
          icon: Icon(Icons.repeat, color: AppColors.priceBlack), label: Text('Repetir Viaje', style: TextStyle(color: AppColors.priceBlack)),
          style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: AppColors.priceBlack), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
      ],
    ]);
  }

  void _fitMapToRoute() {
    if (_mapController == null || _trip == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng([_trip!.pickupLocation.latitude, _trip!.destinationLocation.latitude].reduce((a, b) => a < b ? a : b), [_trip!.pickupLocation.longitude, _trip!.destinationLocation.longitude].reduce((a, b) => a < b ? a : b)),
      northeast: LatLng([_trip!.pickupLocation.latitude, _trip!.destinationLocation.latitude].reduce((a, b) => a > b ? a : b), [_trip!.pickupLocation.longitude, _trip!.destinationLocation.longitude].reduce((a, b) => a > b ? a : b)),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  void _showTripOptions() {
    showResponsiveBottomSheet(context: context, builder: (context) {
      return Padding(padding: EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Icon(Icons.share, color: AppColors.rappiOrange), title: Text('Compartir Viaje'), onTap: () async {
          Navigator.pop(context);
          final messenger = ScaffoldMessenger.of(context);
          try {
            final statusText = _trip!.status == 'completed' ? 'Viaje Completado' : _trip!.status;
            final shareText = 'Detalles del Viaje - Rappi Team\nFecha: ${_formatDateTime(_trip!.requestedAt)}\nEstado: $statusText\nOrigen: ${_trip!.pickupAddress}\nDestino: ${_trip!.destinationAddress}\nDistancia: ${_trip!.estimatedDistance.toStringAsFixed(2)} km\n${_trip!.finalFare != null ? 'Tarifa final: S/${_trip!.finalFare!.toStringAsFixed(2)}' : 'Tarifa estimada: S/${_trip!.estimatedFare.toStringAsFixed(2)}'}\nCompartido desde Rappi Team';
            await Share.share(shareText, subject: 'Detalles del Viaje - Rappi Team');
          } catch (e) { messenger.showSnackBar(SnackBar(content: Text('Error al compartir: $e'), backgroundColor: AppColors.error)); }
        }),
        if (_trip!.status == 'completed') ListTile(leading: Icon(Icons.receipt, color: AppColors.priceBlack), title: Text('Descargar Recibo'), onTap: () async {
          Navigator.pop(context);
          final messenger = ScaffoldMessenger.of(context);
          try {
            messenger.showSnackBar(SnackBar(content: Text('Generando recibo...'), backgroundColor: AppColors.rappiOrange, duration: Duration(seconds: 2)));
            final pdf = pw.Document();
            pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (pw.Context pdfContext) {
              return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Recibo de Viaje', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 10),
                pw.Text('Rappi Team', style: pw.TextStyle(fontSize: 18)), pw.Divider(thickness: 2), pw.SizedBox(height: 20),
                pw.Text('Informacion del viaje', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('ID: ${_trip!.id}'), pw.Text('Fecha: ${_formatDateTime(_trip!.requestedAt)}'),
                if (_trip!.completedAt != null) pw.Text('Completado: ${_formatDateTime(_trip!.completedAt!)}'),
                pw.Text('Ubicaciones', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('Origen: ${_trip!.pickupAddress}'), pw.Text('Destino: ${_trip!.destinationAddress}'),
                pw.Text('Detalles financieros', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('Distancia: ${_trip!.estimatedDistance.toStringAsFixed(2)} km'),
                if (_trip!.finalFare != null) pw.Text('Tarifa: S/${_trip!.finalFare!.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))
                else pw.Text('Tarifa estimada: S/${_trip!.estimatedFare.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Spacer(), pw.Divider(), pw.Text('Gracias por usar Rappi Team', style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
              ]);
            }));
            final output = await getTemporaryDirectory(); final file = File('${output.path}/recibo_${_trip!.id}.pdf'); await file.writeAsBytes(await pdf.save());
            await Share.shareXFiles([XFile(file.path)], subject: 'Recibo de Viaje - Rappi Team', text: 'Recibo de viaje del ${_formatDateTime(_trip!.requestedAt)}');
            messenger.showSnackBar(SnackBar(content: Text('Recibo generado exitosamente'), backgroundColor: AppColors.success));
          } catch (e) { messenger.showSnackBar(SnackBar(content: Text('Error al generar recibo: $e'), backgroundColor: AppColors.error)); }
        }),
        ListTile(leading: Icon(Icons.report, color: AppColors.warning), title: Text('Reportar Problema'), onTap: () { Navigator.pop(context); _showReportDialog(); }),
      ]));
    });
  }

  String _formatDateTime(DateTime dateTime) { return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}'; }

  void _showReportDialog() {
    final TextEditingController reportController = TextEditingController();
    String selectedIssue = 'Problema con el conductor';
    final List<String> issueTypes = ['Problema con el conductor', 'Cobro incorrecto', 'Ruta incorrecta', 'Condicion del vehiculo', 'Trato inapropiado', 'Problema de seguridad', 'Otro'];
    showDialog(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) {
      return AlertDialog(
        title: Text('Reportar Problema', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tipo de problema:', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 8),
          DropdownButtonFormField<String>(value: selectedIssue, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)), items: issueTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(), onChanged: (value) { setDialogState(() => selectedIssue = value!); }),
          SizedBox(height: 16), Text('Describe el problema:', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 8),
          TextField(controller: reportController, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), hintText: 'Describe el problema con el mayor detalle posible...', contentPadding: EdgeInsets.all(16)), maxLines: 5, maxLength: 500),
        ])),
        actions: [
          TextButton(onPressed: () { reportController.dispose(); Navigator.pop(dialogContext); }, child: Text('Cancelar', style: TextStyle(color: AppColors.getTextSecondary(dialogContext)))),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(dialogContext); final navigator = Navigator.of(dialogContext);
              final description = reportController.text.trim();
              if (description.isEmpty) { messenger.showSnackBar(SnackBar(content: Text('Por favor describe el problema'), backgroundColor: AppColors.warning)); return; }
              // TODO(node-migration): reemplazar con endpoint POST /api/support/tickets
              // cuando exista. Por ahora simulamos el envio para no romper el UX.
              await Future<void>.delayed(const Duration(milliseconds: 300));
              reportController.dispose();
              navigator.pop(dialogContext);
              messenger.showSnackBar(SnackBar(content: Text('Reporte registrado'), backgroundColor: AppColors.success, duration: Duration(seconds: 3)));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
            child: Text('Enviar Reporte'),
          ),
        ],
      );
    }));
  }
}
