// ignore_for_file: unused_element
// Pantalla de viaje activo para el conductor
// Muestra el estado actual del viaje y permite al conductor:
// - Marcar que llegó al punto de recogida
// - Verificar código del pasajero
// - Iniciar el viaje
// - Finalizar el viaje
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:math' as math;
// TimeoutException ya está disponible en dart:async
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/utils/payment_utils.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../services/maps_service.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../models/trip_model.dart';
import '../../services/rapi_api_client.dart';
import '../../services/rapi_sse_client.dart';
import '../shared/rating_dialog.dart';
import '../shared/chat_screen.dart';
import '../../utils/map_marker_utils.dart';
import '../../utils/error_messages.dart';

/// Estados del viaje desde la perspectiva del conductor
enum DriverTripState {
  goingToPickup,    // Yendo al punto de recogida
  arrivedAtPickup,  // Llegó al punto de recogida
  waitingVerification, // Esperando verificación mutua
  inProgress,       // Viaje en curso
  arrivedAtDestination, // Llegó al destino
  completed,        // Viaje completado
}

class ActiveTripScreen extends StatefulWidget {
  final String tripId;
  final TripModel? initialTrip;
  final LatLng? initialLocation;

  const ActiveTripScreen({
    super.key,
    required this.tripId,
    this.initialTrip,
    this.initialLocation,
  });

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen>
    with TickerProviderStateMixin {
  final RapiApiClient _api = RapiApiClient.instance;
  final RapiSseClient _sse = RapiSseClient.instance;

  // Completer para Animarker
  final Completer<GoogleMapController> _mapCompleter = Completer<GoogleMapController>();
  GoogleMapController? _mapController;
  StreamSubscription<Map<String, dynamic>>? _tripSubscription;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _locationUpdateTimer;

  TripModel? _currentTrip;
  DriverTripState _tripState = DriverTripState.goingToPickup;
  LatLng? _currentLocation;
  double _currentHeading = 0.0; // Heading del GPS para rotación del marcador

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Iconos modernos para marcadores
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destinationIcon;

  bool _isLoading = false;
  bool _isDisposed = false;
  // Guard contra concurrent _drawRouteAsync — sin esto, cada GPS tick puede
  // observar _polylines.isEmpty=true si la primera Directions call aún no
  // completó, disparando N requests duplicadas por state change.
  bool _routeInFlight = false;
  bool _isFollowingDriver = true; // Toggle for camera follow

  // Ronda 255: medimos la altura REAL del bottom sheet para colocar encima los
  // botones flotantes del mapa. Antes se usaban constantes (clamp 280-430) que
  // se quedaban cortas cuando el sheet crecía, y el sheet terminaba tapando el
  // botón de recentrar y el de navegación.
  final GlobalKey _sheetKey = GlobalKey();
  double _sheetHeight = 0;

  /// Separación desde abajo para los controles flotantes: justo encima del
  /// sheet. Mientras no se haya medido, usa un valor conservador.
  double get _floatingBottomOffset =>
      (_sheetHeight > 0 ? _sheetHeight : 300.0) + 16;

  /// Vuelve a medir el sheet después de cada frame. Es barato (solo lee el
  /// RenderBox ya calculado) y solo llama a setState cuando la altura cambió
  /// de verdad, así que no provoca bucles de rebuild.
  void _measureSheet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _sheetKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final h = box.size.height;
      if ((h - _sheetHeight).abs() > 1.0) {
        setState(() => _sheetHeight = h);
      }
    });
  }

  // Waiting timer for arrived at pickup state
  Timer? _waitingTimer;
  int _waitingSeconds = 0;

  // Para verificación de código
  final TextEditingController _codeController = TextEditingController();

  // Animations
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    debugPrint('🚗 ActiveTripScreen.initState - tripId=${widget.tripId}, hasInitialTrip=${widget.initialTrip != null}, initialLocation=${widget.initialLocation}');
    // Use initial location from home screen for immediate marker display
    if (widget.initialLocation != null) {
      _currentLocation = widget.initialLocation;
    }
    // Fallback: if no initial location, use pickup location from trip
    if (_currentLocation == null && widget.initialTrip != null) {
      _currentLocation = LatLng(
        widget.initialTrip!.pickupLocation.latitude,
        widget.initialTrip!.pickupLocation.longitude,
      );
    }
    _initAnimations();
    _initAsync();
    _startLocationTracking();
    _listenToTripUpdates();
  }

  /// Load icons BEFORE loading trip to avoid race condition
  Future<void> _initAsync() async {
    await _loadCarIcon();
    _loadTrip();
  }

  /// Load custom marker icons using MapMarkerUtils (same as passenger screen)
  Future<void> _loadCarIcon() async {
    try {
      _carIcon = await MapMarkerUtils.getCarTopViewIcon();
      _pickupIcon = await MapMarkerUtils.getPassengerWaitingIcon();
      _destinationIcon = await MapMarkerUtils.getDestinationIcon();
      debugPrint('✅ Iconos de mapa cargados correctamente (MapMarkerUtils)');
      if (mounted && !_isDisposed) {
        _updateMapMarkers();
        setState(() {});
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando iconos: $e');
    }
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tripSubscription?.cancel();
    _positionSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _waitingTimer?.cancel();
    _pulseController.dispose();
    _codeController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadTrip() async {
    // Guard: prevent Firestore query with empty tripId
    if (widget.tripId.isEmpty && widget.initialTrip == null) {
      debugPrint('Error: tripId is empty and no initialTrip provided');
      if (mounted) Navigator.pop(context);
      return;
    }

    if (widget.initialTrip != null) {
      setState(() {
        _currentTrip = widget.initialTrip;
        _updateTripState();
      });
    } else {
      try {
        final response = await _api
            .getRide(widget.tripId)
            .timeout(const Duration(seconds: 15), onTimeout: () {
          throw TimeoutException('Timeout cargando viaje');
        });
        final rideJson = _extractRide(response);
        if (mounted) {
          setState(() {
            _currentTrip = TripModel.fromJson({'id': widget.tripId, ...rideJson});
            _updateTripState();
          });
        }
      } on TimeoutException catch (e) {
        debugPrint('⏱️ $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error de conexión. Reintentando...'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      } catch (e) {
        debugPrint(userFriendlyError(e, fallback: 'Error cargando viaje'));
      }
    }
    _updateMapMarkers();
  }

  Map<String, dynamic> _extractRide(Map<String, dynamic> response) {
    final nested = response['ride'];
    if (nested is Map<String, dynamic>) return nested;
    return response;
  }

  void _listenToTripUpdates() {
    _sse.start();
    _tripSubscription = _sse.rideUpdates.listen((event) {
      if (_isDisposed || !mounted) return;

      final rideId = (event['rideId'] as String?) ??
          (event['id'] as String?) ??
          ((event['ride'] as Map<String, dynamic>?)?['id'] as String?);
      if (rideId != widget.tripId) return;

      final ridePartial = _extractRide(event);
      final status = ridePartial['status'] as String?;

      // Check if ride was cancelled or has a terminal status
      if (status == 'cancelled' ||
          status == 'cancelled_by_passenger' ||
          status == 'cancelled_by_driver' ||
          event['type'] == 'ride_deleted') {
        debugPrint('🚗 ActiveTripScreen: Ride ${widget.tripId} was cancelled (status=$status)');
        _handleRideGone();
        return;
      }

      // Check if ride was completed externally (e.g., by passenger or admin)
      final wasCompleted = _tripState == DriverTripState.completed;

      final currentJson = _currentTrip?.toJson() ?? const <String, dynamic>{};
      setState(() {
        _currentTrip = TripModel.fromJson({
          ...currentJson,
          ...ridePartial,
          'id': widget.tripId,
        });
        _updateTripState();
        _updateMapMarkers();
      });

      // If trip just transitioned to completed and we didn't trigger it locally,
      // show the completed dialog so the driver isn't stuck
      if (!wasCompleted && _tripState == DriverTripState.completed) {
        debugPrint('🚗 ActiveTripScreen: Ride ${widget.tripId} completed externally, showing dialog');
        final finalFare = _currentTrip?.estimatedFare ?? 0.0;
        _showTripCompletedDialog(finalFare);
      }
    });
  }

  /// Handle when the ride document is deleted or cancelled
  void _handleRideGone() {
    if (_isDisposed || !mounted) return;

    // Cancel all subscriptions to avoid further updates
    _tripSubscription?.cancel();
    _positionSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _waitingTimer?.cancel();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('El viaje fue cancelado o ya no existe'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );

    Navigator.of(context).pop();
  }

  void _updateTripState() {
    if (_currentTrip == null) return;

    final oldState = _tripState;

    switch (_currentTrip!.status) {
      case 'accepted':
      case 'on_way':
        _tripState = DriverTripState.goingToPickup;
        break;
      case 'arrived':
      case 'driver_arriving':  // legacy Firestore, mantener compat
        _tripState = DriverTripState.arrivedAtPickup;
        break;
      case 'in_progress':
      case 'waiting_verification':  // legacy — treat as in_progress
      case 'arriving_destination':  // legacy
        _tripState = DriverTripState.inProgress;
        break;
      case 'completed':
        _tripState = DriverTripState.completed;
        break;
      default:
        _tripState = DriverTripState.goingToPickup;
    }

    // Force route redraw when state changes
    if (oldState != _tripState) {
      _polylines.clear();
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted && !_isDisposed) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        if (_isDisposed || !mounted) return;

        // Filtro GPS: descartar lecturas con baja precisión
        if (position.accuracy > 50) return;

        // Actualizar heading: usar GPS si hay velocidad, o calcular por posiciones
        if (position.speed > 0.5 && position.heading > 0) {
          _currentHeading = position.heading;
        } else if (_currentLocation != null) {
          // Fallback: calcular bearing entre posición anterior y actual
          final newLat = position.latitude;
          final newLng = position.longitude;
          final dLat = newLat - _currentLocation!.latitude;
          final dLng = newLng - _currentLocation!.longitude;
          if (dLat.abs() > 0.00001 || dLng.abs() > 0.00001) {
            final y = math.sin(dLng * math.pi / 180) * math.cos(newLat * math.pi / 180);
            final x = math.cos(_currentLocation!.latitude * math.pi / 180) * math.sin(newLat * math.pi / 180) -
                math.sin(_currentLocation!.latitude * math.pi / 180) * math.cos(newLat * math.pi / 180) * math.cos(dLng * math.pi / 180);
            final calculatedBearing = (math.atan2(y, x) * 180 / math.pi + 360) % 360;
            _currentHeading = calculatedBearing;
          }
        }

        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _updateMapMarkers();
        _updateLocationInFirebase();
      });
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error iniciando tracking de ubicación'));
    }
  }

  Future<void> _updateLocationInFirebase() async {
    if (_currentLocation == null || _currentTrip == null) return;

    try {
      // Un solo heartbeat al backend: éste replica la ubicación al ride y al
      // presence del conductor. Reemplaza los dos writes previos a Firestore.
      await _api
          .heartbeat(
            latitude: _currentLocation!.latitude,
            longitude: _currentLocation!.longitude,
            heading: _currentHeading,
            activeRideId: widget.tripId,
          )
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Timeout actualizando ubicación');
      });
    } on TimeoutException {
      debugPrint('⏱️ Timeout en actualización de ubicación');
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error actualizando ubicación'));
    }
  }

  void _updateMapMarkers() {
    if (_currentTrip == null) {
      debugPrint('🚗 _updateMapMarkers: _currentTrip es NULL');
      return;
    }

    debugPrint('🚗 _updateMapMarkers: trip=${_currentTrip!.id}, location=$_currentLocation, carIcon=${_carIcon != null}');
    _markers.clear();

    // Marcador de ubicación actual del conductor con icono moderno
    if (_currentLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _currentLocation!,
        icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.5),
        flat: true,
        rotation: _currentHeading,
        zIndexInt: 10,
        infoWindow: const InfoWindow(title: 'Tu ubicación'),
      ));
    }

    // Marcador de recogida — ocultar si conductor ya llegó o viaje en progreso
    final hidePickup = _tripState == DriverTripState.inProgress ||
        _tripState == DriverTripState.arrivedAtDestination;
    if (!hidePickup) {
      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(
          _currentTrip!.pickupLocation.latitude,
          _currentTrip!.pickupLocation.longitude,
        ),
        icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        zIndexInt: 1,
        infoWindow: InfoWindow(
          title: 'Punto de recogida',
          snippet: _currentTrip!.pickupAddress,
        ),
      ));
    }

    // Marcador de destino (icono moderno rojo)
    _markers.add(Marker(
      markerId: const MarkerId('destination'),
      position: LatLng(
        _currentTrip!.destinationLocation.latitude,
        _currentTrip!.destinationLocation.longitude,
      ),
      icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: 'Destino',
        snippet: _currentTrip!.destinationAddress,
      ),
    ));

    // Draw route only once per state change (con guard concurrent).
    if (_polylines.isEmpty && !_routeInFlight) {
      _drawRouteAsync();
    }

    // Camera: during trip show full route, during pickup follow driver
    if (_mapController != null && _currentLocation != null) {
      if (_tripState == DriverTripState.inProgress || _tripState == DriverTripState.arrivedAtDestination) {
        // Only fit bounds once (not every GPS update)
      } else if (_isFollowingDriver) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(
            target: _currentLocation!,
            zoom: 17.0,
            bearing: _currentHeading,
            tilt: 45.0,
          )),
        );
      }
    }
  }

  /// Fetch real road route from Google Directions API and draw it
  Future<void> _drawRouteAsync() async {
    if (_currentTrip == null) return;
    if (_routeInFlight) return;
    _routeInFlight = true;
    try {
      await _drawRouteInner();
    } finally {
      _routeInFlight = false;
    }
  }

  Future<void> _drawRouteInner() async {
    final pickupLatLng = LatLng(_currentTrip!.pickupLocation.latitude, _currentTrip!.pickupLocation.longitude);
    final destinationLatLng = LatLng(_currentTrip!.destinationLocation.latitude, _currentTrip!.destinationLocation.longitude);

    LatLng origin;
    LatLng destination;

    if (_tripState == DriverTripState.goingToPickup ||
        _tripState == DriverTripState.arrivedAtPickup ||
        _tripState == DriverTripState.waitingVerification) {
      origin = _currentLocation ?? pickupLatLng;
      destination = pickupLatLng;
    } else {
      origin = pickupLatLng;
      destination = destinationLatLng;
    }

    final routePoints = await _getRoutePoints(origin, destination);
    if (mounted && routePoints.isNotEmpty) {
      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          points: routePoints,
          color: AppColors.rappiOrange,
          width: 5,
        ));
      });
      // Fit camera to show full route
      if (_mapController != null) {
        double minLat = routePoints.map((p) => p.latitude).reduce(math.min);
        double maxLat = routePoints.map((p) => p.latitude).reduce(math.max);
        double minLng = routePoints.map((p) => p.longitude).reduce(math.min);
        double maxLng = routePoints.map((p) => p.longitude).reduce(math.max);
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
            60,
          ),
        );
      }
    }
  }

  // Ronda 213 BUG FIX: antes llamaba Routes API v2 directo con key móvil
  // restringida → REQUEST_DENIED silencioso. Ahora va por MapsService
  // (proxy backend con cascada OSRM/Mapbox/Google, key oculta).
  Future<List<LatLng>> _getRoutePoints(LatLng origin, LatLng destination) async {
    debugPrint('🚗 _getRoutePoints: from=$origin to=$destination');
    final route = await MapsService().getDirections(
      origin: origin,
      destination: destination,
    );
    if (route != null && route.points.isNotEmpty) {
      debugPrint('🚗 Route OK (${route.provider}): ${route.points.length} pts');
      return route.points;
    }
    debugPrint('🚗 Route: MapsService retornó null');
    return []; // Sin fallback a línea recta — solo rutas reales.
  }

  // ==================== WAITING TIMER ====================

  void _startWaitingTimer() {
    _waitingSeconds = 0;
    _waitingTimer?.cancel();
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isDisposed &&
          (_tripState == DriverTripState.arrivedAtPickup ||
           _tripState == DriverTripState.waitingVerification)) {
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

  // ==================== ACCIONES DEL CONDUCTOR ====================

  /// Marcar que el conductor llegó al punto de recogida
  Future<void> _markArrived() async {
    setState(() => _isLoading = true);
    await HapticFeedback.mediumImpact();

    try {
      await _api
          .markRideArrived(widget.tripId)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Timeout marcando llegada');
      });

      // Start waiting timer
      _startWaitingTimer();

      // Backend envía push al pasajero automáticamente al recibir el evento.

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Has llegado. Espera al pasajero y toca "Comenzó el viaje" cuando suba.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError(e, fallback: 'Error')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Mostrar diálogo para ingresar código del pasajero
  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.rappiOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user, color: AppColors.rappiOrange),
            ),
            const SizedBox(width: 12),
            const Text('Verificar Pasajero'),
          ],
        ),
        // Ronda 223: SingleChildScrollView para que con teclado abierto el
        // botón "Verificar" no quede oculto.
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ingresa el código de 4 dígitos que te proporcionará el pasajero:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10,
                ),
                decoration: InputDecoration(
                  hintText: '----',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.rappiOrange, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _codeController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _verifyPassengerCode(_codeController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rappiOrange,
            ),
            child: const Text('Verificar'),
          ),
        ],
      ),
    );
  }

  /// Verificar el código del pasajero
  Future<void> _verifyPassengerCode(String code) async {
    if (code.length != 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El código debe tener 4 dígitos'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Refrescamos el ride desde el backend para obtener el código actual.
      final response = await _api
          .getRide(widget.tripId)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Timeout verificando código');
      });
      final tripData = _extractRide(response);

      final passengerCode = tripData['passengerVerificationCode'] ?? tripData['verificationCode'];

      // ✅ FIX: Validar que el código no sea null antes de comparar
      if (passengerCode == null || passengerCode.toString().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El pasajero aún no tiene código asignado'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (code == passengerCode) {
        // La verificación es solo un check local: marcamos el estado en el
        // TripModel para que la UI muestre la pantalla de "esperando".
        // No hay endpoint dedicado; el backend infiere el estado del start.
        setState(() {
          _currentTrip = _currentTrip?.copyWith(
            isPassengerVerified: true,
            status: 'waiting_verification',
          );
          _updateTripState();
        });

        _codeController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Pasajero verificado correctamente!'),
              backgroundColor: AppColors.success,
            ),
          );

          // Mostrar código del conductor al pasajero
          _showDriverCodeDialog();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Código incorrecto. Inténtalo de nuevo.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError(e, fallback: 'Error verificando')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Mostrar el código del conductor para que el pasajero lo verifique
  void _showDriverCodeDialog() {
    final driverCode = _currentTrip?.driverVerificationCode ?? '----';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.qr_code, color: AppColors.rappiOrange),
            SizedBox(width: 12),
            Text('Tu Código de Verificación'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Muestra este código al pasajero para que lo verifique:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.rappiOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.rappiOrange, width: 2),
              ),
              child: Text(
                driverCode,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                  color: AppColors.rappiOrange,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Una vez que el pasajero verifique este código, podrás iniciar el viaje.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rappiOrange,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  /// Iniciar el viaje (después de verificación mutua)
  Future<void> _startTrip() async {
    setState(() => _isLoading = true);
    await HapticFeedback.mediumImpact();

    // Stop waiting timer
    _waitingTimer?.cancel();
    _waitingTimer = null;

    try {
      await _api
          .startRide(widget.tripId)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Timeout iniciando viaje');
      });

      // Backend dispara el push "trip_started" al pasajero.

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('¡Viaje iniciado! Dirígete al destino.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError(e, fallback: 'Error iniciando viaje')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Finalizar el viaje
  Future<void> _completeTrip() async {
    // Confirmar antes de finalizar
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Finalizar Viaje'),
        content: const Text(
          '¿Estás seguro de que has llegado al destino y deseas finalizar el viaje?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final finalFare = _currentTrip?.estimatedFare ?? 0.0;

      // Backend calcula comisión, actualiza wallet del conductor y notifica al
      // pasajero al recibir /rides/:id/complete.
      await _api
          .completeRide(widget.tripId, finalFare: finalFare)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Timeout completando viaje');
      });

      if (mounted) {
        // Mostrar diálogo de resumen y calificación
        _showTripCompletedDialog(finalFare);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError(e, fallback: 'Error finalizando viaje')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTripCompletedDialog(double finalFare) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        // Ronda 223: SingleChildScrollView para diálogo con muchos elementos
        // (icono + título + ganancia + card de resumen + botones). En pantallas
        // pequeñas los botones quedaban fuera.
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 60,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '¡Viaje Completado!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Ganancia: S/ ${finalFare.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.rappiOrange,
              ),
            ),
            const SizedBox(height: 24),
            // Resumen del viaje
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(Icons.location_on, 'Origen', _currentTrip?.pickupAddress ?? ''),
                  const Divider(),
                  _buildSummaryRow(Icons.flag, 'Destino', _currentTrip?.destinationAddress ?? ''),
                  const Divider(),
                  _buildSummaryRow(
                    Icons.route,
                    'Distancia',
                    '${(_currentTrip?.estimatedDistance ?? 0).toStringAsFixed(1)} km',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Mostrar diálogo de calificación
                  _showRatingDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rappiOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Calificar Pasajero',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.rappiOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog() {
    RatingDialog.show(
      context: context,
      // Ronda 250: leía el nombre del PASAJERO dentro de vehicleInfo (el mapa
      // del VEHÍCULO), que además el backend nunca envía. Ahora usa el campo
      // plano real, con el mapa como respaldo por compatibilidad.
      driverName: _currentTrip?.passengerName ??
          _currentTrip?.vehicleInfo?['passengerName'] ??
          'Pasajero',
      driverPhoto: _currentTrip?.passengerPhotoUrl ??
          _currentTrip?.vehicleInfo?['passengerPhoto'] ??
          '',
      tripId: widget.tripId,
      isDriverRating: true,
      onSubmit: (rating, comment, tags) async {
        // Guardar calificación del conductor hacia el pasajero.
        // El backend persiste stars + comment; los tags aún no tienen endpoint
        // dedicado y se descartan en esta versión.
        try {
          await _api.rateRide(
            widget.tripId,
            stars: rating.toDouble(),
            comment: comment,
          );
        } catch (e) {
          debugPrint(userFriendlyError(e, fallback: 'Error calificando pasajero'));
        }

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );
  }

  // ==================== COMUNICACIÓN CON PASAJERO ====================

  Future<void> _callPassenger() async {
    // Backend adjunta el teléfono del pasajero al ride en `passengerInfo`.
    // No hay endpoint /users/:id, así que sólo usamos ese payload.
    final phoneFromInfo = _currentTrip?.passengerPhone ??
        _currentTrip?.passengerInfo?['passengerPhone'] as String? ??
        _currentTrip?.passengerInfo?['phone'] as String? ??
        '';
    var phone = phoneFromInfo;

    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Número de teléfono no disponible'), backgroundColor: AppColors.warning),
        );
      }
      return;
    }

    if (!phone.startsWith('+')) phone = '+51$phone';
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se puede llamar desde este dispositivo'), backgroundColor: AppColors.warning),
        );
      }
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error al llamar'));
    }
  }

  void _openPassengerChat() {
    if (_currentTrip == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserName: _currentTrip!.passengerName ??
              _currentTrip!.vehicleInfo?['passengerName'] ??
              'Pasajero',
          otherUserRole: 'passenger',
          otherUserId: _currentTrip!.userId,
          rideId: _currentTrip!.id,
        ),
      ),
    );
  }

  // ==================== UTILIDADES ====================

  Future<void> _openNavigation() async {
    if (_currentTrip == null) return;

    LatLng destination;
    String destinationAddress;

    if (_tripState == DriverTripState.goingToPickup ||
        _tripState == DriverTripState.arrivedAtPickup ||
        _tripState == DriverTripState.waitingVerification) {
      destination = LatLng(
        _currentTrip!.pickupLocation.latitude,
        _currentTrip!.pickupLocation.longitude,
      );
      destinationAddress = _currentTrip!.pickupAddress;
    } else {
      destination = LatLng(
        _currentTrip!.destinationLocation.latitude,
        _currentTrip!.destinationLocation.longitude,
      );
      destinationAddress = _currentTrip!.destinationAddress;
    }

    // Codificar la dirección para URL
    final encodedAddress = Uri.encodeComponent(destinationAddress);

    // Usar la dirección como destino principal, con coordenadas como respaldo
    final Uri mapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$encodedAddress&destination_place_id=&travelmode=driving',
    );

    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    } else {
      // Si falla con la dirección, intentar con coordenadas
      final Uri fallbackUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=driving',
      );
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  // ==================== BUILD ====================

  /// Maneja el intento de salir de la pantalla
  Future<void> _handleBackPressed() async {
    if (_tripState == DriverTripState.completed) {
      if (mounted) Navigator.pop(context);
      return;
    }
    _showCancelConfirmation();
  }

  @override
  Widget build(BuildContext context) {
    // Remedir el sheet en cada frame: su altura cambia con el estado del viaje
    // y con lo largas que sean las direcciones.
    _measureSheet();
    final canLeave = _tripState == DriverTripState.completed;
    return PopScope(
      canPop: canLeave,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBackPressed();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Map with markers (same approach as App-Plus navigation_screen)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentLocation ?? const LatLng(-12.0464, -77.0428),
                zoom: 16,
                tilt: 45,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (!_mapCompleter.isCompleted) {
                  _mapCompleter.complete(controller);
                }
              },
              onCameraMoveStarted: () {
                if (_isFollowingDriver) {
                  setState(() => _isFollowingDriver = false);
                }
              },
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

            // Top gradient overlay with top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                // Ronda 255: el gradiente se desvanecía a TRANSPARENTE desde el
                // 70%, y justo ahí viven "Tiempo de espera 00:13" y "El
                // pasajero fue notificado" — quedaban flotando sobre el mapa,
                // encimados con los nombres de calles y negocios. El fondo se
                // acababa antes que el contenido. Ahora es sólido hasta el 92%
                // y solo se difumina en el último tramo.
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.getSurface(context),
                      AppColors.getSurface(context),
                      AppColors.getSurface(context),
                      AppColors.getSurface(context).withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.85, 0.92, 1.0],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTopBar(),
                      if (_tripState == DriverTripState.arrivedAtPickup ||
                          _tripState == DriverTripState.waitingVerification) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: _buildPassengerNotifiedBanner(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Navigator pill (bottom-left on map)
            // Ronda 214: bottom hardcoded 380/390 asumía sheet altura fija.
            // En iPhone SE (667px) el pill quedaba tapado por el sheet.
            // Usar % del screen con clamp para adaptar a todos los sizes.
            // Ronda 255: el `bottom` era un numero magico —
            // clamp(280,420) asumia que el bottom sheet nunca pasa de 420px.
            // Pero el sheet CRECE con el contenido (nombre largo, direcciones
            // de dos lineas), y al crecer se tragaba estos botones: en las
            // capturas el de recentrar aparecia cortado por el borde del
            // sheet. Ahora se mide la altura real del sheet y se colocan
            // encima de el.
            Positioned(
              left: 16,
              bottom: _floatingBottomOffset,
              child: _buildNavigatorPill(),
            ),

            // Floating round buttons (right side)
            Positioned(
              right: 16,
              bottom: _floatingBottomOffset + 10,
              child: Column(
                children: [
                  _buildRoundFloatingButton(
                    icon: Icons.share_location_outlined,
                    onPressed: _openNavigation,
                    tooltip: 'Abrir en navegador',
                  ),
                  const SizedBox(height: 10),
                  if (!_isFollowingDriver)
                    _buildRoundFloatingButton(
                      icon: Icons.my_location,
                      onPressed: () {
                        setState(() => _isFollowingDriver = true);
                        if (_mapController != null && _currentLocation != null) {
                          _mapController!.animateCamera(
                            CameraUpdate.newCameraPosition(CameraPosition(
                              target: _currentLocation!,
                              zoom: 17.0,
                              bearing: _currentHeading,
                              tilt: 45.0,
                            )),
                          );
                        }
                      },
                      tooltip: 'Recentrar mapa',
                    ),
                ],
              ),
            ),

            // Bottom sheet with passenger info
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                key: _sheetKey,
                child: _buildPassengerBottomSheet(),
              ),
            ),

            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black45,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.rappiOrange),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== TOP BAR ====================

  Widget _buildTopBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Cancel button on the right
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: _handleBackPressed,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.arrow_back, color: AppColors.getTextPrimary(context), size: 20),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showCancelConfirmation,
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Row 2: Waiting timer (only when waiting for passenger)
        if (_tripState == DriverTripState.arrivedAtPickup ||
            _tripState == DriverTripState.waitingVerification) ...[
          Divider(height: 1, color: AppColors.getBorder(context)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  'Tiempo de espera',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatWaitingTime(_waitingSeconds),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: _waitingSeconds >= 300
                        ? AppColors.error
                        : _waitingSeconds >= 180
                            ? AppColors.warning
                            : AppColors.getTextPrimary(context),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ==================== BANNERS ====================

  Widget _buildPassengerNotifiedBanner() {
    return Text(
      'El pasajero fue notificado',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: AppColors.getTextPrimary(context),
      ),
    );
  }

  // ==================== NAVIGATOR PILL ====================

  Widget _buildNavigatorPill() {
    return GestureDetector(
      onTap: _openNavigation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
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

  // ==================== FLOATING BUTTONS ====================

  Widget _buildRoundFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
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

  // ==================== BOTTOM SHEET ====================

  Widget _buildPassengerBottomSheet() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -4),
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
          const SizedBox(height: 16),

          // Passenger info row: photo+name+rating | addresses | call+chat buttons
          _buildPassengerInfoRow(),

          const SizedBox(height: 14),
          Divider(color: AppColors.getBorder(context), height: 1),
          const SizedBox(height: 14),

          // Price row
          _buildPriceRow(),

          const SizedBox(height: 16),

          // Main action button (changes per state)
          _buildMainActionButton(),
        ],
      ),
    );
  }

  // ==================== PASSENGER INFO ROW ====================

  Widget _buildPassengerInfoRow() {
    // Ronda 250: los tres salían de vehicleInfo (mapa inexistente), de ahí el
    // "Pasajero" sin nombre y el avatar con icono genérico de tus capturas.
    final passengerName = _currentTrip?.passengerName ??
        _currentTrip?.vehicleInfo?['passengerName'] as String? ??
        'Pasajero';
    final passengerPhoto = _currentTrip?.passengerPhotoUrl ??
        _currentTrip?.vehicleInfo?['passengerPhoto'] as String?;
    final passengerRating =
        (_currentTrip?.vehicleInfo?['passengerRating'] as num?)?.toDouble() ?? 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column: photo + name + rating
        Column(
          children: [
            _buildPassengerAvatar(passengerPhoto),
            const SizedBox(height: 6),
            Text(
              passengerName.split(' ').first,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Ronda 255: un pasajero sin calificaciones mostraba "★ 0.0", que
            // se lee como la PEOR nota posible. Sin calificaciones no hay nota
            // que enseñar: se dice "Nuevo" y se omite la estrella.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (passengerRating > 0) ...[
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  const SizedBox(width: 2),
                ],
                Text(
                  passengerRating > 0
                      ? passengerRating.toStringAsFixed(1)
                      : 'Nuevo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: passengerRating > 0
                        ? AppColors.getTextPrimary(context)
                        : AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 14),

        // Column: addresses + payment badge
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pickup address (A)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF34A853),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _currentTrip?.pickupAddress ?? 'Cargando...',
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
              const SizedBox(height: 10),
              // Destination address (B)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4285F4),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _currentTrip?.destinationAddress ?? 'Cargando...',
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
              const SizedBox(height: 8),
              // Payment method badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.ctaGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.ctaGreen, width: 1),
                ),
                child: Text(
                  formatPaymentMethodLabel(_currentTrip?.paymentMethod),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5A6B00),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Column: call + chat buttons
        Column(
          children: [
            // Ronda 249: eran círculos verde-lima con icono negro (ctaGreen,
            // paleta del pasajero). Ahora rojo de marca con icono blanco.
            _buildActionCircleButton(
              icon: Icons.phone,
              color: AppColors.primary,
              onPressed: _callPassenger,
            ),
            const SizedBox(height: 10),
            _buildActionCircleButton(
              icon: Icons.chat_bubble_outline,
              color: AppColors.primary,
              onPressed: _openPassengerChat,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPassengerAvatar(String? photoUrl) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

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
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildAvatarFallback(),
              )
            : _buildAvatarFallback(),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      color: AppColors.rappiOrange.withValues(alpha: 0.1),
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
              color: color.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 24, color: Colors.white),
      ),
    );
  }

  // ==================== PRICE ROW ====================

  Widget _buildPriceRow() {
    final fare = _currentTrip?.estimatedFare ?? 0.0;
    final paymentMethod = formatPaymentMethodLabel(_currentTrip?.paymentMethod);
    final fareText = fare > 0
        ? 'S/ ${fare.toStringAsFixed(2)} · $paymentMethod'
        : 'Precio acordado · $paymentMethod';

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
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            fareText,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.getTextPrimary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ==================== ACTION BUTTON ====================

  Widget _buildMainActionButton() {
    if (_tripState == DriverTripState.inProgress ||
        _tripState == DriverTripState.arrivedAtDestination) {
      // State 3: trip in progress -> "Completar viaje"
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _completeTrip,
          style: ElevatedButton.styleFrom(
            // Ronda 249: usaba AppColors.success (verde) como color de ACCIÓN
            // primaria. `success` es un color semántico de estado, no de CTA.
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Completar viaje',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else if (_tripState == DriverTripState.arrivedAtPickup ||
               _tripState == DriverTripState.waitingVerification) {
      // State 2: waiting for passenger -> "Comenzó el viaje" (lime green)
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _startTrip,
          style: ElevatedButton.styleFrom(
            // Ronda 249: ctaGreen (#BEF264 verde lima) es la paleta inDrive
            // del PASAJERO; se había filtrado a la UI del conductor.
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Comenzó el viaje',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else if (_tripState == DriverTripState.completed) {
      // State 4: completed
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success.withValues(alpha: 0.3),
            foregroundColor: AppColors.success,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Viaje completado',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else {
      // State 1: going to pickup -> "Ya llegué" (blue)
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _markArrived,
          style: ElevatedButton.styleFrom(
            // Ronda 249: "Ya llegué" era AZUL GOOGLE hardcodeado — el CTA más
            // pulsado del conductor, y el que más rompía la marca.
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Ya llegué',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  /// Forzar completar viaje manualmente (sin depender del GPS)
  Future<void> _forceCompleteTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.warning),
            const SizedBox(width: 8),
            const Text('Completar manualmente'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que el pasajero ya llegó a su destino?\n\n'
          'Usa esta opción solo si el GPS no detectó la llegada correctamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Sí, completar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _completeTrip();
    }
  }

  void _showEmergencyOptions() {
    showResponsiveBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.phone, color: AppColors.error),
              title: const Text('Llamar a emergencias (105)'),
              onTap: () async {
                Navigator.pop(context);
                final Uri phoneUri = Uri(scheme: 'tel', path: '105');
                if (await canLaunchUrl(phoneUri)) {
                  await launchUrl(phoneUri);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.support_agent, color: AppColors.warning),
              title: const Text('Contactar soporte'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel, color: AppColors.error),
              title: const Text('Cancelar viaje'),
              onTap: () {
                Navigator.pop(context);
                _showCancelConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Ronda 246: motivos de cancelación del conductor.
  /// Antes se mandaba siempre `reason: 'driver_cancelled'` sin preguntar nada,
  /// y el conductor no sufría ninguna consecuencia — podía soltar viajes sin
  /// coste. Ahora, igual que en inDriver: elige un motivo, se le descuenta un
  /// porcentaje, y el equipo revisa el caso desde el panel para devolvérselo
  /// si el motivo era justificado.
  static const List<Map<String, String>> _cancelReasons = [
    {'code': 'passenger_no_show', 'label': 'El pasajero no apareció'},
    {'code': 'passenger_request', 'label': 'El pasajero me pidió cancelar'},
    {'code': 'passenger_wrong_address', 'label': 'Dirección incorrecta o inaccesible'},
    {'code': 'vehicle_issue', 'label': 'Problema con mi vehículo'},
    {'code': 'traffic_or_road', 'label': 'Vía bloqueada o tráfico extremo'},
    {'code': 'safety_concern', 'label': 'Motivo de seguridad'},
    {'code': 'personal_emergency', 'label': 'Emergencia personal'},
    {'code': 'too_far', 'label': 'El punto está demasiado lejos'},
    {'code': 'price_disagreement', 'label': 'Desacuerdo con la tarifa'},
    {'code': 'other', 'label': 'Otro motivo'},
  ];

  void _showCancelConfirmation() {
    String? selectedCode;
    final detailController = TextEditingController();

    showResponsiveBottomSheet(
      context: context,
      maxHeightFraction: 0.9,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Por qué cancelas el viaje?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(ctx),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.amber.shade800),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cancelar un viaje aceptado tiene un descuento. '
                        'Revisaremos tu motivo y, si está justificado, te lo devolvemos.',
                        style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // RadioGroup (API vigente); RadioListTile.groupValue/onChanged
              // quedaron deprecados tras Flutter 3.32.
              RadioGroup<String>(
                groupValue: selectedCode,
                onChanged: (v) => setSheetState(() => selectedCode = v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _cancelReasons.map((r) {
                    return RadioListTile<String>(
                      value: r['code']!,
                      title: Text(r['label']!, style: const TextStyle(fontSize: 14.5)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: AppColors.rappiRed,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: detailController,
                maxLines: 2,
                maxLength: 300,
                decoration: InputDecoration(
                  labelText: selectedCode == 'other'
                      ? 'Cuéntanos qué pasó *'
                      : 'Detalle (opcional)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Volver'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: selectedCode == null ||
                              (selectedCode == 'other' &&
                                  detailController.text.trim().isEmpty)
                          ? null
                          : () {
                              final code = selectedCode!;
                              final detail = detailController.text.trim();
                              Navigator.pop(sheetCtx);
                              _cancelTrip(
                                reasonCode: code,
                                reason: detail.isNotEmpty
                                    ? detail
                                    : _cancelReasons
                                        .firstWhere((r) => r['code'] == code)['label'],
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancelar viaje'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelTrip({String? reasonCode, String? reason}) async {
    setState(() => _isLoading = true);

    try {
      final resp = await _api
          .cancelRide(
            widget.tripId,
            reason: reason ?? 'driver_cancelled',
            reasonCode: reasonCode,
          )
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Timeout cancelando viaje');
      });

      final penalty = (resp['driverPenalty'] as num?)?.toDouble() ?? 0.0;

      if (mounted) {
        // Ronda 246: informamos con transparencia cuánto se descontó y que
        // será revisado. Antes el conductor no se enteraba de nada.
        if (penalty > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Viaje cancelado. Se descontaron S/ ${penalty.toStringAsFixed(2)}. '
                'Revisaremos tu motivo y te avisaremos si se te devuelve.',
              ),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 6),
            ),
          );
        }
        Navigator.of(context).pushNamedAndRemoveUntil('/driver/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError(e, fallback: 'Error cancelando viaje')),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}
