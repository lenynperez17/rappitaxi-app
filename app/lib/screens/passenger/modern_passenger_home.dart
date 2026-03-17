// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api, unused_import, dead_code
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/app_config.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // Para reverse geocoding (coordenadas → dirección)
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math'; // Para funciones matemáticas: sin, cos, sqrt, atan2 (fórmula Haversine)
import '../../utils/map_marker_utils.dart';
import 'package:http/http.dart' as http;
import '../../generated/l10n/app_localizations.dart'; // Import de localizaciones
import '../../core/widgets/custom_place_text_field.dart'; // Widget custom que resuelve problema del teclado
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../core/widgets/mode_switch_button.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../widgets/common/rappi_app_bar.dart';
import '../../widgets/indrive/indrive_widgets.dart';
import '../../models/price_negotiation_model.dart' as models;
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/price_negotiation_provider.dart';
import '../../services/config_service.dart';
import '../shared/settings_screen.dart';
import '../shared/about_screen.dart';
import '../../utils/logger.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../../core/utils/currency_formatter.dart';
import '../../services/location_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart'; // Para verificar solicitudes de conductor pendientes
import 'package:share_plus/share_plus.dart'; // Para compartir la app
import 'passenger_negotiations_screen.dart'; // Pantalla de negociaciones

// Enum para tipos de servicio disponibles (Estilo inDrive)
enum ServiceType {
  viaje,        // Viaje estándar ciudad
  mototaxi,     // Mototaxi económico
  confort,      // Vehículo cómodo
  xl,           // 5-6 pasajeros
  entregas,     // Paquetes hasta 20kg
  flete,        // Mudanzas/carga grande
  ciudadACiudad, // Viajes interurbanos
}

