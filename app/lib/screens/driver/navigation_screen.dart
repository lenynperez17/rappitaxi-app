// ignore_for_file: deprecated_member_use, unused_field, unused_element, unreachable_switch_default, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../core/constants/app_colors.dart';
import '../../core/utils/logger.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../services/maps_service.dart';
import '../../services/rapi_api_client.dart';
import '../../services/rapi_sse_client.dart';
import '../shared/chat_screen.dart';
import '../../utils/map_marker_utils.dart';
import '../../utils/error_messages.dart';

// API Key de Google Maps para Directions API
const String _googleMapsApiKey = 'AIzaSyB0lGTYq7wjOUEzPYIbxsTPp_COdhEk5Hc';

// Ronda 241: brand color Rapi Team (rojo) — antes verde-lima
// que no coincidía con la identidad de la marca. Mantengo el
// nombre de variable para no tocar todos los call sites.
const Color _inDriveLime = AppColors.rappiOrange;

class NavigationScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;

  const NavigationScreen({super.key, this.tripData});

  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Iconos personalizados para los marcadores
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _personIcon;
  BitmapDescriptor? _destinationIcon;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;

  // Navigation state
  bool _isNavigating = false;
  final bool _showInstructions = true;
  String _currentInstruction = '';
  String _nextInstruction = '';
  double _distanceToNext = 0;
  int _estimatedTime = 0;
  double _totalDistance = 0;
  int _totalTime = 0;
  bool _isRouteInitialized = false;

  // Ubicación GPS real
  LatLng _currentLocation = LatLng(-12.0851, -76.9770);
  LatLng _destination = LatLng(-12.0951, -76.9870);
  LatLng? _pickupLocation;
  LatLng? _finalDestination;
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;

  // Backend Node/SSE (reemplaza Firebase)
  final RapiApiClient _api = RapiApiClient.instance;
  final RapiSseClient _sse = RapiSseClient.instance;
  String? _tripId;
  StreamSubscription<Map<String, dynamic>>? _tripSubscription;

  // Flag para evitar multiples llamadas a la API de rutas
  bool _isFetchingRoute = false;

  // Flag para saber si tenemos ubicación GPS real
  bool _hasRealGpsLocation = false;

  // Flag para prevenir operaciones despues de dispose
  bool _isDisposed = false;

  // FLUJO DEL VIAJE: Estados (estilo inDrive - SIN verificación PIN)
  bool _isNavigatingToPickup = true;
  bool _hasArrivedAtPickup = false;
  bool _isWaitingForPassenger = false;
  bool _isTripInProgress = false;
  bool _isNearFinalDestination = false;

  // Datos del viaje para mostrar
  String _pickupAddress = 'Punto de recogida';
  String _destinationAddress = 'Destino';
  String _passengerName = 'Pasajero';
  String _passengerPhoto = '';
  double _passengerRating = 5.0;
  int _passengerTripCount = 0;
  double _fare = 0.0;
  String _paymentMethod = 'Efectivo';

  /// Format raw payment method value to user-friendly Spanish label
  String _formatPaymentLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'cash':
      case 'efectivo':
        return 'Efectivo';
      case 'yape':
        return 'Yape';
      case 'plin':
        return 'Plin';
      case 'card':
      case 'tarjeta':
        return 'Tarjeta';
      case 'wallet':
      case 'billetera':
        return 'Billetera';
      default:
        return 'Efectivo';
    }
  }
  String _passengerPhone = '';
  String _passengerId = '';

  // TEMPORIZADOR DE ESPERA
  Timer? _waitingTimer;
  int _waitingSeconds = 0;
  DateTime? _arrivalTime;

  // Route instructions
  List<RouteInstruction> _instructions = [];
  int _currentInstructionIndex = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _slideController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    );

    _slideController.forward();

    _loadCustomMarkerIcons();
    _initializeTripData();
    _initializeGPS();

    // Auto-iniciar navegacion con un pequeño delay para que el mapa cargue
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_isDisposed) {
        _startNavigation();
      }
    });
  }

  Future<void> _loadCustomMarkerIcons() async {
    try {
      _carIcon = await MapMarkerUtils.getCarTopViewIcon();
      _personIcon = await MapMarkerUtils.getPassengerWaitingIcon();
      _destinationIcon = await MapMarkerUtils.getDestinationIcon();
      debugPrint('Iconos personalizados cargados correctamente (MapMarkerUtils)');
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error cargando iconos personalizados'));
    }
  }

  void _initializeTripData() {
    debugPrint('INICIALIZANDO TRIP DATA: ${widget.tripData}');
    if (widget.tripData != null) {
      final data = widget.tripData!;
      _tripId = data['id'] ?? data['tripId'];
      debugPrint('_tripId asignado: $_tripId');

      // Intentar con pickupLat/pickupLng (formato de modern_driver_home)
      final pickupLat = data['pickupLat'];
      final pickupLng = data['pickupLng'];
      if (pickupLat != null && pickupLng != null) {
        _pickupLocation = LatLng(
          (pickupLat is double) ? pickupLat : (pickupLat as num).toDouble(),
          (pickupLng is double) ? pickupLng : (pickupLng as num).toDouble(),
        );
        debugPrint(userFriendlyError(_pickupLocation, fallback: 'Pickup desde pickupLat/pickupLng'));
      }

      // Fallback con 'pickupLocation', 'origin' o 'pickup' (mapa {lat, lng}).
      // El backend Node siempre envía coordenadas como objetos JSON, no como
      // GeoPoint de Firestore.
      if (_pickupLocation == null) {
        final originData = data['pickupLocation'] ?? data['origin'] ?? data['pickup'];
        if (originData is Map) {
          final lat = originData['latitude'] ?? originData['lat'];
          final lng = originData['longitude'] ?? originData['lng'];
          if (lat != null && lng != null) {
            _pickupLocation = LatLng(
              (lat as num).toDouble(),
              (lng as num).toDouble(),
            );
          }
        }
        debugPrint(userFriendlyError(_pickupLocation, fallback: 'Pickup desde pickupLocation/origin/pickup'));
      }

      // Intentar con destinationLat/destinationLng
      final destLat = data['destinationLat'];
      final destLng = data['destinationLng'];
      if (destLat != null && destLng != null) {
        _finalDestination = LatLng(
          (destLat is double) ? destLat : (destLat as num).toDouble(),
          (destLng is double) ? destLng : (destLng as num).toDouble(),
        );
        debugPrint(userFriendlyError(_finalDestination, fallback: 'Destino desde destinationLat/destinationLng'));
      }

      // Fallback con 'destinationLocation' (mapa {lat, lng} desde el backend).
      if (_finalDestination == null) {
        final destinationData = data['destinationLocation'] ?? data['destination'] ?? data['dropoff'];
        if (destinationData is Map) {
          final lat = destinationData['latitude'] ?? destinationData['lat'];
          final lng = destinationData['longitude'] ?? destinationData['lng'];
          if (lat != null && lng != null) {
            _finalDestination = LatLng(
              (lat as num).toDouble(),
              (lng as num).toDouble(),
            );
          }
        }
        debugPrint(userFriendlyError(_finalDestination, fallback: 'Destino desde destinationLocation/destination'));
      }

      // Set destination based on current ride status
      final rideStatus = data['status'] as String? ?? '';
      if (rideStatus == 'in_progress') {
        // Trip already started — navigate to final destination
        _destination = _finalDestination ?? _pickupLocation ?? _destination;
        _isNavigatingToPickup = false;
        _isTripInProgress = true;
        _hasArrivedAtPickup = true;
      } else if (_pickupLocation != null) {
        // Still in pickup phase — navigate to pickup
        _destination = _pickupLocation!;
      }

      // Leer datos del viaje y del pasajero
      _pickupAddress = data['pickupAddress'] as String? ??
                       data['originAddress'] as String? ??
                       'Punto de recogida';
      _destinationAddress = data['destinationAddress'] as String? ?? 'Destino';
      _passengerName = data['passengerName'] as String? ?? 'Pasajero';
      _passengerPhoto = data['passengerPhoto'] as String? ?? '';
      _passengerRating = (data['passengerRating'] ?? 5.0).toDouble();
      _passengerTripCount = (data['passengerTripCount'] ?? 0).toInt();
      _fare = (data['fare'] ?? data['acceptedFare'] ?? 0.0).toDouble();
      _paymentMethod = _formatPaymentLabel(data['paymentMethod'] as String? ?? 'cash');
      _passengerPhone = data['passengerPhone'] as String? ?? '';
      _passengerId = data['passengerId'] as String? ?? data['userId'] as String? ?? '';

      debugPrint(userFriendlyError(_passengerName, fallback: 'RESUMEN - Pickup: $_pickupLocation ($_pickupAddress), Destino final: $_finalDestination ($_destinationAddress), Pasajero'));

      if (_tripId != null) {
        _listenToTripChanges();
      }
    }
  }

  void _listenToTripChanges() {
    _tripSubscription?.cancel();

    // Suscribimos al stream global SSE de rides. Cada evento puede traer
    // un `ride` completo, o campos parciales como `rideId` + `status`.
    // Filtramos por _tripId antes de procesar.
    _sse.start();
    _tripSubscription = _sse.rideUpdates.listen((event) {
      if (!mounted || _isDisposed) return;

      // Determinar rideId del evento (puede venir en distintas ubicaciones).
      final String? eventRideId = (event['rideId'] as String?) ??
          (event['id'] as String?) ??
          ((event['ride'] as Map<String, dynamic>?)?['id'] as String?);
      if (eventRideId == null || eventRideId != _tripId) return;

      // Extraer los datos del ride (puede venir anidado como `ride`).
      final Map<String, dynamic> data =
          (event['ride'] as Map<String, dynamic>?) ?? event;
      final status = data['status'] as String?;

      debugPrint(userFriendlyError(status, fallback: 'Status del viaje'));

      if (status == 'in_progress' && !_isTripInProgress) {
        setState(() {
          _isWaitingForPassenger = false;
          _isTripInProgress = true;
          _isNavigatingToPickup = false;
          _hasArrivedAtPickup = true;
          if (_finalDestination != null) {
            _destination = _finalDestination!;
            debugPrint(userFriendlyError(_destination, fallback: 'Destino actualizado al destino final'));
          }
        });
        _waitingTimer?.cancel();
        _isRouteInitialized = false;
        _initializeRoute(AppLocalizations.of(context)!);
      }

      // Handle cancellation by passenger
      if (status == 'cancelled' || status == 'expired') {
        debugPrint('Ride cancelled/expired by passenger. Returning to home.');
        _tripSubscription?.cancel();
        _tripSubscription = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('El pasajero canceló el viaje'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
        }
      }
    });
  }

  Future<void> _initializeGPS() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Logger.warning('Permisos de ubicación denegados');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Logger.warning('Permisos de ubicación denegados permanentemente');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted && !_isDisposed) {
        final isFirstGpsLocation = !_hasRealGpsLocation;

        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _hasRealGpsLocation = true;
        });
        _updateLocationMarker();

        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentLocation),
        );

        if (isFirstGpsLocation) {
          debugPrint('Primera ubicación GPS real obtenida, FORZANDO cálculo de ruta...');
          _isFetchingRoute = false;
          _isRouteInitialized = false;
          _initializeRoute(AppLocalizations.of(context)!);
        }
      }
    } catch (e) {
      Logger.error('Error inicializando GPS', e);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    _pulseController.dispose();
    _slideController.dispose();
    _locationTimer?.cancel();
    _locationTimer = null;
    _positionStream?.cancel();
    _positionStream = null;
    _waitingTimer?.cancel();
    _waitingTimer = null;
    _tripSubscription?.cancel();
    _tripSubscription = null;
    _mapController?.dispose();
    super.dispose();
  }

  void _initializeRoute(AppLocalizations l10n) {
    if (_isRouteInitialized) return;
    _isRouteInitialized = true;

    final distanceToDestination = Geolocator.distanceBetween(
      _currentLocation.latitude,
      _currentLocation.longitude,
      _destination.latitude,
      _destination.longitude,
    );

    final estimatedMinutes = (distanceToDestination / 1000) / 30 * 60;

    String instructionText;
    String arrivalText;
    if (!_isTripInProgress && _pickupLocation != null) {
      instructionText = 'Recoge a $_passengerName';
      arrivalText = userFriendlyError(_pickupAddress, fallback: 'Llegando');
    } else {
      instructionText = 'Lleva al pasajero al destino';
      arrivalText = userFriendlyError(_destinationAddress, fallback: 'Llegando');
    }

    _instructions = [
      RouteInstruction(
        instruction: instructionText,
        distance: distanceToDestination,
        duration: estimatedMinutes.round(),
        turnIcon: Icons.navigation,
        position: _currentLocation,
      ),
      RouteInstruction(
        instruction: arrivalText,
        distance: 50.0,
        duration: 1,
        turnIcon: Icons.location_on,
        position: _destination,
      ),
    ];

    _totalDistance = distanceToDestination;
    _totalTime = estimatedMinutes.round();

    // Draw immediate placeholder route (straight line) so something is visible right away
    final placeholderOrigin = (_isTripInProgress && _pickupLocation != null)
        ? _pickupLocation!
        : _currentLocation;
    setState(() {
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [placeholderOrigin, _destination],
        color: AppColors.rappiOrange,
        width: 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));
    });

    _updateCurrentInstruction(l10n);
    _fetchRealRoute(l10n);
  }

  Future<void> _fetchRealRoute(AppLocalizations l10n) async {
    if (_isFetchingRoute) return;

    if (!_hasRealGpsLocation) {
      debugPrint('Esperando ubicación GPS real antes de calcular ruta...');
      // Retry after GPS is available
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isDisposed) _fetchRealRoute(l10n);
      });
      return;
    }

    _isFetchingRoute = true;

    // Safety timeout: reset flag after 10s in case API hangs
    Future.delayed(const Duration(seconds: 10), () {
      if (_isFetchingRoute) {
        debugPrint('_isFetchingRoute timeout — resetting flag');
        _isFetchingRoute = false;
      }
    });

    try {
      // During in_progress, route is pickup→destination (fixed trip route)
      // During pickup phase, route is driver→pickup
      final routeOrigin = (_isTripInProgress && _pickupLocation != null)
          ? _pickupLocation!
          : _currentLocation;

      debugPrint('Obteniendo ruta vía mapsProxy (OSRM→Mapbox→Google)...');
      debugPrint('Origen: ${routeOrigin.latitude}, ${routeOrigin.longitude} (${_isTripInProgress ? "pickup" : "GPS"})');
      debugPrint('Destino: ${_destination.latitude}, ${_destination.longitude}');

      // Usa MapsService que invoca el callable `directionsProxy`. El backend
      // cae primero a OSRM (gratis), luego Mapbox (free tier), y solo en último
      // recurso a Google Directions. Ahorra ~$150-250/mes en escala vs llamar
      // directo a Google con la API key expuesta en el cliente.
      final route = await MapsService().getDirections(
        origin: LatLng(routeOrigin.latitude, routeOrigin.longitude),
        destination: LatLng(_destination.latitude, _destination.longitude),
        mode: 'driving',
      );

      if (!mounted || _isDisposed) return;

      if (route != null && route.points.isNotEmpty) {
        final List<LatLng> polylineCoordinates = route.points;
        debugPrint('Ruta obtenida (${route.provider}): ${polylineCoordinates.length} puntos · ${route.distanceKm.toStringAsFixed(2)}km · ${route.durationMinutes}min');

        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: PolylineId('route'),
              points: polylineCoordinates,
              color: AppColors.rappiOrange,
              width: 6,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              patterns: [],
            ),
          );
        });

        debugPrint('Polyline agregada con ${_polylines.length} polylines, puntos: ${polylineCoordinates.length}');

        _addRouteMarkers(l10n);

        // Fit camera to show entire route
        if (polylineCoordinates.length > 1 && _mapController != null) {
          double minLat = polylineCoordinates.first.latitude;
          double maxLat = polylineCoordinates.first.latitude;
          double minLng = polylineCoordinates.first.longitude;
          double maxLng = polylineCoordinates.first.longitude;
          for (final p in polylineCoordinates) {
            if (p.latitude < minLat) minLat = p.latitude;
            if (p.latitude > maxLat) maxLat = p.latitude;
            if (p.longitude < minLng) minLng = p.longitude;
            if (p.longitude > maxLng) maxLng = p.longitude;
          }
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng),
              ),
              80,
            ),
          );
        }

        debugPrint('Ruta real dibujada exitosamente');
      } else {
        debugPrint('mapsProxy no devolvió ruta (todos los proveedores fallaron). Usando fallback.');
        _drawSimpleFallbackRoute(l10n);
      }
    } catch (e) {
      Logger.error('Error obteniendo ruta real de Google Directions', e);
      debugPrint(userFriendlyError(e, fallback: 'Error'));
      if (mounted && !_isDisposed) {
        _drawSimpleFallbackRoute(l10n);
      }
    } finally {
      _isFetchingRoute = false;
    }
  }

  String _stripHtmlTags(String htmlString) {
    return htmlString.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  double _parseDistanceString(String distanceStr) {
    try {
      final cleanStr = distanceStr.toLowerCase().replaceAll(',', '.');
      if (cleanStr.contains('km')) {
        final value = double.tryParse(cleanStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        return value * 1000;
      } else {
        return double.tryParse(cleanStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      }
    } catch (e) {
      return 0;
    }
  }

  int _parseDurationString(String durationStr) {
    try {
      final cleanStr = durationStr.toLowerCase();
      if (cleanStr.contains('hour') || cleanStr.contains('hr')) {
        final hours = int.tryParse(cleanStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return hours * 60;
      } else {
        return int.tryParse(cleanStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      }
    } catch (e) {
      return 0;
    }
  }

  IconData _getIconFromInstruction(String instruction) {
    final lower = instruction.toLowerCase();

    if (lower.contains('izquierda') || lower.contains('left')) {
      if (lower.contains('ligera') || lower.contains('slight')) {
        return Icons.turn_slight_left;
      } else if (lower.contains('pronunciada') || lower.contains('sharp')) {
        return Icons.turn_sharp_left;
      }
      return Icons.turn_left;
    }

    if (lower.contains('derecha') || lower.contains('right')) {
      if (lower.contains('ligera') || lower.contains('slight')) {
        return Icons.turn_slight_right;
      } else if (lower.contains('pronunciada') || lower.contains('sharp')) {
        return Icons.turn_sharp_right;
      }
      return Icons.turn_right;
    }

    if (lower.contains('rotonda') || lower.contains('roundabout')) {
      return Icons.roundabout_left;
    }

    if (lower.contains('retorno') || lower.contains('u-turn')) {
      return Icons.u_turn_left;
    }

    if (lower.contains('incorpor') || lower.contains('merge')) {
      return Icons.merge;
    }

    if (lower.contains('rampa') || lower.contains('ramp')) {
      return Icons.ramp_right;
    }

    if (lower.contains('destino') || lower.contains('destination') || lower.contains('llegada')) {
      return Icons.location_on;
    }

    return Icons.straight;
  }

  void _addRouteMarkers(AppLocalizations l10n) {
    _markers.removeWhere((m) =>
        m.markerId.value == 'origin' ||
        m.markerId.value == 'destination' ||
        m.markerId.value == 'pickup');

    _markers.add(
      Marker(
        markerId: MarkerId('origin'),
        position: _pickupLocation ?? _currentLocation,
        icon: _personIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: _pickupAddress),
      ),
    );

    _markers.add(
      Marker(
        markerId: MarkerId('destination'),
        position: _finalDestination ?? _destination,
        icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: _destinationAddress),
      ),
    );
  }

  void _drawSimpleFallbackRoute(AppLocalizations l10n) {
    debugPrint('Dibujando ruta fallback (linea recta)');

    final fallbackOrigin = (_isTripInProgress && _pickupLocation != null)
        ? _pickupLocation!
        : _currentLocation;
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: PolylineId('route'),
          points: [fallbackOrigin, _destination],
          color: AppColors.rappiOrange,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    });

    _addRouteMarkers(l10n);
  }

  void _updateCurrentInstruction(AppLocalizations l10n) {
    if (_currentInstructionIndex < _instructions.length) {
      final current = _instructions[_currentInstructionIndex];
      _currentInstruction = current.instruction;
      _distanceToNext = current.distance.toDouble();
      _estimatedTime = current.duration;

      if (_currentInstructionIndex + 1 < _instructions.length) {
        _nextInstruction = _instructions[_currentInstructionIndex + 1].instruction;
      } else {
        _nextInstruction = 'Llegando al destino';
      }
    }
  }

  void _startNavigation() {
    setState(() {
      _isNavigating = true;
    });

    _startRealTimeLocationTracking();
  }

  Future<void> _startRealTimeLocationTracking() async {
    try {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          if (_isDisposed || !mounted) return;

          final isFirstGpsLocation = !_hasRealGpsLocation;

          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
            _hasRealGpsLocation = true;
          });

          _updateLocationMarker();
          _updateDriverLocationInFirebase(position);
          _checkNavigationProgress();

          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _currentLocation,
                zoom: 15.5,
                tilt: 45,
                bearing: position.heading,
              ),
            ),
          );

          if (isFirstGpsLocation) {
            debugPrint('Primera ubicación GPS real (stream), FORZANDO cálculo de ruta...');
            _isFetchingRoute = false;
            _isRouteInitialized = false;
            _initializeRoute(AppLocalizations.of(context)!);
          }
        },
        onError: (error) {
          Logger.error('Error en stream de ubicación', error);
        },
      );
    } catch (e) {
      Logger.error('Error iniciando tracking de ubicación', e);
    }
  }

  Future<void> _updateDriverLocationInFirebase(Position position) async {
    // Nombre conservado por compatibilidad con las llamadas existentes.
    // Ahora reporta la posición del conductor al backend Node vía heartbeat.
    // El endpoint /api/drivers/presence acepta activeRideId para asociar la
    // localización al viaje activo (equivalente al `driverLocation` viejo).
    try {
      await _api.heartbeat(
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
        accuracy: position.accuracy,
        speed: position.speed,
        activeRideId: _tripId,
      );
    } catch (e) {
      Logger.error('Error enviando heartbeat al backend', e);
    }
  }

  void _checkNavigationProgress() {
    if (!mounted || _isDisposed) return;

    final l10n = AppLocalizations.of(context)!;

    final distanceToDestination = Geolocator.distanceBetween(
      _currentLocation.latitude,
      _currentLocation.longitude,
      _destination.latitude,
      _destination.longitude,
    );

    setState(() {
      _distanceToNext = distanceToDestination;
      // Unified ETA formula: 30 km/h average city speed
      _estimatedTime = ((distanceToDestination / 1000) / 30 * 60).round();
      _totalTime = _estimatedTime;

      if (_isTripInProgress && _finalDestination != null) {
        final distanceToFinal = Geolocator.distanceBetween(
          _currentLocation.latitude,
          _currentLocation.longitude,
          _finalDestination!.latitude,
          _finalDestination!.longitude,
        );
        _isNearFinalDestination = distanceToFinal < 100;
      }
    });

    if (distanceToDestination < 50) {
      if (_isNavigatingToPickup) {
        _arriveAtPickup(l10n);
      } else {
        _arriveAtDestination(l10n);
      }
    }

    if (_currentInstructionIndex < _instructions.length - 1) {
      final nextInstruction = _instructions[_currentInstructionIndex];
      final distanceToNextPoint = Geolocator.distanceBetween(
        _currentLocation.latitude,
        _currentLocation.longitude,
        nextInstruction.position.latitude,
        nextInstruction.position.longitude,
      );

      if (distanceToNextPoint < 30) {
        setState(() {
          _currentInstructionIndex++;
          _updateCurrentInstruction(l10n);
        });
        _showVoiceNotification();
      }
    }
  }

  void _updateLocationMarker() {
    _markers.removeWhere((marker) => marker.markerId.value == 'current');
    _markers.add(
      Marker(
        markerId: MarkerId('current'),
        position: _currentLocation,
        icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        anchor: Offset(0.5, 0.5),
        flat: true,
        // rotation not needed here — camera bearing follows GPS heading
        infoWindow: InfoWindow(title: 'Tu ubicación'),
      ),
    );
  }

  void _showVoiceNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.volume_up, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(_currentInstruction)),
          ],
        ),
        backgroundColor: AppColors.getTextPrimary(context),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _arriveAtPickup(AppLocalizations l10n) {
    _positionStream?.cancel();
    _positionStream = null;
    _locationTimer?.cancel();

    setState(() {
      _isNavigating = false;
      _currentInstruction = '¡Has llegado al punto de recogida!';
    });

    _updatePickupArrival();
    _showPickupArrivalDialog(l10n);
  }

  Future<void> _updatePickupArrival() async {
    if (_tripId == null) return;

    try {
      await _api.markRideArrived(_tripId!);
    } catch (e) {
      Logger.error('Error actualizando llegada al punto de recogida', e);
    }
  }

  void _arriveAtDestination(AppLocalizations l10n) {
    _positionStream?.cancel();
    _positionStream = null;
    _locationTimer?.cancel();

    setState(() {
      _isNavigating = false;
      _currentInstruction = 'Has llegado al destino';
    });

    _updateTripArrival();
    _showArrivalDialog(l10n);
  }

  Future<void> _updateTripArrival() async {
    if (_tripId == null) return;

    try {
      await _api.markRideArrived(_tripId!);
    } catch (e) {
      Logger.error('Error actualizando llegada del viaje', e);
    }
  }

  void _startWaitingTimer() {
    _arrivalTime = DateTime.now();
    _waitingSeconds = 0;

    _waitingTimer?.cancel();

    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isDisposed && _hasArrivedAtPickup) {
        setState(() {
          _waitingSeconds++;
        });
      }
    });
  }

  String _formatWaitingTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _onDriverArrivedAtPickup() async {
    debugPrint(userFriendlyError(_tripId, fallback: 'BOTON LLEGUE PRESIONADO - tripId'));
    if (_tripId == null) {
      debugPrint('ERROR: _tripId es NULL, no se puede continuar');
      return;
    }

    await HapticFeedback.mediumImpact();

    try {
      await _api.markRideArrived(_tripId!);

      if (!mounted) return;

      setState(() {
        _hasArrivedAtPickup = true;
        _isWaitingForPassenger = true;
        _isNavigating = false;
      });

      _startWaitingTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Has llegado. Espera al pasajero y toca "Comenzo el viaje" cuando suba.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      Logger.error('Error marcando llegada', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al marcar llegada'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _startTrip() async {
    if (_tripId == null) return;

    try {
      _waitingTimer?.cancel();
      _waitingTimer = null;

      // TODO(node-migration): reemplazar con endpoint que reciba waitingTimeSeconds
      // cuando el backend acepte ese campo. Por ahora sólo iniciamos el viaje.
      await _api.startRide(_tripId!);

      if (!mounted) return;

      setState(() {
        _isWaitingForPassenger = false;
        _isTripInProgress = true;
        _isNavigatingToPickup = false;
        if (_finalDestination != null) {
          _destination = _finalDestination!;
          debugPrint(userFriendlyError(_destination, fallback: 'Destino actualizado al destino final'));
        }
      });

      _isRouteInitialized = false;
      _initializeRoute(AppLocalizations.of(context)!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Viaje iniciado! Dirigete al destino.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      Logger.error('Error iniciando viaje', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar viaje'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _completeTrip() async {
    if (_tripId == null) return;

    try {
      await _api.completeRide(
        _tripId!,
        finalFare: _fare,
        distanceMeters: _totalDistance.round(),
        durationSeconds: _totalTime * 60,
      );

      if (!mounted) return;

      _showRatingDialog();
    } catch (e) {
      Logger.error('Error completando viaje', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al completar viaje'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showRatingDialog() {
    int rating = 5;
    String selectedTag = '';

    final positiveTags = ['Amable', 'Puntual', 'Respetuoso', 'Buen trato'];
    final negativeTags = ['Impuntual', 'Grosero', 'Ubicación incorrecta', 'Cancelador'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final tags = rating >= 4 ? positiveTags : negativeTags;
          final ratingMessages = {
            5: 'Excelente',
            4: 'Muy bien',
            3: 'Regular',
            2: 'Malo',
            1: 'Muy malo',
          };

          final ratingColors = {
            5: AppColors.success,
            4: AppColors.rappiOrange,
            3: AppColors.warning,
            2: Colors.orange,
            1: AppColors.error,
          };

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with passenger photo
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.rappiOrange, AppColors.rappiOrange.withValues(alpha: 0.7)],
                            ),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                          ),
                        ),
                        Positioned(
                          top: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.rappiOrange.withValues(alpha: 0.1),
                              backgroundImage: _passengerPhoto.isNotEmpty
                                  ? NetworkImage(_passengerPhoto)
                                  : null,
                              child: _passengerPhoto.isEmpty
                                  ? const Icon(Icons.person, size: 36, color: AppColors.rappiOrange)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 44),

                    // Passenger name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _passengerName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '¿Como fue tu experiencia?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Stars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              rating = index + 1;
                              selectedTag = '';
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: index < rating ? Colors.amber : Colors.grey.shade300,
                              size: 44,
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 8),

                    // Rating message
                    Text(
                      ratingMessages[rating] ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ratingColors[rating] ?? AppColors.getTextPrimary(context),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tags
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: tags.map((tag) {
                          final isSelected = selectedTag == tag;
                          return GestureDetector(
                            onTap: () => setDialogState(() {
                              selectedTag = isSelected ? '' : tag;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.rappiOrange.withValues(alpha: 0.1)
                                    : AppColors.getInputFill(context),
                                border: Border.all(
                                  color: isSelected ? AppColors.rappiOrange : AppColors.getBorder(context),
                                  width: isSelected ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? AppColors.rappiOrange : AppColors.getTextSecondary(context),
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                Navigator.of(context).pop();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: AppColors.getBorder(context)),
                                ),
                              ),
                              child: Text(
                                'Omitir',
                                style: TextStyle(color: AppColors.getTextSecondary(context), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () async {
                                    final dialogNav = Navigator.of(dialogContext);
                                    final mainNav = Navigator.of(context);

                                    if (_tripId != null) {
                                      // El conductor califica al pasajero mediante el endpoint /rate.
                                      // El backend distingue quién califica por el JWT (role=driver).
                                      try {
                                        await _api.rateRide(
                                          _tripId!,
                                          stars: rating.toDouble(),
                                          comment: selectedTag.isNotEmpty ? selectedTag : null,
                                        );
                                      } catch (e) {
                                        Logger.error('Error enviando calificación', e);
                                      }
                                    }
                                    if (!mounted) return;
                                    dialogNav.pop();
                                    if (mounted) mainNav.pop();
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: Text(
                                        'Enviar',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showArrivalDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 32),
            SizedBox(width: 12),
            Text('¡Llegaste!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Has llegado exitosamente al destino'),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.route, size: 20, color: AppColors.getTextSecondary(dialogContext)),
                SizedBox(width: 8),
                Text('${(_totalDistance / 1000).toStringAsFixed(1)} km'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer, size: 20, color: AppColors.getTextSecondary(dialogContext)),
                SizedBox(width: 8),
                Text('$_totalTime min'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  void _showPickupArrivalDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.location_on, color: AppColors.success, size: 32),
            SizedBox(width: 12),
            Expanded(child: Text('¡Llegaste al punto de recogida!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Has llegado al punto de recogida. Espera al pasajero para iniciar el viaje.'),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.person, size: 20, color: AppColors.getTextSecondary(dialogContext)),
                SizedBox(width: 8),
                Expanded(child: Text(_passengerName)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.place, size: 20, color: AppColors.getTextSecondary(dialogContext)),
                SizedBox(width: 8),
                Expanded(child: Text(_pickupAddress, maxLines: 2, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _transitionToWaitingForPassenger();
            },
            child: Text('Continuar', style: TextStyle(color: AppColors.rappiOrange)),
          ),
        ],
      ),
    );
  }

  void _transitionToWaitingForPassenger() {
    setState(() {
      _hasArrivedAtPickup = true;
      _isWaitingForPassenger = true;
      _isNavigating = false;
    });

    _startWaitingTimer();
  }

  // Llamar al pasajero por telefono
  Future<void> _callPassenger() async {
    if (_passengerPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Número de teléfono no disponible'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final uri = Uri.parse('tel:$_passengerPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      Logger.error('Error llamando al pasajero', e);
    }
  }

  // Abrir chat con el pasajero
  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserName: _passengerName,
          otherUserRole: 'passenger',
          otherUserId: _passengerId,
          rideId: _tripId ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!_isRouteInitialized) {
      _currentInstruction = 'Calculando ruta...';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initializeRoute(l10n);
        }
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // ---- Mapa ----
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 16,
              tilt: 45,
              bearing: 90,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _applyMapStyle();
              // If route wasn't fetched yet (timing issue), retry now that map is ready
              if (_polylines.isEmpty && _hasRealGpsLocation) {
                _isFetchingRoute = false;
                _fetchRealRoute(AppLocalizations.of(context)!);
              }
            },
            onTap: (_) => FocusScope.of(context).unfocus(),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            buildingsEnabled: true,
            trafficEnabled: true,
          ),

          // ---- ETA flotante sobre el mapa (pantalla 1: yendo al pasajero) ----
          if (!_hasArrivedAtPickup)
            Positioned(
              top: MediaQuery.of(context).padding.top + 50,
              left: 0,
              right: 0,
              child: Center(child: _buildEtaBadge()),
            ),

          // ---- Top gradient overlay + top bar + banner ----
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Colors.white,
                    Colors.white.withValues(alpha:0.85),
                    Colors.white.withValues(alpha:0.0),
                  ],
                  stops: [0.0, 0.4, 0.7, 1.0],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTopBar(l10n),
                    if (_isWaitingForPassenger) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: _buildPassengerNotifiedBanner(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ---- Boton Navegador (pill) abajo-izquierda del mapa ----
          Positioned(
            left: 16,
            bottom: 380,
            child: _buildNavigatorPill(),
          ),

          // ---- Botones flotantes derechos (compartir ruta, escudo seguridad) ----
          Positioned(
            right: 16,
            bottom: 390,
            child: Column(
              children: [
                _buildRoundFloatingButton(
                  icon: Icons.share_location_outlined,
                  onPressed: _openGoogleMapsNavigation,
                  tooltip: 'Abrir en navegador',
                ),
                SizedBox(height: 10),
                _buildRoundFloatingButton(
                  icon: Icons.shield_outlined,
                  onPressed: () {},
                  tooltip: 'Seguridad',
                ),
              ],
            ),
          ),

          // ---- Bottom sheet con info del pasajero ----
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 300 * (1 - _slideAnimation.value)),
                  child: _buildPassengerBottomSheet(l10n),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ETA badge grande estilo inDrive (circulo amarillo con tiempo + icono auto)
  Widget _buildEtaBadge() {
    // _totalTime is already in minutes
    final etaText = _totalTime > 0
        ? '$_totalTime min'
        : '< 1 min';

    return Text(
      etaText,
      style: TextStyle(
        color: Colors.black87,
        fontSize: 52,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
        height: 1.0,
        shadows: [
          Shadow(color: Colors.white, blurRadius: 12),
          Shadow(color: Colors.white, blurRadius: 24),
        ],
      ),
    );
  }

  // Banner "El pasajero fue notificado" — texto grande sobre gradient blanco
  Widget _buildPassengerNotifiedBanner() {
    return Text(
      'El pasajero fue notificado',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: Colors.black87,
      ),
    );
  }

  // Barra superior: cancelar (siempre), + timer de espera si esta esperando
  Widget _buildTopBar(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila 1: Cancelar a la derecha
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Spacer(),
              GestureDetector(
                onTap: () => _cancelNavigation(l10n),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Divider
        if (_isWaitingForPassenger)
          Divider(height: 1, color: AppColors.getBorder(context)),
        // Fila 2: Tiempo de espera (solo en estado esperando)
        if (_isWaitingForPassenger)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  'Tiempo de espera',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Spacer(),
                Text(
                  _formatWaitingTime(_waitingSeconds),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: _waitingSeconds >= 300
                        ? AppColors.error
                        : _waitingSeconds >= 180
                            ? Colors.orange
                            : Colors.black,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        // Si no está esperando, solo Cancelar sin timer (pantalla 1 y 3)
        if (!_isWaitingForPassenger)
          SizedBox.shrink(),
      ],
    );
  }

  // Pill "Navegador" abajo-izquierda estilo inDrive
  Widget _buildNavigatorPill() {
    return GestureDetector(
      onTap: _openGoogleMapsNavigation,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.25),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.navigation, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text(
              'Navegador',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Botón flotante redondo (compartir ruta, seguridad)
  Widget _buildRoundFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.15),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 22, color: AppColors.getTextPrimary(context)),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
      ),
    );
  }

  // Bottom sheet con info del pasajero estilo inDrive
  Widget _buildPassengerBottomSheet(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.18),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.getBorder(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16),

          // Fila principal: foto+nombre+rating | direcciones | botones
          _buildPassengerInfoRow(),

          SizedBox(height: 14),
          Divider(color: AppColors.getBorder(context), height: 1),
          SizedBox(height: 14),

          // Fila precio
          _buildPriceRow(),

          SizedBox(height: 16),

          // Botón de acción principal (cambia según estado)
          _buildActionButton(l10n),
        ],
      ),
    );
  }

  // Fila de información del pasajero
  Widget _buildPassengerInfoRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna: foto + nombre + rating
        Column(
          children: [
            _buildPassengerAvatar(),
            SizedBox(height: 6),
            Text(
              _passengerName.split(' ').first,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 14),
                SizedBox(width: 2),
                Text(
                  _passengerRating.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                if (_passengerTripCount > 0) ...[
                  Text(
                    ' ($_passengerTripCount)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        SizedBox(width: 14),

        // Columna: direcciones + badge de pago
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dirección de recogida (A)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Color(0xFF34A853),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _pickupAddress,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              // Dirección destino (B)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Color(0xFF4285F4),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'B',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _destinationAddress,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              // Badge de metodo de pago
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _inDriveLime.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _inDriveLime, width: 1),
                ),
                child: Text(
                  _paymentMethod,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5A6B00),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 10),

        // Columna: botones llamar + chat
        Column(
          children: [
            _buildActionCircleButton(
              icon: Icons.phone,
              color: _inDriveLime,
              onPressed: _callPassenger,
            ),
            SizedBox(height: 10),
            _buildActionCircleButton(
              icon: Icons.chat_bubble_outline,
              color: _inDriveLime,
              onPressed: _openChat,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPassengerAvatar() {
    final hasPhoto = _passengerPhoto.isNotEmpty;

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.getBorder(context), width: 2),
        color: AppColors.getInputFill(context),
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.network(
                _passengerPhoto,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildAvatarFallback(),
              )
            : _buildAvatarFallback(),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      color: AppColors.rappiOrange.withValues(alpha:0.1),
      child: Icon(
        Icons.person,
        size: 32,
        color: AppColors.rappiOrange,
      ),
    );
  }

  Widget _buildActionCircleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha:0.35),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 24, color: Colors.black87),
      ),
    );
  }

  // Fila de precio
  Widget _buildPriceRow() {
    final fareText = _fare > 0
        ? 'S/ ${_fare.toStringAsFixed(2)} · $_paymentMethod'
        : 'Precio acordado · $_paymentMethod';

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.getInputFill(context),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.payments_outlined,
            size: 22,
            color: AppColors.getTextSecondary(context),
          ),
        ),
        SizedBox(width: 12),
        Text(
          fareText,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.getTextPrimary(context),
          ),
        ),
      ],
    );
  }

  // Botón de acción principal (cambia según estado)
  Widget _buildActionButton(AppLocalizations l10n) {
    if (_isTripInProgress) {
      // Estado 3: viaje en curso -> "Completar viaje"
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _completeTrip,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: Text(
            'Completar viaje',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else if (_isWaitingForPassenger) {
      // Estado 2: esperando pasajero -> "Comenzó el viaje" (verde-lima)
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _startTrip,
          style: ElevatedButton.styleFrom(
            // Ronda 249: _inDriveLime en realidad contiene el ROJO #E31E24
            // (nombre engañoso), así que era texto negro sobre rojo saturado
            // con contraste ~3:1 — ilegible.
            backgroundColor: _inDriveLime,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            'Comenzó el viaje',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else {
      // Estado 1: yendo al pasajero -> "Ya llegué" (azul)
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _onDriverArrivedAtPickup,
          style: ElevatedButton.styleFrom(
            // Ronda 249: segundo "Ya llegué" azul Google — el mismo literal
            // copiado desde active_trip_screen. Arreglar solo uno dejaba el
            // otro azul.
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            'Ya llegué',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  // Panel de espera del pasajero (se mantiene como metodo para _buildInstructionPanel)
  Widget _buildWaitingForPassengerPanel(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: _waitingSeconds >= 300
                ? AppColors.error.withValues(alpha:0.1)
                : _waitingSeconds >= 180
                    ? Colors.orange.withValues(alpha:0.1)
                    : AppColors.success.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _waitingSeconds >= 300
                  ? AppColors.error
                  : _waitingSeconds >= 180
                      ? Colors.orange
                      : AppColors.success,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer,
                color: _waitingSeconds >= 300
                    ? AppColors.error
                    : _waitingSeconds >= 180
                        ? Colors.orange
                        : AppColors.success,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Tiempo de espera: ',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              Text(
                _formatWaitingTime(_waitingSeconds),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: _waitingSeconds >= 300
                      ? AppColors.error
                      : _waitingSeconds >= 180
                          ? Colors.orange
                          : AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _recenterMap() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation,
          zoom: 16,
          tilt: 45,
          bearing: 90,
        ),
      ),
    );
  }

  void _cancelNavigation(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancelar navegación'),
        content: const Text('¿Estás seguro de que deseas cancelar la navegación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }

  void _applyMapStyle() {
    const String mapStyle = '''
    [
      {
        "featureType": "poi",
        "elementType": "labels",
        "stylers": [{"visibility": "off"}]
      }
    ]
    ''';
    _mapController?.setMapStyle(mapStyle);
  }

  Future<void> _openGoogleMapsNavigation() async {
    final lat = _destination.latitude;
    final lng = _destination.longitude;

    final googleMapsUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final fallbackUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else {
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      Logger.error('Error abriendo Google Maps', e);
      try {
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo abrir Google Maps'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

class RouteInstruction {
  final String instruction;
  final double distance;
  final int duration;
  final IconData turnIcon;
  final LatLng position;

  RouteInstruction({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.turnIcon,
    required this.position,
  });
}
