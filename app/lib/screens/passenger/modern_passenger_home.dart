import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';

import '../../generated/l10n/app_localizations.dart';
import '../../core/config/app_config.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_animated_widgets.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../models/price_negotiation_model.dart' as models;
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/price_negotiation_provider.dart';
import '../../utils/logger.dart';
import '../../utils/firestore_error_handler.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import 'passenger_negotiations_screen.dart';
import '../shared/map_picker_screen.dart';

// Widgets extraidos
import 'widgets/passenger_search_bar.dart';
import 'widgets/passenger_service_selector.dart';
import 'widgets/passenger_trip_sheet.dart';
import 'widgets/passenger_driver_offers_sheet.dart';
import 'widgets/passenger_drawer.dart';
import 'widgets/passenger_dialogs.dart';

// Re-exportar ServiceType para imports externos
export 'widgets/passenger_service_selector.dart' show ServiceType;

// Estilo de mapa limpio
const String _cleanMapStyle = '''
[
  {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"labels.text","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"transit.station","stylers":[{"visibility":"off"}]},
  {"featureType":"landscape.man_made","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.land_parcel","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.neighborhood","elementType":"labels","stylers":[{"visibility":"off"}]}
]
''';

class ModernPassengerHomeScreen extends StatefulWidget {
  const ModernPassengerHomeScreen({super.key});

  @override
  State<ModernPassengerHomeScreen> createState() => _ModernPassengerHomeScreenState();
}

