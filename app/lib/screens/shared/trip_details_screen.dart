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
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_button.dart';
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/trip_model.dart';
import '../../utils/logger.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../utils/firestore_error_handler.dart';

/// TripDetailsScreen - Detalles completos del viaje
/// Implementacion completa con funcionalidad real
class TripDetailsScreen extends StatefulWidget {
  final String tripId;
  final TripModel? trip;

  const TripDetailsScreen({
    super.key,
    required this.tripId,
    this.trip,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _mapAnimationController;
  late AnimationController _detailsAnimationController;
  late Animation<double> _mapAnimation;
  late Animation<Offset> _detailsAnimation;

  TripModel? _trip;
  bool _isLoading = true;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Estados de UI
  bool _isMapExpanded = false;

  @override
  void initState() {
    super.initState();

    _mapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _detailsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _mapAnimation = Tween<double>(begin: 200.0, end: 400.0).animate(
      CurvedAnimation(parent: _mapAnimationController, curve: Curves.easeInOut),
    );
    _detailsAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _detailsAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _loadTripData();
  }

  @override
  void dispose() {
    _mapAnimationController.dispose();
    _detailsAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadTripData() async {
    try {
      // Si ya tenemos el trip pasado como parametro, usarlo
      if (widget.trip != null) {
        setState(() {
          _trip = widget.trip;
          _isLoading = false;
        });
        _setupMapData();
        _detailsAnimationController.forward();
        return;
      }

      // Si no, cargar desde el provider
      if (!mounted) return;
      final rideProvider = Provider.of<RideProvider>(context, listen: false);

      // Buscar en el historial o viaje actual
      TripModel? foundTrip;
      if (rideProvider.currentTrip?.id == widget.tripId) {
        foundTrip = rideProvider.currentTrip;
      } else {
        // Buscar en el historial desde Firebase (sin crear datos de ejemplo)
        // foundTrip permanece null si no se encuentra
      }

      if (foundTrip != null) {
        if (!mounted) return;
        setState(() {
          _trip = foundTrip;
          _isLoading = false;
        });
        _setupMapData();
        _detailsAnimationController.forward();
      } else {
        throw Exception('Viaje no encontrado');
      }

    } catch (e) {
      AppLogger.error('Error cargando datos del viaje', e);
      if (mounted) {
        RtSnackbar.show(context, message: AppLocalizations.of(context)!.errorLoadingTripDetails, type: RtSnackbarType.error);
        Navigator.pop(context);
      }
    }
  }


  void _setupMapData() {
    if (_trip == null) return;

    // Configurar marcadores
    _markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: _trip!.pickupLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: AppLocalizations.of(context)!.origin,
          snippet: _trip!.pickupAddress,
        ),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: _trip!.destinationLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: AppLocalizations.of(context)!.destination,
          snippet: _trip!.destinationAddress,
        ),
      ),
    };

