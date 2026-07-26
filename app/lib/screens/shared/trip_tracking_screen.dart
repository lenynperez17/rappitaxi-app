// ignore_for_file: deprecated_member_use, unused_field, unused_element, use_build_context_synchronously
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/maps_service.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../core/utils/responsive_bottom_sheet.dart';

// Models
import '../../models/trip_model.dart';
// Providers
import '../../providers/auth_provider.dart';
// Services
import '../../services/firebase_service.dart';
// Utils
import '../../services/rapi_api_client.dart';
import '../../utils/logger.dart';
import '../../utils/safe_navigation.dart';
// Providers
import '../../providers/ride_provider.dart';
// Screens
import 'chat_screen.dart';
import 'rating_dialog.dart';
import '../../utils/error_messages.dart';

class TripTrackingScreen extends StatefulWidget {
  final String rideId;
  final TripModel? ride;

  const TripTrackingScreen({
    super.key,
    required this.rideId,
    this.ride,
  });

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<Map<String, dynamic>>? _rideUpdatesSubscription;
  Timer? _driverLocationTimer;
  Timer? _etaTimer;

  // Flag to prevent operations after dispose
  bool _isDisposed = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  TripModel? _currentRide;
  // Ronda 245: marca que la carga del viaje agotó los reintentos, para
  // mostrar una salida en vez de un spinner eterno.
  bool _tripLoadFailed = false;
  Position? _currentPosition;
  Position? _driverPosition;
  LatLng? _driverLatLng;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];

  String? _estimatedArrivalKey;
  double _distanceToDestination = 0.0;
  double _distanceToPickup = 0.0;
  String? _currentStatusKey;
  bool _isMapLoaded = false;
  final bool _showDriverInfo = true;

  // Custom marker icons
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _destinationIcon;

  // Cached main route (pickup → destination, never changes)
  List<LatLng>? _cachedMainRoute;

  // Cached driver→pickup route (refreshed when driver moves significantly)
  List<LatLng>? _cachedDriverRoute;
  LatLng? _cachedDriverRouteOrigin;
  bool _isFetchingDriverRoute = false;

  // Prevents showing completion/cancellation dialog more than once
  bool _isCompletionHandled = false;

  // Live rating during trip
  int _liveRating = 0;

  // Smooth driver marker animation
  AnimationController? _driverAnimController;
  LatLng? _previousDriverLatLng;
  double _driverBearing = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _driverAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadCustomIcons();
    _loadRideData();
    _startLocationTracking();
    _startDriverLocationUpdates();
    _startETAUpdates();
  }

  Future<void> _loadCustomIcons() async {
    try {
      _carIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(45, 45)),
        'assets/images/markers/car_top_view.png',
      );
      _destinationIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(40, 40)),
        'assets/images/markers/destination_3d.png',
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error loading custom marker icons'));
    }
  }

  @override
  void dispose() {
    // Mark as disposed BEFORE cancelling resources
    _isDisposed = true;

    // Cancel timers and subscriptions IMMEDIATELY
    _driverLocationTimer?.cancel();
    _driverLocationTimer = null;

    _etaTimer?.cancel();
    _etaTimer = null;

    _positionSubscription?.cancel();
    _positionSubscription = null;

    _rideUpdatesSubscription?.cancel();
    _rideUpdatesSubscription = null;

    _waitTimer?.cancel();
    _waitTimer = null;

    _driverAnimController?.dispose();
    _driverAnimController = null;

    _pulseController.dispose();
    _slideController.dispose();

    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _slideController.forward();
  }

  Future<void> _loadRideData() async {
    try {
      if (!mounted) return;

      if (widget.ride != null) {
        if (!mounted) return;
        setState(() {
          _currentRide = widget.ride;
          _updateStatus();
        });
      } else {
        final ride = await FirebaseService().getRideById(widget.rideId);
        debugPrint('🔄 TRACKING INIT: rideId=${widget.rideId}, ride=${ride != null}, status=${ride?.status}');
        if (mounted) {
          setState(() {
            _currentRide = ride;
            _updateStatus();
            debugPrint('🔄 TRACKING INIT: statusKey=$_currentStatusKey');
          });
        }
      }

      if (_currentRide != null) {
        _setupMapMarkers();
        _calculateRoute();
        _listenToRideUpdates();
      } else {
        // Ronda 245 BUG BLOQUEANTE: `getRideById` se traga las excepciones y
        // devuelve null. Con _currentRide null NUNCA se suscribía al SSE y el
        // build() renderizaba "Cargando información del viaje..." sin AppBar,
        // sin reintento, sin timeout y sin botón de volver: un 401/404/timeout
        // puntual dejaba al pasajero ATRAPADO en la pantalla para siempre.
        // El catch de abajo era inalcanzable justamente por ese null silencioso.
        AppLogger.warning('No se pudo cargar el viaje ${widget.rideId} — activando reintento');
        _scheduleTripLoadRetry();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error al cargar datos del viaje', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError(e, fallback: 'Error al cargar datos del viaje')),
            backgroundColor: Colors.red,
          ),
        );
        _scheduleTripLoadRetry();
      }
    }
  }

  /// Ronda 245: reintenta la carga del viaje con backoff. Tras varios fallos
  /// muestra una salida explícita en vez de dejar el spinner eterno.
  int _tripLoadAttempts = 0;
  Timer? _tripLoadRetryTimer;

  void _scheduleTripLoadRetry() {
    if (!mounted || _currentRide != null) return;
    _tripLoadAttempts++;
    if (_tripLoadAttempts > 4) {
      setState(() => _tripLoadFailed = true);
      return;
    }
    _tripLoadRetryTimer?.cancel();
    _tripLoadRetryTimer = Timer(
      Duration(seconds: 2 * _tripLoadAttempts),
      () {
        if (mounted && _currentRide == null) _loadRideData();
      },
    );
  }

  void _listenToRideUpdates() {
    _rideUpdatesSubscription?.cancel();
    _rideUpdatesSubscription = FirebaseService().listenToRideUpdates(widget.rideId, (ride) {
      debugPrint('🔄 TRACKING: ride update - status=${ride.status}, driverId=${ride.driverId}');
      if (mounted) {
        setState(() {
          _currentRide = ride;
          _updateStatus();
          debugPrint('🔄 TRACKING: statusKey=$_currentStatusKey');
          _setupMapMarkers();
        });

        // Recalculate route when trip transitions to in_progress
        if (ride.status == 'in_progress') {
          _calculateRoute();
        }

        // Handle ride completion → show rating dialog
        if (ride.status == 'completed' && !_isCompletionHandled) {
          _isCompletionHandled = true;
          _showCompletionRatingDialog();
        }

        // Handle ride cancellation → notify and go back to home
        if (ride.status == 'cancelled' && !_isCompletionHandled) {
          _isCompletionHandled = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Viaje cancelado'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context).pushNamedAndRemoveUntil('/passenger/home', (route) => false);
        }
      }
    });
  }

  void _showCompletionRatingDialog() {
    final driverName = _currentRide?.vehicleInfo?['driverName'] ?? 'Conductor';
    final driverPhoto = _currentRide?.vehicleInfo?['driverPhoto'] ?? '';

    RatingDialog.show(
      context: context,
      driverName: driverName,
      driverPhoto: driverPhoto,
      tripId: widget.rideId,
      onSubmit: (rating, comment, tags) {
        // Save rating to Firestore via RideProvider
        final rideProvider = Provider.of<RideProvider>(context, listen: false);
        rideProvider.rateTrip(
          widget.rideId,
          rating.toDouble(),
          comment,
        );
      },
    ).then((_) {
      // Navigate back to home after dialog closes (with or without rating)
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  void _updateStatus() {
    if (_currentRide == null) return;

    switch (_currentRide!.status) {
      case 'searching':
        _currentStatusKey = 'searchingDriver';
        break;
      case 'accepted':
        _currentStatusKey = 'driverAssignedOnWay';
        break;
      case 'driver_arriving':
        _currentStatusKey = 'driverArriving';
        break;
      case 'arrived':
        _currentStatusKey = 'driverArrived';
        break;
      case 'in_progress':
        _currentStatusKey = 'tripInProgress';
        break;
      case 'completed':
        _currentStatusKey = 'tripCompletedStatus';
        break;
      case 'cancelled':
        _currentStatusKey = 'tripCancelledStatus';
        break;
      default:
        _currentStatusKey = 'unknownStatus';
        break;
    }
  }

  String _getLocalizedStatus(BuildContext context) {
    switch (_currentStatusKey) {
      case 'searchingDriver':
        return 'Buscando conductor...';
      case 'driverAssignedOnWay':
        return 'Conductor asignado, en camino';
      case 'driverArriving':
        return 'El conductor esta llegando';
      case 'driverArrived':
        return 'El conductor ha llegado';
      case 'tripInProgress':
        return 'Viaje en curso';
      case 'tripCompletedStatus':
        return 'Viaje completado';
      case 'tripCancelledStatus':
        return 'Viaje cancelado';
      default:
        return 'Estado desconocido';
    }
  }

  String _getLocalizedEta(BuildContext context) {
    if (_estimatedArrivalKey == null) {
      return 'Calculando tiempo estimado...';
    }
    if (_estimatedArrivalKey == 'verySoon') {
      return 'Muy pronto';
    }
    return _estimatedArrivalKey!;
  }

  Future<void> _startLocationTracking() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
          _calculateDistances();
        }
      });
    } catch (e, stackTrace) {
      AppLogger.error('Error al obtener ubicación', e, stackTrace);
    }
  }

  void _startDriverLocationUpdates() {
    _driverLocationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) {
        // Triple check to prevent operations after dispose
        if (_isDisposed) {
          timer.cancel();
          return;
        }

        if (!mounted) {
          timer.cancel();
          return;
        }

        _updateDriverLocation();
      },
    );
  }

  void _startETAUpdates() {
    _etaTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) {
        if (_isDisposed || !mounted) {
          timer.cancel();
          return;
        }
        _calculateETA();
      },
    );
  }

  Future<void> _updateDriverLocation() async {
    if (_currentRide?.driverId == null) return;

    try {
      // Antes se leia rides/{rideId}.driverLocation (Firestore GeoPoint).
      // Ahora leemos la ubicacion desde el backend Node via FirebaseService,
      // que internamente delega en RapiApiClient.driverLocation(driverId).
      final driverData = await FirebaseService()
          .getDriverLocationWithHeading(_currentRide!.driverId);

      if (driverData != null && mounted) {
        final newPosition = LatLng(driverData['lat']!, driverData['lng']!);
        final heading = driverData['heading'] ?? 0.0;
        _updateDriverPosition(newPosition, firestoreHeading: heading);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error al actualizar ubicación del conductor', e, stackTrace);
    }
  }

  void _updateDriverPosition(LatLng newPosition, {double firestoreHeading = 0.0}) {
    if (!mounted) return;

    final oldPos = _driverLatLng;

    // Calculate bearing for car rotation
    if (oldPos != null) {
      final dist = Geolocator.distanceBetween(
        oldPos.latitude, oldPos.longitude,
        newPosition.latitude, newPosition.longitude,
      );
      // Only update bearing if driver actually moved (>5m) to avoid jitter
      if (dist > 5) {
        // Prefer Firestore heading if available, otherwise calculate from positions
        if (firestoreHeading != 0.0) {
          _driverBearing = firestoreHeading;
        } else {
          _driverBearing = Geolocator.bearingBetween(
            oldPos.latitude, oldPos.longitude,
            newPosition.latitude, newPosition.longitude,
          );
        }
      }
    } else if (firestoreHeading != 0.0) {
      _driverBearing = firestoreHeading;
    }

    // If no previous position or animation controller unavailable, snap instantly
    if (oldPos == null || _driverAnimController == null) {
      _driverLatLng = newPosition;
      _driverPosition = Position(
        latitude: newPosition.latitude,
        longitude: newPosition.longitude,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: _driverBearing,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
      if (mounted) setState(() {});
      _setupMapMarkers();
      _calculateDistances();
      _updateDriverRouteOnly();
      _updateCameraBounds();
      _previousDriverLatLng = newPosition;
      return;
    }

    // Smooth animation: interpolate from old to new position
    _previousDriverLatLng = oldPos;
    final controller = _driverAnimController!;
    controller.reset();

    final latTween = Tween<double>(begin: oldPos.latitude, end: newPosition.latitude);
    final lngTween = Tween<double>(begin: oldPos.longitude, end: newPosition.longitude);
    final curved = CurvedAnimation(parent: controller, curve: Curves.easeInOut);

    void animListener() {
      if (!mounted || _isDisposed) return;
      final animLat = latTween.evaluate(curved);
      final animLng = lngTween.evaluate(curved);
      _driverLatLng = LatLng(animLat, animLng);

      // Update only the driver marker (lightweight, no full _setupMapMarkers)
      _markers.removeWhere((m) => m.markerId.value == 'driver');
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driverLatLng!,
        icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        rotation: _driverBearing,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      ));
      setState(() {});
    }

    controller.addListener(animListener);
    controller.forward().then((_) {
      controller.removeListener(animListener);
      if (!mounted) return;
      // Final state: update everything
      _driverLatLng = newPosition;
      _driverPosition = Position(
        latitude: newPosition.latitude,
        longitude: newPosition.longitude,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: _driverBearing,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
      _setupMapMarkers();
      _calculateDistances();
      _updateDriverRouteOnly();
      _updateCameraBounds();
    });
  }

  /// Update driver→pickup polyline using Directions API (cached)
  void _updateDriverRouteOnly() {
    if (_currentRide == null) return;
    // Don't touch polylines during in_progress - main_route handles it
    if (_currentRide!.status == 'in_progress') return;

    // Remove old driver route
    _polylines.removeWhere((p) => p.polylineId.value == 'driver_route');

    // Add driver→pickup route if driver location available and not yet arrived
    if (_driverLatLng != null &&
        (_currentRide!.status == 'accepted' || _currentRide!.status == 'driver_arriving')) {
      final pickup = LatLng(
        _currentRide!.pickupLocation.latitude,
        _currentRide!.pickupLocation.longitude,
      );

      // Use cached route if available, otherwise straight line as placeholder
      final routePoints = _cachedDriverRoute ?? [_driverLatLng!, pickup];

      _polylines.add(Polyline(
        polylineId: const PolylineId('driver_route'),
        points: routePoints,
        color: AppColors.rappiOrange.withValues(alpha: 0.7),
        width: 4,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));

      // Fetch real route if not cached or driver moved significantly (>200m)
      _fetchDriverRouteIfNeeded(_driverLatLng!, pickup);
    }

    if (mounted) setState(() {});
  }

  /// Fetch driver→pickup route from Directions API, with debouncing.
  /// Only re-fetches if driver moved >200m from last cached origin.
  Future<void> _fetchDriverRouteIfNeeded(LatLng driverPos, LatLng pickup) async {
    if (_isFetchingDriverRoute) return;

    // Check if we need to refresh: no cache, or driver moved >200m
    if (_cachedDriverRoute != null && _cachedDriverRouteOrigin != null) {
      final distance = Geolocator.distanceBetween(
        _cachedDriverRouteOrigin!.latitude, _cachedDriverRouteOrigin!.longitude,
        driverPos.latitude, driverPos.longitude,
      );
      if (distance < 200) return; // Driver hasn't moved enough, skip
    }

    _isFetchingDriverRoute = true;
    try {
      final route = await _getRoutePolylinePoints(driverPos, pickup);
      if (route.length > 2 && mounted) {
        _cachedDriverRoute = route;
        _cachedDriverRouteOrigin = driverPos;
        // Update polyline with real route
        _polylines.removeWhere((p) => p.polylineId.value == 'driver_route');
        _polylines.add(Polyline(
          polylineId: const PolylineId('driver_route'),
          points: route,
          color: AppColors.rappiOrange.withValues(alpha: 0.7),
          width: 4,
          startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        ));
        setState(() {});
      }
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error fetching driver route'));
    } finally {
      _isFetchingDriverRoute = false;
    }
  }

  /// Animate camera to show driver + relevant point (pickup or destination)
  void _updateCameraBounds() {
    if (_mapController == null || _currentRide == null) return;

    final pickup = LatLng(
      _currentRide!.pickupLocation.latitude,
      _currentRide!.pickupLocation.longitude,
    );
    final destination = LatLng(
      _currentRide!.destinationLocation.latitude,
      _currentRide!.destinationLocation.longitude,
    );

    final isInProgress = _currentRide!.status == 'in_progress';

    // During trip: show pickup + destination route only (not driver GPS which may be far)
    // During pickup: show driver + pickup
    final points = <LatLng>[];
    if (isInProgress) {
      points.addAll([pickup, destination]);
    } else {
      if (_driverLatLng != null) points.add(_driverLatLng!);
      points.add(pickup);
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  void _calculateDistances() {
    if (_currentPosition == null || _currentRide == null) return;

    // Distance to destination
    _distanceToDestination = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _currentRide!.destinationLocation.latitude,
      _currentRide!.destinationLocation.longitude,
    ) / 1000;

    // Distance to pickup (if trip hasn't started)
    if (_currentRide!.status == 'accepted' ||
        _currentRide!.status == 'driver_arriving') {
      _distanceToPickup = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _currentRide!.pickupLocation.latitude,
        _currentRide!.pickupLocation.longitude,
      ) / 1000;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _calculateETA() async {
    if (_driverLatLng == null || _currentRide == null) return;

    try {
      // ETA calculation simulation (in production use Google Directions API)
      double distance;

      if (_currentRide!.status == 'accepted' || _currentRide!.status == 'driver_arriving') {
        // Driver distance to pickup
        distance = Geolocator.distanceBetween(
          _driverLatLng!.latitude,
          _driverLatLng!.longitude,
          _currentRide!.pickupLocation.latitude,
          _currentRide!.pickupLocation.longitude,
        ) / 1000;
      } else {
        // Driver/user distance to destination
        distance = _distanceToDestination;
      }

      // Estimated average speed (30 km/h in city)
      const averageSpeed = 30.0;
      final etaMinutes = (distance / averageSpeed * 60).round();

      if (mounted) {
        setState(() {
          _estimatedArrivalKey = etaMinutes > 0
              ? '$etaMinutes min'
              : 'verySoon';
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error al calcular ETA', e, stackTrace);
    }
  }

  void _setupMapMarkers() {
    if (_currentRide == null) return;

    _markers.clear();

    final isPickupPhase = _currentRide!.status == 'accepted' ||
        _currentRide!.status == 'driver_arriving';

    // Origin marker
    _markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: LatLng(
        _currentRide!.pickupLocation.latitude,
        _currentRide!.pickupLocation.longitude,
      ),
      infoWindow: InfoWindow(
        title: 'Origen',
        snippet: _currentRide!.pickupAddress,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    ));

    // Destination marker (only during trip, not during pickup phase)
    if (!isPickupPhase) {
      _markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: LatLng(
          _currentRide!.destinationLocation.latitude,
          _currentRide!.destinationLocation.longitude,
        ),
        infoWindow: InfoWindow(
          title: 'Destino',
          snippet: _currentRide!.destinationAddress,
        ),
        icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    // Driver marker (if available)
    if (_driverLatLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driverLatLng!,
        infoWindow: InfoWindow(
          title: 'Conductor',
          snippet: _currentRide!.vehicleInfo?['driverName'] ?? 'Conductor asignado',
        ),
        icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        rotation: _driverBearing,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      ));
    }

    // Current position marker (hidden during pickup — passenger already knows where they are)
    if (_currentPosition != null && !isPickupPhase) {
      _markers.add(Marker(
        markerId: const MarkerId('current'),
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        infoWindow: const InfoWindow(
          title: 'Mi ubicación',
          snippet: 'Tu ubicación actual',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    if (mounted) {
      setState(() {});
    }
  }

  // Ronda 213 BUG FIX: antes usaba PolylinePoints con la key móvil restringida
  // → REQUEST_DENIED silencioso → línea recta invisible. Ahora va por
  // MapsService (proxy backend con cascada OSRM/Mapbox/Google, key oculta).
  Future<List<LatLng>> _getRoutePolylinePoints(LatLng origin, LatLng destination) async {
    // Retry hasta 2 veces (backend puede tener cold start del proveedor).
    for (int attempt = 0; attempt < 2; attempt++) {
      final route = await MapsService().getDirections(
        origin: origin,
        destination: destination,
      );
      if (route != null && route.points.isNotEmpty) {
        debugPrint('Route (${route.provider}): ${route.points.length} pts');
        return route.points;
      }
      if (attempt == 0) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }
    }
    debugPrint('MapsService falló tras 2 intentos → fallback recta');
    return [origin, destination];
  }

  Future<void> _calculateRoute() async {
    if (_currentRide == null) return;

    _polylines.clear();

    final pickup = LatLng(
      _currentRide!.pickupLocation.latitude,
      _currentRide!.pickupLocation.longitude,
    );
    final destination = LatLng(
      _currentRide!.destinationLocation.latitude,
      _currentRide!.destinationLocation.longitude,
    );

    // Main route: pickup → destination (cached, only 1 API call ever)
    final mainRoute = _cachedMainRoute ?? await _getRoutePolylinePoints(pickup, destination);
    _cachedMainRoute ??= mainRoute;

    final isPickupPhase = _currentRide!.status == 'accepted' ||
        _currentRide!.status == 'driver_arriving';

    if (isPickupPhase) {
      // During pickup phase: only show driver → pickup route
      // Passenger sees the driver coming to them (like Google Maps navigation)
      if (_driverLatLng != null) {
        final routePoints = _cachedDriverRoute ?? [_driverLatLng!, pickup];
        _polylines.add(Polyline(
          polylineId: const PolylineId('driver_route'),
          points: routePoints,
          color: AppColors.rappiOrange.withValues(alpha: 0.7),
          width: 4,
          startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        ));
        // Fetch real route async (will update polyline when ready)
        _fetchDriverRouteIfNeeded(_driverLatLng!, pickup);
      }
    } else {
      // During trip (in_progress): show pickup → destination route
      _polylines.add(Polyline(
        polylineId: const PolylineId('main_route'),
        points: mainRoute,
        color: AppColors.rappiOrange,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));
    }

    if (mounted) {
      setState(() {
        _routePoints = mainRoute;
        // Rebuild markers to include destination marker during in_progress
        _setupMapMarkers();
      });
      await Future.delayed(const Duration(milliseconds: 500));
      _centerMapOnRoute();
    }
  }

  Future<void> _centerMapOnRoute() async {
    if (_mapController == null || _routePoints.isEmpty) return;

    LatLngBounds bounds;

    if (_routePoints.length == 1) {
      bounds = LatLngBounds(
        southwest: _routePoints.first,
        northeast: _routePoints.first,
      );
    } else {
      double minLat = _routePoints.first.latitude;
      double maxLat = _routePoints.first.latitude;
      double minLng = _routePoints.first.longitude;
      double maxLng = _routePoints.first.longitude;

      for (LatLng point in _routePoints) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }

      bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
    }

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  Future<void> _callDriver() async {
    // Ronda 255: leía el teléfono SOLO de vehicleInfo, un mapa anidado que el
    // backend NUNCA envía — de ahí el "Teléfono del conductor no disponible"
    // de las capturas, incluso con el conductor ya asignado. El backend lo
    // manda suelto en la raíz como driverPhone (ronda 250b lo añadió al
    // modelo); el mapa queda como respaldo.
    var phone = _currentRide?.driverPhone ??
        _currentRide?.vehicleInfo?['driverPhone'] as String? ??
        '';

    // Ronda 257: el teléfono SOLO viaja en el detalle GET /api/rides/:id — ni
    // el listado /api/rides ni el stream SSE lo incluyen. Y esta pantalla, si
    // recibe el ride ya construido (widget.ride), nunca consulta el detalle:
    // por eso el pasajero seguía viendo "Teléfono del conductor no disponible"
    // con el conductor ya asignado. Si falta, lo pedimos en ese momento.
    if (phone.isEmpty && widget.rideId.isNotEmpty) {
      try {
        final detail = await RapiApiClient.instance.getRide(widget.rideId);
        final map = (detail['ride'] ?? detail) as Map<String, dynamic>;
        phone = (map['driverPhone'] ?? '').toString();
      } catch (e) {
        AppLogger.warning('No se pudo obtener el teléfono del conductor: '
            '${userFriendlyError(e, fallback: "error de red")}');
      }
    }

    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teléfono del conductor no disponible'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    if (!phone.startsWith('+')) phone = '+51$phone';
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede llamar desde este dispositivo'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _openChat() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            rideId: widget.rideId,
            otherUserName: _currentRide!.vehicleInfo?['driverName'] ?? 'Conductor',
            otherUserRole: 'driver',
            otherUserId: _currentRide!.driverId,
          ),
        ),
      );
    }
  }

  Future<void> _showEmergencyDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Emergencia', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: const Text('¿Deseas activar el modo de emergencia? Se contactara a los servicios de emergencia.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _activateEmergency();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Activar emergencia'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _activateEmergency() async {
    try {
      // Call emergency services
      final Uri emergencyUri = Uri(scheme: 'tel', path: '911');
      if (await canLaunchUrl(emergencyUri)) {
        await launchUrl(emergencyUri);
      }

      // Notify the system
      await FirebaseService().reportEmergency(
        widget.rideId,
        _currentPosition,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergencia activada. Se ha notificado a los servicios de emergencia.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error al activar emergencia', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError(e, fallback: 'Error al activar emergencia')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelRide() async {
    final isInProgress = _currentRide?.status == 'in_progress';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar viaje'),
        content: Text(isInProgress
            ? '¿Estás seguro de que deseas cancelar el viaje?\n\nEl viaje ya está en curso. ¿Estás seguro de que deseas cancelarlo?'
            : '¿Estás seguro de que deseas cancelar el viaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _isCompletionHandled = true;
      try {
        await FirebaseService().cancelRide(widget.rideId);
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/passenger/home', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userFriendlyError(e, fallback: 'Error al cancelar')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


  // ═══════════════════════════════════════════════════════════════
  // UI — inDrive-style redesign
  // ═══════════════════════════════════════════════════════════════

  Timer? _waitTimer;
  int _waitSeconds = 0;
  bool _waitTimerStarted = false;

  void _startWaitTimer() {
    if (_waitTimerStarted) return;
    _waitTimerStarted = true;
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_isDisposed || !mounted) { t.cancel(); return; }
      setState(() => _waitSeconds++);
    });
  }

  String _formatWaitTime() {
    final m = (_waitSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_waitSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Returns the main title shown at the top of the bottom sheet based on ride status.
  String _buildStatusTitle(bool isEs) {
    final status = _currentRide?.status ?? '';
    switch (status) {
      case 'arrived':
        return isEs
            ? 'El conductor llego. Tiempo de espera: ${_formatWaitTime()}'
            : 'Driver arrived. Wait time: ${_formatWaitTime()}';
      case 'driver_arriving':
        final eta = _estimatedArrivalKey;
        if (eta == null || eta == 'verySoon') {
          return isEs
              ? 'El conductor va en camino. Llegará muy pronto'
              : 'Driver is on the way. Arriving very soon';
        }
        return isEs
            ? userFriendlyError(eta, fallback: 'El conductor va en camino. Tiempo estimado')
            : userFriendlyError(eta, fallback: 'Driver is on the way. Estimated time');
      case 'accepted':
        final eta = _estimatedArrivalKey;
        if (eta == null || eta == 'verySoon') {
          return isEs
              ? 'Conductor asignado. Llegará muy pronto'
              : 'Driver assigned. Arriving very soon';
        }
        return isEs
            ? userFriendlyError(eta, fallback: 'Conductor asignado. Tiempo estimado')
            : userFriendlyError(eta, fallback: 'Driver assigned. Estimated time');
      case 'in_progress':
        // Calculate estimated arrival time as absolute clock time
        final etaKey = _estimatedArrivalKey;
        if (etaKey != null && etaKey != 'verySoon') {
          final minutes = int.tryParse(etaKey.replaceAll(' min', '')) ?? 0;
          if (minutes > 0) {
            final arrivalTime = DateTime.now().add(Duration(minutes: minutes));
            final hour = arrivalTime.hour > 12 ? arrivalTime.hour - 12 : (arrivalTime.hour == 0 ? 12 : arrivalTime.hour);
            final minuteStr = arrivalTime.minute.toString().padLeft(2, '0');
            final period = arrivalTime.hour >= 12 ? 'PM' : 'AM';
            return isEs
                ? 'Llegarás aproximadamente a las $hour:$minuteStr $period'
                : 'You\'ll arrive at approximately $hour:$minuteStr $period';
          }
        }
        return isEs ? 'Llegando muy pronto' : 'Arriving very soon';
      case 'completed':
        return isEs ? 'Viaje completado' : 'Trip completed';
      case 'cancelled':
        return isEs ? 'Viaje cancelado' : 'Trip cancelled';
      default:
        return isEs ? 'Buscando conductor...' : 'Searching for driver...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEs = Localizations.localeOf(context).languageCode == 'es';

    if (_currentRide == null) {
      // Ronda 245: antes esto era SOLO un spinner sin AppBar ni salida. Si la
      // carga fallaba, el pasajero quedaba encerrado sin forma de volver.
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimary(context)),
            onPressed: () => safePopOrHome(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _tripLoadFailed
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 20),
                      Text(
                        'No pudimos cargar tu viaje',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Revisa tu conexión e inténtalo de nuevo.',
                        style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _tripLoadFailed = false;
                            _tripLoadAttempts = 0;
                          });
                          _loadRideData();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.rappiRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => safePopOrHome(context),
                        child: const Text('Volver al inicio'),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Cargando información del viaje...'),
                    ],
                  ),
          ),
        ),
      );
    }

    // Start wait timer only when driver has physically arrived
    if (_currentRide!.status == 'arrived' || _currentRide!.status == 'driver_arriving') {
      _startWaitTimer();
    }

    final vehicleInfo = _currentRide?.vehicleInfo;
    final driverName = vehicleInfo?['driverName'] ?? 'Conductor';
    final driverPhoto = vehicleInfo?['driverPhoto'] as String?;
    final driverRating = (vehicleInfo?['driverRating'] as num?)?.toDouble() ?? 5.0;
    final plate = vehicleInfo?['vehiclePlate'] ?? vehicleInfo?['licensePlate'] ?? vehicleInfo?['plate'] ?? '';
    final vehicleModel = vehicleInfo?['vehicleModel'] ?? '';
    final vehicleColor = vehicleInfo?['vehicleColor'] ?? vehicleInfo?['color'] ?? '';
    // vehicleModel already contains "brand model year", so combine with color
    final vehicleDisplay = vehicleColor.isNotEmpty
        ? '$vehicleColor $vehicleModel'.trim()
        : vehicleModel.toString().trim();
    final tripPrice = _currentRide?.finalFare ?? _currentRide?.estimatedFare ?? 0.0;
    final paymentMethod = vehicleInfo?['paymentMethod'] as String? ?? 'cash';
    // isArrived: driver has physically arrived at the pickup point
    final isArrived = _currentRide!.status == 'arrived' || _currentRide!.status == 'driver_arriving' || _currentRide!.status == 'waiting_verification';
    // isInProgress: trip has started
    final isInProgress = _currentRide!.status == 'in_progress';

    return Scaffold(
      body: Stack(
        children: [
          // ── MAP ──
          Positioned.fill(
            child: GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                setState(() => _isMapLoaded = true);
                Future.delayed(const Duration(seconds: 1), () => _centerMapOnRoute());
              },
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentRide!.pickupLocation.latitude,
                  _currentRide!.pickupLocation.longitude,
                ),
                zoom: 15,
              ),
              // Bottom sheet covers ~55% of screen — push map content up, add top margin too
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.58,
                top: MediaQuery.of(context).padding.top + 20,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              trafficEnabled: false,
              buildingsEnabled: false,
            ),
          ),

          // ── Safety button (top right) ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: GestureDetector(
              onTap: () => _showSecuritySheet(context, isEs, driverName, driverPhoto, driverRating, vehicleInfo),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: const Icon(Icons.verified_user, size: 24, color: Color(0xFF4CAF50)),
              ),
            ),
          ),

          // ── BOTTOM SHEET ──
          DraggableScrollableSheet(
            initialChildSize: isArrived ? 0.72 : (isInProgress ? 0.35 : 0.62),
            minChildSize: 0.25,
            maxChildSize: 0.85,
            builder: (ctx, scrollController) => Container(
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── STATUS HEADER (all states) ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title line: depends on status
                        Text(
                          _buildStatusTitle(isEs),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Vehicle info row (visible when driver is assigned)
                        if (vehicleDisplay.isNotEmpty) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  vehicleDisplay,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ),
                              const Icon(Icons.directions_car, size: 36, color: Color(0xFF9E9E9E)),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],

                        // License plate badge
                        if (plate.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.getBorder(context), width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              plate,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextPrimary(context),
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ] else
                          const SizedBox(height: 6),
                      ],
                    ),
                  ),

                  // ── "Ya voy" button (only when driver has arrived) ──
                  if (isArrived) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEs
                                      ? 'El conductor sabe que vas en camino'
                                      : 'The driver knows you\'re on your way',
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.rappiOrange,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            isEs ? 'Ya voy' : 'On my way',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 4),

                  Divider(height: 1, color: AppColors.getBorder(context)),
                  const SizedBox(height: 16),

                  // ── DRIVER INFO ROW ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // Driver photo + rating
                        Expanded(child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 32,
                                  backgroundColor: AppColors.rappiOrange.withValues(alpha:0.1),
                                  backgroundImage: driverPhoto != null && driverPhoto.isNotEmpty ? NetworkImage(driverPhoto) : null,
                                  child: driverPhoto == null || driverPhoto.isEmpty
                                      ? const Icon(Icons.person, size: 32, color: AppColors.rappiOrange)
                                      : null,
                                ),
                                Positioned(
                                  top: -4, right: -8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star, size: 12, color: Colors.amber),
                                        const SizedBox(width: 2),
                                        Text(driverRating.toStringAsFixed(2), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(driverName.split(' ').first, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                          ],
                        )),
                        // Contact driver
                        Expanded(child: GestureDetector(
                          onTap: () {
                            showResponsiveBottomSheet(
                              context: context,
                              builder: (ctx) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 16),
                                    Text(isEs ? 'Contactar al conductor' : 'Contact driver', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                                    const SizedBox(height: 16),
                                    ListTile(
                                      leading: const Icon(Icons.phone, color: AppColors.rappiOrange),
                                      title: Text(isEs ? 'Llamar' : 'Call'),
                                      onTap: () { Navigator.pop(ctx); _callDriver(); },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.chat, color: AppColors.rappiOrange),
                                      title: Text(isEs ? 'Chat' : 'Chat'),
                                      onTap: () { Navigator.pop(ctx); _openChat(); },
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.rappiOrange.withValues(alpha:0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.phone_in_talk, size: 28, color: Color(0xFF4CAF50)),
                              ),
                              const SizedBox(height: 6),
                              Text(isEs ? 'Contactar\nal conductor' : 'Contact\ndriver', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(context))),
                            ],
                          ),
                        )),
                        // Security
                        Expanded(child: GestureDetector(
                          onTap: () => _showSecuritySheet(context, isEs, driverName, driverPhoto, driverRating, vehicleInfo),
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.rappiOrange.withValues(alpha:0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.verified_user, size: 28, color: Color(0xFF4CAF50)),
                                  ),
                                  Positioned(
                                    top: -2, right: -2,
                                    child: Container(
                                      width: 10, height: 10,
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(isEs ? 'Seguridad' : 'Safety', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(context))),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Observation for driver ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: () => _openChat(),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.getInputFill(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outline, color: AppColors.getTextSecondary(context)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isEs ? '¿Tienes alguna observación\npara el conductor?' : 'Any observation\nfor the driver?',
                                style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Payment ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isEs ? 'Pago' : 'Payment', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildPaymentIcon(paymentMethod),
                            const SizedBox(width: 8),
                            Text('S/ ${tripPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                            const SizedBox(width: 8),
                            Text('·', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextSecondary(context))),
                            const SizedBox(width: 8),
                            Text(_getPaymentLabel(paymentMethod, isEs), style: TextStyle(fontSize: 15, color: AppColors.getTextSecondary(context))),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Trip details ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isEs ? 'Tu viaje actual' : 'Your current trip', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.rappiOrange, shape: BoxShape.circle)),
                                Container(width: 2, height: 30, color: Colors.grey[300]),
                                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle)),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentRide!.pickupAddress,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _currentRide!.destinationAddress,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Share trip ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEs ? 'Compartiendo ubicación en tiempo real...' : 'Sharing live location...')),
                        );
                      },
                      child: Row(
                        children: [
                          Icon(Icons.share, color: AppColors.getTextPrimary(context)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(isEs ? 'Compartir mi viaje' : 'Share my trip', style: TextStyle(fontSize: 15, color: AppColors.getTextPrimary(context)))),
                          Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Call emergency ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: InkWell(
                      onTap: () async {
                        final Uri emergencyUri = Uri(scheme: 'tel', path: '105');
                        if (await canLaunchUrl(emergencyUri)) await launchUrl(emergencyUri);
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.local_hospital, color: Colors.red, size: 22),
                          const SizedBox(width: 12),
                          Expanded(child: Text(isEs ? 'Llamar a emergencias' : 'Call emergency', style: const TextStyle(fontSize: 15, color: Colors.red))),
                          Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Cancel trip button ──
                  if (!isInProgress && _currentRide!.status != 'completed')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showCancelConfirmation(context, isEs, driverName, driverPhoto),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.getInputFill(context),
                            foregroundColor: Colors.red,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(isEs ? 'Cancelar viaje' : 'Cancel trip', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),

                  // ── Finish trip button ── (when in progress, for driver/testing)
                  if (isInProgress)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Text(
                            _getLocalizedStatus(context),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getLocalizedEta(context),
                            style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)),
                          ),
                        ],
                      ),
                    ),

                  // ── Live rating during trip ──
                  if (isInProgress) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        children: [
                          Text(
                            isEs ? 'Califica a tu conductor' : 'Rate your driver',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _liveRating = index + 1);
                                  // La calificación en vivo se envía al finalizar
                                  // via api.rateRide — no persistimos por evento.
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(
                                    index < _liveRating ? Icons.star_rounded : Icons.star_outline_rounded,
                                    size: 40,
                                    color: index < _liveRating ? AppColors.rappiOrange : Colors.grey.shade300,
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isEs
                                ? 'El conductor todavía no ve esta calificación.\nPodrás cambiarla después'
                                : 'The driver can\'t see this rating yet.\nYou can change it later',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cancel Confirmation (inDrive-style) ──
  void _showCancelConfirmation(BuildContext context, bool isEs, String driverName, String? driverPhoto) {
    showResponsiveBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEs ? '¿Realmente\nquieres cancelar?' : 'Do you really\nwant to cancel?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
            ),
            const SizedBox(height: 12),
            Text(
              isEs
                  ? 'Las cancelaciones frecuentes pueden reducir tu calificación y afectar la aceptación de tus solicitudes'
                  : 'Frequent cancellations may lower your rating and affect your request acceptance',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.rappiOrange.withValues(alpha:0.1),
              backgroundImage: driverPhoto != null && driverPhoto.isNotEmpty ? NetworkImage(driverPhoto) : null,
              child: driverPhoto == null || driverPhoto.isEmpty ? const Icon(Icons.person, size: 36) : null,
            ),
            const SizedBox(height: 8),
            Text(
              isEs ? 'El conductor esta esperando' : 'The driver is waiting',
              style: TextStyle(fontSize: 15, color: AppColors.getTextPrimary(context)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rappiOrange,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(isEs ? 'Continuar viaje' : 'Continue trip', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showCancelReasons(context, isEs);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.getInputFill(context),
                  foregroundColor: Colors.red,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(isEs ? 'Cancelar viaje' : 'Cancel trip', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cancel Reasons (inDrive-style) ──
  void _showCancelReasons(BuildContext context, bool isEs) {
    final reasons = isEs
        ? [
            'Ya no necesito el viaje',
            'El conductor no llegó al punto de recogida',
            'El auto está en malas condiciones',
            'El conductor pidió cancelar la solicitud',
            'El conductor pide una tarifa adicional',
            'Es un conductor diferente',
            'Es un auto diferente',
            'No me siento seguro/a',
            'Cuestión con la aplicación',
            'Otra razón',
          ]
        : [
            'I no longer need the ride',
            'The driver didn\'t arrive at the pickup point',
            'The car is in poor condition',
            'The driver asked to cancel',
            'The driver is asking for an extra fare',
            'It\'s a different driver',
            'It\'s a different car',
            'I don\'t feel safe',
            'Issue with the app',
            'Other reason',
          ];

    showResponsiveBottomSheet(
      context: context,
      maxHeightFraction: 0.8,
      builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isEs ? 'Motivo de la cancelacion' : 'Cancellation reason',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: reasons.length,
                itemBuilder: (_, i) => InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    // Prevent the Firestore listener from also navigating
                    _isCompletionHandled = true;
                    try {
                      await FirebaseService().cancelRide(widget.rideId);
                      if (mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/passenger/home', (route) => false);
                      }
                    } catch (e) {
                      _isCompletionHandled = false;
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(userFriendlyError(e, fallback: 'Error')), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Text(reasons[i], style: TextStyle(fontSize: 16, color: AppColors.getTextPrimary(context))),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rappiOrange,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(isEs ? 'Continuar viaje' : 'Continue trip', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
    );
  }

  // ── Security Sheet (inDrive-style) ──
  void _showSecuritySheet(BuildContext context, bool isEs, String driverName, String? driverPhoto, double driverRating, Map<String, dynamic>? vehicleInfo) {
    final secVehicleModel = vehicleInfo?['vehicleModel'] ?? '';
    final secVehicleColor = vehicleInfo?['vehicleColor'] ?? vehicleInfo?['color'] ?? '';
    final vehicleDisplay = secVehicleColor.toString().isNotEmpty
        ? '$secVehicleColor $secVehicleModel'.trim()
        : secVehicleModel.toString().trim();

    showResponsiveBottomSheet(
      context: context,
      maxHeightFraction: 0.85,
      builder: (ctx) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            // Title + close
            Row(
              children: [
                Expanded(child: Text(isEs ? 'Funciones de seguridad' : 'Safety features', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)))),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),

            // 3 action cards
            Row(
              children: [
                _buildSecurityAction(Icons.share, isEs ? 'Compartir\nmi viaje' : 'Share\nmy trip', () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEs ? 'Compartiendo...' : 'Sharing...')));
                }),
                const SizedBox(width: 12),
                _buildSecurityAction(Icons.chat_bubble_outline, isEs ? 'Soporte' : 'Support', () {
                  Navigator.pop(ctx);
                }),
                const SizedBox(width: 12),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildSecurityAction(Icons.people_outline, isEs ? 'Contactos\nde emergencia' : 'Emergency\ncontacts', () {
                      Navigator.pop(ctx);
                    }),
                    Positioned(top: -2, right: -2, child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Call 105
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final Uri uri = Uri(scheme: 'tel', path: '105');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                icon: const Icon(Icons.local_hospital, color: Colors.white),
                label: Text(isEs ? 'Llamar 105' : 'Call 105', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Driver verifications
            Text(isEs ? 'Verificaciones del conductor' : 'Driver verifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getInputFill(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: driverPhoto != null && driverPhoto.isNotEmpty ? NetworkImage(driverPhoto) : null,
                        child: driverPhoto == null || driverPhoto.isEmpty ? const Icon(Icons.person, size: 28) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(driverName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                            Row(
                              children: [
                                Text(driverRating.toStringAsFixed(2), style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
                                const SizedBox(width: 4),
                                const Icon(Icons.star, size: 14, color: Colors.amber),
                              ],
                            ),
                            if (vehicleDisplay.isNotEmpty)
                              Text(vehicleDisplay, style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildVerificationItem(Icons.verified_user, isEs ? 'Sin antecedentes penales' : 'No criminal record'),
                  const SizedBox(height: 8),
                  _buildVerificationItem(Icons.badge, isEs ? 'Licencia de conducir validada' : 'Validated driver\'s license'),
                  const SizedBox(height: 8),
                  _buildVerificationItem(Icons.camera_alt, isEs ? 'Control fotográfico completado' : 'Photo check completed'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // How you're protected
            Text(isEs ? '¿Cómo estás protegido?' : 'How you\'re protected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.getInputFill(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isEs ? 'Soporte de\nseguridad proactivo' : 'Proactive\nsafety support', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                        const SizedBox(height: 8),
                        const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 32),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.getInputFill(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isEs ? 'Verificación de\nconductores' : 'Driver\nverification', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                        const SizedBox(height: 8),
                        const Icon(Icons.how_to_reg, color: Color(0xFF4CAF50), size: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
    );
  }

  Widget _buildSecurityAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getInputFill(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: AppColors.getTextPrimary(context)),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.getTextPrimary(context))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.getTextSecondary(context)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: AppColors.getTextPrimary(context)))),
        Icon(Icons.chevron_right, size: 18, color: AppColors.getTextSecondary(context)),
      ],
    );
  }

  Widget _buildPaymentIcon(String method) {
    switch (method) {
      case 'yape':
        return Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: const Color(0xFF6B21A8), borderRadius: BorderRadius.circular(6)),
          child: const Center(child: Text('Y', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
        );
      case 'plin':
        return Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: const Color(0xFF00BFA5), borderRadius: BorderRadius.circular(6)),
          child: const Center(child: Text('P', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
        );
      case 'card':
        return const Icon(Icons.credit_card, size: 28, color: Color(0xFF1565C0));
      default:
        return const Icon(Icons.payments, size: 28, color: Color(0xFF4CAF50));
    }
  }

  String _getPaymentLabel(String method, bool isEs) {
    switch (method) {
      case 'yape': return 'Yape';
      case 'plin': return 'Plin';
      case 'card': return isEs ? 'Tarjeta' : 'Card';
      case 'wallet': return isEs ? 'Billetera' : 'Wallet';
      default: return isEs ? 'Efectivo' : 'Cash';
    }
  }
}