class _ModernPassengerHomeScreenState extends State<ModernPassengerHomeScreen>
    with TickerProviderStateMixin {

  // Controladores
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final FocusNode _priceFocusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  RideProvider? _rideProviderRef;

  late AnimationController _bottomSheetController;
  late AnimationController _searchBarController;
  late Animation<double> _bottomSheetAnimation;
  late Animation<double> _searchBarAnimation;

  // Estados
  bool _showPriceNegotiation = false;
  bool _showDriverOffers = false;
  double _offeredPrice = 15.0;
  bool _locationPermissionGranted = false;
  bool _isManualPriceEntry = false;
  ServiceType _selectedServiceType = ServiceType.standard;
  String _selectedPaymentMethod = 'Efectivo';
  bool _isSelectingLocation = false;
  bool _showContinueButton = false;
  Timer? _buttonDelayTimer;
  bool _isAdjustingPickup = false;
  bool _isCreatingNegotiation = false;
  bool _searchBarExpanded = false;
  bool _hasNotifications = false;

  // Coordenadas
  LatLng? _pickupCoordinates;
  LatLng? _destinationCoordinates;

  // Calculos de ruta
  double? _calculatedDistance;
  int? _estimatedTime;
  double? _suggestedPrice;

  // Negociación
  models.PriceNegotiation? _currentNegotiation;
  Timer? _negotiationTimer;
  Timer? _countdownTimer;

  // Constantes
  static const double _kZoomClose = 16.0;
  static const double _kZoomMedium = 15.0;
  static const double _kBoundsPadding = 100.0;

  // ════════════════════════════════════════════
  // LIFECYCLE
  // ════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _bottomSheetController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _searchBarController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _bottomSheetAnimation = CurvedAnimation(parent: _bottomSheetController, curve: Curves.easeInOut);
    _searchBarAnimation = CurvedAnimation(parent: _searchBarController, curve: Curves.easeInOut);
    _bottomSheetController.forward();
    _searchBarController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRideProviderListener();
      _requestLocationPermission();
      _checkForActiveNegotiations();
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _negotiationTimer?.cancel();
    _buttonDelayTimer?.cancel();
    _countdownTimer?.cancel();
    _rideProviderRef?.removeListener(_onRideProviderChanged);
    _bottomSheetController.dispose();
    _searchBarController.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _priceController.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      drawer: PassengerDrawer(
        onLogout: () => PassengerDialogs.showLogoutConfirmation(context),
      ),
      body: GestureDetector(
        onTap: _hideKeyboard,
        child: Stack(
          children: [
            // Mapa ocupa 100% de la pantalla
            _buildGoogleMap(),
            // FABs flotantes superiores (menu y notificaciones)
            if (!_isAdjustingPickup) _buildTopFloatingButtons(isDark),
            // Overlay de ajuste de pickup
            if (_isAdjustingPickup) _buildFixedMarkerOverlay(isDark),
            if (_isAdjustingPickup) _buildConfirmLocationButton(),
            // Barra de busqueda flotante
            if (!_isAdjustingPickup) _buildAnimatedSearchBar(),
            // Bottom sheet
            if (!_isAdjustingPickup) _buildBottomSheet(),
            // Boton mi ubicación
            if (!_isAdjustingPickup) _buildMyLocationButton(isDark),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // WIDGETS DEL BUILD
  // ════════════════════════════════════════════

  /// FABs flotantes en la parte superior: menu hamburguesa (izq) y notificaciones (der)
  Widget _buildTopFloatingButtons(bool isDark) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          top: RtSpacing.sm,
          left: RtSpacing.base,
          right: RtSpacing.base,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Boton menu hamburguesa
            _buildFloatingCircleButton(
              isDark: isDark,
              icon: Icons.menu_rounded,
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            // Boton notificaciones con badge
            _buildNotificationButton(isDark),
          ],
        ),
      ),
    );
  }

  /// Boton circular flotante generico con fondo blanco y sombra
  Widget _buildFloatingCircleButton({
    required bool isDark,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? RtColors.neutral900 : RtColors.white,
        shape: BoxShape.circle,
        boxShadow: RtShadow.medium(isDark: isDark),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isDark ? RtColors.white : RtColors.neutral900,
          size: RtIconSize.md,
        ),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  /// Boton de notificaciones con badge rojo condicional
  Widget _buildNotificationButton(bool isDark) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? RtColors.neutral900 : RtColors.white,
        shape: BoxShape.circle,
        boxShadow: RtShadow.medium(isDark: isDark),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: Icon(
              Icons.notifications_rounded,
              color: isDark ? RtColors.white : RtColors.neutral900,
              size: RtIconSize.md,
            ),
            onPressed: () => Navigator.pushNamed(context, '/shared/notifications'),
            padding: EdgeInsets.zero,
          ),
          // Badge rojo si hay notificaciones pendientes
          if (_hasNotifications)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: RtColors.brand,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? RtColors.neutral900 : RtColors.white,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoogleMap() {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(target: LatLng(-12.0851, -76.9770), zoom: 15),
      onMapCreated: (c) => _mapController = c,
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: _locationPermissionGranted,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      style: _cleanMapStyle,
      liteModeEnabled: false,
      buildingsEnabled: false,
      indoorViewEnabled: false,
      trafficEnabled: false,
      minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
    );
  }

  Widget _buildFixedMarkerOverlay(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 48, color: RtColors.brand,
            shadows: [Shadow(color: RtColors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))]),
          Container(
            margin: const EdgeInsets.only(top: RtSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base, vertical: RtSpacing.sm),
            decoration: BoxDecoration(
              color: isDark ? RtColors.neutral900 : RtColors.white,
              borderRadius: RtRadius.borderXl,
              boxShadow: RtShadow.medium(isDark: isDark),
            ),
            child: Text('Mueve el mapa para ajustar tu ubicación',
              style: RtTypo.bodySmall.copyWith(fontWeight: FontWeight.w600, color: isDark ? RtColors.white : RtColors.neutral900)),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmLocationButton() {
    return Positioned(
      left: RtSpacing.lg, right: RtSpacing.lg, bottom: 40,
      child: AnimatedPulseButton(
        text: 'Confirmar ubicación', icon: Icons.check,
        onPressed: () async {
          await _confirmPickupLocation();
          if (mounted) setState(() => _showPriceNegotiation = true);
        },
      ),
    );
  }

  Widget _buildAnimatedSearchBar() {
    return SafeArea(
      child: Padding(
        // Padding superior para dejar espacio a los FABs
        padding: const EdgeInsets.only(top: 56),
        child: AnimatedBuilder(
          animation: _searchBarAnimation,
          builder: (context, _) => Transform.translate(
            offset: Offset(0, -100 * (1 - _searchBarAnimation.value)),
            child: Opacity(
              opacity: _searchBarAnimation.value,
              child: PassengerSearchBar(
                pickupController: _pickupController,
                destinationController: _destinationController,
                pickupCoordinates: _pickupCoordinates,
                destinationCoordinates: _destinationCoordinates,
                onPlaceSelected: _handlePlaceSelected,
                onFieldTapped: _handleFieldTapped,
                onUseCurrentLocation: _handleUseCurrentLocation,
                onOpenMapPicker: (isOrigin) => _openMapPicker(isOrigin: isOrigin),
                onClearAll: _handleClearAll,
                onSearchingChanged: (v) {
                  if (mounted) setState(() => _isSelectingLocation = v);
                },
                isExpanded: _searchBarExpanded,
                onTap: () {
                  if (mounted) setState(() => _searchBarExpanded = true);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildBottomSheet() {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: AnimatedBuilder(
          animation: _bottomSheetAnimation,
          builder: (context, _) => Transform.translate(
            offset: Offset(0, 400 * (1 - _bottomSheetAnimation.value)),
            child: _buildActiveSheet(),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSheet() {
    if (_showDriverOffers) {
      return PassengerDriverOffersSheet(
        negotiation: _currentNegotiation,
        onClose: () {
          setState(() { _showDriverOffers = false; _currentNegotiation = null; });
          _cancelPriceNegotiation();
        },
        onAcceptOffer: (offer) async {
          final confirmed = await PassengerDialogs.showAcceptOffer(context, offer);
          if (confirmed == true) await _acceptDriverOffer(offer);
        },
      );
    }

    _updateContinueButtonVisibility();

    return PassengerTripSheet(
      serviceSelector: PassengerServiceSelector(
        selectedType: _selectedServiceType,
        onServiceSelected: _handleServiceSelected,
      ),
      isSelectingLocation: _isSelectingLocation,
      showContinueButton: _showContinueButton,
      onContinue: _handleContinue,
      showPriceNegotiation: _showPriceNegotiation,
      calculatedDistance: _calculatedDistance,
      estimatedTime: _estimatedTime,
      suggestedPrice: _suggestedPrice,
      offeredPrice: _offeredPrice,
      selectedPaymentMethod: _selectedPaymentMethod,
      isManualPriceEntry: _isManualPriceEntry,
      isCreatingNegotiation: _isCreatingNegotiation,
      priceController: _priceController,
      priceFocusNode: _priceFocusNode,
      onPriceSelected: (price) {
        _hideKeyboard();
        setState(() { _offeredPrice = price; _priceController.text = price.toStringAsFixed(2); _isManualPriceEntry = false; });
      },
      onPaymentMethodChanged: (m) { setState(() => _selectedPaymentMethod = m); },
      onManualPriceEntryChanged: (v) { if (mounted) setState(() => _isManualPriceEntry = v); },
      onStartNegotiation: _startNegotiation,
      onCancelNegotiation: _cancelPriceNegotiation,
      onHideKeyboard: _hideKeyboard,
      onFavoriteTapped: (label) { _destinationController.text = label; if (mounted) setState(() => _showPriceNegotiation = true); },
      onRecentTapped: (title) { _destinationController.text = title; if (mounted) setState(() => _showPriceNegotiation = true); },
    );
  }

  /// Boton "mi ubicación" rediseñado como FAB con fondo blanco e icono rojo brand
  Widget _buildMyLocationButton(bool isDark) {
    return Positioned(
      right: RtSpacing.base,
      bottom: _showPriceNegotiation ? 420 : 320,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? RtColors.neutral900 : RtColors.white,
          shape: BoxShape.circle,
          boxShadow: RtShadow.medium(isDark: isDark),
        ),
        child: IconButton(
          icon: Icon(Icons.my_location_rounded, color: RtColors.brand, size: RtIconSize.md),
          onPressed: () async {
            final loc = await _getCurrentLocation();
            if (loc != null && _mapController != null && mounted) {
              _mapController!.animateCamera(CameraUpdate.newLatLngZoom(loc, _kZoomClose));
            }
          },
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // HANDLERS
  // ════════════════════════════════════════════

  void _handlePlaceSelected(bool isPickup, LatLng coords) async {
    if (!mounted) return;
    setState(() {
      if (isPickup) { _pickupCoordinates = coords; } else { _destinationCoordinates = coords; }
    });
    await _addMarkerAndZoom(coords, isPickup ? 'pickup_marker' : 'destination_marker', isPickup);
    if (_pickupCoordinates != null && _destinationCoordinates != null) {
      await _updateRoutePolyline();
      if (mounted) setState(() => _isSelectingLocation = false);
    }
  }

  void _handleFieldTapped(bool isPickup) {
    if (mounted) {
      setState(() {
        _isSelectingLocation = true;
        // Expandir la barra de busqueda al tocar cualquier campo
        _searchBarExpanded = true;
      });
    }
  }

  void _handleUseCurrentLocation() async {
    _pickupController.text = 'Obteniendo ubicación...';
    final loc = await _getCurrentLocation();
    if (loc != null && mounted) {
      final addr = await _reverseGeocode(loc);
      if (!mounted) return;
      setState(() { _pickupCoordinates = loc; _pickupController.text = addr ?? 'Mi ubicación actual'; });
      _addMarkerAndZoom(loc, 'pickup_marker', true);
    } else if (mounted) {
      setState(() => _pickupController.text = '');
    }
  }

  void _handleClearAll() {
    if (!mounted) return;
    setState(() {
      _pickupController.clear(); _destinationController.clear();
      _pickupCoordinates = null; _destinationCoordinates = null;
      _markers.clear(); _polylines.clear();
      _isSelectingLocation = false; _showContinueButton = false;
      _calculatedDistance = null; _estimatedTime = null; _suggestedPrice = null;
      _searchBarExpanded = false;
    });
    _buttonDelayTimer?.cancel();
  }

  void _handleServiceSelected(ServiceType type) {
    if (!mounted) return;
    setState(() {
      _selectedServiceType = type;
      if (_pickupCoordinates != null && _destinationCoordinates != null) {
        final d = _calculateDistance(_pickupCoordinates!, _destinationCoordinates!);
        _suggestedPrice = _calculatePrice(d);
        _offeredPrice = _suggestedPrice!;
      }
    });
    _updateRoutePolyline();
  }

  Future<void> _handleContinue() async {
    if (!mounted) return;
    setState(() => _showContinueButton = false);
    _buttonDelayTimer?.cancel();

    final errMsg = AppLocalizations.of(context)!.couldNotGetCurrentLocation;

    if (_pickupCoordinates == null) {
      final loc = await _getCurrentLocation();
      if (!mounted) return;
      if (loc != null) { setState(() => _pickupCoordinates = loc); }
      else { RtSnackbar.show(context, message: errMsg, type: RtSnackbarType.error); return; }
    }

    if (_pickupCoordinates != null && _destinationCoordinates != null) {
      final d = _calculateDistance(_pickupCoordinates!, _destinationCoordinates!);
      final t = _estimateTime(d);
      final p = _calculatePrice(d);
      if (!mounted) return;
      setState(() { _calculatedDistance = d; _estimatedTime = t; _suggestedPrice = p; _offeredPrice = p; _isSelectingLocation = false; });
      await _updateRoutePolyline();
      if (mounted) _startPickupAdjustment();
    } else {
      RtSnackbar.show(context, message: 'Por favor selecciona un destino', type: RtSnackbarType.warning);
    }
  }

  void _updateContinueButtonVisibility() {
    final bool kbOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bool canContinue = _pickupController.text.isNotEmpty && _destinationController.text.isNotEmpty;

    if (canContinue && !kbOpen && !_showContinueButton) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _buttonDelayTimer?.cancel();
        _buttonDelayTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted && canContinue && !kbOpen) setState(() => _showContinueButton = true);
        });
      });
    } else if ((!canContinue || kbOpen) && _showContinueButton) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _buttonDelayTimer?.cancel();
        if (mounted) setState(() => _showContinueButton = false);
      });
    }
  }

  // ════════════════════════════════════════════
  // PROVIDERS Y LISTENERS
  // ════════════════════════════════════════════

  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _setupRideProviderListener() {
    if (!mounted) return;
    try {
      final rp = Provider.of<RideProvider>(context, listen: false);
      _rideProviderRef = rp;
      rp.addListener(_onRideProviderChanged);
    } catch (e) { AppLogger.error('Error configurando listener RideProvider', e); }
  }

  void _onRideProviderChanged() {
    if (!mounted) return;
    final trip = Provider.of<RideProvider>(context, listen: false).currentTrip;
    if (trip != null && (trip.status == 'accepted' || trip.status == 'driver_arriving') && trip.passengerVerificationCode != null) {
      Navigator.pushNamed(context, '/passenger/verification-code', arguments: trip);
    }
  }

  Future<void> _checkForActiveNegotiations() async {
    if (!mounted) return;
    try {
      final np = Provider.of<PriceNegotiationProvider>(context, listen: false);
      np.startListeningToMyNegotiations();
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final uid = Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? '';
      final active = np.activeNegotiations
          .where((n) => n.passengerId == uid)
          .where((n) => n.status == models.NegotiationStatus.waiting || n.status == models.NegotiationStatus.negotiating)
          .toList();

      if (active.isNotEmpty) {
        setState(() { _currentNegotiation = active.first; _showDriverOffers = true; _showPriceNegotiation = false; _hasNotifications = true; });
        _startCountdownTimer();
        if (mounted) {
          RtSnackbar.show(context, message: 'Tienes una solicitud de viaje activa', type: RtSnackbarType.info);
        }
      } else if (_showDriverOffers || _currentNegotiation != null) {
        setState(() {
          _currentNegotiation = null; _showDriverOffers = false; _showPriceNegotiation = false;
          _polylines.clear(); _markers.clear();
          _pickupController.clear(); _destinationController.clear(); _priceController.clear();
          _pickupCoordinates = null; _destinationCoordinates = null;
          _calculatedDistance = null; _estimatedTime = null; _suggestedPrice = null;
        });
      }
    } catch (e) { AppLogger.error('Error verificando negociaciones activas', e); }
  }

  Future<void> _requestLocationPermission() async {
    if (!mounted) return;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        if (mounted) setState(() => _locationPermissionGranted = true);
      }
    } catch (e) { AppLogger.error('Error permisos de ubicación', e); }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _currentNegotiation == null) { timer.cancel(); return; }
      if (_currentNegotiation!.isExpired) {
        timer.cancel();
        setState(() { _showDriverOffers = false; _currentNegotiation = null; });
        RtSnackbar.show(context, message: 'Tu solicitud ha expirado. Puedes crear una nueva.', type: RtSnackbarType.warning);
        return;
      }
      setState(() {});
    });
  }

  // ════════════════════════════════════════════
  // MAPA: MARCADORES, ZOOM, AJUSTE
  // ════════════════════════════════════════════

  Future<void> _addMarkerAndZoom(LatLng pos, String id, bool isPickup) async {
    final m = Marker(
      markerId: MarkerId(id), position: pos,
      icon: BitmapDescriptor.defaultMarkerWithHue(isPickup ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: isPickup ? 'Origen' : 'Destino'),
    );
    if (!mounted) return;
    setState(() { _markers.removeWhere((x) => x.markerId.value == id); _markers.add(m); _isSelectingLocation = true; });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, _kZoomMedium));
    if (_pickupCoordinates != null && _destinationCoordinates != null) await _zoomToShowBoth();
  }

  Future<void> _zoomToShowBoth() async {
    if (_pickupCoordinates == null || _destinationCoordinates == null || _mapController == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(min(_pickupCoordinates!.latitude, _destinationCoordinates!.latitude), min(_pickupCoordinates!.longitude, _destinationCoordinates!.longitude)),
      northeast: LatLng(max(_pickupCoordinates!.latitude, _destinationCoordinates!.latitude), max(_pickupCoordinates!.longitude, _destinationCoordinates!.longitude)),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, _kBoundsPadding));
  }

  void _startPickupAdjustment() {
    if (_pickupCoordinates == null || !mounted) return;
    setState(() { _isAdjustingPickup = true; _markers.clear(); _polylines.clear(); });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_pickupCoordinates!, _kZoomClose));
  }

  Future<void> _confirmPickupLocation() async {
    if (_mapController == null || !mounted) return;
    try {
      final bounds = await _mapController!.getVisibleRegion();
      final center = LatLng((bounds.northeast.latitude + bounds.southwest.latitude) / 2, (bounds.northeast.longitude + bounds.southwest.longitude) / 2);
      setState(() => _pickupCoordinates = center);

      final addr = await _reverseGeocode(center);
      if (addr != null && mounted) setState(() => _pickupController.text = addr);

      await _addMarkerAndZoom(_pickupCoordinates!, 'pickup_marker', true);
      if (_destinationCoordinates != null) {
        await _addMarkerAndZoom(_destinationCoordinates!, 'destination_marker', false);
        await _updateRoutePolyline();
        final d = _calculateDistance(_pickupCoordinates!, _destinationCoordinates!);
        if (mounted) setState(() { _calculatedDistance = d; _estimatedTime = _estimateTime(d); _suggestedPrice = _calculatePrice(d); });
      }
      if (mounted) setState(() => _isAdjustingPickup = false);
    } catch (e) {
      AppLogger.error('Error confirmando pickup', e);
      if (mounted) setState(() => _isAdjustingPickup = false);
    }
  }

  // ════════════════════════════════════════════
  // NEGOCIACION Y ACEPTAR OFERTA
  // ════════════════════════════════════════════

  void _startNegotiation() async {
    if (_pickupController.text.isEmpty || _destinationController.text.isEmpty) {
      RtSnackbar.show(context, message: AppLocalizations.of(context)!.enterOriginAndDestination, type: RtSnackbarType.warning);
      return;
    }
    if (_isCreatingNegotiation) return;
    setState(() => _isCreatingNegotiation = true);

    try {
      final np = Provider.of<PriceNegotiationProvider>(context, listen: false);
      final ap = Provider.of<AuthProvider>(context, listen: false);
      final user = ap.currentUser;

      await np.cleanupCancelledNegotiations();

      if (user != null) {
        final myActive = np.activeNegotiations
            .where((n) => n.passengerId == user.id)
            .where((n) => n.status == models.NegotiationStatus.waiting || n.status == models.NegotiationStatus.negotiating)
            .where((n) => n.expiresAt.isAfter(DateTime.now())).toList();

        if (myActive.isNotEmpty) {
          if (!mounted) return;
          setState(() => _isCreatingNegotiation = false);
          final goTo = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
            title: const Text('Ya tienes una solicitud activa'),
            content: const Text('Solo puedes tener una solicitud activa a la vez. Deseas ver tu solicitud actual?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: RtColors.brand), child: const Text('Ver solicitud')),
            ],
          ));
          if (goTo == true && mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerNegotiationsScreen())).then((_) { if (mounted) _checkForActiveNegotiations(); });
          return;
        }
      }

      if (user == null) { if (!mounted) return; setState(() => _isCreatingNegotiation = false); RtSnackbar.show(context, message: AppLocalizations.of(context)!.userNotAuthenticated, type: RtSnackbarType.error); return; }

      final curLoc = await _getCurrentLocation();
      if (curLoc == null) { if (!mounted) return; setState(() => _isCreatingNegotiation = false); RtSnackbar.show(context, message: AppLocalizations.of(context)!.locationPermissionDenied, type: RtSnackbarType.error); return; }

      final destLoc = await _getDestinationLocation();
      if (destLoc == null) { if (!mounted) return; setState(() => _isCreatingNegotiation = false); return; }

      final pickup = models.LocationPoint(latitude: curLoc.latitude, longitude: curLoc.longitude, address: _pickupController.text.isEmpty ? 'Mi ubicación actual' : _pickupController.text, reference: null);
      final dest = models.LocationPoint(latitude: destLoc.latitude, longitude: destLoc.longitude, address: _destinationController.text, reference: null);

      models.PaymentMethod pm;
      switch (_selectedPaymentMethod) {
        case 'Tarjeta': pm = models.PaymentMethod.card; break;
        case 'Billetera': pm = models.PaymentMethod.wallet; break;
        default: pm = models.PaymentMethod.cash; break;
      }

      await np.createNegotiation(pickup: pickup, destination: dest, offeredPrice: _offeredPrice, paymentMethod: pm, notes: null);
      if (!mounted) return;
      setState(() { _showPriceNegotiation = false; _isCreatingNegotiation = false; });
      RtSnackbar.show(context, message: 'Solicitud enviada! Los conductores cercanos veran tu oferta', type: RtSnackbarType.success);
      Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerNegotiationsScreen())).then((_) { if (mounted) _checkForActiveNegotiations(); });
    } catch (e) {
      if (!mounted) return;
      setState(() { _showPriceNegotiation = false; _isCreatingNegotiation = false; });
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  void _cancelPriceNegotiation() {
    if (!mounted) return;
    setState(() {
      _showPriceNegotiation = false; _polylines.clear(); _markers.clear();
      _pickupCoordinates = null; _destinationCoordinates = null;
      _pickupController.clear(); _destinationController.clear(); _priceController.clear();
      _isSelectingLocation = false; _isManualPriceEntry = false;
      _calculatedDistance = null; _estimatedTime = null; _suggestedPrice = null;
      _offeredPrice = 15.0; _showContinueButton = false; _isAdjustingPickup = false;
      _searchBarExpanded = false;
    });
    _buttonDelayTimer?.cancel();
  }

  Future<void> _acceptDriverOffer(models.DriverOffer offer) async {
    if (_currentNegotiation == null) return;
    PassengerDialogs.showAcceptingLoading(context);

    try {
      final np = Provider.of<PriceNegotiationProvider>(context, listen: false);
      final rideId = await np.acceptDriverOffer(_currentNegotiation!.id, offer.driverId);
      if (mounted) Navigator.of(context).pop();

      if (rideId != null) {
        _countdownTimer?.cancel();
        setState(() { _showDriverOffers = false; _currentNegotiation = null; });
        if (mounted) PassengerDialogs.showDriverAccepted(context, offer, rideId);
      } else if (mounted) {
        RtSnackbar.show(context, message: 'Error al aceptar la oferta. Intenta de nuevo.', type: RtSnackbarType.error);
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  // ════════════════════════════════════════════
  // UTILIDADES: GPS, GEOCODING, CALCULO, RUTA
  // ════════════════════════════════════════════

  Future<LatLng?> _getCurrentLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) { perm = await Geolocator.requestPermission(); if (perm == LocationPermission.denied) return null; }
      if (perm == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)));
      return LatLng(pos.latitude, pos.longitude);
    } catch (e) { AppLogger.error('Error GPS', e); return null; }
  }

  Future<String?> _reverseGeocode(LatLng coords) async {
    try {
      final pms = await placemarkFromCoordinates(coords.latitude, coords.longitude);
      if (pms.isEmpty) return null;
      final p = pms.first;
      final parts = <String>[if (p.street?.isNotEmpty == true) p.street!, if (p.subLocality?.isNotEmpty == true) p.subLocality!, if (p.locality?.isNotEmpty == true) p.locality!];
      final addr = parts.join(', ');
      return addr.isEmpty ? 'Ubicación (${coords.latitude.toStringAsFixed(4)}, ${coords.longitude.toStringAsFixed(4)})' : addr;
    } catch (e) { AppLogger.error('Error reverse geocoding', e); return null; }
  }

  Future<void> _openMapPicker({required bool isOrigin}) async {
    final l10n = AppLocalizations.of(context)!;
    LatLng? init = isOrigin ? _pickupCoordinates : _destinationCoordinates;
    init ??= _pickupCoordinates ?? _destinationCoordinates;

    final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => MapPickerScreen(initialLocation: init, title: isOrigin ? l10n.selectPickupLocation : l10n.selectDestination)));
    if (result != null && mounted) {
      final loc = result['location'] as String;
      final c = result['coordinates'] as Map<String, dynamic>;
      final ll = LatLng((c['lat'] as num).toDouble(), (c['lng'] as num).toDouble());
      setState(() { if (isOrigin) { _pickupController.text = loc; _pickupCoordinates = ll; } else { _destinationController.text = loc; _destinationCoordinates = ll; } });
      _addMarkerAndZoom(ll, isOrigin ? 'pickup_marker' : 'destination_marker', isOrigin);
      if (_pickupCoordinates != null && _destinationCoordinates != null) { await _updateRoutePolyline(); if (mounted) setState(() => _isSelectingLocation = false); }
    }
  }

  Future<LatLng?> _getDestinationLocation() async {
    if (_destinationController.text.trim().isEmpty) return null;
    if (_destinationCoordinates != null) return _destinationCoordinates;
    if (mounted) RtSnackbar.show(context, message: 'Por favor selecciona una dirección de la lista', type: RtSnackbarType.warning);
    return null;
  }

  double _calculateDistance(LatLng s, LatLng e) {
    const r = 6371.0;
    final dLat = (e.latitude - s.latitude) * (3.141592653589793 / 180.0);
    final dLon = (e.longitude - s.longitude) * (3.141592653589793 / 180.0);
    final lat1 = s.latitude * (3.141592653589793 / 180.0);
    final lat2 = e.latitude * (3.141592653589793 / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  int _estimateTime(double km) => (km / 20.0 * 60).round();

  double _calculatePrice(double km) {
    double mult;
    switch (_selectedServiceType) {
      case ServiceType.standard: mult = 1.0; break;
      case ServiceType.xl: mult = 1.5; break;
      case ServiceType.premium: mult = 2.0; break;
      case ServiceType.delivery: mult = 0.8; break;
      case ServiceType.moto: mult = 0.7; break;
    }
    return (5.0 + km * 2.0) * mult;
  }

  Future<void> _updateRoutePolyline() async {
    if (_pickupCoordinates == null || _destinationCoordinates == null) { if (mounted) setState(() => _polylines.clear()); return; }
    final pts = await _getRoutePoints(_pickupCoordinates!, _destinationCoordinates!);
    if (!mounted) return;
    setState(() { _polylines.clear(); _polylines.add(Polyline(polylineId: const PolylineId('route'), points: pts, color: RtColors.brand, width: 5, startCap: Cap.roundCap, endCap: Cap.roundCap)); });
  }

  Future<List<LatLng>> _getRoutePoints(LatLng o, LatLng d) async {
    try {
      final pp = PolylinePoints(apiKey: AppConfig.googleMapsApiKey);
      final response = await pp.getRouteBetweenCoordinatesV2(
        request: RoutesApiRequest(
          origin: PointLatLng(o.latitude, o.longitude),
          destination: PointLatLng(d.latitude, d.longitude),
          travelMode: TravelMode.driving,
        ),
      );
      final result = pp.convertToLegacyResult(response);
      if (result.points.isNotEmpty) return result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
      return [o, d];
    } catch (e) { AppLogger.error('Error ruta Directions API', e); return [o, d]; }
  }
}
