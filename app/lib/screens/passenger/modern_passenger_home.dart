// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Para ocultar teclado en Android
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // ✅ NUEVO: Para reverse geocoding (coordenadas → dirección)
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math'; // Para funciones matemáticas: sin, cos, sqrt, atan2 (fórmula Haversine)
import '../../generated/l10n/app_localizations.dart'; // ✅ NUEVO: Import de localizaciones
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../core/config/app_config.dart'; // 🔐 NUEVO: Configuración de API Keys desde .env
import '../../core/widgets/custom_place_text_field.dart'; // ✅ NUEVO: Widget custom que resuelve problema del teclado
import '../../core/widgets/mode_switch_button.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../widgets/common/rappi_app_bar.dart';
import '../../models/price_negotiation_model.dart' as models;
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/price_negotiation_provider.dart'; // ✅ Provider de negociación
import 'passenger_negotiations_screen.dart'; // ✅ Pantalla de negociaciones
import '../shared/settings_screen.dart';
import '../shared/about_screen.dart';
import '../../utils/logger.dart';
import '../../utils/map_marker_utils.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../../core/utils/currency_formatter.dart';

// Enum para tipos de servicio disponibles
enum ServiceType {
  standard,    // Taxi Estándar (1-4 pasajeros)
  xl,          // Taxi XL - Furgoneta (5-6 pasajeros)
  premium,     // Taxi Premium - Lujo (1-4 pasajeros)
  delivery,    // Delivery Express (paquetes)
  moto,        // Moto Taxi (1 pasajero, rápido)
}

// 🔐 GOOGLE MAPS API KEY - Usar desde configuración central
// La API Key se configura en AppConfig mediante variables de entorno (.env)
// Ver app/lib/core/config/app_config.dart para instrucciones de configuración
// Usar directamente AppConfig.googleMapsApiKey en lugar de variable top-level

// Estilo de mapa limpio - Oculta POIs, etiquetas y distracciones visuales
// Solo muestra calles principales y geografía básica para mejor enfoque en la ruta
const String _cleanMapStyle = '''
[
  {
    "featureType": "poi",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.business",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit.station",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "administrative.neighborhood",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  }
]
''';

class ModernPassengerHomeScreen extends StatefulWidget {
  const ModernPassengerHomeScreen({super.key});

  @override
  State<ModernPassengerHomeScreen> createState() =>
      _ModernPassengerHomeScreenState();
}