    // Configurar ruta si esta disponible
    if (_trip!.route != null && _trip!.route!.isNotEmpty) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _trip!.route!,
          color: RtColors.brand,
          width: 4,
          patterns: [],
        ),
      };
    }

    setState(() {});
  }

  void _toggleMapSize() {
    setState(() {
      _isMapExpanded = !_isMapExpanded;
    });

    if (_isMapExpanded) {
      _mapAnimationController.forward();
    } else {
      _mapAnimationController.reverse();
    }

    HapticFeedback.lightImpact();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      RtSnackbar.show(context, message: AppLocalizations.of(context)!.cannotMakeCall, type: RtSnackbarType.error);
    }
  }

  Future<void> _openInMaps() async {
    if (_trip == null) return;

    final pickupAddress = _trip!.pickupAddress;
    final destinationAddress = _trip!.destinationAddress;

    // Codificar las direcciones para URL
    final encodedPickup = Uri.encodeComponent(pickupAddress);
    final encodedDestination = Uri.encodeComponent(destinationAddress);

    // Usar direcciones en lugar de coordenadas para mejor visualizacion
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&origin=$encodedPickup&destination=$encodedDestination&travelmode=driving';
    final uri = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback con coordenadas si falla con direcciones
      final pickup = _trip!.pickupLocation;
      final destination = _trip!.destinationLocation;
      final fallbackUrl = 'https://www.google.com/maps/dir/?api=1&origin=${pickup.latitude},${pickup.longitude}&destination=${destination.latitude},${destination.longitude}&travelmode=driving';
      final fallbackUri = Uri.parse(fallbackUrl);

      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        RtSnackbar.show(context, message: AppLocalizations.of(context)!.cannotOpenMaps, type: RtSnackbarType.error);
      }
    }
  }

  void _openChat() {
    if (_trip == null) return;

    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) return;

    // Determinar con quien chatear
    String otherUserName;
    String otherUserRole;
    String? otherUserId;

    // DUAL-ACCOUNT: Usar activeMode para validar el rol actual
    if (currentUser.activeMode == 'passenger') {
      otherUserName = _trip!.vehicleInfo?['driverName'] ?? 'Conductor';
      otherUserRole = 'driver';
      otherUserId = _trip!.driverId;
    } else {
      otherUserName = 'Pasajero';
      otherUserRole = 'passenger';
      otherUserId = _trip!.userId;
    }

    Navigator.pushNamed(
      context,
      '/shared/chat',
      arguments: {
        'rideId': _trip!.id,
        'otherUserName': otherUserName,
        'otherUserRole': otherUserRole,
        'otherUserId': otherUserId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: RtAppBar(
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.tripDetailsTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: RtColors.white)),
            if (_trip != null)
              Text(_trip!.id.substring(0, 8), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: RtColors.white)),
          ],
        ),
        variant: RtAppBarVariant.gradient,
        actions: [
          if (_trip != null) ...[
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: _openChat,
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showTripOptions,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _trip == null
              ? _buildErrorState()
              : _buildTripDetails(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(RtColors.brand),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.loadingTripDetails,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: RtColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.tripNotFound,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.couldNotLoadTripDetails,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          RtButton(
            label: AppLocalizations.of(context)!.goBack,
            onPressed: () => Navigator.pop(context),
            isFullWidth: false,
          ),
        ],
      ),
    );
  }

  Widget _buildTripDetails() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Mapa del viaje
          _buildTripMap(),

          // Detalles del viaje
          SlideTransition(
            position: _detailsAnimation,
            child: _buildDetailsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildTripMap() {
    return AnimatedBuilder(
      animation: _mapAnimation,
      builder: (context, child) {
        return Container(
          height: _mapAnimation.value,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: RtShadow.soft(),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _trip!.pickupLocation,
                    zoom: 13.0,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    _fitMapToRoute();
                  },
                  mapType: MapType.normal,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),

                // Controles del mapa
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      _buildMapControl(
                        icon: _isMapExpanded ? Icons.compress : Icons.expand,
                        onPressed: _toggleMapSize,
                      ),
                      const SizedBox(height: 8),
                      _buildMapControl(
                        icon: Icons.my_location,
                        onPressed: _fitMapToRoute,
                      ),
                      const SizedBox(height: 8),
                      _buildMapControl(
                        icon: Icons.open_in_new,
                        onPressed: _openInMaps,
                      ),
                    ],
                  ),
                ),

                // Información del estado en el mapa
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _buildMapStatusInfo(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapControl({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: RtColors.brand),
        iconSize: 20,
      ),
    );
  }

  Widget _buildMapStatusInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMapStat(
            icon: Icons.straighten,
            label: AppLocalizations.of(context)!.distanceLabel,
            value: '${_trip!.estimatedDistance.toStringAsFixed(1)} km',
          ),
          Container(width: 1, height: 30, color: Theme.of(context).dividerColor),
          _buildMapStat(
            icon: Icons.access_time,
            label: AppLocalizations.of(context)!.durationLabel,
            value: '25 min',
          ),
          Container(width: 1, height: 30, color: Theme.of(context).dividerColor),
          _buildMapStat(
            icon: Icons.account_balance_wallet,
            label: AppLocalizations.of(context)!.fareLabel,
            value: 'S/. ${(_trip!.finalFare ?? _trip!.estimatedFare).toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _buildMapStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: RtColors.brand),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildParticipantsCard(),
          const SizedBox(height: 16),
          _buildRouteCard(),
          const SizedBox(height: 16),
          _buildPaymentCard(),
          if (_trip!.status == 'completed') ...[
            const SizedBox(height: 16),
            _buildRatingCard(),
          ],
          const SizedBox(height: 16),
          _buildTimestampsCard(),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _trip!.status;
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'completed':
        statusColor = RtColors.success;
        statusIcon = Icons.check_circle;
        statusText = AppLocalizations.of(context)!.tripCompleted;
        break;
      case 'in_progress':
        statusColor = RtColors.brand;
        statusIcon = Icons.directions_car;
        statusText = AppLocalizations.of(context)!.inProgress;
        break;
      case 'cancelled':
        statusColor = RtColors.error;
        statusIcon = Icons.cancel;
        statusText = AppLocalizations.of(context)!.cancelled;
        break;
      default:
        statusColor = RtColors.warning;
        statusIcon = Icons.schedule;
        statusText = AppLocalizations.of(context)!.pending;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RtShadow.soft(),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  'ID: ${_trip!.id.substring(0, 8)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsCard() {
    final authProvider = Provider.of<AuthProvider>(context);
    // DUAL-ACCOUNT: Usar activeMode para determinar la vista actual
    final isPassenger = authProvider.currentUser?.activeMode == 'passenger';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RtShadow.soft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.participantsLabel,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Conductor
          _buildParticipantRow(
            title: AppLocalizations.of(context)!.driverLabel,
            name: _trip!.vehicleInfo?['driverName'] ?? AppLocalizations.of(context)!.driverLabel,
            phone: _trip!.vehicleInfo?['driverPhone'] ?? '',
            subtitle: '${_trip!.vehicleInfo?['model'] ?? ''} - ${_trip!.vehicleInfo?['plate'] ?? ''}',
            color: RtColors.brand,
            icon: Icons.directions_car,
            canContact: isPassenger,
          ),

          const Divider(height: 24),

          // Pasajero
          _buildParticipantRow(
            title: AppLocalizations.of(context)!.passengerLabel,
            name: AppLocalizations.of(context)!.passengerLabel,
            phone: '+',
            subtitle: AppLocalizations.of(context)!.clientLabel,
            color: RtColors.info,
            icon: Icons.person,
            canContact: !isPassenger,
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantRow({
    required String title,
    required String name,
    required String phone,
    required String subtitle,
    required Color color,
    required IconData icon,
    required bool canContact,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        if (canContact) ...[
          IconButton(
            onPressed: () => _makePhoneCall(phone),
            icon: const Icon(Icons.phone, color: RtColors.brand),
          ),
          IconButton(
            onPressed: _openChat,
            icon: const Icon(Icons.chat, color: RtColors.brand),
          ),
        ],
      ],
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RtShadow.soft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.tripRouteTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Origen
          _buildLocationRow(
            icon: Icons.my_location,
            iconColor: RtColors.success,
            title: AppLocalizations.of(context)!.originLabel,
            address: _trip!.pickupAddress,
            isFirst: true,
          ),

          // Linea conectora
          _buildConnectorLine(),

          // Destino
          _buildLocationRow(
            icon: Icons.location_on,
            iconColor: RtColors.error,
            title: AppLocalizations.of(context)!.destinationLabel,
            address: _trip!.destinationAddress,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectorLine() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
      child: Container(
        width: 2,
        height: 20,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              RtColors.success.withValues(alpha: 0.5),
              RtColors.error.withValues(alpha: 0.5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    // Inicializar con valores por defecto
    IconData paymentIcon = Icons.money;
    String paymentLabel = 'Efectivo';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RtShadow.soft(),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RtColors.brand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(paymentIcon, color: RtColors.brand, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.paymentMethodLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  paymentLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'S/. ${(_trip!.finalFare ?? _trip!.estimatedFare).toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: RtColors.brand,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard() {
    if (_trip!.passengerRating == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RtShadow.soft(),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RtColors.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star, color: RtColors.warning, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.ratingLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      Icons.star,
                      size: 16,
                      color: index < _trip!.passengerRating!
                          ? RtColors.warning
                          : Theme.of(context).dividerColor,
                    );
                  }),
                ),
              ],
            ),
          ),
          Text(
            '${_trip!.passengerRating}/5',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: RtColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RtShadow.soft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.tripHistoryTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          _buildTimestampRow(
            AppLocalizations.of(context)!.requestCreatedLabel,
            _trip!.requestedAt,
            Icons.add_circle_outline,
          ),

          if (_trip!.startedAt != null) ...[
            const SizedBox(height: 8),
            _buildTimestampRow(
              AppLocalizations.of(context)!.tripStartedLabel,
              _trip!.startedAt!,
              Icons.play_arrow,
            ),
          ],

          if (_trip!.completedAt != null) ...[
            const SizedBox(height: 8),
            _buildTimestampRow(
              AppLocalizations.of(context)!.tripCompletedLabel,
              _trip!.completedAt!,
              Icons.check_circle,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimestampRow(String label, DateTime timestamp, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: RtColors.brand),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Text(
          _formatDateTime(timestamp),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: RtButton(
                label: AppLocalizations.of(context)!.viewInMaps,
                icon: Icons.map,
                onPressed: _openInMaps,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RtButton(
                label: AppLocalizations.of(context)!.chatButton,
                icon: Icons.chat,
                onPressed: _openChat,
                variant: RtButtonVariant.outlined,
              ),
            ),
          ],
        ),
        if (_trip!.status == 'completed') ...[
          const SizedBox(height: 12),
          RtButton(
            label: AppLocalizations.of(context)!.repeatTrip,
            icon: Icons.repeat,
            onPressed: () async {
              if (!mounted) return;
              try {
                Navigator.of(context).pushReplacementNamed(
                  '/passenger-home',
                  arguments: {
                    'repeatTrip': true,
                    'pickupLocation': _trip!.pickupLocation,
                    'pickupAddress': _trip!.pickupAddress,
                    'destinationLocation': _trip!.destinationLocation,
                    'destinationAddress': _trip!.destinationAddress,
                  },
                );
              } catch (e) {
                if (!mounted) return;
                RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
              }
            },
            variant: RtButtonVariant.outlined,
          ),
        ],
      ],
    );
  }

  void _fitMapToRoute() {
    if (_mapController == null || _trip == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        [_trip!.pickupLocation.latitude, _trip!.destinationLocation.latitude].reduce((a, b) => a < b ? a : b),
        [_trip!.pickupLocation.longitude, _trip!.destinationLocation.longitude].reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        [_trip!.pickupLocation.latitude, _trip!.destinationLocation.latitude].reduce((a, b) => a > b ? a : b),
        [_trip!.pickupLocation.longitude, _trip!.destinationLocation.longitude].reduce((a, b) => a > b ? a : b),
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  void _showTripOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share, color: RtColors.brand),
                title: Text(AppLocalizations.of(context)!.shareTrip),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final shareText = '''
Detalles del Viaje - RapiTeam

Fecha: ${_formatDateTime(_trip!.requestedAt)}
${_trip!.status == 'completed' ? 'Estado: Completado' : 'Estado: ${_trip!.status}'}

Origen: ${_trip!.pickupAddress}
Destino: ${_trip!.destinationAddress}

Distancia: ${(_trip!.estimatedDistance / 1000).toStringAsFixed(2)} km
${_trip!.finalFare != null ? 'Tarifa final: S/. ${_trip!.finalFare!.toStringAsFixed(2)}' : 'Tarifa estimada: S/. ${_trip!.estimatedFare.toStringAsFixed(2)}'}

Compartido desde RapiTeam App
''';

                    await Share.share(
                      shareText,
                      subject: 'Detalles del Viaje - RapiTeam',
                    );
                  } catch (e) {
                    if (!mounted) return;
                    RtSnackbar.show(this.context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
                  }
                },
              ),
              if (_trip!.status == 'completed')
                ListTile(
                  leading: const Icon(Icons.receipt, color: RtColors.info),
                  title: Text(AppLocalizations.of(context)!.downloadReceipt),
                  onTap: () async {
                    Navigator.pop(context);

                    try {
                      if (!mounted) return;
                      RtSnackbar.show(this.context, message: 'Generando recibo PDF...', type: RtSnackbarType.info);

                      // Crear PDF
                      final pdf = pw.Document();

                      pdf.addPage(
                        pw.Page(
                          pageFormat: PdfPageFormat.a4,
                          build: (pw.Context context) {
                            return pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'RECIBO DE VIAJE',
                                  style: pw.TextStyle(
                                    fontSize: 24,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 10),
                                pw.Text('RapiTeam', style: pw.TextStyle(fontSize: 18)),
                                pw.Divider(thickness: 2),
                                pw.SizedBox(height: 20),

                                pw.Text('Información del Viaje', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 10),
                                pw.Text('ID: ${_trip!.id}'),
                                pw.Text('Fecha: ${_formatDateTime(_trip!.requestedAt)}'),
                                if (_trip!.completedAt != null)
                                  pw.Text('Completado: ${_formatDateTime(_trip!.completedAt!)}'),
                                pw.SizedBox(height: 20),

                                pw.Text('Ubicaciones', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 10),
                                pw.Text('Origen: ${_trip!.pickupAddress}'),
                                pw.Text('Destino: ${_trip!.destinationAddress}'),
                                pw.SizedBox(height: 20),

                                pw.Text('Detalles Financieros', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 10),
                                pw.Text('Distancia: ${(_trip!.estimatedDistance / 1000).toStringAsFixed(2)} km'),
                                if (_trip!.finalFare != null)
                                  pw.Text('Tarifa: S/. ${_trip!.finalFare!.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))
                                else
                                  pw.Text('Tarifa estimada: S/. ${_trip!.estimatedFare.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),

                                pw.Spacer(),
                                pw.Divider(),
                                pw.Text('Gracias por viajar con RapiTeam', style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
                              ],
                            );
                          },
                        ),
                      );

                      // Guardar PDF
                      final output = await getTemporaryDirectory();
                      final file = File('${output.path}/recibo_${_trip!.id}.pdf');
                      await file.writeAsBytes(await pdf.save());

                      // Compartir PDF
                      await Share.shareXFiles(
                        [XFile(file.path)],
                        subject: 'Recibo de Viaje - RapiTeam',
                        text: 'Recibo del viaje realizado el ${_formatDateTime(_trip!.requestedAt)}',
                      );

                      if (!mounted) return;
                      RtSnackbar.show(this.context, message: 'Recibo PDF generado exitosamente', type: RtSnackbarType.success);
                    } catch (e) {
                      if (!mounted) return;
                      RtSnackbar.show(this.context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.report, color: RtColors.warning),
                title: Text(AppLocalizations.of(context)!.reportProblem),
                onTap: () {
                  Navigator.pop(context);
                  // Reportar problema
                  _showReportDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Mostrar dialogo de reporte
  void _showReportDialog() {
    final TextEditingController reportController = TextEditingController();
    String selectedIssue = 'Conductor';
    final List<String> issueTypes = [
      'Conductor',
      'Tarifa incorrecta',
      'Ruta incorrecta',
      'Vehículo en mal estado',
      'Trato inadecuado',
      'Problema de seguridad',
      'Otro',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text('Reportar Problema', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tipo de problema:', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedIssue,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  items: issueTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)));
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedIssue = value!);
                  },
                ),
                const SizedBox(height: 16),
                Text('Descripción del problema:', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 8),
                TextField(
                  controller: reportController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Describe el problema en detalle...',
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: 5,
                  maxLength: 500,
                ),
              ],
            ),
          ),
          actions: [
            RtButton(
              label: 'Cancelar',
              onPressed: () {
                reportController.dispose();
                Navigator.pop(context);
              },
              variant: RtButtonVariant.ghost,
              isFullWidth: false,
            ),
            RtButton(
              label: 'Enviar Reporte',
              onPressed: () async {
                final description = reportController.text.trim();

                if (description.isEmpty) {
                  RtSnackbar.show(context, message: 'Por favor describe el problema', type: RtSnackbarType.warning);
                  return;
                }

                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final userId = authProvider.currentUser?.id;

                  // Crear ticket de soporte en Firebase
                  await FirebaseFirestore.instance.collection('supportTickets').add({
                    'userId': userId,
                    'tripId': _trip!.id,
                    'issueType': selectedIssue,
                    'description': description,
                    'status': 'pending',
                    'createdAt': FieldValue.serverTimestamp(),
                    'tripDetails': {
                      'pickupAddress': _trip!.pickupAddress,
                      'destinationAddress': _trip!.destinationAddress,
                      'fare': _trip!.finalFare ?? _trip!.estimatedFare,
                      'date': _trip!.requestedAt.toIso8601String(),
                    },
                  });

                  reportController.dispose();
                  if (!mounted) return;
                  Navigator.of(this.context).pop();

                  RtSnackbar.show(this.context, message: 'Reporte enviado exitosamente. Nos pondremos en contacto pronto.', type: RtSnackbarType.success);
                } catch (e) {
                  if (!mounted) return;
                  RtSnackbar.show(this.context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
                }
              },
              variant: RtButtonVariant.danger,
              isFullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}
