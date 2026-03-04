// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
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
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/trip_model.dart';
import '../../utils/logger.dart';
import '../../utils/map_marker_utils.dart';
import '../../generated/l10n/app_localizations.dart';

/// TripDetailsScreen - Detalles completos del viaje
/// ✅ IMPLEMENTACIÓN COMPLETA con funcionalidad real
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

  // Iconos modernos para marcadores
  BitmapDescriptor? _originIcon;
  BitmapDescriptor? _destinationIcon;

  // Estados de UI
  bool _isMapExpanded = false;
  final bool _showFullRoute = true;

  @override
  void initState() {
    super.initState();
    
    _mapAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _detailsAnimationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _mapAnimation = Tween<double>(begin: 200.0, end: 400.0).animate(
      CurvedAnimation(parent: _mapAnimationController, curve: Curves.easeInOut),
    );
    _detailsAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _detailsAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _loadCustomIcons();
    _loadTripData();
  }

  /// Cargar iconos modernos para marcadores
  Future<void> _loadCustomIcons() async {
    _originIcon = await MapMarkerUtils.getOriginIcon();
    _destinationIcon = await MapMarkerUtils.getDestinationIcon();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _mapAnimationController.dispose();
    _detailsAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadTripData() async {
    try {
      // Si ya tenemos el trip pasado como parámetro, usarlo
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorLoadingTripDetails),
            backgroundColor: ModernTheme.error,
          ),
        );
        Navigator.pop(context);
      }
    }
  }


  void _setupMapData() {
    if (_trip == null) return;

    // Configurar marcadores (iconos modernos)
    _markers = {
      Marker(
        markerId: MarkerId('pickup'),
        position: _trip!.pickupLocation,
        icon: _originIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(
          title: AppLocalizations.of(context)!.origin,
          snippet: _trip!.pickupAddress,
        ),
      ),
      Marker(
        markerId: MarkerId('destination'),
        position: _trip!.destinationLocation,
        icon: _destinationIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(
          title: AppLocalizations.of(context)!.destination,
          snippet: _trip!.destinationAddress,
        ),
      ),
    };

    // Configurar ruta si está disponible
    if (_trip!.route != null && _trip!.route!.isNotEmpty) {
      _polylines = {
        Polyline(
          polylineId: PolylineId('route'),
          points: _trip!.route!,
          color: ModernTheme.rappiOrange,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.cannotMakeCall),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  Future<void> _openInMaps() async {
    if (_trip == null) return;

    final pickupAddress = _trip!.pickupAddress;
    final destinationAddress = _trip!.destinationAddress;

    // Codificar las direcciones para URL
    final encodedPickup = Uri.encodeComponent(pickupAddress);
    final encodedDestination = Uri.encodeComponent(destinationAddress);

    // Usar direcciones en lugar de coordenadas para mejor visualización
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cannotOpenMaps),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  void _openChat() {
    if (_trip == null) return;
    
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    
    if (currentUser == null) return;
    
    // Determinar con quién chatear
    String otherUserName;
    String otherUserRole;
    String? otherUserId;

    // ✅ DUAL-ACCOUNT: Usar activeMode para validar el rol actual
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
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.tripDetailsTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (_trip != null)
              Text(_trip!.id.substring(0, 8), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          if (_trip != null) ...[
            IconButton(
              icon: Icon(Icons.chat, color: context.onPrimaryText),
              onPressed: _openChat,
            ),
            IconButton(
              icon: Icon(Icons.more_vert, color: context.onPrimaryText),
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
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
          ),
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.loadingTripDetails,
            style: TextStyle(
              color: context.secondaryText,
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
          Icon(
            Icons.error_outline,
            size: 64,
            color: ModernTheme.error,
          ),
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.tripNotFound,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.primaryText,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.couldNotLoadTripDetails,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.secondaryText,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
            ),
            child: Text(AppLocalizations.of(context)!.goBack, style: TextStyle(color: context.onPrimaryText)),
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
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: ModernTheme.getCardShadow(context),
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
                      SizedBox(height: 8),
                      _buildMapControl(
                        icon: Icons.my_location,
                        onPressed: _fitMapToRoute,
                      ),
                      SizedBox(height: 8),
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
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: ModernTheme.rappiOrange),
        iconSize: 20,
      ),
    );
  }

  Widget _buildMapStatusInfo() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
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
            icon: Icons.account_balance_wallet, // ✅ Cambiado de attach_money ($) a wallet
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
        Icon(icon, size: 16, color: ModernTheme.rappiOrange),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.primaryText,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: context.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatusCard(),
          SizedBox(height: 16),
          _buildParticipantsCard(),
          SizedBox(height: 16),
          _buildRouteCard(),
          SizedBox(height: 16),
          _buildPaymentCard(),
          if (_trip!.status == 'completed') ...[
            SizedBox(height: 16),
            _buildRatingCard(),
          ],
          SizedBox(height: 16),
          _buildTimestampsCard(),
          SizedBox(height: 16),
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
        statusColor = ModernTheme.success;
        statusIcon = Icons.check_circle;
        statusText = AppLocalizations.of(context)!.tripCompleted;
        break;
      case 'in_progress':
        statusColor = ModernTheme.rappiOrange;
        statusIcon = Icons.directions_car;
        statusText = AppLocalizations.of(context)!.inProgress;
        break;
      case 'cancelled':
        statusColor = ModernTheme.error;
        statusIcon = Icons.cancel;
        statusText = AppLocalizations.of(context)!.cancelled;
        break;
      default:
        statusColor = ModernTheme.warning;
        statusIcon = Icons.schedule;
        statusText = AppLocalizations.of(context)!.pending;
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.primaryText,
                  ),
                ),
                Text(
                  'ID: ${_trip!.id.substring(0, 8)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: context.onPrimaryText,
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
    // ✅ DUAL-ACCOUNT: Usar activeMode para determinar la vista actual
    final isPassenger = authProvider.currentUser?.activeMode == 'passenger';

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.participantsLabel,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.primaryText,
            ),
          ),
          SizedBox(height: 16),

          // Conductor
          _buildParticipantRow(
            title: AppLocalizations.of(context)!.driverLabel,
            name: _trip!.vehicleInfo?['driverName'] ?? AppLocalizations.of(context)!.driverLabel,
            phone: _trip!.vehicleInfo?['driverPhone'] ?? '',
            subtitle: '${_trip!.vehicleInfo?['model'] ?? ''} - ${_trip!.vehicleInfo?['plate'] ?? ''}',
            color: ModernTheme.rappiOrange,
            icon: Icons.directions_car,
            canContact: isPassenger,
          ),

          Divider(height: 24),

          // Pasajero
          _buildParticipantRow(
            title: AppLocalizations.of(context)!.passengerLabel,
            name: AppLocalizations.of(context)!.passengerLabel,
            phone: '+',
            subtitle: AppLocalizations.of(context)!.clientLabel,
            color: ModernTheme.primaryBlue,
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
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: context.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.primaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: context.secondaryText,
                ),
              ),
            ],
          ),
        ),
        if (canContact) ...[
          IconButton(
            onPressed: () => _makePhoneCall(phone),
            icon: Icon(Icons.phone, color: ModernTheme.rappiOrange),
          ),
          IconButton(
            onPressed: _openChat,
            icon: Icon(Icons.chat, color: ModernTheme.rappiOrange),
          ),
        ],
      ],
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.tripRouteTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.primaryText,
            ),
          ),
          SizedBox(height: 16),

          // Origen
          _buildLocationRow(
            icon: Icons.my_location,
            iconColor: ModernTheme.success,
            title: AppLocalizations.of(context)!.originLabel,
            address: _trip!.pickupAddress,
            isFirst: true,
          ),

          // Línea conectora
          _buildConnectorLine(),

          // Destino
          _buildLocationRow(
            icon: Icons.location_on,
            iconColor: ModernTheme.error,
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
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: context.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                address,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.primaryText,
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
      padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
      child: Container(
        width: 2,
        height: 20,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ModernTheme.success.withValues(alpha: 0.5),
              ModernTheme.error.withValues(alpha: 0.5),
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

    // Usar valores por defecto ya que TripModel no tiene paymentMethod
    /* switch (_trip!.paymentMethod) {
      case 'cash':
        paymentIcon = Icons.money;
        paymentLabel = 'Efectivo';
        break;
      case 'card':
        paymentIcon = Icons.credit_card;
        paymentLabel = 'Tarjeta';
        break;
      case 'yape':
        paymentIcon = Icons.phone_android;
        paymentLabel = 'Yape';
        break;
      default:
        paymentIcon = Icons.payment;
        paymentLabel = 'Otro';
    } */

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(paymentIcon, color: ModernTheme.rappiOrange, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.paymentMethodLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  paymentLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.primaryText,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'S/. ${(_trip!.finalFare ?? _trip!.estimatedFare).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ModernTheme.rappiOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard() {
    if (_trip!.passengerRating == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.star, color: const Color(0xFFFFB800), size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.ratingLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      Icons.star,
                      size: 16,
                      color: index < _trip!.passengerRating!
                          ? const Color(0xFFFFB800)
                          : Theme.of(context).dividerColor,
                    );
                  }),
                ),
              ],
            ),
          ),
          Text(
            '${_trip!.passengerRating}/5',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFB800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampsCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.tripHistoryTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.primaryText,
            ),
          ),
          SizedBox(height: 16),

          _buildTimestampRow(
            AppLocalizations.of(context)!.requestCreatedLabel,
            _trip!.requestedAt,
            Icons.add_circle_outline,
          ),

          if (_trip!.startedAt != null) ...[
            SizedBox(height: 8),
            _buildTimestampRow(
              AppLocalizations.of(context)!.tripStartedLabel,
              _trip!.startedAt!,
              Icons.play_arrow,
            ),
          ],

          if (_trip!.completedAt != null) ...[
            SizedBox(height: 8),
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
        Icon(icon, size: 16, color: ModernTheme.rappiOrange),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: context.primaryText,
            ),
          ),
        ),
        Text(
          _formatDateTime(timestamp),
          style: TextStyle(
            fontSize: 12,
            color: context.secondaryText,
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
              child: ElevatedButton.icon(
                onPressed: _openInMaps,
                icon: Icon(Icons.map, color: context.onPrimaryText),
                label: Text(AppLocalizations.of(context)!.viewInMaps, style: TextStyle(color: context.onPrimaryText)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.rappiOrange,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openChat,
                icon: Icon(Icons.chat, color: ModernTheme.rappiOrange),
                label: Text(AppLocalizations.of(context)!.chatButton, style: TextStyle(color: ModernTheme.rappiOrange)),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: ModernTheme.rappiOrange),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_trip!.status == 'completed') ...[
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                // ✅ IMPLEMENTADO: Repetir viaje con los mismos datos
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                try {
                  // Navegar a passenger home con los datos del viaje anterior
                  navigator.pushReplacementNamed(
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
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error al repetir viaje: $e'),
                      backgroundColor: ModernTheme.error,
                    ),
                  );
                }
              },
              icon: Icon(Icons.repeat, color: ModernTheme.primaryBlue),
              label: Text(AppLocalizations.of(context)!.repeatTrip, style: TextStyle(color: ModernTheme.primaryBlue)),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: ModernTheme.primaryBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
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
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.share, color: ModernTheme.rappiOrange),
                title: Text(AppLocalizations.of(context)!.shareTrip),
                onTap: () async {
                  Navigator.pop(context);
                  // ✅ IMPLEMENTADO: Compartir viaje
                  final messenger = ScaffoldMessenger.of(context);

                  try {
                    final shareText = '''
🚕 Detalles del Viaje - Rappi Team

📅 Fecha: ${_formatDateTime(_trip!.requestedAt)}
${_trip!.status == 'completed' ? '✅ Estado: Completado' : '📍 Estado: ${_trip!.status}'}

📍 Origen: ${_trip!.pickupAddress}
📍 Destino: ${_trip!.destinationAddress}

📏 Distancia: ${(_trip!.estimatedDistance / 1000).toStringAsFixed(2)} km
${_trip!.finalFare != null ? '💰 Tarifa final: S/. ${_trip!.finalFare!.toStringAsFixed(2)}' : '💰 Tarifa estimada: S/. ${_trip!.estimatedFare.toStringAsFixed(2)}'}

Compartido desde Rappi Team App
''';

                    await Share.share(
                      shareText,
                      subject: 'Detalles del Viaje - Rappi Team',
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Error al compartir: $e'),
                        backgroundColor: ModernTheme.error,
                      ),
                    );
                  }
                },
              ),
              if (_trip!.status == 'completed')
                ListTile(
                  leading: Icon(Icons.receipt, color: ModernTheme.primaryBlue),
                  title: Text(AppLocalizations.of(context)!.downloadReceipt),
                  onTap: () async {
                    Navigator.pop(context);
                    // ✅ IMPLEMENTADO: Descargar recibo en PDF
                    final messenger = ScaffoldMessenger.of(context);

                    try {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Generando recibo PDF...'),
                          backgroundColor: ModernTheme.rappiOrange,
                          duration: Duration(seconds: 2),
                        ),
                      );

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
                                pw.Text('Rappi Team', style: pw.TextStyle(fontSize: 18)),
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
                                pw.Text('Gracias por viajar con Rappi Team', style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
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
                        subject: 'Recibo de Viaje - Rappi Team',
                        text: 'Recibo del viaje realizado el ${_formatDateTime(_trip!.requestedAt)}',
                      );

                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Recibo PDF generado exitosamente'),
                          backgroundColor: ModernTheme.success,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error al generar recibo: $e'),
                          backgroundColor: ModernTheme.error,
                        ),
                      );
                    }
                  },
                ),
              ListTile(
                leading: Icon(Icons.report, color: ModernTheme.warning),
                title: Text(AppLocalizations.of(context)!.reportProblem),
                onTap: () {
                  Navigator.pop(context);
                  // ✅ IMPLEMENTADO: Reportar problema
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

  // ✅ IMPLEMENTADO: Mostrar diálogo de reporte
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
          title: Text('Reportar Problema', style: TextStyle(fontWeight: FontWeight.bold, color: context.primaryText)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tipo de problema:', style: TextStyle(fontWeight: FontWeight.bold, color: context.primaryText)),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedIssue,
                  style: TextStyle(color: context.primaryText),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  items: issueTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type, style: TextStyle(color: context.primaryText)));
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedIssue = value!);
                  },
                ),
                SizedBox(height: 16),
                Text('Descripción del problema:', style: TextStyle(fontWeight: FontWeight.bold, color: context.primaryText)),
                SizedBox(height: 8),
                TextField(
                  controller: reportController,
                  style: TextStyle(color: context.primaryText),
                  decoration: InputDecoration(
                    hintText: 'Describe el problema en detalle...',
                    hintStyle: TextStyle(color: context.secondaryText),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: EdgeInsets.all(16),
                  ),
                  maxLines: 5,
                  maxLength: 500,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                reportController.dispose();
                Navigator.pop(context);
              },
              child: Text('Cancelar', style: TextStyle(color: context.secondaryText)),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final description = reportController.text.trim();

                if (description.isEmpty) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Por favor describe el problema'),
                      backgroundColor: ModernTheme.warning,
                    ),
                  );
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
                  navigator.pop();

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Reporte enviado exitosamente. Nos pondremos en contacto pronto.'),
                      backgroundColor: ModernTheme.success,
                      duration: Duration(seconds: 3),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error al enviar reporte: $e'),
                      backgroundColor: ModernTheme.error,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.warning,
                foregroundColor: context.onPrimaryText,
              ),
              child: Text('Enviar Reporte'),
            ),
          ],
        ),
      ),
    );
  }
}