class _ModernPassengerHomeScreenState extends State<ModernPassengerHomeScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  // Controllers
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _priceController = TextEditingController(); // Para entrada manual de precio

  // FocusNode para controlar el teclado del campo de precio
  final FocusNode _priceFocusNode = FocusNode();

  // ✅ Flag para prevenir uso de controllers después de dispose
  bool _isDisposed = false;

  // ✅ Referencia al RideProvider para poder remover listener en dispose sin usar context
  RideProvider? _rideProviderRef;

  // Animation controllers
  late AnimationController _bottomSheetController;
  late AnimationController _searchBarController;
  late Animation<double> _bottomSheetAnimation;
  late Animation<double> _searchBarAnimation;
  
  // Estados
  bool _isSearchingDestination = false;
  bool _showPriceNegotiation = false;
  bool _showDriverOffers = false;
  double _offeredPrice = 15.0;
  bool _locationPermissionGranted = false; // Para habilitar myLocation en Maps
  bool _isManualPriceEntry = false; // true cuando el usuario quiere digitar el precio manualmente
  ServiceType _selectedServiceType = ServiceType.standard; // Tipo de servicio seleccionado (default: Standard)
  String _selectedPaymentMethod = 'Efectivo'; // Método de pago seleccionado (default: Efectivo)
  bool _isSelectingLocation = false; // ✅ true cuando el usuario está ingresando/seleccionando direcciones
  bool _showContinueButton = false; // ✅ true solo cuando el teclado está cerrado y campos están llenos
  Timer? _buttonDelayTimer; // Timer para delay del botón después de cerrar teclado
  bool _isAdjustingPickup = false; // ✅ NUEVO: true cuando se muestra el marcador fijo para ajustar ubicación moviendo el mapa
  bool _isCreatingNegotiation = false; // ✅ NUEVO: true mientras se está creando una negociación (previene múltiples clics)

  // Coordenadas de lugares seleccionados con Google Places
  LatLng? _pickupCoordinates;
  LatLng? _destinationCoordinates;

  // Iconos modernos para marcadores
  BitmapDescriptor? _originIcon;
  BitmapDescriptor? _destinationIcon;
  BitmapDescriptor? _passengerIcon;

  // Tarifas dinámicas cargadas desde Firebase settings/app_config
  double _configBaseFare = 5.0; // Valor por defecto si Firebase no responde
  double _configRatePerKm = 2.0; // Valor por defecto si Firebase no responde

  // Cálculos reales de la ruta (sin placeholders)
  double? _calculatedDistance; // Distancia real en km usando Haversine
  int? _estimatedTime; // Tiempo estimado real en minutos
  double? _suggestedPrice; // Precio sugerido real basado en distancia

  // Negociación actual
  models.PriceNegotiation? _currentNegotiation;
  Timer? _negotiationTimer;
  Timer? _countdownTimer; // Timer para actualizar cronómetro cada segundo

  // ==================== CONSTANTES UI - PRINCIPIO DRY ====================
  // Border Radius
  static const double _kBorderRadiusXLarge = 30.0;
  static const double _kBorderRadiusLarge = 20.0;
  static const double _kBorderRadiusMedium = 16.0;
  static const double _kBorderRadiusSmall = 12.0;
  static const double _kBorderRadiusTiny = 2.0;

  // Padding
  static const EdgeInsets _kPaddingAll20 = EdgeInsets.all(20);
  static const EdgeInsets _kPaddingAll16 = EdgeInsets.all(16);
  static const EdgeInsets _kPaddingAll12 = EdgeInsets.all(12);
  static const EdgeInsets _kPaddingAll8 = EdgeInsets.all(8);
  static const EdgeInsets _kPaddingHorizontal20Vertical8 = EdgeInsets.symmetric(horizontal: 20, vertical: 8);
  static const EdgeInsets _kPaddingHorizontal16Vertical8 = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const EdgeInsets _kPaddingVertical8 = EdgeInsets.symmetric(vertical: 8);
  static const EdgeInsets _kPaddingVertical12 = EdgeInsets.symmetric(vertical: 12);
  static const EdgeInsets _kPaddingHorizontal16 = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets _kPaddingHorizontal20 = EdgeInsets.symmetric(horizontal: 20);

  // Spacing (SizedBox)
  static const double _kSpacingXLarge = 24.0;
  static const double _kSpacingLarge = 20.0;
  static const double _kSpacingMedium = 16.0;
  static const double _kSpacingSmall = 12.0;
  static const double _kSpacingXSmall = 8.0;
  static const double _kSpacingTiny = 6.0;
  static const double _kSpacingMicro = 4.0;
  static const double _kSpacingNano = 3.0;
  static const double _kSpacingPico = 2.0;

  // Font Sizes
  static const double _kFontSizeXXLarge = 24.0;
  static const double _kFontSizeXLarge = 20.0;
  static const double _kFontSizeLarge = 18.0;
  static const double _kFontSizeMedium = 16.0;
  static const double _kFontSizeSmall = 14.0;
  static const double _kFontSizeXSmall = 12.0;
  static const double _kFontSizeTiny = 10.0;
  static const double _kFontSizeMicro = 9.0;

  // Icon Sizes
  static const double _kIconSizeXLarge = 32.0;
  static const double _kIconSizeLarge = 28.0;
  static const double _kIconSizeMedium = 20.0;
  static const double _kIconSizeSmall = 16.0;
  static const double _kIconSizeXSmall = 14.0;

  // Marker Circle Size
  static const double _kMarkerCircleSize = 10.0;

  // Handle/Divider Sizes
  static const double _kHandleWidth = 40.0;
  static const double _kHandleHeight = 4.0;

  // Map Zoom Levels
  static const double _kZoomLevelClose = 16.0; // Muy cerca para ver detalles
  static const double _kZoomLevelMedium = 15.0; // Suficiente para ver la zona claramente
  static const double _kMapBoundsPadding = 100.0; // Padding para LatLngBounds

  // Service Card Size
  static const double _kServiceCardWidth = 100.0;
  // ======================================================================

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('ModernPassengerHomeScreen', 'initState');

    _bottomSheetController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _searchBarController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _bottomSheetAnimation = CurvedAnimation(
      parent: _bottomSheetController,
      curve: Curves.easeInOut,
    );

    _searchBarAnimation = CurvedAnimation(
      parent: _searchBarController,
      curve: Curves.easeInOut,
    );

    _bottomSheetController.forward();
    _searchBarController.forward();

    // Cargar tarifas dinámicas desde Firebase
    _loadFaresFromConfig();

    // Cargar iconos modernos para marcadores
    _loadCustomIcons();

    // ✅ REMOVIDOS: Listeners problemáticos que impedían actualización de UI
    // La lógica de show/hide de UI ahora se maneja directamente en onTap y onPlaceSelected
    // para permitir actualización correcta cuando el usuario cambia direcciones

    // Listener para cambios en el estado del viaje
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRideProviderListener();
      _requestLocationPermission(); // Solicitar permisos de ubicación al iniciar
      _checkForActiveNegotiations(); // ✅ Verificar si hay negociaciones activas al iniciar
    });
  }

  /// Cargar iconos modernos para marcadores
  Future<void> _loadCustomIcons() async {
    _originIcon = await MapMarkerUtils.getOriginIcon();
    _destinationIcon = await MapMarkerUtils.getDestinationIcon();
    _passengerIcon = await MapMarkerUtils.getPassengerIcon();
    if (mounted) setState(() {});
  }

  void _setupRideProviderListener() {
    if (!mounted) return;

    AppLogger.debug('Configurando listener del RideProvider');
    try {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      // ✅ Guardar referencia para poder remover listener en dispose sin usar context
      _rideProviderRef = rideProvider;
      // Escuchar cambios en el viaje actual
      rideProvider.addListener(_onRideProviderChanged);
      AppLogger.debug('Listener del RideProvider configurado exitosamente');
    } catch (e) {
      AppLogger.error('Error configurando listener del RideProvider', e);
    }
  }

  /// ✅ Verificar si el pasajero tiene negociaciones activas (al cambiar de rol)
  Future<void> _checkForActiveNegotiations() async {
    if (!mounted) return;

    try {
      AppLogger.info('🔍 Verificando negociaciones activas del pasajero...');

      final negotiationProvider = Provider.of<PriceNegotiationProvider>(context, listen: false);

      // Iniciar listener en tiempo real para recibir ofertas
      negotiationProvider.startListeningToMyNegotiations();

      // Esperar un momento para que carguen las negociaciones
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Verificar si hay negociaciones activas
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.currentUser?.id ?? '';

      final myActiveNegotiations = negotiationProvider.activeNegotiations
          .where((n) => n.passengerId == currentUserId)
          .where((n) => n.status == models.NegotiationStatus.waiting || n.status == models.NegotiationStatus.negotiating)
          .toList();

      if (myActiveNegotiations.isNotEmpty) {
        AppLogger.info('✅ Encontradas ${myActiveNegotiations.length} negociaciones activas');

        // Mostrar el sheet de ofertas de conductores
        setState(() {
          _currentNegotiation = myActiveNegotiations.first;
          _showDriverOffers = true;
          _showPriceNegotiation = false;
        });

        // ✅ Iniciar el cronómetro para actualizar el tiempo restante
        _startCountdownTimer();

        // Mostrar mensaje informativo
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('Tienes una solicitud de viaje activa')),
                ],
              ),
              backgroundColor: ModernTheme.info,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        AppLogger.info('📭 No hay negociaciones activas');

        // ✅ FIX: Si la UI estaba mostrando ofertas o negociación de precio (UI de servicio activo)
        // y ya no hay negociaciones activas, limpiar completamente
        // Esto previene que se muestre la ruta y el botón "Continuar" sin contexto
        if (_showDriverOffers || _currentNegotiation != null) {
          AppLogger.info('🧹 Limpiando estado de negociación anterior (servicio ya no activo)');
          setState(() {
            _currentNegotiation = null;
            _showDriverOffers = false;
            _showPriceNegotiation = false;

            // Limpiar la ruta del mapa
            _polylines.clear();
            _markers.clear();

            // Limpiar campos de texto
            _pickupController.clear();
            _destinationController.clear();
            _priceController.clear();

            // Limpiar coordenadas
            _pickupCoordinates = null;
            _destinationCoordinates = null;

            // Limpiar cálculos de ruta
            _calculatedDistance = null;
            _estimatedTime = null;
            _suggestedPrice = null;
          });
        }
      }
    } catch (e) {
      AppLogger.error('Error verificando negociaciones activas', e);
    }
  }
  
  void _onRideProviderChanged() {
    // Verification codes removed - no longer navigating to verification screen
  }

  /// Solicitar permisos de ubicación al iniciar la app
  Future<void> _requestLocationPermission() async {
    if (!mounted) return;

    try {
      AppLogger.info('Solicitando permisos de ubicación para Google Maps');

      // Verificar permisos actuales
      LocationPermission permission = await Geolocator.checkPermission();

      // Si están denegados, solicitarlos
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // Actualizar estado según resultado
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        if (!mounted) return;
        setState(() {
          _locationPermissionGranted = true;
        });
        AppLogger.info('✅ Permisos de ubicación otorgados');
        // Obtener posición actual y mostrar marcador de persona
        try {
          final position = await Geolocator.getCurrentPosition();
          _addPassengerMarker(LatLng(position.latitude, position.longitude));
        } catch (e) {
          AppLogger.warning('⚠️ No se pudo obtener posición para marcador: $e');
        }
      } else {
        AppLogger.warning('⚠️ Permisos de ubicación denegados - MyLocation deshabilitado en Maps');
        AppLogger.warning('   Permiso actual: $permission');
        print('⚠️ MAPA: Permisos denegados ($permission), el mapa se mostrará SIN ubicación del usuario');
      }

    } catch (e, stackTrace) {
      AppLogger.error('Error solicitando permisos de ubicación', e, stackTrace);
    }
  }

  /// Agregar marcador de persona en la ubicación del pasajero
  void _addPassengerMarker(LatLng position) {
    if (!mounted || _passengerIcon == null) return;
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'my_location');
      _markers.add(Marker(
        markerId: const MarkerId('my_location'),
        position: position,
        icon: _passengerIcon!,
        infoWindow: const InfoWindow(title: 'Mi ubicación'),
      ));
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 15),
    );
  }

  @override
  void dispose() {
    // ✅ Marcar como disposed ANTES de cancelar cualquier recurso
    _isDisposed = true;

    // ✅ Liberar MapController para evitar ImageReader buffer warnings
    _mapController?.dispose();
    _mapController = null;

    // Cancelar timers INMEDIATAMENTE para prevenir callbacks pendientes
    _negotiationTimer?.cancel();
    _negotiationTimer = null;
    _buttonDelayTimer?.cancel();
    _buttonDelayTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;

    // ✅ Remover listener usando la referencia guardada (NO usar context en dispose)
    _rideProviderRef?.removeListener(_onRideProviderChanged);
    _rideProviderRef = null;

    _bottomSheetController.dispose();
    _searchBarController.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _priceController.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  // ✅ Método helper para ocultar teclado de manera confiable en Android
  void _hideKeyboard() {
    FocusScope.of(context).unfocus(); // Quita el foco
    SystemChannels.textInput.invokeMethod('TextInput.hide'); // Fuerza el ocultamiento en Android
  }

  // ✅ Iniciar Timer para actualizar cronómetro de ofertas cada segundo
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _currentNegotiation == null) {
        timer.cancel();
        return;
      }

      // Verificar si la negociación expiró
      if (_currentNegotiation!.isExpired) {
        timer.cancel();
        setState(() {
          _showDriverOffers = false;
          _currentNegotiation = null;
        });
        // Mostrar mensaje de expiración
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu solicitud ha expirado. Puedes crear una nueva.'),
            backgroundColor: ModernTheme.warning,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Actualizar UI para refrescar el cronómetro
      setState(() {});
    });
  }

  // ✅ Detener Timer del cronómetro
  void _stopCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// ✅ Agregar marcador para ubicación seleccionada y hacer zoom
  /// Coloca un marcador en el mapa (icono moderno para origen/destino)
  /// y centra el mapa en esa ubicación con zoom apropiado
  Future<void> _addMarkerAndZoom(LatLng position, String markerId, bool isPickup) async {
    // Crear marcador con icono moderno
    final marker = Marker(
      markerId: MarkerId(markerId),
      position: position,
      icon: isPickup
          ? (_originIcon ?? BitmapDescriptor.defaultMarker)
          : (_destinationIcon ?? BitmapDescriptor.defaultMarker),
      infoWindow: InfoWindow(
        title: isPickup ? 'Origen' : 'Destino',
      ),
    );

    if (!mounted) return;
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == markerId);
      if (isPickup) _markers.removeWhere((m) => m.markerId.value == 'my_location');
      _markers.add(marker);
    });

    // Hacer zoom a la ubicación
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(position, _kZoomLevelMedium), // ✅ Constante: suficiente para ver la zona claramente
      );
      AppLogger.info('Zoom a ${isPickup ? "origen" : "destino"}: ${position.latitude}, ${position.longitude}');
    }

    // Si ambas ubicaciones están disponibles, hacer zoom para mostrar ambas
    if (_pickupCoordinates != null && _destinationCoordinates != null) {
      await _zoomToShowBothLocations();
    }
  }

  /// ✅ NUEVO: Activar modo de ajuste de ubicación de recogida
  /// Muestra un marcador fijo en el centro del mapa y permite al usuario
  /// mover el mapa debajo del marcador para ajustar la ubicación exacta
  void _startPickupAdjustment() {
    if (_pickupCoordinates == null) return;

    if (!mounted) return;
    setState(() {
      _isAdjustingPickup = true;
      // Ocultar todos los marcadores mientras se ajusta
      _markers.clear();
      // Ocultar la ruta mientras se ajusta
      _polylines.clear();
    });

    // Centrar el mapa en la ubicación de pickup
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_pickupCoordinates!, _kZoomLevelClose),
      );
    }

    AppLogger.info('Modo de ajuste de pickup activado - mapa centrado en: ${_pickupCoordinates!.latitude}, ${_pickupCoordinates!.longitude}');
  }

  /// ✅ NUEVO: Confirmar la ubicación de recogida ajustada
  /// Obtiene las coordenadas del centro del mapa y las establece como punto de recogida
  Future<void> _confirmPickupLocation() async {
    if (_mapController == null || !mounted) return;

    try {
      // Obtener la posición central del mapa (donde está el marcador fijo)
      final LatLngBounds bounds = await _mapController!.getVisibleRegion();
      final LatLng center = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );

      AppLogger.info('Ubicación de pickup confirmada: ${center.latitude}, ${center.longitude}');

      // Actualizar coordenadas de pickup
      setState(() {
        _pickupCoordinates = center;
      });

      // Hacer reverse geocoding para actualizar el campo de texto
      final newAddress = await _reverseGeocode(center);
      if (newAddress != null && mounted) {
        setState(() {
          _pickupController.text = newAddress;
        });
        AppLogger.info('Dirección actualizada: $newAddress');
      }

      // Restaurar marcadores y ruta
      await _addMarkerAndZoom(_pickupCoordinates!, 'pickup_marker', true);
      if (_destinationCoordinates != null) {
        await _addMarkerAndZoom(_destinationCoordinates!, 'destination_marker', false);
        await _updateRoutePolyline();

        // Recalcular valores con la nueva ubicación
        final distance = _calculateDistance(_pickupCoordinates!, _destinationCoordinates!);
        final time = _estimateTime(distance);
        final price = _calculatePrice(distance);

        if (!mounted) return;
        setState(() {
          _calculatedDistance = distance;
          _estimatedTime = time;
          _suggestedPrice = price;
        });
        AppLogger.info('Ruta recalculada: $distance km, $time min, ${price.toCurrency()}');
      }

      // Salir del modo de ajuste
      if (!mounted) return;
      setState(() {
        _isAdjustingPickup = false;
      });

    } catch (e, stackTrace) {
      AppLogger.error('Error confirmando ubicación de pickup', e, stackTrace);
      if (!mounted) return;
      setState(() {
        _isAdjustingPickup = false;
      });
    }
  }

  /// ✅ Hacer zoom para mostrar ambas ubicaciones (origen y destino)
  /// Calcula los límites (bounds) que incluyen ambos puntos y ajusta el zoom automáticamente
  Future<void> _zoomToShowBothLocations() async {
    if (_pickupCoordinates == null || _destinationCoordinates == null) return;
    if (_mapController == null) return;

    // Calcular límites que incluyan ambos puntos
    double southWestLat = min(_pickupCoordinates!.latitude, _destinationCoordinates!.latitude);
    double southWestLng = min(_pickupCoordinates!.longitude, _destinationCoordinates!.longitude);
    double northEastLat = max(_pickupCoordinates!.latitude, _destinationCoordinates!.latitude);
    double northEastLng = max(_pickupCoordinates!.longitude, _destinationCoordinates!.longitude);

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );

    // Animar cámara para mostrar ambos puntos con padding
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, _kMapBoundsPadding), // ✅ Constante: padding para LatLngBounds
    );

    AppLogger.info('Zoom ajustado para mostrar origen y destino');
  }

  void _startNegotiation() async {
    // Validar que se hayan ingresado origen y destino
    if (_pickupController.text.isEmpty || _destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.enterOriginAndDestination),
          backgroundColor: ModernTheme.warning,
        ),
      );
      return;
    }

    // ✅ Prevenir múltiples clics - Activar loading
    if (_isCreatingNegotiation) return; // Si ya está creando, ignorar nuevos clics

    setState(() {
      _isCreatingNegotiation = true;
    });

    try {
      if (!mounted) return;
      // ✅ CORRECCIÓN: Usar PriceNegotiationProvider en lugar de RideProvider
      final negotiationProvider = Provider.of<PriceNegotiationProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      // ✅ IMPORTANTE: Limpiar negociaciones cuyo viaje fue cancelado antes de crear nueva
      await negotiationProvider.cleanupCancelledNegotiations();

      // ✅ NUEVO: Verificar si ya existe una negociación activa (solo 1 servicio a la vez)
      if (user != null) {
        final myActiveNegotiations = negotiationProvider.activeNegotiations
            .where((n) => n.passengerId == user.id)
            .where((n) => n.status == models.NegotiationStatus.waiting ||
                          n.status == models.NegotiationStatus.negotiating)
            .where((n) => n.expiresAt.isAfter(DateTime.now()))
            .toList();

        if (myActiveNegotiations.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _isCreatingNegotiation = false;
          });

          // Mostrar mensaje y preguntar si quiere ir a ver la negociación activa
          final goToNegotiations = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Ya tienes una solicitud activa'),
              content: const Text(
                'Solo puedes tener una solicitud de viaje activa a la vez. '
                '¿Deseas ver tu solicitud actual?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.rappiOrange),
                  child: const Text('Ver solicitud'),
                ),
              ],
            ),
          );

          if (goToNegotiations == true && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PassengerNegotiationsScreen()),
            ).then((_) {
              // ✅ Cuando regrese, verificar estado
              if (mounted) {
                _checkForActiveNegotiations();
              }
            });
          }
          return;
        }
      }

      if (user == null) {
        if (!mounted) return;
        setState(() {
          _isCreatingNegotiation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.userNotAuthenticated),
            backgroundColor: ModernTheme.error,
          ),
        );
        return;
      }

      // Obtener ubicación real del GPS del dispositivo
      LatLng? currentLocation = await _getCurrentLocation();
      if (currentLocation == null) {
        if (!mounted) return;
        setState(() {
          _isCreatingNegotiation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.locationPermissionDenied),
            backgroundColor: ModernTheme.error,
          ),
        );
        return;
      }

      // Geocoding real para destino (si no se proporcionó coordenadas específicas)
      LatLng? destinationLocation = await _getDestinationLocation();
      if (destinationLocation == null) {
        if (!mounted) return;
        setState(() {
          _isCreatingNegotiation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo encontrar la dirección de destino'),
            backgroundColor: ModernTheme.error,
          ),
        );
        return;
      }

      // ✅ Construir LocationPoints para negociación
      final pickup = models.LocationPoint(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        address: _pickupController.text.isEmpty ? 'Mi ubicación actual' : _pickupController.text,
        reference: null,
      );

      final destination = models.LocationPoint(
        latitude: destinationLocation.latitude,
        longitude: destinationLocation.longitude,
        address: _destinationController.text,
        reference: null,
      );

      // ✅ Determinar método de pago basado en selección del usuario
      models.PaymentMethod paymentMethod;
      switch (_selectedPaymentMethod) {
        case 'Tarjeta':
          paymentMethod = models.PaymentMethod.card;
          break;
        case 'Billetera':
          paymentMethod = models.PaymentMethod.wallet;
          break;
        case 'Efectivo':
        default:
          paymentMethod = models.PaymentMethod.cash;
          break;
      }

      // ✅ CORRECCIÓN: Crear negociación en lugar de solicitud directa
      await negotiationProvider.createNegotiation(
        pickup: pickup,
        destination: destination,
        offeredPrice: _offeredPrice,
        paymentMethod: paymentMethod,
        notes: null,
      );

      if (!mounted) return;

      // ✅ Cerrar el sheet de precio y mostrar mensaje de éxito
      setState(() {
        _showPriceNegotiation = false;
        _isCreatingNegotiation = false; // ✅ Desactivar loading
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Solicitud enviada! Los conductores cercanos verán tu oferta'),
          backgroundColor: ModernTheme.success,
          duration: Duration(seconds: 2),
        ),
      );

      // ✅ NUEVO: Navegar a la pantalla de negociaciones para ver ofertas
      // ✅ FIX: Usar .then() para verificar estado cuando el usuario regrese
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PassengerNegotiationsScreen(),
        ),
      ).then((_) {
        // ✅ Cuando el usuario regrese de la pantalla de negociaciones,
        // verificar si todavía tiene negociaciones activas
        if (mounted) {
          _checkForActiveNegotiations();
        }
      });

    } catch (e) {
      if (!mounted) return;

      setState(() {
        _showPriceNegotiation = false;
        _isCreatingNegotiation = false; // ✅ Desactivar loading en caso de error
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear negociación: ${e.toString()}'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  /// ✅ FIX: Método para cancelar la negociación de precio y limpiar todo
  /// Permite al usuario volver atrás y empezar de nuevo
  void _cancelPriceNegotiation() {
    AppLogger.info('Cancelando negociación de precio - limpiando estado');

    if (!mounted) return;
    setState(() {
      // Ocultar price negotiation sheet
      _showPriceNegotiation = false;

      // Limpiar la ruta del mapa
      _polylines.clear();

      // Limpiar marcadores
      _markers.clear();

      // Resetear coordenadas
      _pickupCoordinates = null;
      _destinationCoordinates = null;

      // Limpiar campos de texto
      _pickupController.clear();
      _destinationController.clear();
      _priceController.clear();

      // Resetear estados
      _isSelectingLocation = false;
      _isManualPriceEntry = false;
      _calculatedDistance = null;
      _estimatedTime = null;
      _suggestedPrice = null;
      _offeredPrice = 15.0; // Valor por defecto
      _showContinueButton = false; // ✅ Resetear estado del botón
      _isAdjustingPickup = false; // ✅ Salir del modo de ajuste
    });

    // ✅ Cancelar timer del botón si existe
    _buttonDelayTimer?.cancel();

    AppLogger.info('Estado reseteado completamente - usuario puede comenzar de nuevo');
  }

  void _simulateDriverOffers() {
    _negotiationTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      // ✅ TRIPLE VERIFICACIÓN para prevenir uso después de dispose
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_currentNegotiation != null &&
          _currentNegotiation!.driverOffers.length < 5) {
        setState(() {
          final newOffer = models.DriverOffer(
            driverId: 'driver${_currentNegotiation!.driverOffers.length}',
            driverName: 'Conductor ${_currentNegotiation!.driverOffers.length + 1}',
            driverPhoto: '', // Se obtiene del perfil del conductor desde Firebase
            driverRating: 4.5 + (_currentNegotiation!.driverOffers.length * 0.1),
            vehicleModel: ['Toyota Corolla', 'Nissan Sentra', 'Hyundai Accent'][
              _currentNegotiation!.driverOffers.length % 3
            ],
            vehiclePlate: 'ABC-${100 + _currentNegotiation!.driverOffers.length}',
            vehicleColor: ['Blanco', 'Negro', 'Gris'][
              _currentNegotiation!.driverOffers.length % 3
            ],
            acceptedPrice: _offeredPrice - (_currentNegotiation!.driverOffers.length * 0.5),
            estimatedArrival: 3 + _currentNegotiation!.driverOffers.length,
            offeredAt: DateTime.now(),
            status: models.OfferStatus.pending,
            completedTrips: 500 + (_currentNegotiation!.driverOffers.length * 100),
            acceptanceRate: 90.0 + _currentNegotiation!.driverOffers.length,
          );
          
          _currentNegotiation = _currentNegotiation!.copyWith(
            driverOffers: [..._currentNegotiation!.driverOffers, newOffer],
            status: models.NegotiationStatus.negotiating,
          );
          
          _showDriverOffers = true;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Manejar teclado manualmente con DraggableScrollableSheet
      appBar: RappiAppBar(
        title: 'Rappi Team',
        showBackButton: false,
        actions: [
          ModeSwitchButton(compact: true),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.notifications, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () => Navigator.pushNamed(context, '/shared/notifications'),
          ),
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu, color: Theme.of(context).colorScheme.onPrimary),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _buildDrawer(),
      body: GestureDetector(
        onTap: _hideKeyboard, // ✅ Cierra teclado al tocar fuera de los campos (Android compatible)
        child: Stack(
          children: [
            // Mapa con estilo limpio (sin POIs ni distracciones) - pantalla completa
            GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(-12.0851, -76.9770),
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller, // ✅ Habilitado para controlar zoom y cámara
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false, // Desactivado: usamos marcador personalizado de persona
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            style: _cleanMapStyle, // ✅ Aplica estilo limpio que oculta POIs y etiquetas
            // ✅ OPTIMIZACIONES: Reducir carga de renderizado y eliminar ImageReader warnings
            liteModeEnabled: false,  // Modo normal pero optimizado
            buildingsEnabled: false, // Deshabilitar edificios 3D
            indoorViewEnabled: false, // Deshabilitar vista interior
            trafficEnabled: false,   // Tráfico deshabilitado por defecto
            minMaxZoomPreference: MinMaxZoomPreference(10, 20), // Limitar zoom
          ),

          // ✅ NUEVO: Marcador fijo en el centro del mapa (solo visible en modo de ajuste)
          if (_isAdjustingPickup)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Marcador verde fijo en el centro (color corporativo)
                  Icon(
                    Icons.location_on,
                    size: 48,
                    color: ModernTheme.rappiOrange,
                    shadows: [
                      Shadow(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  // Texto descriptivo
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Mueve el mapa para ajustar tu ubicación',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ✅ NUEVO: Botón de confirmar ubicación (solo visible en modo de ajuste)
          if (_isAdjustingPickup)
            Positioned(
              left: 20,
              right: 20,
              bottom: 40,
              child: AnimatedPulseButton(
                text: 'Confirmar ubicación',
                icon: Icons.check,
                onPressed: () async {
                  await _confirmPickupLocation();
                  // Después de confirmar, mostrar la negociación de precio
                  if (!mounted) return;
                  setState(() {
                    _showPriceNegotiation = true;
                  });
                },
              ),
            ),

          // Selector de tipo de servicio (parte superior, solo cuando no está seleccionando)
          // ✅ Ocultar cuando el usuario está seleccionando ubicaciones o ajustando pickup
          if (!_isSelectingLocation && !_isAdjustingPickup)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: AnimatedBuilder(
                  animation: _searchBarAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -100 * (1 - _searchBarAnimation.value)),
                      child: Opacity(
                        opacity: _searchBarAnimation.value,
                        child: _buildServiceSelector(),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Bottom sheet con búsqueda de destino
          // ✅ Ocultar cuando está ajustando pickup
          if (!_isAdjustingPickup)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                // When keyboard is open, expand container so sheet content stays above keyboard
                height: MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).size.height * 0.95
                    : MediaQuery.of(context).size.height * 0.55,
                child: _showDriverOffers
                    ? _buildDriverOffersSheet()
                    : _showPriceNegotiation
                        ? _buildPriceNegotiationSheet()
                        : _buildDestinationBottomSheet(),
              ),
            ),

          // FAB de ubicación actual - movido a la esquina superior derecha
          // ✅ Ocultar cuando está ajustando pickup
          if (!_isAdjustingPickup)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).padding.top + (_isSelectingLocation ? 16 : 120),
              child: _buildLocationButton(),
            ),
        ], // Stack children
      ), // Stack
      ), // GestureDetector
    ); // Scaffold
  }
  
  /// ✅ Widget reutilizable para campos de dirección (DRY - elimina duplicación)
  /// ✅ SOLUCIÓN DEFINITIVA: Usa CustomPlaceTextField con flutter_typeahead
  /// Resuelve el problema del teclado (borrado letra por letra) porque NO recrea el TextField
  Widget _buildAddressField({
    required TextEditingController controller,
    required String hintText,
    required Color markerColor,
    required bool isPickup,
  }) {
    final apiKey = AppConfig.googleMapsApiKey;

    return CustomPlaceTextField(
      controller: controller,
      hintText: hintText,
      googleApiKey: apiKey,
      onTap: () {
        // User tapped on the text field — do NOT collapse the sheet here.
        // _isSelectingLocation is set to true only when a place suggestion is
        // selected and we need to zoom the map. Collapsing here would hide
        // the very field the user wants to type in.
        AppLogger.info('Usuario tocó campo ${isPickup ? "origen" : "destino"}');
      },
      onPlaceSelected: (PlacePrediction prediction) async {
        // Cuando se selecciona un lugar con coordenadas
        if (prediction.lat != null && prediction.lng != null) {
          final coords = LatLng(prediction.lat!, prediction.lng!);

          if (!mounted) return;
          setState(() {
            if (isPickup) {
              _pickupCoordinates = coords;
            } else {
              _destinationCoordinates = coords;
            }

            // Marcar que está buscando destino (solo para destination field)
            if (!isPickup) {
              _isSearchingDestination = true;
            }
          });

          AppLogger.info('${isPickup ? "Pickup" : "Destination"} coordinates guardadas: ${coords.latitude}, ${coords.longitude}');

          // Agregar marcador (verde para origen, rojo para destino) y hacer zoom
          await _addMarkerAndZoom(
            coords,
            isPickup ? 'pickup_marker' : 'destination_marker',
            isPickup,
          );

          // ✅ NUEVO: Si ambas coordenadas existen, actualizar polyline automáticamente
          if (_pickupCoordinates != null && _destinationCoordinates != null) {
            AppLogger.info('Ambas coordenadas disponibles - actualizando polyline automáticamente');
            await _updateRoutePolyline();

            // ✅ Después de actualizar polyline, resetear _isSelectingLocation para mostrar UI
            if (!mounted) return;
            setState(() {
              _isSelectingLocation = false;
            });
            AppLogger.info('Polyline actualizado - UI normal restaurada');
          }
        }
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(_kBorderRadiusMedium),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Campo de recogida - ✅ Refactorizado con widget reutilizable (DRY)
          Container(
            padding: _kPaddingHorizontal20Vertical8,
            child: Row(
              children: [
                // Círculo verde de marcador de origen
                Container(
                  width: _kMarkerCircleSize,
                  height: _kMarkerCircleSize,
                  decoration: BoxDecoration(
                    color: ModernTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: _kSpacingMedium),
                // Campo de autocompletado de dirección
                Expanded(
                  child: _buildAddressField(
                    controller: _pickupController,
                    hintText: AppLocalizations.of(context)!.whereAreYou,
                    markerColor: ModernTheme.success,
                    isPickup: true,
                  ),
                ),
                // ✅ Botón para usar ubicación actual (GPS con reverse geocoding)
                IconButton(
                  icon: Icon(Icons.my_location, color: context.primaryColor),
                  onPressed: () async {
                    // ✅ NUEVO: Mostrar indicador de carga mientras obtiene ubicación
                    _pickupController.text = 'Obteniendo ubicación...';

                    // Obtener coordenadas GPS reales
                    final currentLocation = await _getCurrentLocation();
                    if (currentLocation != null && mounted) {
                      // ✅ NUEVO: Hacer reverse geocoding para obtener dirección legible
                      final address = await _reverseGeocode(currentLocation);

                      if (!mounted) return;
                      setState(() {
                        _pickupCoordinates = currentLocation;
                        // Mostrar dirección real si está disponible, sino mostrar "Mi ubicación actual"
                        _pickupController.text = address ?? 'Mi ubicación actual';
                      });
                      _addMarkerAndZoom(currentLocation, 'pickup_marker', true);

                      AppLogger.info('Ubicación GPS con dirección: $address');
                    } else {
                      // Si no se pudo obtener ubicación, limpiar el campo
                      if (!mounted) return;
                      setState(() {
                        _pickupController.text = '';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          
          Divider(height: 1),
          
          // Campo de destino - ✅ Refactorizado con widget reutilizable (DRY)
          Container(
            padding: _kPaddingHorizontal20Vertical8,
            child: Row(
              children: [
                // Círculo rojo de marcador de destino
                Container(
                  width: _kMarkerCircleSize,
                  height: _kMarkerCircleSize,
                  decoration: BoxDecoration(
                    color: ModernTheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: _kSpacingMedium),
                // Campo de autocompletado de dirección
                Expanded(
                  child: _buildAddressField(
                    controller: _destinationController,
                    hintText: AppLocalizations.of(context)!.whereAreYouGoing,
                    markerColor: ModernTheme.error,
                    isPickup: false,
                  ),
                ),
                // ✅ Botón para limpiar campos y empezar de nuevo
                if (_pickupController.text.isNotEmpty || _destinationController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.close, color: ModernTheme.error),
                    tooltip: 'Limpiar todo',
                    onPressed: () {
                      if (!mounted) return;
                      setState(() {
                        // Limpiar campos de texto
                        _pickupController.clear();
                        _destinationController.clear();
                        // Limpiar coordenadas
                        _pickupCoordinates = null;
                        _destinationCoordinates = null;
                        // Limpiar marcadores y ruta
                        _markers.clear();
                        _polylines.clear();
                        // Resetear estados
                        _isSelectingLocation = false;
                        _showContinueButton = false;
                        _calculatedDistance = null;
                        _estimatedTime = null;
                        _suggestedPrice = null;
                      });
                      _buttonDelayTimer?.cancel();
                      AppLogger.info('Direcciones limpiadas - usuario puede empezar de nuevo');
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// ✅ Bottom sheet unificado: barra de búsqueda INTEGRADA dentro del DraggableScrollableSheet
  /// Eliminada la capa flotante separada — ahora todo es un solo panel cohesivo
  Widget _buildDestinationBottomSheet() {
    return _buildDestinationSheet();
  }

  Widget _buildDestinationSheet() {
    // ✅ Detectar si el teclado está abierto
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // Verificar si ambos campos están llenos
    final bool canContinue = _pickupController.text.isNotEmpty &&
                             _destinationController.text.isNotEmpty;

    // ✅ FIX CRÍTICO: Usar WidgetsBinding.addPostFrameCallback para evitar setState durante build
    // Si ambos campos están llenos Y el teclado está cerrado, iniciar timer
    if (canContinue && !isKeyboardOpen && !_showContinueButton) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Cancelar timer anterior si existe
        _buttonDelayTimer?.cancel();
        // Esperar 300ms después de que el teclado se cierre para mostrar botón
        _buttonDelayTimer = Timer(Duration(milliseconds: 300), () {
          if (mounted && canContinue && !isKeyboardOpen) {
            setState(() {
              _showContinueButton = true;
            });
          }
        });
      });
    } else if (!canContinue || isKeyboardOpen) {
      // Si los campos no están llenos o el teclado está abierto, ocultar botón
      if (_showContinueButton) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _buttonDelayTimer?.cancel();
          if (mounted) {
            setState(() {
              _showContinueButton = false;
            });
          }
        });
      }
    }

    // DraggableScrollableSheet para permitir arrastrar con el dedo
    // ✅ Tamaños condicionales:
    // - Seleccionando ubicación: 8% (solo handle visible)
    // - Con botón "Continuar": 50% (expandido para mostrar botón completo)
    // - Sin botón "Continuar": 35% (tamaño normal)
    return DraggableScrollableSheet(
      // ✅ Keyboard-aware: expandir sheet cuando el teclado está abierto
      initialChildSize: isKeyboardOpen ? 0.75 : (_isSelectingLocation ? 0.08 : (_showContinueButton ? 0.55 : 0.45)),
      minChildSize: isKeyboardOpen ? 0.65 : (_isSelectingLocation ? 0.08 : 0.30),
      maxChildSize: isKeyboardOpen ? 0.95 : 0.75,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(_kBorderRadiusXLarge)),
            boxShadow: ModernTheme.getFloatingShadow(context),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle visual para indicar que es draggable
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 8),
                width: _kHandleWidth,
                height: _kHandleHeight,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(_kBorderRadiusTiny),
                ),
              ),

              // Contenido con scroll — barra de búsqueda DENTRO del scrollable para evitar overflow
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ Barra de búsqueda integrada (scrolleable, no fija)
                      AnimatedBuilder(
                        animation: _searchBarAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _searchBarAnimation.value,
                            child: _buildSearchBar(),
                          );
                        },
                      ),

                      // ✅ Ocultar favoritos y recientes cuando está seleccionando ubicaciones (mapa limpio)
                      if (!_isSelectingLocation) ...[
                        // Lugares favoritos
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lugares favoritos',
                                style: TextStyle(
                                  fontSize: _kFontSizeLarge,
                                  fontWeight: FontWeight.bold,
                                  color: context.primaryText,
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildFavoritePlace(Icons.home, 'Casa'),
                                  _buildFavoritePlace(Icons.work, 'Trabajo'),
                                  _buildFavoritePlace(Icons.school, 'Universidad'),
                                  _buildFavoritePlace(Icons.add, 'Agregar'),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Divider(height: 1),

                        // Destinos recientes
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recientes',
                                style: TextStyle(
                                  fontSize: _kFontSizeLarge,
                                  fontWeight: FontWeight.bold,
                                  color: context.primaryText,
                                ),
                              ),
                              SizedBox(height: 12),
                              _buildRecentPlace('Centro Comercial Plaza', 'Av. Principal 123'),
                              _buildRecentPlace('Aeropuerto Internacional', 'Terminal 1'),
                              _buildRecentPlace('Parque Central', 'Calle Principal s/n'),
                            ],
                          ),
                        ),
                      ],

                      // ✅ FIX OVERFLOW + DELAY: Botón Continuar DENTRO del scrollable (solo visible después de cerrar teclado)
                      if (_showContinueButton)
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: AnimatedPulseButton(
                            text: 'Continuar',
                            icon: Icons.arrow_forward,
                            onPressed: () async {
                              if (!mounted) return;

                              // ✅ Resetear estado del botón inmediatamente al presionar
                              setState(() {
                                _showContinueButton = false;
                              });
                              _buttonDelayTimer?.cancel();

                              // ✅ Capturar ScaffoldMessenger y strings localizados ANTES de cualquier await para evitar warnings
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              final locationErrorMessage = AppLocalizations.of(context)!.couldNotGetCurrentLocation;

                              // ✅ Si no hay coordenadas de origen, obtener ubicación GPS actual automáticamente
                              if (_pickupCoordinates == null) {
                                AppLogger.info('No hay origen seleccionado, obteniendo ubicación GPS actual...');
                                final currentLocation = await _getCurrentLocation();
                                if (!mounted) return;

                                if (currentLocation != null) {
                                  setState(() {
                                    _pickupCoordinates = currentLocation;
                                  });
                                  AppLogger.info('Origen establecido a ubicación GPS: ${currentLocation.latitude}, ${currentLocation.longitude}');
                                } else {
                                  AppLogger.warning('No se pudo obtener ubicación GPS');
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(content: Text(locationErrorMessage)),
                                  );
                                  return;
                                }
                              }

                              // CALCULAR VALORES REALES con coordenadas reales
                              if (_pickupCoordinates != null && _destinationCoordinates != null) {
                                final distance = _calculateDistance(_pickupCoordinates!, _destinationCoordinates!);
                                final time = _estimateTime(distance);
                                final price = _calculatePrice(distance);

                                // ✅ Verificar mounted antes de setState
                                if (!mounted) return;
                                setState(() {
                                  _calculatedDistance = distance;
                                  _estimatedTime = time;
                                  _suggestedPrice = price;
                                  _offeredPrice = price; // Inicializar precio ofertado con el sugerido
                                  _isSelectingLocation = false; // ✅ Desactivar modo de selección para mostrar UI normal
                                });

                                // Dibujar línea de ruta REAL en el mapa (siguiendo calles)
                                await _updateRoutePolyline();
                                if (!mounted) return;

                                AppLogger.info('Ruta calculada con coordenadas REALES: $distance km, $time min, ${price.toCurrency()}');

                                // ✅ NUEVO: Activar modo de ajuste de pickup en lugar de ir directo a negociación
                                _startPickupAdjustment();
                              } else {
                                // Si aún no hay destino, mostrar advertencia
                                AppLogger.warning('Falta seleccionar destino');
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(content: Text('Por favor selecciona un destino')),
                                );
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildPriceNegotiationSheet() {
    // Calcular valores reales si tenemos coordenadas
    String distanceTimeText = 'Calculando ruta...';
    String suggestedPriceText = 'Calculando precio...';

    if (_calculatedDistance != null && _estimatedTime != null && _suggestedPrice != null) {
      // Usar valores calculados REALES
      distanceTimeText = '${_calculatedDistance!.toStringAsFixed(1)} km • $_estimatedTime min';
      suggestedPriceText = 'Precio sugerido: ${_suggestedPrice!.toCurrency()}';
    } else if (_pickupCoordinates != null && _destinationCoordinates != null) {
      // Calcular ahora si aún no se ha hecho
      final distance = _calculateDistance(_pickupCoordinates!, _destinationCoordinates!);
      final time = _estimateTime(distance);
      final price = _calculatePrice(distance);

      distanceTimeText = '${distance.toStringAsFixed(1)} km • $time min';
      suggestedPriceText = 'Precio sugerido: ${price.toCurrency()}';
    }

    // NotificationListener para detectar cuando el usuario arrastra el sheet y ocultar el teclado
    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        // ✅ Ocultar teclado cuando el usuario empieza a arrastrar el sheet (Android compatible)
        _hideKeyboard();
        if (mounted) {
          setState(() => _isManualPriceEntry = false);
        }
        return false; // No consumir la notificación (permitir que se propague)
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.6, // ✅ FIX OVERFLOW: 60% de la pantalla (aumentado de 0.5 para eliminar overflow de 51px)
        minChildSize: 0.3,     // Mínimo 30%
        maxChildSize: 0.85,    // Máximo 85%
        builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(_kBorderRadiusXLarge)),
            boxShadow: ModernTheme.getFloatingShadow(context),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle visual para indicar que es draggable
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 8),
                width: _kHandleWidth,
                height: _kHandleHeight,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(_kBorderRadiusTiny),
                ),
              ),

              // ✅ FIX: Header con botón cancelar para volver atrás
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Botón para cancelar y volver atrás
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: context.primaryText),
                      onPressed: _cancelPriceNegotiation,
                      tooltip: 'Volver',
                    ),
                    // Título centrado
                    Expanded(
                      child: Center(
                        child: Text(
                          'Ofrece tu precio',
                          style: TextStyle(
                            fontSize: _kFontSizeXLarge,
                            fontWeight: FontWeight.bold,
                            color: context.primaryText,
                          ),
                        ),
                      ),
                    ),
                    // SizedBox para balancear el IconButton y mantener el título centrado
                    SizedBox(width: 48),
                  ],
                ),
              ),

              // Contenido con scroll
              Expanded(
                child: GestureDetector(
                  // ✅ Ocultar teclado al hacer tap fuera del TextField (Android compatible)
                  onTap: () {
                    _hideKeyboard();
                    if (!mounted) return;
                    setState(() => _isManualPriceEntry = false);
                  },
                  child: SingleChildScrollView(
                    controller: scrollController, // CRÍTICO: Para que drag y scroll trabajen juntos
                    child: Padding(
                      padding: EdgeInsets.all(8), // ✅ Reducido de 14 a 8 (ahorra 12px adicionales)
                      child: Column(
                        children: [
                        // ✅ Texto descriptivo (el título ya está en el header)
                        Text(
                          'Los conductores cercanos verán tu oferta',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.secondaryText,
                          ),
                        ),
                        SizedBox(height: 10), // ✅ Reducido de 16 a 10 (ahorra 6px adicionales)

                        // Información del viaje CON VALORES REALES (sin placeholders)
                        Container(
                          padding: EdgeInsets.all(10), // ✅ Reducido de 14 a 10 (ahorra 4px adicionales)
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(_kBorderRadiusMedium),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.route, color: ModernTheme.primaryBlue),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      distanceTimeText, // VALOR REAL CALCULADO
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      suggestedPriceText, // VALOR REAL CALCULADO
                                      style: TextStyle(
                                        color: ModernTheme.success,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10), // ✅ Reducido de 16 a 10 (ahorra 6px adicionales)

                        // Opciones de precio sugeridas (3-4 botones con diferentes precios en S/)
                        Text(
                          'Selecciona tu precio:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.primaryText,
                          ),
                        ),
                        SizedBox(height: 6), // ✅ Reducido de 10 a 6 (ahorra 4px adicionales)

                        // Botones de sugerencia de precio
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildPriceSuggestionButton((_suggestedPrice ?? 15.0) * 0.9), // -10%
                            _buildPriceSuggestionButton(_suggestedPrice ?? 15.0), // Precio sugerido (destacado)
                            _buildPriceSuggestionButton((_suggestedPrice ?? 15.0) * 1.1), // +10%
                            _buildPriceSuggestionButton((_suggestedPrice ?? 15.0) * 1.2), // +20%
                          ],
                        ),
                        SizedBox(height: 8), // ✅ Reducido de 12 a 8 (ahorra 4px adicionales)

                        // TextField para entrada manual de precio
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(_kBorderRadiusSmall),
                            border: Border.all(
                              color: _isManualPriceEntry ? context.primaryColor : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                              width: _isManualPriceEntry ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'S/',
                                style: TextStyle(
                                  fontSize: _kFontSizeLarge,
                                  fontWeight: FontWeight.w600,
                                  color: context.primaryText,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _priceController,
                                  focusNode: _priceFocusNode,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(
                                    fontSize: _kFontSizeLarge,
                                    fontWeight: FontWeight.w600,
                                    color: context.primaryColor,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(context)!.enterPrice,
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  onTap: () {
                                    if (!mounted) return;
                                    setState(() => _isManualPriceEntry = true);
                                  },
                                  onChanged: (value) {
                                    final price = double.tryParse(value);
                                    if (price != null && mounted) {
                                      setState(() => _offeredPrice = price);
                                    }
                                  },
                                  onSubmitted: (_) {
                                    // ✅ Ocultar teclado al presionar Enter (Android compatible)
                                    _hideKeyboard();
                                    if (!mounted) return;
                                    setState(() => _isManualPriceEntry = false);
                                  },
                                ),
                              ),
                              if (_priceController.text.isNotEmpty)
                                IconButton(
                                  icon: Icon(Icons.close, size: 20),
                                  onPressed: () {
                                    _priceController.clear();
                                    _hideKeyboard(); // ✅ Ocultar teclado (Android compatible)
                                    if (!mounted) return;
                                    setState(() {
                                      _isManualPriceEntry = false;
                                      _offeredPrice = _suggestedPrice ?? 15.0;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10), // ✅ Reducido de 16 a 10 (ahorra 6px adicionales)

                        // Métodos de pago - Usar Wrap para evitar overflow
                        Wrap(
                          spacing: 12, // Espacio horizontal entre elementos
                          runSpacing: 12, // Espacio vertical si hay salto de línea
                          alignment: WrapAlignment.center,
                          children: [
                            _buildPaymentMethod(Icons.money, 'Efectivo', _selectedPaymentMethod == 'Efectivo'),
                            _buildPaymentMethod(Icons.credit_card, 'Tarjeta', _selectedPaymentMethod == 'Tarjeta'),
                            _buildPaymentMethod(Icons.account_balance_wallet, 'Billetera', _selectedPaymentMethod == 'Billetera'),
                          ],
                        ),
                        SizedBox(height: 10), // ✅ Reducido de 16 a 10 (ahorra 6px adicionales)

                        // Botón de buscar conductor
                        AnimatedPulseButton(
                          text: 'Buscar conductor',
                          icon: Icons.search,
                          onPressed: _startNegotiation,
                          isLoading: _isCreatingNegotiation, // ✅ Mostrar spinner mientras se crea la negociación
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ), // Cierre del Expanded
          ],
          ),
        );
      },
    ),
    );  // Cierre del NotificationListener
  }

  Widget _buildDriverOffersSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: ModernTheme.getFloatingShadow(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ Handle con botón de cerrar
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // ✅ Botón X para cancelar
              Positioned(
                right: 16,
                top: 8,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showDriverOffers = false;
                      _currentNegotiation = null;
                    });
                    _cancelPriceNegotiation();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: context.secondaryText,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Título con contador
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ofertas de conductores',
                      style: TextStyle(
                        fontSize: _kFontSizeXLarge,
                        fontWeight: FontWeight.bold,
                        color: context.primaryText,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_currentNegotiation?.driverOffers.length ?? 0} conductores interesados',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.secondaryText,
                      ),
                    ),
                  ],
                ),
                // Timer countdown
                Builder(
                  builder: (context) {
                    final remaining = _currentNegotiation?.timeRemaining;
                    final isExpired = remaining == null || remaining.isNegative || remaining.inSeconds <= 0;
                    final timerText = isExpired
                        ? 'Expirado'
                        : '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? ModernTheme.error.withValues(alpha: 0.1)
                            : ModernTheme.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(_kBorderRadiusLarge),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isExpired ? Icons.timer_off : Icons.timer,
                            size: 16,
                            color: isExpired ? ModernTheme.error : ModernTheme.warning,
                          ),
                          SizedBox(width: 4),
                          Text(
                            timerText,
                            style: TextStyle(
                              color: isExpired ? ModernTheme.error : ModernTheme.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Lista de ofertas
          SizedBox(
            height: 300,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 20),
              itemCount: _currentNegotiation?.driverOffers.length ?? 0,
              itemBuilder: (context, index) {
                final offer = _currentNegotiation!.driverOffers[index];
                return _buildDriverOfferCard(offer);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDriverOfferCard(models.DriverOffer offer) {
    return AnimatedElevatedCard(
      onTap: () async {
        // ✅ Mostrar diálogo de confirmación antes de aceptar
        final confirmed = await _showAcceptOfferConfirmation(offer);
        if (confirmed == true) {
          await _acceptDriverOffer(offer);
        }
      },
      borderRadius: 16,
      child: Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            // Foto del conductor
            CircleAvatar(
              radius: 30,
              backgroundImage: (offer.driverPhoto.isNotEmpty && offer.driverPhoto.startsWith('http'))
                  ? NetworkImage(offer.driverPhoto)
                  : null,
            ),
            SizedBox(width: 12),
            
            // Información del conductor
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        offer.driverName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.star, size: 16, color: ModernTheme.accentYellow),
                      Text(
                        offer.driverRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 14,
                          color: context.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${offer.vehicleModel} • ${offer.vehicleColor}',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.secondaryText,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: ModernTheme.info),
                      SizedBox(width: 4),
                      Text(
                        '${offer.estimatedArrival} min',
                        style: TextStyle(
                          fontSize: 12,
                          color: ModernTheme.info,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.directions_car, size: 14, color: context.secondaryText),
                      SizedBox(width: 4),
                      Text(
                        '${offer.completedTrips} viajes',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Precio ofertado
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: ModernTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(_kBorderRadiusLarge),
              ),
              child: Text(
                offer.acceptedPrice.toCurrency(),
                style: TextStyle(
                  color: ModernTheme.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFavoritePlace(IconData icon, String label) {
    return InkWell(
      onTap: () {
        if (label != 'Agregar') {
          _destinationController.text = label;
          if (!mounted) return;
          setState(() => _showPriceNegotiation = true);
        }
      },
      borderRadius: BorderRadius.circular(_kBorderRadiusSmall),
      child: Container(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: context.primaryColor),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecentPlace(String title, String subtitle) {
    return InkWell(
      onTap: () {
        _destinationController.text = title;
        if (!mounted) return;
        setState(() => _showPriceNegotiation = true);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                color: context.secondaryText,
                size: 20,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
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
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: context.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentMethod(IconData icon, String label, bool selected) {
    return InkWell(
      onTap: () {
        if (!mounted) return;
        setState(() {
          _selectedPaymentMethod = label;
        });
        AppLogger.info('Método de pago seleccionado: $label');
      },
      borderRadius: BorderRadius.circular(_kBorderRadiusSmall),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: selected ? context.primaryColor : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(_kBorderRadiusSmall),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? context.primaryColor : context.secondaryText,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? context.primaryColor : context.secondaryText,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construir botón de sugerencia de precio
  /// Muestra un precio específico en soles (S/) y lo resalta si es el precio actualmente ofertado
  Widget _buildPriceSuggestionButton(double price) {
    // Verificar si este precio es el actualmente seleccionado (con tolerancia de 0.01 para comparación de doubles)
    final bool isSelected = (_offeredPrice - price).abs() < 0.01;

    return InkWell(
      onTap: () {
        if (!mounted) return;

        // ✅ Ocultar teclado si está abierto (Android compatible)
        _hideKeyboard();

        setState(() {
          // Actualizar precio ofertado
          _offeredPrice = price;
          // Actualizar el TextField con el valor seleccionado
          _priceController.text = price.toStringAsFixed(2);
          // Marcar que NO es entrada manual (es selección de botón)
          _isManualPriceEntry = false;
        });

        AppLogger.info('Precio seleccionado desde botón: ${price.toCurrency()}');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
            ? context.primaryColor
            : context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
              ? context.primaryColor
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
            ? [
                BoxShadow(
                  color: context.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                )
              ]
            : null,
        ),
        child: Text(
          price.toCurrency(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? Theme.of(context).colorScheme.onPrimary : context.primaryText,
          ),
        ),
      ),
    );
  }

  /// Construir selector de tipo de servicio (horizontal)
  Widget _buildServiceSelector() {
    return Container(
      height: 120,
      margin: EdgeInsets.only(top: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildServiceTypeCard(
            type: ServiceType.standard,
            icon: Icons.local_taxi,
            name: 'Taxi\nEstándar',
            description: '1-4 pasajeros',
            priceMultiplier: '1.0x',
          ),
          _buildServiceTypeCard(
            type: ServiceType.xl,
            icon: Icons.airport_shuttle,
            name: 'Taxi\nXL',
            description: '5-6 pasajeros',
            priceMultiplier: '1.5x',
          ),
          _buildServiceTypeCard(
            type: ServiceType.premium,
            icon: Icons.drive_eta,
            name: 'Taxi\nPremium',
            description: 'Lujo, 1-4 pax',
            priceMultiplier: '2.0x',
          ),
          _buildServiceTypeCard(
            type: ServiceType.delivery,
            icon: Icons.local_shipping,
            name: 'Delivery\nExpress',
            description: 'Solo paquetes',
            priceMultiplier: '0.8x',
          ),
          _buildServiceTypeCard(
            type: ServiceType.moto,
            icon: Icons.two_wheeler,
            name: 'Moto\nTaxi',
            description: '1 pasajero',
            priceMultiplier: '0.7x',
          ),
        ],
      ),
    );
  }

  /// Construir tarjeta de tipo de servicio individual
  Widget _buildServiceTypeCard({
    required ServiceType type,
    required IconData icon,
    required String name,
    required String description,
    required String priceMultiplier,
  }) {
    final bool isSelected = _selectedServiceType == type;

    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        final previousType = _selectedServiceType;
        setState(() {
          _selectedServiceType = type;
          // Recalcular precio si ya hay coordenadas
          if (_pickupCoordinates != null && _destinationCoordinates != null) {
            final distance = _calculateDistance(_pickupCoordinates!, _destinationCoordinates!);
            final price = _calculatePrice(distance);
            _suggestedPrice = price;
            _offeredPrice = price;
            AppLogger.info('Tipo de servicio cambiado a: $type, nuevo precio: ${price.toCurrency()}');
          }
        });
        // ✅ Feedback visual: mostrar SnackBar confirmando la selección
        if (previousType != type) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('$name seleccionado'.replaceAll('\n', ' '), style: TextStyle(fontWeight: FontWeight.w600)),
                  Spacer(),
                  Text(priceMultiplier, style: TextStyle(color: Colors.white70)),
                ],
              ),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: context.primaryColor,
            ),
          );
        }
        // Actualizar polyline si cambia el tipo de servicio (mantener la ruta visible)
        _updateRoutePolyline();
      },
      child: Container(
        width: _kServiceCardWidth,
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? context.primaryColor : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(_kBorderRadiusMedium),
          border: Border.all(
            color: isSelected ? context.primaryColor : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: context.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  )
                ]
              : ModernTheme.getCardShadow(context),
        ),
        child: Padding(
          padding: EdgeInsets.all(8), // Reducido de 12 a 8 (ahorra 8px verticales)
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28, // Reducido de 32 a 28 (ahorra 4px)
                color: isSelected ? Theme.of(context).colorScheme.onPrimary : context.primaryColor,
              ),
              SizedBox(height: 6), // Reducido de 8 a 6 (ahorra 2px)
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Theme.of(context).colorScheme.onPrimary : context.primaryText,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 3), // Reducido de 4 a 3 (ahorra 1px)
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.9) : context.secondaryText,
                ),
              ),
              SizedBox(height: 2),
              Text(
                priceMultiplier,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Theme.of(context).colorScheme.onPrimary : ModernTheme.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ Botón flotante para centrar el mapa en la ubicación GPS actual
  Widget _buildLocationButton() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: IconButton(
        icon: Icon(Icons.my_location, color: context.primaryColor),
        onPressed: () async {
          // Obtener ubicación GPS actual
          final currentLocation = await _getCurrentLocation();
          if (currentLocation != null && _mapController != null && mounted) {
            // Centrar el mapa en la ubicación actual con zoom apropiado
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(currentLocation, _kZoomLevelClose), // ✅ Constante: muy cerca para ver detalles
            );
            AppLogger.info('Mapa centrado en ubicación GPS: ${currentLocation.latitude}, ${currentLocation.longitude}');
          }
        },
      ),
    );
  }
  
  // ✅ Mostrar diálogo de confirmación antes de aceptar oferta
  Future<bool?> _showAcceptOfferConfirmation(models.DriverOffer offer) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_kBorderRadiusLarge),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: ModernTheme.rappiOrange, size: 28),
            SizedBox(width: 12),
            Text('Confirmar viaje'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info del conductor
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: offer.driverPhoto.isNotEmpty
                      ? NetworkImage(offer.driverPhoto)
                      : null,
                  child: offer.driverPhoto.isEmpty
                      ? Icon(Icons.person, size: 25)
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.driverName,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: ModernTheme.accentYellow),
                          SizedBox(width: 4),
                          Text(
                            offer.driverRating.toStringAsFixed(1),
                            style: TextStyle(fontSize: 14, color: context.secondaryText),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Vehículo
            Text(
              offer.vehicleModel,
              style: TextStyle(fontSize: 14, color: context.secondaryText),
            ),
            Text(
              '${offer.vehiclePlate} • ${offer.vehicleColor}',
              style: TextStyle(fontSize: 14, color: context.secondaryText),
            ),
            SizedBox(height: 16),
            // Precio
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Precio acordado:', style: TextStyle(fontSize: 16)),
                  Text(
                    'S/. ${offer.acceptedPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ModernTheme.rappiOrange,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            // Tiempo de llegada
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: ModernTheme.info),
                SizedBox(width: 4),
                Text(
                  'Llega en ~${offer.estimatedArrival} min',
                  style: TextStyle(color: ModernTheme.info),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Aceptar viaje'),
          ),
        ],
      ),
    );
  }

  // ✅ Aceptar oferta de conductor - Crea el viaje y muestra confirmación
  Future<void> _acceptDriverOffer(models.DriverOffer offer) async {
    if (_currentNegotiation == null) return;

    // Mostrar loading mientras se procesa
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_kBorderRadiusLarge),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModernLoadingIndicator(color: ModernTheme.rappiOrange),
            SizedBox(height: 20),
            Text(
              'Aceptando oferta...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );

    try {
      // Usar el provider para crear el viaje
      final negotiationProvider = Provider.of<PriceNegotiationProvider>(context, listen: false);
      final rideId = await negotiationProvider.acceptDriverOffer(
        _currentNegotiation!.id,
        offer.driverId,
      );

      // Cerrar el loading
      if (mounted) Navigator.of(context).pop();

      if (rideId != null) {
        // Detener el cronómetro
        _stopCountdownTimer();

        // Resetear estados de la pantalla
        setState(() {
          _showDriverOffers = false;
          _currentNegotiation = null;
        });

        // Mostrar diálogo de éxito y navegar al tracking
        _showDriverAcceptedDialog(offer, rideId);
      } else {
        // Error al crear el viaje
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al aceptar la oferta. Intenta de nuevo.'),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      // Cerrar el loading
      if (mounted) Navigator.of(context).pop();

      AppLogger.error('Error aceptando oferta', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  // ✅ Mostrar diálogo de confirmación con opción de ver detalles
  void _showDriverAcceptedDialog(models.DriverOffer offer, String rideId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_kBorderRadiusLarge),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: ModernTheme.success, size: 64),
            SizedBox(height: 20),
            Text(
              '¡Conductor confirmado!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '${offer.driverName} está en camino',
              style: TextStyle(color: dialogContext.secondaryText),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              'Llegará en aproximadamente ${offer.estimatedArrival} minutos',
              style: TextStyle(
                color: ModernTheme.info,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            AnimatedPulseButton(
              text: 'Ver seguimiento',
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Navegar a pantalla de seguimiento del viaje
                Navigator.pushNamed(
                  context,
                  '/trip-tracking',
                  arguments: {'rideId': rideId},
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            // Header del drawer unificado
            RappiTeamDrawerHeader(
              userType: 'passenger',
              userName: 'Usuario Pasajero',
            ),
            
            // Opciones del menú
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.history,
                    title: AppLocalizations.of(context)!.tripHistory,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/trip-history');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.star,
                    title: AppLocalizations.of(context)!.ratings,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/ratings-history');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.payment,
                    title: AppLocalizations.of(context)!.paymentMethods,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/payment-methods');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.favorite,
                    title: AppLocalizations.of(context)!.favoritePlaces,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/favorites');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.local_offer,
                    title: AppLocalizations.of(context)!.promotions,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/promotions');
                    },
                  ),
                  Divider(),
                  _buildDrawerItem(
                    icon: Icons.person,
                    title: AppLocalizations.of(context)!.profile,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/profile');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: AppLocalizations.of(context)!.settings,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.help,
                    title: AppLocalizations.of(context)!.helpCenter,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AboutScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    title: AppLocalizations.of(context)!.logout,
                    onTap: () {
                      Navigator.pop(context);
                      _showLogoutConfirmation();
                    },
                    color: ModernTheme.error,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Confirmación de logout
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: color ?? ModernTheme.rappiOrange,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? context.primaryText,
        ),
      ),
      onTap: onTap,
    );
  }

  /// Obtener ubicación GPS REAL del dispositivo
  Future<LatLng?> _getCurrentLocation() async {
    try {
      AppLogger.info('Obteniendo ubicación GPS real del dispositivo');

      // Verificar permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.warning('Permisos de ubicación denegados');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.error('Permisos de ubicación denegados permanentemente');
        return null;
      }

      // Obtener ubicación actual real
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final LatLng currentLocation = LatLng(position.latitude, position.longitude);
      AppLogger.info('Ubicación GPS real obtenida: ${position.latitude}, ${position.longitude}');

      return currentLocation;

    } catch (e, stackTrace) {
      AppLogger.error('Error obteniendo ubicación GPS real', e, stackTrace);
      return null;
    }
  }

  /// ✅ NUEVO: Obtener dirección legible desde coordenadas GPS (Reverse Geocoding)
  /// Convierte LatLng a dirección de calle legible para el usuario
  Future<String?> _reverseGeocode(LatLng coordinates) async {
    try {
      AppLogger.info('Realizando reverse geocoding para: ${coordinates.latitude}, ${coordinates.longitude}');

      // Obtener placemarks (lugares) desde las coordenadas
      List<Placemark> placemarks = await placemarkFromCoordinates(
        coordinates.latitude,
        coordinates.longitude,
      );

      if (placemarks.isEmpty) {
        AppLogger.warning('No se encontraron resultados de reverse geocoding');
        return null;
      }

      // Tomar el primer resultado (el más relevante)
      final Placemark place = placemarks.first;

      // Construir dirección legible
      // Formato: "Calle, Número, Distrito, Ciudad"
      List<String> addressParts = [];

      if (place.street != null && place.street!.isNotEmpty) {
        addressParts.add(place.street!);
      }
      if (place.subLocality != null && place.subLocality!.isNotEmpty) {
        addressParts.add(place.subLocality!);
      }
      if (place.locality != null && place.locality!.isNotEmpty) {
        addressParts.add(place.locality!);
      }

      final String address = addressParts.join(', ');

      if (address.isEmpty) {
        AppLogger.warning('Dirección vacía después de reverse geocoding');
        return 'Ubicación encontrada (${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)})';
      }

      AppLogger.info('Reverse geocoding exitoso: $address');
      return address;

    } catch (e, stackTrace) {
      AppLogger.error('Error en reverse geocoding', e, stackTrace);
      return null;
    }
  }

  /// Obtener ubicación de destino REAL desde Google Places autocomplete
  Future<LatLng?> _getDestinationLocation() async {
    if (_destinationController.text.trim().isEmpty) {
      AppLogger.warning('Dirección de destino vacía');
      return null;
    }

    try {
      // Usar coordenadas obtenidas de Google Places autocomplete
      if (_destinationCoordinates != null) {
        AppLogger.info('Usando coordenadas de Google Places: ${_destinationCoordinates!.latitude}, ${_destinationCoordinates!.longitude}');
        return _destinationCoordinates;
      }

      // Si no hay coordenadas (usuario escribió pero no seleccionó de la lista)
      // NO usar fallback - mostrar error al usuario
      AppLogger.warning('Usuario escribió dirección pero no seleccionó de autocomplete. Coordenadas no disponibles.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor selecciona una dirección de la lista de sugerencias'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return null;

    } catch (e, stackTrace) {
      AppLogger.error('Error obteniendo ubicación de destino', e, stackTrace);
      return null;
    }
  }

  /// Calcular distancia REAL entre dos coordenadas usando fórmula Haversine
  /// Retorna la distancia en kilómetros
  double _calculateDistance(LatLng start, LatLng end) {
    // Radio de la Tierra en km
    const double earthRadiusKm = 6371.0;

    // Convertir grados a radianes
    final double lat1Rad = start.latitude * (3.141592653589793 / 180.0);
    final double lat2Rad = end.latitude * (3.141592653589793 / 180.0);
    final double deltaLatRad = (end.latitude - start.latitude) * (3.141592653589793 / 180.0);
    final double deltaLonRad = (end.longitude - start.longitude) * (3.141592653589793 / 180.0);

    // Fórmula Haversine
    final double a = (sin(deltaLatRad / 2) * sin(deltaLatRad / 2)) +
        (cos(lat1Rad) * cos(lat2Rad) * sin(deltaLonRad / 2) * sin(deltaLonRad / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distanceKm = earthRadiusKm * c;

    AppLogger.info('Distancia calculada (Haversine): ${distanceKm.toStringAsFixed(2)} km');
    return distanceKm;
  }

  /// Calcular tiempo estimado REAL basado en distancia
  /// Usa velocidad promedio de Lima en tráfico: ~20 km/h
  /// Retorna el tiempo en minutos
  int _estimateTime(double distanceKm) {
    // Velocidad promedio en Lima considerando tráfico
    const double averageSpeedKmh = 20.0;

    // Tiempo = distancia / velocidad (en horas), luego convertir a minutos
    final double timeHours = distanceKm / averageSpeedKmh;
    final int timeMinutes = (timeHours * 60).round();

    AppLogger.info('Tiempo estimado: $timeMinutes minutos (${distanceKm.toStringAsFixed(2)} km a $averageSpeedKmh km/h)');
    return timeMinutes;
  }

  /// Cargar tarifas desde Firebase settings/app_config
  Future<void> _loadFaresFromConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_config')
          .get();
      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _configBaseFare = (data['baseFare'] ?? data['base_fare'] ?? 5.0).toDouble();
          _configRatePerKm = (data['perKm'] ?? data['ratePerKm'] ?? data['per_km'] ?? 2.0).toDouble();
        });
        AppLogger.info('✅ Tarifas cargadas desde Firebase: base=$_configBaseFare, perKm=$_configRatePerKm');
      }
    } catch (e) {
      AppLogger.warning('⚠️ Error cargando tarifas, usando valores por defecto: $e');
    }
  }

  /// Calcular precio sugerido REAL basado en distancia y tipo de servicio
  /// Fórmula: (Tarifa base + (distancia * tarifa por km)) * multiplicador de servicio
  /// Retorna el precio en soles (S/)
  double _calculatePrice(double distanceKm) {
    // Tarifas leídas desde Firebase settings/app_config
    final double baseFare = _configBaseFare;
    final double ratePerKm = _configRatePerKm;

    // Multiplicadores por tipo de servicio
    double serviceMultiplier;
    String serviceName;

    switch (_selectedServiceType) {
      case ServiceType.standard:
        serviceMultiplier = 1.0; // Precio estándar
        serviceName = 'Taxi Estándar';
        break;
      case ServiceType.xl:
        serviceMultiplier = 1.5; // 50% más caro (vehículo grande)
        serviceName = 'Taxi XL';
        break;
      case ServiceType.premium:
        serviceMultiplier = 2.0; // Doble del precio (vehículo de lujo)
        serviceName = 'Taxi Premium';
        break;
      case ServiceType.delivery:
        serviceMultiplier = 0.8; // 20% más barato (solo paquetes, no pasajeros)
        serviceName = 'Delivery Express';
        break;
      case ServiceType.moto:
        serviceMultiplier = 0.7; // 30% más barato (moto, solo 1 pasajero)
        serviceName = 'Moto Taxi';
        break;
    }

    // Cálculo: (base + (distancia * tarifa)) * multiplicador
    final double basePrice = baseFare + (distanceKm * ratePerKm);
    final double totalPrice = basePrice * serviceMultiplier;

    AppLogger.info('Precio calculado: ${totalPrice.toCurrency()} ($serviceName x$serviceMultiplier: base ${baseFare.toCurrency()} + ${distanceKm.toStringAsFixed(2)} km × ${ratePerKm.toCurrency()}/km)');
    return totalPrice;
  }

  /// Obtener puntos de la ruta REAL desde Google Directions API
  /// Retorna lista de LatLng que forman la ruta siguiendo las calles
  Future<List<LatLng>> _getRoutePolylinePoints(LatLng origin, LatLng destination) async {
    try {
      AppLogger.info('Obteniendo ruta real desde Google Directions API: ${origin.latitude},${origin.longitude} → ${destination.latitude},${destination.longitude}');

      // Inicializar PolylinePoints con la API key desde AppConfig
      final polylinePoints = PolylinePoints(apiKey: AppConfig.googleMapsApiKey);

      // Request route from Routes API V2
      final result = await polylinePoints.getRouteBetweenCoordinatesV2(
        request: RoutesApiRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          travelMode: TravelMode.driving,
        ),
      );

      if (result.primaryRoute?.polylinePoints case List<PointLatLng> points) {
        List<LatLng> polylineCoordinates = points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        AppLogger.info('Ruta real obtenida con ${polylineCoordinates.length} puntos desde Routes API');
        return polylineCoordinates;
      } else {
        AppLogger.warning('No se pudo obtener ruta desde Routes API');
        AppLogger.info('Usando fallback: línea recta entre origen y destino');
        return [origin, destination];
      }

    } catch (e, stackTrace) {
      AppLogger.error('Error obteniendo ruta desde Directions API', e, stackTrace);

      // Fallback: retornar línea recta en caso de error
      AppLogger.info('Usando fallback por error: línea recta entre origen y destino');
      return [origin, destination];
    }
  }

  /// Actualizar la polilínea de ruta en el mapa
  /// Dibuja una línea naranja siguiendo la ruta REAL de las calles (no línea recta)
  Future<void> _updateRoutePolyline() async {
    if (_pickupCoordinates == null || _destinationCoordinates == null) {
      // Si no hay coordenadas, limpiar la polilínea
      if (!mounted) return;
      setState(() {
        _polylines.clear();
      });
      AppLogger.info('Polilínea limpiada - no hay coordenadas');
      return;
    }

    // Obtener los puntos de la ruta REAL desde Google Directions API
    final List<LatLng> routePoints = await _getRoutePolylinePoints(
      _pickupCoordinates!,
      _destinationCoordinates!,
    );

    // Verificar que el widget sigue montado antes de usar context
    if (!mounted) return;

    // Crear polilínea con TODOS los puntos de la ruta real (no solo 2 puntos)
    final Polyline routePolyline = Polyline(
      polylineId: PolylineId('route'),
      points: routePoints, // ✅ AHORA USA RUTA REAL CON MÚLTIPLES PUNTOS
      color: context.primaryColor,
      width: 5,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );

    if (!mounted) return;
    setState(() {
      _polylines.clear(); // Limpiar polilíneas anteriores
      _polylines.add(routePolyline); // Agregar la nueva polilínea con ruta real
    });

    AppLogger.info('Polilínea de ruta REAL dibujada con ${routePoints.length} puntos: ${_pickupCoordinates!.latitude},${_pickupCoordinates!.longitude} → ${_destinationCoordinates!.latitude},${_destinationCoordinates!.longitude}');
  }
}