// ELIMINADO: TripModality - inDrive NO tiene viajes programados ni rideshare urbanos

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

  // Servicio de configuración para tarifas dinámicas
  final ConfigService _configService = ConfigService();
  FareConfig? _fareConfig; // Cache local de tarifas

  // Controllers
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _priceController = TextEditingController(); // Para entrada manual de precio

  // FocusNode para controlar el teclado del campo de precio
  final FocusNode _priceFocusNode = FocusNode();

  // Flag para prevenir uso de controllers después de dispose
  bool _isDisposed = false;

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
  ServiceType _selectedServiceType = ServiceType.viaje; // Tipo de servicio seleccionado (default: Viaje)
  String _selectedPaymentMethod = 'Efectivo'; // Método de pago seleccionado (default: Efectivo)
  bool _isSelectingLocation = false; // true cuando el usuario está ingresando/seleccionando direcciones
  bool _isSearchingDriver = false; // true cuando se está buscando conductor
  bool _isWaitingForDriver = false; // true cuando ya se envió la solicitud y espera respuesta
  String? _currentRideId; // Ride ID para cancel incluso si provider pierde estado
  bool _isInTrackingScreen = false; // Evita navegación duplicada a pantalla de tracking
  bool _isCancelling = false; // Evita navegación a tracking durante cancelación
  bool _isEditingOrigin = false; // true cuando el usuario quiere editar el campo de origen
  bool _isCameraMoving = false; // true while user is dragging the map
  bool _wasInPriceNegotiation = false; // true when editing route from price sheet
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  // Inline search results (inDrive style)
  List<PlacePrediction> _destinationSearchResults = [];
  List<PlacePrediction> _originSearchResults = [];
  Timer? _searchDebounceTimer;
  int _searchTab = 0; // 0=Resultados, 1=Sugerida, 2=Guardada
  bool _isSearchingPlaces = false;
  final TextEditingController _inlineDestinationController = TextEditingController();

  // Simulated driver markers animation
  Timer? _driverAnimationTimer;
  LatLng? _simulatedCenter; // Center point for driver markers
  BitmapDescriptor? _cachedCarIcon;
  final List<_SimDriver> _simDrivers = [];

  // Suggested pickup snap points
  final List<LatLng> _refDotPositions = [];
  int _activeRefDotIndex = -1; // -1 = none active
  BitmapDescriptor? _refDotIcon;
  BitmapDescriptor? _refDotActiveIcon;
  LatLng? _lastCameraTarget; // Tracks camera position for geocoding/snap
  bool _isSnapping = false; // Prevents onCameraIdle loop during programmatic snap
  static const double _activateThresholdDeg = 0.00012; // ~13m — green only when pin is almost on top
  static const double _regenerateThresholdDeg = 0.003; // ~330m — regenerate dots beyond this

  // Coordenadas de lugares seleccionados con Google Places
  LatLng? _pickupCoordinates;
  LatLng? _destinationCoordinates;

  // Cálculos reales de la ruta (sin placeholders)
  double? _calculatedDistance; // Distancia real en km usando Haversine
  int? _estimatedTime; // Tiempo estimado real en minutos
  double? _suggestedPrice; // Precio sugerido real basado en distancia

  // Negociación actual
  models.PriceNegotiation? _currentNegotiation;
  Timer? _negotiationTimer;

  // ==================== DATOS ESPECÍFICOS POR CATEGORÍA DE SERVICIO ====================
  // XL - Cantidad de pasajeros
  int _xlPassengerCount = 5; // 5-6 pasajeros

  // Entregas (delivery)
  String _deliveryDescription = ''; // ¿Qué envías?
  String _deliveryWeight = '<5kg'; // Peso: <5kg, 5-10kg, 10-20kg
  String _deliveryRecipientName = ''; // Nombre destinatario
  String _deliveryRecipientPhone = ''; // Teléfono destinatario

  // Flete (mudanzas/carga)
  String _freightType = 'Cajas'; // Tipo: Muebles, Electrodomésticos, Cajas, Otros
  bool _freightNeedsHelper = false; // ¿Necesita ayudante?
  String _freightNotes = ''; // Notas adicionales

  // Ciudad a Ciudad (interurbano)
  int _intercityStops = 0; // Paradas: 0-3
  String _intercityLuggage = 'Normal'; // Equipaje: Ligero, Normal, Mucho
  TimeOfDay? _intercityDepartureTime; // Hora de salida preferida

  // ==================== LUGARES FAVORITOS Y RECIENTES ====================
  Map<String, Map<String, dynamic>> _userFavorites = {};
  List<Map<String, dynamic>> _recentPlaces = [];
  bool _loadingPlaces = true;

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
  static const double _kZoomLevelClose = 17.0;
  static const double _kZoomLevelMedium = 16.5;
  static const double _kMapBoundsPadding = 100.0;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _setupRideProviderListener();
        _loadActiveTripIfNeeded();
      } catch (e) {
        debugPrint('Error en setupRideProviderListener: $e');
      }
      _requestLocationPermission().then((_) {
        _autoFillCurrentLocation();
      }).catchError((e) {
        debugPrint('Error en requestLocationPermission: $e');
      });
      _loadFareConfig().catchError((e) {
        debugPrint('Error en loadFareConfig: $e');
      });
      _loadUserPlaces().catchError((e) {
        debugPrint('Error en loadUserPlaces: $e');
      });
    });
  }

  /// Load active trip from Firestore if user has one (e.g. after app restart)
  Future<void> _loadActiveTripIfNeeded() async {
    final rideProvider = context.read<RideProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;

    // Clean up expired negotiations first
    try {
      final negotiationProvider = context.read<PriceNegotiationProvider>();
      await negotiationProvider.cleanupExpiredNegotiations();
    } catch (e) {
      debugPrint('Error cleaning up negotiations: $e');
    }

    if (!rideProvider.hasActiveTrip) {
      if (!mounted) return;
      final trip = rideProvider.currentTrip;
      if (trip != null && (trip.status == 'requested' || trip.status == 'accepted')) {
        setState(() {
          _isWaitingForDriver = true;
          _showPriceNegotiation = true;
          _currentRideId = trip.id;
          _offeredPrice = trip.finalFare ?? 15.0;
          _suggestedPrice ??= _offeredPrice;
          _pickupController.text = trip.pickupAddress;
          _destinationController.text = trip.destinationAddress;
        });
        debugPrint('🔄 Restored UI for active ride: ${trip.id} status=${trip.status}');
      }
    }

    // Ensure waiting state is clean on fresh start
    if (!_isWaitingForDriver) {
      setState(() {
        _isSearchingDriver = false;
        _showDriverOffers = false;
      });
    }
  }

  /// Cargar lugares favoritos y recientes del usuario desde Firestore
  Future<void> _loadUserPlaces() async {
    if (!mounted) return;

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.id;

      if (userId == null) {
        setState(() => _loadingPlaces = false);
        return;
      }

      final favoritesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();

      if (mounted && favoritesSnapshot.docs.isNotEmpty) {
        final Map<String, Map<String, dynamic>> loadedFavorites = {};

        for (final doc in favoritesSnapshot.docs) {
          final data = doc.data();
          final name = (data['name'] as String?)?.toLowerCase() ?? '';
          final address = data['address'] as String?;
          final lat = data['latitude'] as double?;
          final lng = data['longitude'] as double?;

          if (address != null && lat != null && lng != null) {
            String key;
            if (name.contains('casa') || name.contains('home') || data['icon'] == 'home') {
              key = 'home';
            } else if (name.contains('trabajo') || name.contains('work') || data['icon'] == 'work') {
              key = 'work';
            } else if (name.contains('universidad') || name.contains('school') || name.contains('uni') || data['icon'] == 'school') {
              key = 'university';
            } else {
              key = doc.id;
            }

            loadedFavorites[key] = {
              'address': address,
              'lat': lat,
              'lng': lng,
              'name': data['name'],
            };
          }
        }

        setState(() {
          _userFavorites = loadedFavorites;
        });
      }

      final recentTrips = await FirebaseFirestore.instance
          .collection('trips')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(5)
          .get();

      if (mounted) {
        final List<Map<String, dynamic>> places = [];
        final Set<String> seenAddresses = {};

        for (final doc in recentTrips.docs) {
          final data = doc.data();
          final destAddress = data['destinationAddress'] as String?;
          final destLat = data['destinationLocation']?['latitude'] as double?;
          final destLng = data['destinationLocation']?['longitude'] as double?;

          if (destAddress != null && destLat != null && destLng != null) {
            final addressKey = destAddress.toLowerCase().trim();
            if (!seenAddresses.contains(addressKey)) {
              seenAddresses.add(addressKey);
              places.add({
                'address': destAddress,
                'subtitle': _formatRecentSubtitle(data),
                'lat': destLat,
                'lng': destLng,
              });
            }
          }

          if (places.length >= 3) break;
        }

        setState(() {
          _recentPlaces = places;
          _loadingPlaces = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error cargando lugares del usuario: $e');
      if (mounted) {
        setState(() => _loadingPlaces = false);
      }
    }
  }

  String _formatRecentSubtitle(Map<String, dynamic> tripData) {
    final completedAt = tripData['completedAt'];
    if (completedAt == null) return '';

    DateTime date;
    if (completedAt is Timestamp) {
      date = completedAt.toDate();
    } else {
      return '';
    }

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Hoy';
    } else if (diff.inDays == 1) {
      return 'Ayer';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _loadFareConfig() async {
    try {
      _fareConfig = await _configService.getFares();
      AppLogger.info('Tarifas cargadas: base=${_fareConfig?.baseFare}, perKm=${_fareConfig?.perKm}');
    } catch (e) {
      AppLogger.error('Error cargando tarifas, usando valores por defecto', e);
      _fareConfig = FareConfig.defaultConfig();
    }
  }

  Future<void> _autoFillCurrentLocation() async {
    if (!mounted || !_locationPermissionGranted) return;

    try {
      setState(() {
        _pickupController.text = 'Obteniendo ubicación...';
      });

      final currentLocation = await _getCurrentLocation();
      if (currentLocation != null && mounted) {
        final address = await _reverseGeocode(currentLocation);
        if (!mounted) return;

        setState(() {
          _pickupCoordinates = currentLocation;
          _pickupController.text = address ?? 'Mi ubicación actual';
        });

        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(currentLocation, _kZoomLevelMedium),
          );
        }

        AppLogger.info('Ubicación auto-llenada: $address');

        await _addReferencePointDots(currentLocation);
        await _addSimulatedDriverMarkers(currentLocation);
      } else if (mounted) {
        setState(() => _pickupController.text = '');
      }
    } catch (e) {
      AppLogger.error('Error auto-llenando ubicación: $e');
      if (mounted) {
        setState(() => _pickupController.text = '');
      }
    }
  }
  
  void _setupRideProviderListener() {
    if (!mounted) return;
    
    AppLogger.debug('Configurando listener del RideProvider');
    try {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      rideProvider.addListener(_onRideProviderChanged);
      AppLogger.debug('Listener del RideProvider configurado exitosamente');
    } catch (e) {
      AppLogger.error('Error configurando listener del RideProvider', e);
    }
  }
  
  void _onRideProviderChanged() {
    if (!mounted) return;

    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final currentTrip = rideProvider.currentTrip;

    debugPrint('🔔 _onRideProviderChanged: trip=${currentTrip?.id}, status=${currentTrip?.status}, isLoading=${rideProvider.isLoading}, _isWaitingForDriver=$_isWaitingForDriver');

    if (currentTrip != null) {
      if (currentTrip.status == 'in_progress') {
        if (!_isInTrackingScreen && !_isCancelling && !_isWaitingForDriver) {
          _isInTrackingScreen = true;
          Navigator.pushNamed(
            context,
            '/passenger/tracking',
            arguments: currentTrip.id,
          ).then((_) {
            if (mounted) {
              setState(() {
                _isInTrackingScreen = false;
                _isSearchingDriver = false;
                _isWaitingForDriver = false;
                _showDriverOffers = false;
                _currentRideId = null;
              });
            }
          });
        }
      } else if ((currentTrip.status == 'accepted' || currentTrip.status == 'arrived' || currentTrip.status == 'driver_arriving') && currentTrip.driverId != null) {
        if (!_isWaitingForDriver && !_isInTrackingScreen && !_isCancelling) {
          _isInTrackingScreen = true;
          Navigator.pushNamed(
            context,
            '/passenger/tracking',
            arguments: currentTrip.id,
          ).then((_) {
            if (mounted) {
              setState(() {
                _isInTrackingScreen = false;
                _isSearchingDriver = false;
                _isWaitingForDriver = false;
                _showDriverOffers = false;
                _currentRideId = null;
              });
            }
          });
        }
      } else if (currentTrip.status == 'completed' || currentTrip.status == 'cancelled') {
        debugPrint('🔴 RESETTING STATE: trip ${currentTrip.id} has status ${currentTrip.status}');
        setState(() {
          _isInTrackingScreen = false;
          _isWaitingForDriver = false;
          _isSearchingDriver = false;
          _showDriverOffers = false;
          _isCancelling = false;
          _currentRideId = null;
        });
      } else if (currentTrip.status == 'expired') {
        debugPrint('🔴 RESETTING STATE: trip ${currentTrip.id} expired');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontró conductor disponible. Intenta solicitar otro viaje.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        setState(() {
          _isInTrackingScreen = false;
          _isWaitingForDriver = false;
          _isSearchingDriver = false;
          _showDriverOffers = false;
          _isCancelling = false;
          _currentRideId = null;
        });
      }
    } else {
      // Only reset if waiting for driver, NOT if in tracking screen.
      // The tracking screen handles its own lifecycle and will reset
      // _isInTrackingScreen when it pops via .then() callback.
      if (_isWaitingForDriver && !_isInTrackingScreen && !rideProvider.isLoading) {
        debugPrint('🔴 RESETTING STATE: no trip, isLoading=false, _isWaitingForDriver=$_isWaitingForDriver');
        setState(() {
          _isWaitingForDriver = false;
          _isSearchingDriver = false;
          _showDriverOffers = false;
          _showPriceNegotiation = false;
          _isCancelling = false;
          _currentRideId = null;
        });
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    if (!mounted) return;

    try {
      AppLogger.info('Verificando permisos de ubicación para Google Maps');

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        if (!mounted) return;
        setState(() {
          _locationPermissionGranted = true;
        });
        AppLogger.info('Permisos de ubicación ya otorgados - MyLocation habilitado en Maps');
        return;
      }

      if (!mounted) return;

      // Request permission directly (LocationService.showLocationDisclosure not available)
      final permission2 = await Geolocator.requestPermission();
      final granted = permission2 == LocationPermission.whileInUse || permission2 == LocationPermission.always;

      if (!mounted) return;
      setState(() {
        _locationPermissionGranted = granted;
      });

      if (granted) {
        AppLogger.info('Permisos de ubicación otorgados - MyLocation habilitado en Maps');
      } else {
        AppLogger.warning('Permisos de ubicación denegados - MyLocation deshabilitado en Maps');
      }

    } catch (e, stackTrace) {
      AppLogger.error('Error solicitando permisos de ubicación', e, stackTrace);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    _mapController?.dispose();
    _mapController = null;

    _negotiationTimer?.cancel();
    _negotiationTimer = null;
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = null;
    _driverAnimationTimer?.cancel();
    _driverAnimationTimer = null;
    _inlineDestinationController.dispose();
    _sheetController.dispose();

    try {
      if (mounted) {
        final rideProvider = Provider.of<RideProvider>(context, listen: false);
        rideProvider.removeListener(_onRideProviderChanged);
      }
    } catch (e) {
      AppLogger.debug('Error removiendo listener en dispose: $e');
    }

    _bottomSheetController.dispose();
    _searchBarController.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _priceController.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  void _hideKeyboard() => FocusScope.of(context).unfocus();

  /// Reverse geocode camera target to update pickup address.
  Future<void> _reverseGeocodeMapCenter() async {
    final target = _lastCameraTarget;
    if (target == null || !mounted) return;
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${target.latitude},${target.longitude}'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty && mounted) {
          final address = data['results'][0]['formatted_address'] as String;
          setState(() {
            _pickupController.text = address;
            _pickupCoordinates = target;
          });
        }
      }
    } catch (e) {
      AppLogger.debug('Reverse geocode error: $e');
    }
  }

  Future<void> _addReferencePointDots(LatLng center) async {
    _refDotIcon = await getReferencePointIcon();
    _refDotActiveIcon = await getReferencePointActiveIcon();
    _markers.removeWhere((m) => m.markerId.value.startsWith('ref_dot'));
    _refDotPositions.clear();
    _activeRefDotIndex = -1;

    final random = Random();
    const int dotCount = 7;

    final candidates = <LatLng>[];
    for (int i = 0; i < dotCount; i++) {
      final angle = (i / dotCount) * 2 * pi + (random.nextDouble() - 0.5) * 0.4;
      final dist = 0.0003 + random.nextDouble() * 0.0008;
      candidates.add(LatLng(
        center.latitude + cos(angle) * dist,
        center.longitude + sin(angle) * dist,
      ));
    }

    final positions = await _snapToNearestRoads(candidates);

    for (int i = 0; i < positions.length; i++) {
      _refDotPositions.add(positions[i]);
      _markers.add(Marker(
        markerId: MarkerId('ref_dot_$i'),
        position: positions[i],
        icon: _refDotIcon!,
        anchor: const Offset(0.5, 0.5),
        zIndex: 1,
      ));
    }
    if (mounted) setState(() {});
  }

  Future<List<LatLng>> _snapToNearestRoads(List<LatLng> candidates) async {
    try {
      final pointsParam = candidates
          .map((p) => '${p.latitude},${p.longitude}')
          .join('|');
      final url = Uri.parse(
        'https://roads.googleapis.com/v1/nearestRoads'
        '?points=$pointsParam'
        '&key=${AppConfig.googleMapsApiKey}',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final snapped = data['snappedPoints'] as List? ?? [];
        if (snapped.isNotEmpty) {
          const double minGap = 0.00027;
          final result = <LatLng>[];
          for (final p in snapped) {
            final loc = p['location'];
            final lat = (loc['latitude'] as num).toDouble();
            final lng = (loc['longitude'] as num).toDouble();
            final candidate = LatLng(lat, lng);
            final tooClose = result.any((existing) =>
              sqrt(pow(existing.latitude - lat, 2) + pow(existing.longitude - lng, 2)) < minGap);
            if (!tooClose) result.add(candidate);
          }
          if (result.isNotEmpty) return result;
        }
      } else {
        AppLogger.debug('Roads API status: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.debug('Roads API error: $e');
    }
    return candidates;
  }

  int _findNearestDotWithinThreshold(LatLng target) {
    int nearest = -1;
    double minDist = _activateThresholdDeg;
    for (int i = 0; i < _refDotPositions.length; i++) {
      final d = _refDotPositions[i];
      final dist = sqrt(pow(d.latitude - target.latitude, 2) + pow(d.longitude - target.longitude, 2));
      if (dist < minDist) {
        minDist = dist;
        nearest = i;
      }
    }
    return nearest;
  }

  int _findClosestDot(LatLng target) {
    if (_refDotPositions.isEmpty) return -1;
    int closest = 0;
    double minDist = double.infinity;
    for (int i = 0; i < _refDotPositions.length; i++) {
      final d = _refDotPositions[i];
      final dist = sqrt(pow(d.latitude - target.latitude, 2) + pow(d.longitude - target.longitude, 2));
      if (dist < minDist) {
        minDist = dist;
        closest = i;
      }
    }
    return closest;
  }

  void _updateActiveRefDot(LatLng cameraTarget) {
    if (_refDotPositions.isEmpty || _refDotIcon == null || _refDotActiveIcon == null) return;

    final nearest = _findNearestDotWithinThreshold(cameraTarget);
    if (nearest == _activeRefDotIndex) return;

    if (_activeRefDotIndex >= 0) {
      final prevId = MarkerId('ref_dot_$_activeRefDotIndex');
      _markers.removeWhere((m) => m.markerId == prevId);
      _markers.add(Marker(
        markerId: prevId,
        position: _refDotPositions[_activeRefDotIndex],
        icon: _refDotIcon!,
        anchor: const Offset(0.5, 0.5),
        zIndex: 1,
      ));
    }

    if (nearest >= 0) {
      final newId = MarkerId('ref_dot_$nearest');
      _markers.removeWhere((m) => m.markerId == newId);
      _markers.add(Marker(
        markerId: newId,
        position: _refDotPositions[nearest],
        icon: _refDotActiveIcon!,
        anchor: const Offset(0.5, 0.5),
        zIndex: 2,
      ));
    }

    _activeRefDotIndex = nearest;
    if (mounted) setState(() {});
  }

  Future<void> _snapToNearestDot() async {
    if (_mapController == null || _activeRefDotIndex < 0 || _activeRefDotIndex >= _refDotPositions.length) {
      _isSnapping = false;
      return;
    }
    final target = _refDotPositions[_activeRefDotIndex];
    _lastCameraTarget = target;
    await _mapController!.animateCamera(CameraUpdate.newLatLng(target));
    Future.delayed(const Duration(seconds: 2), () {
      if (_isSnapping && mounted) _isSnapping = false;
    });
  }

  bool _shouldRegenerateMarkers(LatLng newCenter) {
    if (_simulatedCenter == null) return true;
    final dist = sqrt(
      pow(newCenter.latitude - _simulatedCenter!.latitude, 2) +
      pow(newCenter.longitude - _simulatedCenter!.longitude, 2),
    );
    return dist > _regenerateThresholdDeg;
  }

  Future<void> _addSimulatedDriverMarkers(LatLng center) async {
    _simulatedCenter = center;
    final random = Random();
    const int driverCount = 5;

    try {
      _cachedCarIcon = await MapMarkerUtils.getCarTopViewIcon();
    } catch (_) {
      _cachedCarIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    }

    _simDrivers.clear();
    final now = DateTime.now();
    for (int i = 0; i < driverCount; i++) {
      final angle = (i / driverCount) * 2 * pi + (random.nextDouble() - 0.5) * 0.5;
      final distance = 0.0015 + random.nextDouble() * 0.003;
      _simDrivers.add(_SimDriver(
        lat: center.latitude + cos(angle) * distance,
        lng: center.longitude + sin(angle) * distance,
        heading: random.nextDouble() * 360,
        speed: 0.00004 + random.nextDouble() * 0.00012,
        alpha: 1.0,
        visible: true,
        nextMove: now.add(Duration(milliseconds: 500 + random.nextInt(2000))),
        nextDisappear: now.add(Duration(seconds: 10 + random.nextInt(25))),
      ));
    }

    _syncSimDriverMarkers();

    _driverAnimationTimer?.cancel();
    _driverAnimationTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || _isDisposed) return;
      _tickSimDrivers();
    });
  }

  void _tickSimDrivers() {
    if (_simulatedCenter == null || _cachedCarIcon == null) return;
    final random = Random();
    final center = _simulatedCenter!;
    final now = DateTime.now();
    bool changed = false;

    for (int i = 0; i < _simDrivers.length; i++) {
      final d = _simDrivers[i];

      if (d.visible && d.alpha > 0 && now.isAfter(d.nextDisappear)) {
        final newAlpha = (d.alpha - 0.25).clamp(0.0, 1.0);
        if (newAlpha <= 0) {
          _simDrivers[i] = d.copyWith(
            alpha: 0.0,
            visible: false,
            nextDisappear: now.add(Duration(seconds: 2 + random.nextInt(4))),
          );
        } else {
          _simDrivers[i] = d.copyWith(alpha: newAlpha);
        }
        changed = true;
        continue;
      }

      if (!d.visible && now.isAfter(d.nextDisappear)) {
        final angle = random.nextDouble() * 2 * pi;
        final dist = 0.002 + random.nextDouble() * 0.004;
        _simDrivers[i] = _SimDriver(
          lat: center.latitude + cos(angle) * dist,
          lng: center.longitude + sin(angle) * dist,
          heading: random.nextDouble() * 360,
          speed: 0.00004 + random.nextDouble() * 0.00012,
          alpha: 0.3,
          visible: true,
          nextMove: now.add(Duration(milliseconds: 800 + random.nextInt(1500))),
          nextDisappear: now.add(Duration(seconds: 12 + random.nextInt(25))),
        );
        changed = true;
        continue;
      }

      if (d.visible && d.alpha < 1.0) {
        _simDrivers[i] = d.copyWith(alpha: (d.alpha + 0.2).clamp(0.0, 1.0));
        changed = true;
      }

      if (!d.visible || now.isBefore(d.nextMove)) continue;

      final headingRad = d.heading * pi / 180;
      var newLat = d.lat + cos(headingRad) * d.speed;
      var newLng = d.lng + sin(headingRad) * d.speed;
      var newHeading = d.heading + (random.nextDouble() - 0.5) * 35;

      final distFromCenter = sqrt(
        pow(newLat - center.latitude, 2) + pow(newLng - center.longitude, 2),
      );
      if (distFromCenter > 0.005) {
        final angleToCenter = atan2(
          center.longitude - newLng, center.latitude - newLat,
        ) * 180 / pi;
        newHeading = angleToCenter + (random.nextDouble() - 0.5) * 30;
      }

      _simDrivers[i] = d.copyWith(
        lat: newLat,
        lng: newLng,
        heading: newHeading,
        nextMove: now.add(Duration(milliseconds: 1500 + random.nextInt(2000))),
      );
      changed = true;
    }

    if (changed) _syncSimDriverMarkers();
  }

  void _syncSimDriverMarkers() {
    if (!mounted || _cachedCarIcon == null) return;

    _markers.removeWhere((m) => m.markerId.value.startsWith('driver_sim_'));

    for (int i = 0; i < _simDrivers.length; i++) {
      final d = _simDrivers[i];
      if (d.alpha <= 0) continue;

      _markers.add(Marker(
        markerId: MarkerId('driver_sim_$i'),
        position: LatLng(d.lat, d.lng),
        icon: _cachedCarIcon!,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        rotation: d.heading,
        alpha: d.alpha,
        zIndex: 0,
      ));
    }

    setState(() {});
  }

  /// Inline search for destination (inDrive style - results in sheet, not overlay)
  void _onDestinationSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    if (query.isEmpty) {
      setState(() {
        _destinationSearchResults = [];
        _isSearchingPlaces = false;
      });
      return;
    }
    setState(() => _isSearchingPlaces = true);
    _searchDebounceTimer = Timer(Duration(milliseconds: 400), () async {
      if (!mounted) return;
      try {
        final locationBias = (_pickupCoordinates != null)
            ? '&location=${_pickupCoordinates!.latitude},${_pickupCoordinates!.longitude}&radius=5000'
            : '';
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&key=${AppConfig.googleMapsApiKey}'
          '&language=es'
          '&components=country:pe'
          '$locationBias',
        );
        final response = await http.get(url);
        if (!mounted) return;
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK') {
            final results = (data['predictions'] as List)
                .map((p) => PlacePrediction.fromJson(p))
                .toList();
            setState(() {
              _destinationSearchResults = results;
              _isSearchingPlaces = false;
            });
          } else {
            setState(() {
              _destinationSearchResults = [];
              _isSearchingPlaces = false;
            });
          }
        }
      } catch (e) {
        if (mounted) setState(() => _isSearchingPlaces = false);
      }
    });
  }

  Future<void> _selectSearchResult(PlacePrediction prediction) async {
    _destinationController.text = prediction.description;
    _inlineDestinationController.text = prediction.description;
    setState(() => _destinationSearchResults = []);

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${prediction.placeId}'
        '&key=${AppConfig.googleMapsApiKey}'
        '&fields=geometry,formatted_address,name',
      );
      final response = await http.get(url);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          final coords = LatLng(location['lat'].toDouble(), location['lng'].toDouble());
          setState(() => _destinationCoordinates = coords);
          await _addMarkerAndZoom(coords, 'destination_marker', false);

          if (_pickupCoordinates != null && _destinationCoordinates != null) {
            if (!_markers.any((m) => m.markerId.value == 'pickup_marker')) {
              await _addMarkerAndZoom(_pickupCoordinates!, 'pickup_marker', true);
            }
            await _updateRoutePolyline();
            if (!mounted) return;
            setState(() {
              _isSelectingLocation = false;
              _showPriceNegotiation = true;
              _markers.removeWhere((m) => m.markerId.value.startsWith('ref_dot'));
              _markers.removeWhere((m) => m.markerId.value.startsWith('sim_driver_'));
            });
            await _zoomToShowBothLocations();
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error getting place details: $e');
    }
  }

  void _onOriginSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    if (query.isEmpty) {
      setState(() {
        _originSearchResults = [];
        _isSearchingPlaces = false;
      });
      return;
    }
    setState(() => _isSearchingPlaces = true);
    _searchDebounceTimer = Timer(Duration(milliseconds: 400), () async {
      if (!mounted) return;
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&key=${AppConfig.googleMapsApiKey}'
          '&language=es'
          '&components=country:pe',
        );
        final response = await http.get(url);
        if (!mounted) return;
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK') {
            final results = (data['predictions'] as List)
                .map((p) => PlacePrediction.fromJson(p))
                .toList();
            setState(() {
              _originSearchResults = results;
              _isSearchingPlaces = false;
            });
          } else {
            setState(() {
              _originSearchResults = [];
              _isSearchingPlaces = false;
            });
          }
        }
      } catch (e) {
        if (mounted) setState(() => _isSearchingPlaces = false);
      }
    });
  }

  Future<void> _selectOriginResult(PlacePrediction prediction) async {
    _pickupController.text = prediction.description;
    setState(() {
      _originSearchResults = [];
      _isEditingOrigin = false;
    });

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${prediction.placeId}'
        '&key=${AppConfig.googleMapsApiKey}'
        '&fields=geometry,formatted_address,name',
      );
      final response = await http.get(url);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          final coords = LatLng(location['lat'].toDouble(), location['lng'].toDouble());
          setState(() => _pickupCoordinates = coords);
          await _addMarkerAndZoom(coords, 'pickup_marker', true);

          if (_pickupCoordinates != null && _destinationCoordinates != null) {
            await _updateRoutePolyline();
            if (!mounted) return;
            setState(() => _isSelectingLocation = false);
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error getting origin place details: $e');
    }
  }

  Future<void> _addMarkerAndZoom(LatLng position, String markerId, bool isPickup) async {
    final customIcon = isPickup
        ? await MapMarkerUtils.getOriginIcon()
        : await MapMarkerUtils.getDestinationIcon();

    final marker = Marker(
      markerId: MarkerId(markerId),
      position: position,
      icon: customIcon,
      anchor: const Offset(0.5, 0.5),
    );

    if (!mounted) return;
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == markerId);
      _markers.add(marker);
      _isSelectingLocation = true;
    });

    final hasBoth = _pickupCoordinates != null && _destinationCoordinates != null;
    if (_mapController != null && !hasBoth) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(position, _kZoomLevelMedium),
      );
      AppLogger.info('Zoom a ${isPickup ? "origen" : "destino"}: ${position.latitude}, ${position.longitude}');
    }
  }

  Future<void> _zoomToShowBothLocations() async {
    if (_pickupCoordinates == null || _destinationCoordinates == null) return;
    if (_mapController == null) return;

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || _mapController == null) return;

    double southWestLat = min(_pickupCoordinates!.latitude, _destinationCoordinates!.latitude);
    double southWestLng = min(_pickupCoordinates!.longitude, _destinationCoordinates!.longitude);
    double northEastLat = max(_pickupCoordinates!.latitude, _destinationCoordinates!.latitude);
    double northEastLng = max(_pickupCoordinates!.longitude, _destinationCoordinates!.longitude);

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );

    _isSnapping = true;
    _mapController!.moveCamera(
      CameraUpdate.newLatLngBounds(bounds, 60.0),
    );

    AppLogger.info('Zoom ajustado para mostrar origen y destino');
  }

  void _startNegotiation() async {
    AppLogger.info('🚀🚀🚀 BOTÓN BUSCAR CONDUCTOR PRESIONADO');

    if (_pickupController.text.isEmpty || _destinationController.text.isEmpty) {
      AppLogger.warning('❌ Origen o destino vacíos');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.enterOriginAndDestination),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      if (!mounted) return;

      setState(() {
        _isSearchingDriver = true;
      });
      AppLogger.info('🔍 Estado de búsqueda activado');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        AppLogger.error('❌ Usuario no autenticado');
        if (!mounted) return;
        setState(() => _isSearchingDriver = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.userNotAuthenticated),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      AppLogger.info('✅ Usuario autenticado: ${user.email}');

      if (!mounted) return;
      setState(() {
        _showPriceNegotiation = true;
        _markers.removeWhere((m) => m.markerId.value.startsWith('ref_dot'));
        _markers.removeWhere((m) => m.markerId.value.startsWith('sim_driver_'));
      });

      AppLogger.info('📍 Obteniendo ubicación GPS...');
      LatLng? currentLocation = await _getCurrentLocation();
      if (currentLocation == null) {
        AppLogger.error('❌ No se pudo obtener ubicación GPS');
        if (!mounted) return;
        setState(() => _isSearchingDriver = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.locationPermissionDenied),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      AppLogger.info('✅ Ubicación GPS: ${currentLocation.latitude}, ${currentLocation.longitude}');

      AppLogger.info('📍 Obteniendo ubicación de destino...');
      LatLng? destinationLocation = await _getDestinationLocation();
      if (destinationLocation == null) {
        AppLogger.error('❌ No se pudo obtener ubicación de destino');
        if (!mounted) return;
        setState(() => _isSearchingDriver = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo encontrar el destino'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      AppLogger.info('✅ Destino: ${destinationLocation.latitude}, ${destinationLocation.longitude}');

      AppLogger.info('🚕 Creando negociación InDrive...');

      if (!mounted) return;
      setState(() {
        _isWaitingForDriver = true;
        _showPriceNegotiation = false;
      });
      AppLogger.info('📺 Mostrando pantalla de espera de conductor');

      // Use PriceNegotiationProvider to create in 'negotiations' collection
      // This is what drivers poll for (not 'rides')
      final negotiationProvider = Provider.of<PriceNegotiationProvider>(context, listen: false);

      final pickup = models.LocationPoint(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        address: _pickupController.text.isEmpty ? 'Mi ubicación' : _pickupController.text,
        reference: null,
      );

      final destination = models.LocationPoint(
        latitude: destinationLocation.latitude,
        longitude: destinationLocation.longitude,
        address: _destinationController.text,
        reference: null,
      );

      // Map payment method string to enum
      models.PaymentMethod paymentMethodEnum;
      switch (_selectedPaymentMethod) {
        case 'card':
          paymentMethodEnum = models.PaymentMethod.card;
          break;
        case 'wallet':
          paymentMethodEnum = models.PaymentMethod.wallet;
          break;
        default:
          paymentMethodEnum = models.PaymentMethod.cash;
      }

      try {
        await negotiationProvider.createNegotiation(
          pickup: pickup,
          destination: destination,
          offeredPrice: _offeredPrice,
          paymentMethod: paymentMethodEnum,
          notes: null,
        );
        AppLogger.info('✅ Negociación creada exitosamente');
        // Start listening for real-time driver offers on this negotiation
        negotiationProvider.startListeningToMyNegotiations();
      } catch (e) {
        AppLogger.error('❌ Error creando negociación: $e');
        if (!mounted) return;
        setState(() {
          _isWaitingForDriver = false;
          _isSearchingDriver = false;
          _showPriceNegotiation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear solicitud: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      _currentRideId = null;
      AppLogger.info('📝 Negociación creada, esperando ofertas de conductores');

    } catch (e) {
      AppLogger.error('❌ Error en _startNegotiation: $e');
      if (!mounted) return;

      setState(() {
        _showPriceNegotiation = false;
        _isSearchingDriver = false;
        _isWaitingForDriver = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorRequestingTrip(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelPriceNegotiation() {
    AppLogger.info('Cancelando negociación de precio - limpiando estado');

    if (!mounted) return;
    setState(() {
      _showPriceNegotiation = false;
      _polylines.clear();
      _markers.clear();
      _pickupCoordinates = null;
      _destinationCoordinates = null;
      _pickupController.clear();
      _destinationController.clear();
      _priceController.clear();
      _isSelectingLocation = false;
      _isManualPriceEntry = false;
      _wasInPriceNegotiation = false;
      _calculatedDistance = null;
      _estimatedTime = null;
      _suggestedPrice = null;
      _offeredPrice = 15.0;
    });

    AppLogger.info('Estado reseteado completamente - usuario puede comenzar de nuevo');
  }

  void _simulateDriverOffers() {
    _negotiationTimer = Timer.periodic(Duration(seconds: 3), (timer) {
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
            driverPhoto: '',
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
    final rideProvider = Provider.of<RideProvider>(context, listen: false);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && rideProvider.hasActiveTrip) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No puedes salir mientras tienes un viaje activo'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
      child: Scaffold(
      appBar: null,
      drawer: PassengerDrawer(
        onFavoriteSelected: (address, lat, lng) {
          setState(() {
            _destinationController.text = address;
            _destinationCoordinates = LatLng(lat, lng);
          });
        },
      ),
      body: GestureDetector(
        onTap: _hideKeyboard,
        child: Stack(
          children: [
            GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(-12.0851, -76.9770),
              zoom: 17,
            ),
            padding: EdgeInsets.only(
              bottom: _showPriceNegotiation
                  ? MediaQuery.of(context).size.height * 0.62
                  : 280,
              top: _showPriceNegotiation ? 120 : 0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (_) => _hideKeyboard(),
            onCameraMoveStarted: () {
              if (_isSnapping) return;
              if (_showPriceNegotiation) return;
              if (!_isSelectingLocation) {
                setState(() => _isCameraMoving = true);
                if (_sheetController.isAttached) {
                  _sheetController.animateTo(0.12, duration: Duration(milliseconds: 250), curve: Curves.easeOut);
                }
              }
            },
            onCameraMove: (position) {
              _lastCameraTarget = position.target;
              if (_showPriceNegotiation) return;
              if (_isCameraMoving && !_isSelectingLocation) {
                _updateActiveRefDot(position.target);
              }
            },
            onCameraIdle: () async {
              if (_isSnapping) {
                _isSnapping = false;
                return;
              }
              if (_showPriceNegotiation) return;
              if (!_isSelectingLocation) {
                final wasDragging = _isCameraMoving;
                setState(() => _isCameraMoving = false);
                if (_sheetController.isAttached && _sheetController.size < 0.5) {
                  _sheetController.animateTo(0.68, duration: Duration(milliseconds: 300), curve: Curves.easeOut);
                }
                if (wasDragging && _mapController != null && _lastCameraTarget != null) {
                  LatLng? greenDotPos;
                  if (_activeRefDotIndex >= 0 && _activeRefDotIndex < _refDotPositions.length) {
                    greenDotPos = _refDotPositions[_activeRefDotIndex];
                  }
                  final dotCenter = greenDotPos ?? _lastCameraTarget!;
                  await _addReferencePointDots(dotCenter);
                  if (_shouldRegenerateMarkers(dotCenter)) {
                    _markers.removeWhere((m) => m.markerId.value.startsWith('sim_driver_'));
                    await _addSimulatedDriverMarkers(dotCenter);
                  }
                  if (greenDotPos != null) {
                    _isSnapping = true;
                    _lastCameraTarget = greenDotPos;
                    _markers.add(Marker(
                      markerId: const MarkerId('ref_dot_snapped'),
                      position: greenDotPos,
                      icon: _refDotActiveIcon!,
                      anchor: const Offset(0.5, 0.5),
                      zIndex: 3,
                    ));
                    if (mounted) setState(() {});
                    await _mapController!.animateCamera(CameraUpdate.newLatLng(greenDotPos));
                    Future.delayed(const Duration(seconds: 2), () {
                      if (_isSnapping && mounted) _isSnapping = false;
                    });
                  }
                  _reverseGeocodeMapCenter();
                }
              }
            },
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
            minMaxZoomPreference: MinMaxZoomPreference(10, 20),
          ),

          if (_isWaitingForDriver && false)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),

          if (!_isSelectingLocation &&
              !_markers.any((m) => m.markerId.value == 'pickup_marker'))
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 324),
                child: Icon(
                  Icons.location_on,
                  size: 44,
                  color: Colors.black87,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),

          if (!(_isWaitingForDriver && false))
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildInDriveMenuButton(),
                    const Spacer(),
                    _buildInDriveNotificationButton(),
                  ],
                ),
              ),
            ),

          if (_showPriceNegotiation && !_isWaitingForDriver && !_showDriverOffers)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: _buildRouteAddressCard(),
            ),

          if (_showPriceNegotiation && !_isWaitingForDriver && !_showDriverOffers)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              left: 12,
              child: GestureDetector(
                onTap: _cancelPriceNegotiation,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.arrow_back, size: 20, color: AppColors.getTextPrimary(context)),
                ),
              ),
            ),

          Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: (_isWaitingForDriver && false)
                  ? MediaQuery.of(context).padding.top
                  : null,
              child: SizedBox(
                height: (_isWaitingForDriver && false)
                    ? null
                    : MediaQuery.of(context).size.height * (_isSelectingLocation ? 0.95 : 0.85),
                child: AnimatedBuilder(
                  animation: _bottomSheetAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 400 * (1 - _bottomSheetAnimation.value)),
                      child: _isWaitingForDriver
                          ? Consumer2<RideProvider, PriceNegotiationProvider>(
                              builder: (context, rp, negotiationProvider, child) {
                                final driverOffers = negotiationProvider.currentNegotiation?.driverOffers
                                    .where((o) => o.status == models.OfferStatus.pending)
                                    .toList() ?? [];
                                final hasOffers = driverOffers.isNotEmpty;
                                return Align(
                                  alignment: hasOffers ? Alignment.topCenter : Alignment.bottomCenter,
                                  child: child!,
                                );
                              },
                              child: SearchingDriversSheet(
                              pickupAddress: _pickupController.text,
                              destinationAddress: _destinationController.text,
                              offeredPrice: _offeredPrice,
                              suggestedPrice: _suggestedPrice ?? 15.0,
                              minPrice: ((_suggestedPrice ?? 15.0) * 0.5).ceilToDouble().clamp(3.0, _suggestedPrice ?? 15.0),
                              maxPrice: ((_suggestedPrice ?? 15.0) * 3.0).floorToDouble(),
                              selectedPaymentMethod: _selectedPaymentMethod,
                              onPriceChanged: (price) {
                                setState(() => _offeredPrice = price);
                                final rid = _currentRideId;
                                if (rid != null) {
                                  FirebaseFirestore.instance.collection('rides').doc(rid).update({
                                    'offeredFare': price,
                                  });
                                }
                              },
                              onRenewSearch: (newPrice) async {
                                // TODO: implement renewSearch in RideProvider
                                final renewed = false;
                                if (!renewed) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Tiempo máximo de búsqueda alcanzado (10 min). Intenta solicitar otro viaje.'),
                                        backgroundColor: Colors.orange,
                                        duration: Duration(seconds: 4),
                                      ),
                                    );
                                    setState(() {
                                      _isWaitingForDriver = false;
                                      _isSearchingDriver = false;
                                      _showDriverOffers = false;
                                      _currentRideId = null;
                                    });
                                  }
                                  return;
                                }
                                if (newPrice != null) {
                                  setState(() => _offeredPrice = newPrice);
                                }
                              },
                              onCancel: _cancelWaitingForDriver,
                              onAcceptOffer: (offer) => _acceptDriverOffer(offer, Provider.of<RideProvider>(context, listen: false)),
                              onRejectOffer: (offer) => _rejectDriverOffer(offer, Provider.of<RideProvider>(context, listen: false)),
                              onCounterOffer: (offer) => _showCounterOfferDialog(offer, Provider.of<RideProvider>(context, listen: false)),
                              onGoToTracking: (trip) {
                                setState(() { _isWaitingForDriver = false; });
                                Navigator.pushNamed(context, '/passenger/tracking', arguments: trip.id);
                              },
                            ),
                          )
                          : _showDriverOffers
                              ? _buildDriverOffersSheet()
                              : _showPriceNegotiation
                                  ? PriceSettingSheet(
                                      calculatedDistance: _calculatedDistance,
                                      estimatedTime: _estimatedTime,
                                      suggestedPrice: _suggestedPrice,
                                      offeredPrice: _offeredPrice,
                                      selectedPaymentMethod: _selectedPaymentMethod,
                                      isSearchingDriver: _isSearchingDriver,
                                      selectedServiceType: _selectedServiceType.name,
                                      pickupAddress: _pickupController.text,
                                      destinationAddress: _destinationController.text,
                                      onBack: _cancelPriceNegotiation,
                                      onSearchDriver: _startNegotiation,
                                      onPriceChanged: (price) {
                                        setState(() {
                                          _offeredPrice = price;
                                          _priceController.text = price.toStringAsFixed(2);
                                        });
                                      },
                                      onPaymentMethodChanged: (method) {
                                        setState(() => _selectedPaymentMethod = method);
                                      },
                                      onServiceTypeChanged: (type) {
                                        setState(() {
                                          _selectedServiceType = ServiceType.values.firstWhere(
                                            (e) => e.name == type,
                                            orElse: () => ServiceType.viaje,
                                          );
                                          const multipliers = {
                                            'viaje': 1.0,
                                            'mototaxi': 0.75,
                                            'entregas': 0.85,
                                          };
                                          final mult = multipliers[type] ?? 1.0;
                                          final base = _suggestedPrice ?? 15.0;
                                          _offeredPrice = (base * mult).roundToDouble();
                                          _priceController.text = _offeredPrice.toStringAsFixed(2);
                                        });
                                      },
                                    )
                                  : _buildDestinationSheet(),
                    );
                  },
                ),
              ),
            ),


          if (!_isSelectingLocation && !_showPriceNegotiation &&
              !(_isWaitingForDriver && false))
            Positioned(
              right: 12,
              bottom: MediaQuery.of(context).size.height * 0.60,
              child: _buildLocationButton(),
            ),
        ],
      ),
      ),
      ),
    );
  }
  
  Widget _buildAddressField({
    required TextEditingController controller,
    required String hintText,
    required Color markerColor,
    required bool isPickup,
  }) {
    return CustomPlaceTextField(
      controller: controller,
      hintText: hintText,
      googleApiKey: AppConfig.googleMapsApiKey,
      onTap: () {
        if (mounted) {
          setState(() {
            _isSelectingLocation = true;
          });
          AppLogger.info('Usuario tocó campo ${isPickup ? "origen" : "destino"} - UI ocultada');
        }
      },
      onPlaceSelected: (PlacePrediction prediction) async {
        if (prediction.lat != null && prediction.lng != null) {
          final coords = LatLng(prediction.lat!, prediction.lng!);

          if (!mounted) return;
          setState(() {
            if (isPickup) {
              _pickupCoordinates = coords;
            } else {
              _destinationCoordinates = coords;
            }

            if (!isPickup) {
              _isSearchingDestination = true;
            }
          });

          AppLogger.info('${isPickup ? "Pickup" : "Destination"} coordinates guardadas: ${coords.latitude}, ${coords.longitude}');

          await _addMarkerAndZoom(
            coords,
            isPickup ? 'pickup_marker' : 'destination_marker',
            isPickup,
          );

          if (_pickupCoordinates != null && _destinationCoordinates != null) {
            if (!isPickup && !_markers.any((m) => m.markerId.value == 'pickup_marker')) {
              await _addMarkerAndZoom(_pickupCoordinates!, 'pickup_marker', true);
            }
            await _updateRoutePolyline();
            if (!mounted) return;
            setState(() {
              _isSelectingLocation = false;
              _showPriceNegotiation = true;
              _markers.removeWhere((m) => m.markerId.value.startsWith('ref_dot'));
              _markers.removeWhere((m) => m.markerId.value.startsWith('sim_driver_'));
            });
            await _zoomToShowBothLocations();
          }
        }
      },
    );
  }

  // ============================================================================
  // WIDGETS ESTILO INDRIVE - Botones flotantes y UI minimalista
  // ============================================================================

  Widget _buildInDriveMenuButton() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Builder(
        builder: (context) => Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Icon(Icons.menu, color: AppColors.getTextPrimary(context), size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildInDriveNotificationButton() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.pushNamed(context, '/shared/notifications'),
          child: Icon(Icons.notifications_outlined, color: AppColors.getTextPrimary(context), size: 22),
        ),
      ),
    );
  }

  Widget _buildRouteAddressCard() {
    final pickupText = _pickupController.text.isNotEmpty
        ? _pickupController.text
        : 'Mi ubicación actual';
    final destText = _destinationController.text;
    final timeText = _estimatedTime != null ? ' ~$_estimatedTime min.' : '';

    return GestureDetector(
      onTap: () {
        setState(() {
          _wasInPriceNegotiation = true;
          _showPriceNegotiation = false;
          _isSelectingLocation = true;
        });
      },
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pickupText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Portal',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE53935), width: 2.5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$destText$timeText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add, size: 18, color: AppColors.getTextPrimary(context)),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildInDriveAddressFields() {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Introduce tu ruta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _isSelectingLocation = false;
                  if (_wasInPriceNegotiation) {
                    _wasInPriceNegotiation = false;
                    _showPriceNegotiation = true;
                  }
                }),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.getInputFill(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 20, color: AppColors.getTextPrimary(context)),
                ),
              ),
            ],
          ),
        ),

        GestureDetector(
          onTap: () => setState(() => _isEditingOrigin = true),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.getInputFill(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isEditingOrigin
              ? Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green.shade700, width: 2),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _pickupController,
                        autofocus: true,
                        onChanged: _onOriginSearchChanged,
                        decoration: InputDecoration(
                          hintText: l10n.whereAreYou,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          suffixIcon: _pickupController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _pickupController.clear();
                                    _onOriginSearchChanged('');
                                  },
                                )
                              : null,
                        ),
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.my_location, color: AppColors.rappiOrange, size: 22),
                      constraints: BoxConstraints(),
                      padding: EdgeInsets.only(left: 8),
                      onPressed: () async {
                        _pickupController.text = 'Obteniendo ubicación...';
                        final currentLocation = await _getCurrentLocation();
                        if (currentLocation != null && mounted) {
                          final address = await _reverseGeocode(currentLocation);
                          if (!mounted) return;
                          setState(() {
                            _pickupCoordinates = currentLocation;
                            _pickupController.text = address ?? 'Mi ubicación actual';
                            _isEditingOrigin = false;
                          });
                          _addMarkerAndZoom(currentLocation, 'pickup_marker', true);
                        } else if (mounted) {
                          setState(() => _pickupController.text = '');
                        }
                      },
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green.shade700, width: 2),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'De',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            _pickupController.text.isEmpty
                              ? 'Obteniendo ubicación...'
                              : _pickupController.text,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.getTextPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          ),
        ),

        SizedBox(height: 10),

        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.getInputFill(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.rappiOrange.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: AppColors.getTextSecondary(context), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'A',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                    TextField(
                      controller: _inlineDestinationController,
                      autofocus: true,
                      onChanged: _onDestinationSearchChanged,
                      decoration: InputDecoration(
                        hintText: l10n.whereAreYouGoing,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        suffixIcon: _inlineDestinationController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _inlineDestinationController.clear();
                                  _onDestinationSearchChanged('');
                                },
                              )
                            : null,
                      ),
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Could open map picker
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.my_location, color: Colors.blue, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsTabs() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildSearchTab('Resultados de la búsqueda', 0),
              SizedBox(width: 8),
              _buildSearchTab('Sugerida', 1),
              SizedBox(width: 8),
              _buildSearchTab('Guardada', 2),
            ],
          ),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSearchTab(String label, int index) {
    final isActive = _searchTab == index;
    return GestureDetector(
      onTap: () => setState(() => _searchTab = index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.getTextPrimary(context) : AppColors.getInputFill(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? AppColors.getSurface(context) : AppColors.getTextSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineSearchResult(PlacePrediction prediction, {VoidCallback? onTap}) {
    // Distance text not available in this version of PlacePrediction
    const String? distanceText = null;

    return InkWell(
      onTap: onTap ?? () => _selectSearchResult(prediction),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, color: AppColors.getTextSecondary(context), size: 24),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prediction.mainText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  if (prediction.secondaryText.isNotEmpty)
                    Text(
                      prediction.secondaryText,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (distanceText != null) ...[
              SizedBox(width: 8),
              Text(
                distanceText,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ],
            SizedBox(width: 8),
            Icon(Icons.bookmark_outline, color: AppColors.getTextSecondary(context), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildOriginFieldCollapsed(AppLocalizations l10n) {
    return GestureDetector(
      onTap: () {
        setState(() => _isEditingOrigin = true);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.rappiOrange,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.rappiOrangeDark, width: 2),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _pickupController.text.isEmpty
                  ? 'Obteniendo ubicación...'
                  : _pickupController.text,
                style: TextStyle(
                  fontSize: 14,
                  color: _pickupController.text.isEmpty
                    ? AppColors.getTextSecondary(context)
                    : AppColors.getTextPrimary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.edit_outlined,
              size: 18,
              color: AppColors.getTextSecondary(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOriginFieldExpanded(AppLocalizations l10n) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.rappiOrange,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.rappiOrangeDark, width: 2),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildAddressField(
            controller: _pickupController,
            hintText: l10n.whereAreYou,
            markerColor: AppColors.rappiOrange,
            isPickup: true,
          ),
        ),
        IconButton(
          icon: Icon(Icons.my_location, color: AppColors.rappiOrange),
          onPressed: () async {
            _pickupController.text = 'Obteniendo ubicación...';
            final currentLocation = await _getCurrentLocation();
            if (currentLocation != null && mounted) {
              final address = await _reverseGeocode(currentLocation);
              if (!mounted) return;
              setState(() {
                _pickupCoordinates = currentLocation;
                _pickupController.text = address ?? 'Mi ubicación actual';
                _isEditingOrigin = false;
              });
              _addMarkerAndZoom(currentLocation, 'pickup_marker', true);
            } else if (mounted) {
              setState(() => _pickupController.text = '');
            }
          },
        ),
        IconButton(
          icon: Icon(Icons.check, color: AppColors.rappiOrange),
          onPressed: () {
            setState(() => _isEditingOrigin = false);
          },
        ),
      ],
    );
  }

  Widget _buildInDriveServiceSelector() {
    const services = <(ServiceType, String, String, IconData)>[
      (ServiceType.viaje, 'Viaje', 'assets/images/vehicles/sedan.png', Icons.local_taxi),
      (ServiceType.mototaxi, 'Mototaxi', 'assets/images/vehicles/mototaxi.png', Icons.two_wheeler),
      (ServiceType.entregas, 'Entregas', 'assets/images/vehicles/van_entregas.png', Icons.inventory_2),
      (ServiceType.ciudadACiudad, 'Ciudad a Ciudad', 'assets/images/vehicles/suv_interurbano.png', Icons.route),
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12),
        itemCount: services.length,
        itemBuilder: (context, index) {
          final (type, label, asset, fallbackIcon) = services[index];
          final isSelected = _selectedServiceType == type;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedServiceType = type);
              _showServiceDetailsIfNeeded(type);
            },
            child: Container(
              width: 90,
              margin: EdgeInsets.symmetric(horizontal: 4),
              padding: EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.rappiOrange.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? Border.all(color: AppColors.rappiOrange, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Image.asset(
                      asset,
                      errorBuilder: (_, __, ___) => Icon(
                        fallbackIcon,
                        size: 36,
                        color: isSelected ? AppColors.rappiOrange : AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.rappiOrange : AppColors.getTextPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(_kBorderRadiusLarge),
        boxShadow: AppColors.getCardShadow(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: _kPaddingHorizontal20Vertical8,
            child: Row(
              children: [
                Container(
                  width: _kMarkerCircleSize,
                  height: _kMarkerCircleSize,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: _kSpacingMedium),
                Expanded(
                  child: _buildAddressField(
                    controller: _pickupController,
                    hintText: AppLocalizations.of(context)!.whereAreYou,
                    markerColor: AppColors.success,
                    isPickup: true,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.my_location, color: AppColors.rappiOrange),
                  onPressed: () async {
                    _pickupController.text = 'Obteniendo ubicación...';

                    final currentLocation = await _getCurrentLocation();
                    if (currentLocation != null && mounted) {
                      final address = await _reverseGeocode(currentLocation);

                      if (!mounted) return;
                      setState(() {
                        _pickupCoordinates = currentLocation;
                        _pickupController.text = address ?? 'Mi ubicación actual';
                      });
                      _addMarkerAndZoom(currentLocation, 'pickup_marker', true);

                      AppLogger.info('Ubicación GPS con dirección: $address');
                    } else {
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
          
          Container(
            padding: _kPaddingHorizontal20Vertical8,
            child: Row(
              children: [
                Container(
                  width: _kMarkerCircleSize,
                  height: _kMarkerCircleSize,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: _kSpacingMedium),
                Expanded(
                  child: _buildAddressField(
                    controller: _destinationController,
                    hintText: AppLocalizations.of(context)!.whereAreYouGoing,
                    markerColor: AppColors.error,
                    isPickup: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDestinationSheet() {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final double sheetInitial = _isSelectingLocation
        ? 0.92
        : 0.68;
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (_wasInPriceNegotiation && notification.extent <= 0.13) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _isSelectingLocation = false;
              _wasInPriceNegotiation = false;
              _showPriceNegotiation = true;
            });
          });
        }
        return false;
      },
      child: DraggableScrollableSheet(
      key: ValueKey('dest_sheet_${_isSelectingLocation}_$_wasInPriceNegotiation'),
      controller: _sheetController.isAttached ? null : _sheetController,
      initialChildSize: sheetInitial,
      minChildSize: 0.12,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.12, 0.68, 0.95],
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    margin: EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.getBorder(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              if (!_isSelectingLocation)
                SliverToBoxAdapter(child: _buildInDriveServiceSelector()),

              if (!_isSelectingLocation)
                SliverToBoxAdapter(child: SizedBox(height: 8)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _isSelectingLocation
                      ? _buildInDriveAddressFields()
                      : _buildInDriveSearchBar(),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 12)),

              if (_isSelectingLocation && (_destinationSearchResults.isNotEmpty || _originSearchResults.isNotEmpty || _isSearchingPlaces))
                SliverToBoxAdapter(
                  child: _buildSearchResultsTabs(),
                ),

              if (_isSelectingLocation && _isSearchingPlaces)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rappiOrange),
                      ),
                    ),
                  ),
                ),

              if (_isSelectingLocation && _isEditingOrigin && _originSearchResults.isNotEmpty && !_isSearchingPlaces)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildInlineSearchResult(
                      _originSearchResults[index],
                      onTap: () => _selectOriginResult(_originSearchResults[index]),
                    ),
                    childCount: _originSearchResults.length,
                  ),
                ),

              if (_isSelectingLocation && !_isEditingOrigin && _destinationSearchResults.isNotEmpty && !_isSearchingPlaces)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildInlineSearchResult(_destinationSearchResults[index]),
                    childCount: _destinationSearchResults.length,
                  ),
                ),

              if (!_isSelectingLocation)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_loadingPlaces)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.rappiOrange,
                                ),
                              ),
                            ),
                          )
                        else if (_recentPlaces.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Aún no tienes viajes recientes',
                              style: TextStyle(
                                color: AppColors.getTextSecondary(context),
                                fontSize: 14,
                              ),
                            ),
                          )
                        else
                          ..._recentPlaces.map((place) => _buildRecentPlace(
                            place['address'] as String,
                            place['subtitle'] as String,
                            lat: place['lat'] as double?,
                            lng: place['lng'] as double?,
                          )),
                      ],
                    ),
                  ),
                ),

              if (isKeyboardOpen)
                SliverToBoxAdapter(
                  child: SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ),
            ],
          ),
        );
      },
    ),
    );
  }

  Widget _buildInDriveSearchBar() {
    return GestureDetector(
      onTap: () {
        setState(() => _isSelectingLocation = true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.getInputFill(context),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: AppColors.getTextSecondary(context), size: 24),
            const SizedBox(width: 12),
            Text(
              '¿A dónde y por cuánto?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceNegotiationSheet() {
    String distanceTimeText = 'Calculando ruta...';
    String suggestedPriceText = 'Calculando precio...';

    if (_calculatedDistance != null && _estimatedTime != null && _suggestedPrice != null) {
      distanceTimeText = '${_calculatedDistance!.toStringAsFixed(1)} km • $_estimatedTime min';
      suggestedPriceText = 'Precio sugerido: ${_suggestedPrice!.toCurrency()}';
    } else if (_pickupCoordinates != null && _destinationCoordinates != null) {
      final distance = _calculateDistance(_pickupCoordinates!, _destinationCoordinates!);
      final time = _estimateTime(distance);
      final price = _calculatePrice(distance);

      distanceTimeText = '${distance.toStringAsFixed(1)} km • $time min';
      suggestedPriceText = 'Precio sugerido: ${price.toCurrency()}';
    }

    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        _hideKeyboard();
        if (mounted) {
          setState(() => _isManualPriceEntry = false);
        }
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(_kBorderRadiusXLarge)),
            boxShadow: AppColors.getCardShadow(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 8),
                width: _kHandleWidth,
                height: _kHandleHeight,
                decoration: BoxDecoration(
                  color: AppColors.getBorder(context),
                  borderRadius: BorderRadius.circular(_kBorderRadiusTiny),
                ),
              ),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimary(context)),
                      onPressed: _cancelPriceNegotiation,
                      tooltip: 'Volver',
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Ofrece tu precio',
                          style: TextStyle(
                            fontSize: _kFontSizeXLarge,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
              ),

              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _hideKeyboard();
                    if (!mounted) return;
                    setState(() => _isManualPriceEntry = false);
                  },
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Column(
                        children: [
                        Text(
                          'Los conductores cercanos verán tu oferta',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        SizedBox(height: 10),

                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.getInputFill(context),
                            borderRadius: BorderRadius.circular(_kBorderRadiusMedium),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.route, color: AppColors.rappiOrange),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      distanceTimeText,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      suggestedPriceText,
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),

                        Text(
                          'Selecciona tu precio',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        SizedBox(height: 6),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildPriceSuggestionButton((_suggestedPrice ?? 15.0) * 0.9),
                            _buildPriceSuggestionButton(_suggestedPrice ?? 15.0),
                            _buildPriceSuggestionButton((_suggestedPrice ?? 15.0) * 1.1),
                            _buildPriceSuggestionButton((_suggestedPrice ?? 15.0) * 1.2),
                          ],
                        ),
                        SizedBox(height: 8),

                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.getInputFill(context),
                            borderRadius: BorderRadius.circular(_kBorderRadiusSmall),
                            border: Border.all(
                              color: _isManualPriceEntry ? AppColors.rappiOrange : AppColors.getBorder(context),
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
                                  color: AppColors.getTextPrimary(context),
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
                                    color: AppColors.rappiOrange,
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
                                    _hideKeyboard();
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
                        SizedBox(height: 10),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildPaymentChip(Icons.payments_outlined, 'Efectivo', _selectedPaymentMethod == 'Efectivo', Color(0xFF4CAF50)),
                            _buildPaymentChip(null, 'Yape', _selectedPaymentMethod == 'Yape', Color(0xFF6B2D8B), isYape: true),
                            _buildPaymentChip(null, 'Plin', _selectedPaymentMethod == 'Plin', Color(0xFF00BFA5), isPlin: true),
                            _buildPaymentChip(Icons.credit_card, 'Tarjeta', _selectedPaymentMethod == 'Tarjeta', Color(0xFF1976D2)),
                            _buildPaymentChip(Icons.account_balance_wallet, 'Billetera', _selectedPaymentMethod == 'Billetera', Color(0xFFFF9800)),
                          ],
                        ),
                        SizedBox(height: 10),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isSearchingDriver ? null : () {
                              AppLogger.info('🚀🚀🚀 BOTÓN BUSCAR CONDUCTOR PRESIONADO (ElevatedButton)');
                              _startNegotiation();
                            },
                            icon: _isSearchingDriver
                                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Icon(Icons.search, color: Colors.white),
                            label: Text(
                              _isSearchingDriver ? 'Buscando...' : 'Buscar conductor',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.rappiOrange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
    ),
    );
  }

  Widget _buildWaitingForDriverSheet() {
    return Consumer<RideProvider>(
      builder: (context, rideProvider, _) {
        final offers = <Map<String, dynamic>>[];
        final hasOffers = offers.isNotEmpty;
        final currentTrip = rideProvider.currentTrip;
        final hasDirectAcceptance = currentTrip?.status == 'accepted' &&
            currentTrip?.driverId != null &&
            !hasOffers;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: AppColors.getCardShadow(),
          ),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: EdgeInsets.only(bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getBorder(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                if (hasDirectAcceptance) ...[
                  _buildAcceptedDriverCard(currentTrip!, rideProvider),
                ] else if (hasOffers) ...[
                  Row(
                    children: [
                      Icon(Icons.local_offer, color: Colors.green, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Ofertas de conductores',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${offers.length}',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: offers.length,
                      itemBuilder: (context, index) {
                        final offer = offers[index];
                        return _buildRealTimeDriverOfferCard(offer, rideProvider);
                      },
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.8, end: 1.2),
                          duration: Duration(milliseconds: 1000),
                          curve: Curves.easeInOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.rappiOrange.withValues(alpha: 0.2),
                                ),
                              ),
                            );
                          },
                          onEnd: () {
                            if (mounted && _isWaitingForDriver) {
                              setState(() {});
                            }
                          },
                        ),
                        Icon(
                          Icons.local_taxi,
                          size: 50,
                          color: AppColors.rappiOrange,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  Text(
                    'Buscando conductor',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),

                  SizedBox(height: 12),

                  Text(
                    'Notificando conductores cercanos...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextSecondary(context),
                      height: 1.5,
                    ),
                  ),

                  SizedBox(height: 8),

                  LinearProgressIndicator(
                    backgroundColor: AppColors.getInputFill(context),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.rappiOrange),
                  ),
                ],

                SizedBox(height: 24),

                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.getInputFill(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.circle, size: 12, color: Colors.green),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _pickupController.text.isNotEmpty
                                ? _pickupController.text
                                : 'Mi ubicación',
                              style: TextStyle(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 5),
                        child: Container(
                          width: 2,
                          height: 20,
                          color: AppColors.getBorder(context),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 12, color: AppColors.rappiOrange),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _destinationController.text,
                              style: TextStyle(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _cancelWaitingForDriver,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Cancelar búsqueda',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAcceptedDriverCard(dynamic trip, RideProvider rideProvider) {
    final vehicleInfo = trip.vehicleInfo as Map<String, dynamic>?;
    final driverName = vehicleInfo?['driverName'] ?? 'Conductor';
    final driverPhoto = vehicleInfo?['driverPhoto'] as String?;
    final plate = vehicleInfo?['plate'] ?? '';
    final model = vehicleInfo?['model'] ?? '';
    final brand = vehicleInfo?['brand'] ?? '';
    final acceptedPrice = trip.finalFare ?? 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, color: Colors.green, size: 48),
        SizedBox(height: 12),
        Text(
          'Viaje aceptado',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getInputFill(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.rappiOrange.withValues(alpha: 0.1),
                backgroundImage: driverPhoto != null && driverPhoto.isNotEmpty
                    ? NetworkImage(driverPhoto)
                    : null,
                child: driverPhoto == null || driverPhoto.isEmpty
                    ? Icon(Icons.person, size: 28, color: AppColors.rappiOrange)
                    : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    if (model.isNotEmpty || brand.isNotEmpty)
                      Text(
                        '$brand $model'.trim(),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    if (plate.isNotEmpty)
                      Text(
                        plate,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                  ],
                ),
              ),
              if (acceptedPrice > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'S/ ${acceptedPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() { _isWaitingForDriver = false; });
              Navigator.pushNamed(
                context,
                '/passenger/tracking',
                arguments: trip.id,
              );
            },
            icon: Icon(Icons.navigation),
            label: Text('Ir a Tracking'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rappiOrange,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRealTimeDriverOfferCard(Map<String, dynamic> offer, RideProvider rideProvider) {
    final driverName = offer['driverName'] ?? 'Conductor';
    final driverPhoto = offer['driverPhoto'] as String?;
    final offeredPrice = (offer['offeredPrice'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getInputFill(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.rappiOrange.withValues(alpha: 0.2),
                backgroundImage: driverPhoto != null && driverPhoto.isNotEmpty
                    ? NetworkImage(driverPhoto)
                    : null,
                child: driverPhoto == null || driverPhoto.isEmpty
                    ? Icon(Icons.person, color: AppColors.rappiOrange)
                    : null,
              ),
              SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'S/ ${offeredPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _rejectDriverOffer(offer, rideProvider),
                    icon: Icon(Icons.close, color: Colors.red),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      minimumSize: Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                    tooltip: 'Rechazar',
                  ),
                  SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _showCounterOfferDialog(offer, rideProvider),
                    icon: Icon(Icons.edit, size: 16),
                    label: Text('Ofertar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size(0, 36),
                      textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _acceptDriverOffer(offer, rideProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Aceptar S/${offeredPrice.toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _acceptDriverOffer(Map<String, dynamic> offer, RideProvider rideProvider) async {
    final negotiationProvider = Provider.of<PriceNegotiationProvider>(context, listen: false);
    final negotiation = negotiationProvider.currentNegotiation;
    final driverId = offer['driverId'] as String? ?? '';

    if (negotiation == null || driverId.isEmpty) {
      AppLogger.error('Cannot accept offer: no active negotiation or missing driverId');
      return;
    }

    try {
      final rideId = await negotiationProvider.acceptDriverOffer(negotiation.id, driverId);

      if (rideId != null && mounted) {
        setState(() {
          _isWaitingForDriver = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viaje aceptado'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushNamed(
          context,
          '/passenger/tracking',
          arguments: rideId,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al aceptar la oferta. Intenta de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error accepting driver offer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectDriverOffer(Map<String, dynamic> offer, RideProvider rideProvider) async {
    final negotiationProvider = Provider.of<PriceNegotiationProvider>(context, listen: false);
    final negotiation = negotiationProvider.currentNegotiation;
    final driverId = offer['driverId'] as String? ?? '';

    if (negotiation == null || driverId.isEmpty) {
      AppLogger.error('Cannot reject offer: no active negotiation or missing driverId');
      return;
    }

    try {
      await negotiationProvider.rejectDriverOffer(negotiation.id, driverId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oferta rechazada'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error rejecting driver offer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al rechazar oferta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCounterOfferDialog(Map<String, dynamic> offer, RideProvider rideProvider) {
    final currentPrice = (offer['offeredPrice'] as num?)?.toDouble() ?? 0.0;
    final counterPriceController = TextEditingController(text: currentPrice.toStringAsFixed(0));
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Contraoferta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Oferta actual: S/ ${currentPrice.toStringAsFixed(2)}'),
              SizedBox(height: 16),
              TextField(
                controller: counterPriceController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Tu oferta',
                  prefixText: 'S/ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              // Send counter-offer
              const success = true;

              if (mounted) {
                if (success) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Contraoferta enviada al conductor'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error al enviar contraoferta. Intenta de nuevo.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text('Enviar'),
          ),
        ],
      ),
    ).then((_) => counterPriceController.dispose());
  }

  Future<void> _cancelWaitingForDriver() async {
    AppLogger.info('❌ Usuario canceló la búsqueda de conductor (rideId: $_currentRideId)');

    if (!mounted) return;

    _isCancelling = true;

    // Stop listening for negotiation updates
    final negotiationProvider = Provider.of<PriceNegotiationProvider>(context, listen: false);
    negotiationProvider.stopPassengerListeners();

    // Cancel the negotiation in Firestore if there is an active one
    final currentNegotiation = negotiationProvider.currentNegotiation;
    if (currentNegotiation != null) {
      try {
        await FirebaseFirestore.instance
            .collection('negotiations')
            .doc(currentNegotiation.id)
            .update({'status': 'cancelled'});
        AppLogger.info('🗑️ Negotiation ${currentNegotiation.id} cancelled in Firestore');
      } catch (e) {
        AppLogger.error('Error cancelling negotiation: $e');
      }
    }

    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final cancelled = await rideProvider.cancelRide();
    AppLogger.info('🗑️ cancelRide result: $cancelled');

    if (!mounted) return;

    setState(() {
      _isWaitingForDriver = false;
      _isSearchingDriver = false;
      _showDriverOffers = false;
      _showPriceNegotiation = true;
      _currentRideId = null;
      _isCancelling = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Búsqueda cancelada'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildDriverOffersSheet() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: AppColors.getCardShadow(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.getBorder(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
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
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${(_currentNegotiation?.driverOffers.length ?? 0)} conductores interesados',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(_kBorderRadiusLarge),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: AppColors.warning),
                      SizedBox(width: 4),
                      Text(
                        '${_currentNegotiation?.timeRemaining.inMinutes ?? 0}:${(_currentNegotiation?.timeRemaining.inSeconds ?? 0) % 60}',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
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
      onTap: () {
        _showDriverAcceptedDialog(offer);
      },
      borderRadius: 16,
      child: Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(offer.driverPhoto),
            ),
            SizedBox(width: 12),
            
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
                      Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                      Text(
                        offer.driverRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${offer.vehicleModel} • ${offer.vehicleColor}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14, color: AppColors.info),
                      SizedBox(width: 4),
                      Text(
                        '${offer.estimatedArrival} min',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.info,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.directions_car_rounded, size: 14, color: AppColors.getTextSecondary(context)),
                      SizedBox(width: 4),
                      Text(
                        '${offer.completedTrips} viajes',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(_kBorderRadiusLarge),
              ),
              child: Text(
                offer.acceptedPrice.toCurrency(),
                style: TextStyle(
                  color: AppColors.success,
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
  
  Widget _buildFavoritePlace(IconData icon, String label, {String? favoriteKey}) {
    final isAddButton = label == 'Agregar';
    final favoriteData = favoriteKey != null ? _userFavorites[favoriteKey] : null;
    final hasFavorite = favoriteData != null && favoriteData['address'] != null;

    return InkWell(
      onTap: () async {
        if (isAddButton) {
          Navigator.pushNamed(context, '/passenger/favorites');
          return;
        }

        if (hasFavorite) {
          final address = favoriteData['address'] as String;
          final lat = favoriteData['lat'] as double?;
          final lng = favoriteData['lng'] as double?;

          if (lat != null && lng != null) {
            _destinationController.text = address;
            _destinationCoordinates = LatLng(lat, lng);

            await _addMarkerAndZoom(LatLng(lat, lng), 'destination_marker', false);
            if (_pickupCoordinates != null && !_markers.any((m) => m.markerId.value == 'pickup_marker')) {
              await _addMarkerAndZoom(_pickupCoordinates!, 'pickup_marker', true);
            }

            if (!mounted) return;

            if (_pickupCoordinates != null) {
              await _updateRoutePolyline();
            }
            if (!mounted) return;
            setState(() {
              _showPriceNegotiation = true;
              _markers.removeWhere((m) => m.markerId.value.startsWith('ref_dot'));
              _markers.removeWhere((m) => m.markerId.value.startsWith('sim_driver_'));
            });
            await _zoomToShowBothLocations();
          }
        } else {
          Navigator.pushNamed(context, '/passenger/favorites');
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
                color: hasFavorite
                    ? AppColors.rappiOrange.withValues(alpha: 0.1)
                    : AppColors.getInputFill(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: hasFavorite ? AppColors.rappiOrange : AppColors.getTextSecondary(context),
              ),
            ),
            SizedBox(height: 8),
            Text(
              hasFavorite ? _truncateAddress(favoriteData['address'] as String) : label,
              style: TextStyle(
                fontSize: 12,
                color: hasFavorite ? AppColors.getTextPrimary(context) : AppColors.getTextSecondary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _truncateAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 8)}...';
  }
  
  Widget _buildRecentPlace(String title, String subtitle, {double? lat, double? lng}) {
    return InkWell(
      onTap: () async {
        _destinationController.text = title;

        if (lat != null && lng != null) {
          _destinationCoordinates = LatLng(lat, lng);

          await _addMarkerAndZoom(LatLng(lat, lng), 'destination_marker', false);
          if (_pickupCoordinates != null && !_markers.any((m) => m.markerId.value == 'pickup_marker')) {
            await _addMarkerAndZoom(_pickupCoordinates!, 'pickup_marker', true);
          }
        }

        if (!mounted) return;

        if (_pickupCoordinates != null && _destinationCoordinates != null) {
          await _updateRoutePolyline();
        }
        if (!mounted) return;
        setState(() {
          _showPriceNegotiation = true;
          _markers.removeWhere((m) => m.markerId.value.startsWith('ref_dot'));
          _markers.removeWhere((m) => m.markerId.value.startsWith('sim_driver_'));
        });
        if (_pickupCoordinates != null && _destinationCoordinates != null) {
          await _zoomToShowBothLocations();
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              color: AppColors.getTextSecondary(context),
              size: 24,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextPrimary(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentChip(IconData? icon, String label, bool selected, Color brandColor, {bool isYape = false, bool isPlin = false}) {
    return InkWell(
      onTap: () {
        if (!mounted) return;
        setState(() {
          _selectedPaymentMethod = label;
        });
        AppLogger.info('Método de pago seleccionado: $label');
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? brandColor.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: selected ? brandColor : AppColors.getBorder(context),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isYape)
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: Color(0xFF6B2D8B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(child: Text('Y', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
              )
            else if (isPlin)
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: Color(0xFF00BFA5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(child: Text('P', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
              )
            else
              Icon(icon, color: selected ? brandColor : AppColors.getTextSecondary(context), size: 20),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? brandColor : AppColors.getTextSecondary(context),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSuggestionButton(double price) {
    final bool isSelected = (_offeredPrice - price).abs() < 0.01;

    return InkWell(
      onTap: () {
        if (!mounted) return;

        _hideKeyboard();

        setState(() {
          _offeredPrice = price;
          _priceController.text = price.toStringAsFixed(2);
          _isManualPriceEntry = false;
        });

        AppLogger.info('Precio seleccionado desde botón: ${price.toCurrency()}');
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
            ? AppColors.rappiOrange
            : AppColors.getInputFill(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
              ? AppColors.rappiOrange
              : AppColors.getBorder(context),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.rappiOrange.withValues(alpha: 0.3),
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
            color: isSelected ? AppColors.white : AppColors.getTextPrimary(context),
          ),
        ),
      ),
    );
  }

  void _showServiceDetailsIfNeeded(ServiceType type) {
    switch (type) {
      case ServiceType.viaje:
      case ServiceType.mototaxi:
      case ServiceType.confort:
        break;
      case ServiceType.xl:
        _showXLDetailsModal();
        break;
      case ServiceType.entregas:
        _showDeliveryDetailsModal();
        break;
      case ServiceType.flete:
        _showFreightDetailsModal();
        break;
      case ServiceType.ciudadACiudad:
        _showIntercityDetailsModal();
        break;
    }
  }

  void _showXLDetailsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.airport_shuttle, color: AppColors.rappiOrange, size: 28),
                SizedBox(width: 12),
                Text(
                  'Servicio XL',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Vehículo grande para 5-6 pasajeros',
              style: TextStyle(color: AppColors.getTextSecondary(context)),
            ),
            SizedBox(height: 24),
            Text(
              '¿Cuántos pasajeros viajan?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setModalState) => Row(
                children: [
                  _buildPassengerOption(5, setModalState),
                  SizedBox(width: 16),
                  _buildPassengerOption(6, setModalState),
                ],
              ),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'El precio incluye servicio de vehículo grande',
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rappiOrange,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Confirmar', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildPassengerOption(int count, StateSetter setModalState) {
    final isSelected = _xlPassengerCount == count;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setModalState(() {});
          setState(() => _xlPassengerCount = count);
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.rappiOrange : AppColors.getSurface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.rappiOrange : AppColors.getBorder(context),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
                ),
              ),
              Text(
                'pasajeros',
                style: TextStyle(
                  color: isSelected ? Colors.white.withValues(alpha: 0.9) : AppColors.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeliveryDetailsModal() {
    final descController = TextEditingController(text: _deliveryDescription);
    final recipientNameController = TextEditingController(text: _deliveryRecipientName);
    final recipientPhoneController = TextEditingController(text: _deliveryRecipientPhone);
    String selectedWeight = _deliveryWeight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(children: [
                    Icon(Icons.inventory_2, color: AppColors.rappiOrange, size: 28),
                    SizedBox(width: 12),
                    Text('Servicio de Entregas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ]),
                  SizedBox(height: 8),
                  Text('El conductor recogerá tu paquete', style: TextStyle(color: AppColors.getTextSecondary(context))),
                ],
              ),
            ),
            Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: StatefulBuilder(
                  builder: (context, setModalState) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('¿Qué envías?', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      TextField(controller: descController, decoration: InputDecoration(hintText: 'Ej: Documentos, ropa, comida...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: AppColors.getInputFill(context))),
                      SizedBox(height: 20),
                      Text('Peso aproximado', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Row(children: ['<5kg', '5-10kg', '10-20kg'].map((weight) {
                        final isSelected = selectedWeight == weight;
                        return Expanded(child: GestureDetector(
                          onTap: () => setModalState(() => selectedWeight = weight),
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 4), padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: isSelected ? AppColors.rappiOrange : AppColors.getSurface(context), borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? AppColors.rappiOrange : AppColors.getBorder(context))),
                            child: Center(child: Text(weight, style: TextStyle(color: isSelected ? Colors.white : AppColors.getTextPrimary(context), fontWeight: FontWeight.w600))),
                          ),
                        ));
                      }).toList()),
                      SizedBox(height: 20),
                      Text('Datos del destinatario', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      TextField(controller: recipientNameController, decoration: InputDecoration(hintText: 'Nombre del destinatario', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: AppColors.getInputFill(context))),
                      SizedBox(height: 12),
                      TextField(controller: recipientPhoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(hintText: 'Teléfono del destinatario', prefixIcon: Icon(Icons.phone_outlined), prefixText: '+51 ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: AppColors.getInputFill(context))),
                      SizedBox(height: 20),
                      Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20), SizedBox(width: 12), Expanded(child: Text('Máximo 20kg. Para cargas mayores usa Flete.', style: TextStyle(color: Colors.orange.shade700, fontSize: 13)))])),
                    ],
                  ),
                ),
              ),
            ),
            Padding(padding: EdgeInsets.all(20), child: SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () { setState(() { _deliveryDescription = descController.text; _deliveryWeight = selectedWeight; _deliveryRecipientName = recipientNameController.text; _deliveryRecipientPhone = recipientPhoneController.text; }); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.rappiOrange, padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Confirmar detalles', style: TextStyle(fontSize: 16, color: Colors.white)),
            ))),
          ],
        ),
      ),
      ),
    );
  }

  void _showFreightDetailsModal() {
    final notesController = TextEditingController(text: _freightNotes);
    String selectedType = _freightType;
    bool needsHelper = _freightNeedsHelper;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(color: AppColors.getSurface(context), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            SizedBox(height: 20),
            Row(children: [Icon(Icons.local_shipping, color: AppColors.rappiOrange, size: 28), SizedBox(width: 12), Text('Servicio de Flete', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
            SizedBox(height: 8),
            Text('Mudanzas y carga grande', style: TextStyle(color: AppColors.getTextSecondary(context))),
          ])),
          Divider(height: 1),
          Padding(padding: EdgeInsets.all(20), child: StatefulBuilder(
            builder: (context, setModalState) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tipo de carga', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: ['Muebles', 'Electrodomésticos', 'Cajas', 'Otros'].map((type) {
                final isSelected = selectedType == type;
                return GestureDetector(onTap: () => setModalState(() => selectedType = type),
                  child: Container(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: isSelected ? AppColors.rappiOrange : AppColors.getSurface(context), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? AppColors.rappiOrange : AppColors.getBorder(context))),
                    child: Text(type, style: TextStyle(color: isSelected ? Colors.white : AppColors.getTextPrimary(context), fontWeight: FontWeight.w600))));
              }).toList()),
              SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('¿Necesitas ayudante?', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('Para cargar/descargar', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12)),
                ])),
                Switch(value: needsHelper, onChanged: (value) => setModalState(() => needsHelper = value), activeColor: AppColors.rappiOrange),
              ]),
              SizedBox(height: 20),
              Text('Notas adicionales', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              TextField(controller: notesController, maxLines: 3, decoration: InputDecoration(hintText: 'Ej: Piso 3 sin ascensor, manejar con cuidado...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: AppColors.getInputFill(context))),
              SizedBox(height: 20),
              Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20), SizedBox(width: 12), Expanded(child: Text('El precio final se acuerda con el conductor según la carga.', style: TextStyle(color: Colors.blue.shade700, fontSize: 13)))])),
            ]),
          )),
          Padding(padding: EdgeInsets.all(20), child: SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () { setState(() { _freightType = selectedType; _freightNeedsHelper = needsHelper; _freightNotes = notesController.text; }); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rappiOrange, padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Confirmar detalles', style: TextStyle(fontSize: 16, color: Colors.white)),
          ))),
        ]),
        ),
      ),
    );
  }

  void _showIntercityDetailsModal() {
    int selectedStops = _intercityStops;
    String selectedLuggage = _intercityLuggage;
    TimeOfDay? selectedTime = _intercityDepartureTime;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(color: AppColors.getSurface(context), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            SizedBox(height: 20),
            Row(children: [Icon(Icons.route, color: AppColors.rappiOrange, size: 28), SizedBox(width: 12), Text('Ciudad a Ciudad', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
            SizedBox(height: 8),
            Text('Viajes interurbanos - precio negociable', style: TextStyle(color: AppColors.getTextSecondary(context))),
          ])),
          Divider(height: 1),
          Padding(padding: EdgeInsets.all(20), child: StatefulBuilder(
            builder: (context, setModalState) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('¿Cuántas paradas en el camino?', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Row(children: [0, 1, 2, 3].map((stops) {
                final isSelected = selectedStops == stops;
                return Expanded(child: GestureDetector(onTap: () => setModalState(() => selectedStops = stops),
                  child: Container(margin: EdgeInsets.symmetric(horizontal: 4), padding: EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(color: isSelected ? AppColors.rappiOrange : AppColors.getSurface(context), borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? AppColors.rappiOrange : AppColors.getBorder(context))),
                    child: Center(child: Text(stops == 0 ? 'Sin paradas' : '$stops', style: TextStyle(color: isSelected ? Colors.white : AppColors.getTextPrimary(context), fontWeight: FontWeight.w600, fontSize: 13))))));
              }).toList()),
              SizedBox(height: 24),
              Text('¿Cuánto equipaje llevas?', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Row(children: ['Ligero', 'Normal', 'Mucho'].map((luggage) {
                final isSelected = selectedLuggage == luggage;
                return Expanded(child: GestureDetector(onTap: () => setModalState(() => selectedLuggage = luggage),
                  child: Container(margin: EdgeInsets.symmetric(horizontal: 4), padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: isSelected ? AppColors.rappiOrange : AppColors.getSurface(context), borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? AppColors.rappiOrange : AppColors.getBorder(context))),
                    child: Center(child: Text(luggage, style: TextStyle(color: isSelected ? Colors.white : AppColors.getTextPrimary(context), fontWeight: FontWeight.w600))))));
              }).toList()),
              SizedBox(height: 24),
              Text('Hora de salida preferida (opcional)', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final time = await showTimePicker(context: context, initialTime: selectedTime ?? TimeOfDay.now());
                  if (time != null) setModalState(() => selectedTime = time);
                },
                child: Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: AppColors.getBorder(context)), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.access_time, color: AppColors.rappiOrange), SizedBox(width: 12),
                    Text(selectedTime != null ? selectedTime!.format(context) : 'Salir ahora', style: TextStyle(fontSize: 16)),
                    Spacer(),
                    if (selectedTime != null) GestureDetector(onTap: () => setModalState(() => selectedTime = null), child: Icon(Icons.close, color: Colors.grey)),
                  ])),
              ),
              SizedBox(height: 20),
              Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [Icon(Icons.info_outline, color: Colors.green.shade700, size: 20), SizedBox(width: 12), Expanded(child: Text('Para viajes largos, el precio es negociable con el conductor.', style: TextStyle(color: Colors.green.shade700, fontSize: 13)))])),
            ]),
          )),
          Padding(padding: EdgeInsets.all(20), child: SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () { setState(() { _intercityStops = selectedStops; _intercityLuggage = selectedLuggage; _intercityDepartureTime = selectedTime; }); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rappiOrange, padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Confirmar detalles', style: TextStyle(fontSize: 16, color: Colors.white)),
          ))),
        ]),
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          child: Icon(Icons.my_location, color: AppColors.rappiOrange, size: 22),
          onTap: () async {
            final currentLocation = await _getCurrentLocation();
            if (currentLocation != null && _mapController != null && mounted) {
              _mapController!.animateCamera(
                CameraUpdate.newLatLngZoom(currentLocation, _kZoomLevelClose),
              );
            }
          },
        ),
      ),
    );
  }
  
  void _showDriverAcceptedDialog(models.DriverOffer offer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_kBorderRadiusLarge),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModernLoadingIndicator(color: AppColors.success),
            SizedBox(height: 20),
            Text(
              'Conductor encontrado',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'El conductor ${(offer.driverName)} va en camino',
              style: TextStyle(color: AppColors.getTextSecondary(context)),
            ),
            SizedBox(height: 20),
            AnimatedPulseButton(
              text: 'Ver detalles',
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDrawer() {
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.currentUser?.fullName.split(" ").first ?? 'Pasajero';

    return Drawer(
      child: Container(
        color: AppColors.getSurface(context),
        child: Column(
          children: [
            // Header - using SafeArea + simple profile section
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/passenger/profile');
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.rappiOrange.withValues(alpha: 0.1),
                        child: Icon(Icons.person, size: 28, color: AppColors.rappiOrange),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                            Text('Pasajero', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(icon: Icons.history_rounded, title: l10n.tripHistory, onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/passenger/trip-history'); }),
                  _buildDrawerItem(icon: Icons.favorite_rounded, title: l10n.favoritePlaces, onTap: () async {
                    Navigator.pop(context);
                    final result = await Navigator.pushNamed(context, '/passenger/favorites');
                    if (result != null && mounted) {
                      if (result is Map<String, dynamic>) {
                        final address = result['address'] as String?;
                        final lat = result['latitude'] as double?;
                        final lng = result['longitude'] as double?;
                        if (address != null && lat != null && lng != null) {
                          _destinationController.text = address;
                          _destinationCoordinates = LatLng(lat, lng);
                          await _addMarkerAndZoom(LatLng(lat, lng), 'destination_marker', false);
                          if (_pickupCoordinates != null) {
                            if (!_markers.any((m) => m.markerId.value == 'pickup_marker')) {
                              await _addMarkerAndZoom(_pickupCoordinates!, 'pickup_marker', true);
                            }
                            await _updateRoutePolyline();
                            if (!mounted) return;
                            setState(() {
                              _showPriceNegotiation = true;
                              _markers.removeWhere((m) => m.markerId.value.startsWith('ref_dot'));
                              _markers.removeWhere((m) => m.markerId.value.startsWith('sim_driver_'));
                            });
                            await _zoomToShowBothLocations();
                          } else {
                            setState(() {});
                          }
                        }
                      }
                    }
                  }),
                  _buildDrawerItem(icon: Icons.share_rounded, title: 'Compartir App', onTap: () { Navigator.pop(context); _shareApp(); }),
                  Divider(),
                  _buildDrawerItem(icon: Icons.support_agent_rounded, title: 'Soporte', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => AboutScreen())); }),
                  _buildDrawerItem(icon: Icons.settings_rounded, title: l10n.settings, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen())); }),
                  Divider(),
                  _buildDrawerItem(icon: Icons.logout_rounded, title: l10n.logout, onTap: () async {
                    Navigator.pop(context);
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    await authProvider.logout();
                    if (!mounted) return;
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  }, color: AppColors.error),
                ],
              ),
            ),

            _buildDriverModeButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverModeButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.currentUser;
        final hasDriverRole = user?.availableRoles?.contains('driver') ?? false;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Material(
            color: AppColors.rappiOrange,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _handleDriverModeTap(authProvider, hasDriverRole),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.local_taxi_rounded, color: Colors.white, size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Modo Conductor', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          Text(hasDriverRole ? 'Cambiar a conductor' : 'Empieza a ganar dinero',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleDriverModeTap(AuthProvider authProvider, bool hasDriverRole) async {
    Navigator.pop(context);

    if (hasDriverRole) {
      final success = await authProvider.switchMode('driver');
      if (!mounted) return;

      if (success) {
        Navigator.pushNamedAndRemoveUntil(context, '/driver/home', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? 'Error al cambiar modo'), backgroundColor: AppColors.error),
        );
      }
    } else {
      final userId = authProvider.currentUser?.id;
      if (userId != null) {
        _showLoadingDialog('Verificando...');
        final pendingApplication = await _checkPendingDriverApplication(userId);
        if (mounted) Navigator.pop(context);
        if (!mounted) return;
        if (pendingApplication != null) {
          Navigator.pushNamed(context, '/driver/register/pending', arguments: pendingApplication);
        } else {
          Navigator.pushNamed(context, '/driver/register');
        }
      } else {
        Navigator.pushNamed(context, '/driver/register');
      }
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.rappiOrange),
                const SizedBox(height: 16),
                Text(message, style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _checkPendingDriverApplication(String userId) async {
    try {
      AppLogger.info('Verificando solicitud de conductor pendiente para userId: $userId');
      final snapshot = await FirebaseFirestore.instance
          .collection('driver_applications')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['pending', 'under_review'])
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        AppLogger.info('Solicitud pendiente encontrada: ${snapshot.docs.first.id}');
        return data;
      }
      AppLogger.info('No se encontró solicitud pendiente');
      return null;
    } catch (e) {
      AppLogger.error('Error verificando solicitud pendiente: $e');
      return null;
    }
  }

  void _shareApp() {
    Share.share(
      '¡Descarga Rapi Team y viaja seguro!\n\n'
      'La mejor app de transporte de tu ciudad.\n\n'
      'Android: https://play.google.com/store/apps/details?id=com.rapiteam.app\n'
      'iOS: https://apps.apple.com/app/rapiteam',
      subject: 'Rapi Team - Tu app de transporte',
    );
    AppLogger.info('Usuario compartió la app');
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.rappiOrange),
      title: Text(title, style: TextStyle(color: color ?? AppColors.getTextPrimary(context))),
      onTap: onTap,
    );
  }

  Future<LatLng?> _getCurrentLocation() async {
    try {
      AppLogger.info('Obteniendo ubicación GPS real del dispositivo');
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
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      final LatLng currentLocation = LatLng(position.latitude, position.longitude);
      AppLogger.info('Ubicación GPS real obtenida: ${position.latitude}, ${position.longitude}');
      return currentLocation;
    } catch (e, stackTrace) {
      AppLogger.error('Error obteniendo ubicación GPS real', e, stackTrace);
      return null;
    }
  }

  Future<String?> _reverseGeocode(LatLng coordinates) async {
    try {
      AppLogger.info('Realizando reverse geocoding para: ${coordinates.latitude}, ${coordinates.longitude}');
      List<Placemark> placemarks = await placemarkFromCoordinates(coordinates.latitude, coordinates.longitude);
      if (placemarks.isEmpty) { AppLogger.warning('No se encontraron resultados de reverse geocoding'); return null; }
      final Placemark place = placemarks.first;
      List<String> addressParts = [];
      if (place.street != null && place.street!.isNotEmpty) addressParts.add(place.street!);
      if (place.subLocality != null && place.subLocality!.isNotEmpty) addressParts.add(place.subLocality!);
      if (place.locality != null && place.locality!.isNotEmpty) addressParts.add(place.locality!);
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

  Future<LatLng?> _getDestinationLocation() async {
    if (_destinationController.text.trim().isEmpty) { AppLogger.warning('Dirección de destino vacía'); return null; }
    try {
      if (_destinationCoordinates != null) {
        AppLogger.info('Usando coordenadas de Google Places: ${_destinationCoordinates!.latitude}, ${_destinationCoordinates!.longitude}');
        return _destinationCoordinates;
      }
      AppLogger.warning('Usuario escribió dirección pero no seleccionó de autocomplete. Coordenadas no disponibles.');
      final fallbackCoordinates = LatLng(-12.0464, -77.0428);
      AppLogger.warning('Usando coordenadas fallback (centro de Lima): ${fallbackCoordinates.latitude}, ${fallbackCoordinates.longitude}');
      return fallbackCoordinates;
    } catch (e, stackTrace) {
      AppLogger.error('Error obteniendo ubicación de destino', e, stackTrace);
      return null;
    }
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadiusKm = 6371.0;
    final double lat1Rad = start.latitude * (3.141592653589793 / 180.0);
    final double lat2Rad = end.latitude * (3.141592653589793 / 180.0);
    final double deltaLatRad = (end.latitude - start.latitude) * (3.141592653589793 / 180.0);
    final double deltaLonRad = (end.longitude - start.longitude) * (3.141592653589793 / 180.0);
    final double a = (sin(deltaLatRad / 2) * sin(deltaLatRad / 2)) + (cos(lat1Rad) * cos(lat2Rad) * sin(deltaLonRad / 2) * sin(deltaLonRad / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distanceKm = earthRadiusKm * c;
    AppLogger.info('Distancia calculada (Haversine): ${distanceKm.toStringAsFixed(2)} km');
    return distanceKm;
  }

  int _estimateTime(double distanceKm) {
    const double averageSpeedKmh = 20.0;
    final double timeHours = distanceKm / averageSpeedKmh;
    final int timeMinutes = (timeHours * 60).round();
    AppLogger.info('Tiempo estimado: $timeMinutes minutos (${distanceKm.toStringAsFixed(2)} km a $averageSpeedKmh km/h)');
    return timeMinutes;
  }

  double _calculatePrice(double distanceKm) {
    final double baseFare = _fareConfig?.baseFare ?? 5.0;
    final double ratePerKm = _fareConfig?.perKm ?? 2.0;
    final double minimumFare = _fareConfig?.minimumFare ?? 6.0;
    final double maximumFare = _fareConfig?.maximumFare ?? 200.0;

    double serviceMultiplier;
    String serviceName;
    double? serviceMinPrice;

    switch (_selectedServiceType) {
      case ServiceType.viaje: serviceMultiplier = 1.0; serviceName = 'Viaje'; break;
      case ServiceType.mototaxi: serviceMultiplier = 0.7; serviceName = 'Mototaxi'; break;
      case ServiceType.confort: serviceMultiplier = 1.3; serviceName = 'Confort'; break;
      case ServiceType.xl: serviceMultiplier = 1.5; serviceName = 'XL'; break;
      case ServiceType.entregas: serviceMultiplier = 0.8; serviceName = 'Entregas'; break;
      case ServiceType.flete: serviceMultiplier = 2.0; serviceName = 'Flete'; break;
      case ServiceType.ciudadACiudad: serviceMultiplier = 1.8; serviceName = 'Ciudad a Ciudad'; break;
    }

    final double basePrice = baseFare + (distanceKm * ratePerKm);
    double totalPrice = basePrice * serviceMultiplier;
    final effectiveMin = serviceMinPrice ?? minimumFare;
    if (totalPrice < effectiveMin) totalPrice = effectiveMin;
    if (totalPrice > maximumFare) { totalPrice = maximumFare; AppLogger.info('Precio limitado a tarifa máxima: ${maximumFare.toCurrency()}'); }
    AppLogger.info('Precio calculado: ${totalPrice.toCurrency()} ($serviceName x$serviceMultiplier: base ${baseFare.toCurrency()} + ${distanceKm.toStringAsFixed(2)} km × ${ratePerKm.toCurrency()}/km)');
    return double.parse(totalPrice.toStringAsFixed(2));
  }

  Future<List<LatLng>> _getRoutePolylinePoints(LatLng origin, LatLng destination) async {
    try {
      AppLogger.info('Obteniendo ruta real desde Google Directions API');
      PolylinePoints polylinePoints = PolylinePoints(apiKey: AppConfig.googleMapsApiKey);
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );
      if (result.points.isNotEmpty) {
        List<LatLng> polylineCoordinates = result.points.map((point) => LatLng(point.latitude, point.longitude)).toList();
        AppLogger.info('Ruta real obtenida con ${polylineCoordinates.length} puntos');
        return polylineCoordinates;
      } else {
        AppLogger.warning('No se pudo obtener ruta. Error: ${result.errorMessage}');
        return [origin, destination];
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error obteniendo ruta', e, stackTrace);
      return [origin, destination];
    }
  }

  Future<void> _updateRoutePolyline() async {
    if (_pickupCoordinates == null || _destinationCoordinates == null) {
      if (!mounted) return;
      setState(() { _polylines.clear(); });
      return;
    }
    final List<LatLng> routePoints = await _getRoutePolylinePoints(_pickupCoordinates!, _destinationCoordinates!);
    final Polyline routePolyline = Polyline(
      polylineId: PolylineId('route'),
      points: routePoints,
      color: const Color(0xFF4285F4),
      width: 5,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );
    if (!mounted) return;
    setState(() {
      _polylines.clear();
      _polylines.add(routePolyline);
    });
    AppLogger.info('Polilínea de ruta REAL dibujada con ${routePoints.length} puntos');
  }
}

/// Internal model for simulated driver position and state
class _SimDriver {
  final double lat;
  final double lng;
  final double heading;
  final double speed;
  final double alpha;
  final bool visible;
  final DateTime nextMove;
  final DateTime nextDisappear;

  const _SimDriver({
    required this.lat,
    required this.lng,
    required this.heading,
    required this.speed,
    this.alpha = 1.0,
    required this.visible,
    required this.nextMove,
    required this.nextDisappear,
  });

  _SimDriver copyWith({
    double? lat,
    double? lng,
    double? heading,
    double? speed,
    double? alpha,
    bool? visible,
    DateTime? nextMove,
    DateTime? nextDisappear,
  }) {
    return _SimDriver(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      alpha: alpha ?? this.alpha,
      visible: visible ?? this.visible,
      nextMove: nextMove ?? this.nextMove,
      nextDisappear: nextDisappear ?? this.nextDisappear,
    );
  }
}
