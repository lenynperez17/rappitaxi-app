import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math' as math;

// Core
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_button.dart';

// Models
import '../../models/trip_model.dart';

// Providers
import '../../providers/auth_provider.dart';

// Services
import '../../services/firebase_service.dart';

// Utils
import '../../utils/logger.dart';
import '../../utils/firestore_error_handler.dart';

// Screens
import 'chat_screen.dart';

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
  Timer? _driverLocationTimer;
  Timer? _etaTimer;

  // Flag para prevenir operaciones después de dispose
  bool _isDisposed = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  TripModel? _currentRide;
  Position? _currentPosition;
  LatLng? _driverLatLng;
  LatLng? _lastUpdatedDriverLatLng; // Para throttle de actualizaciones del mapa

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];

  String _estimatedArrival = 'Calculando...';
  double _distanceToDestination = 0.0;
  double _distanceToPickup = 0.0;
  String _currentStatus = 'Buscando conductor...';
  bool _isMapLoaded = false;
  bool _showDriverInfo = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadRideData();
    _startLocationTracking();
    _startDriverLocationUpdates();
    _startETAUpdates();
  }

  @override
  void dispose() {
    // Marcar como disposed ANTES de cancelar recursos
    _isDisposed = true;

    // Cancelar timers y suscripciones INMEDIATAMENTE
    _driverLocationTimer?.cancel();
    _driverLocationTimer = null;
    _etaTimer?.cancel();
    _etaTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;

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
        if (mounted) {
          setState(() {
            _currentRide = ride;
            _updateStatus();
          });
        }
      }

      if (_currentRide != null) {
        _setupMapMarkers();
        _calculateRoute();
        _listenToRideUpdates();
      }
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  void _listenToRideUpdates() {
    FirebaseService().listenToRideUpdates(widget.rideId, (ride) {
      if (mounted) {
        // Verificar si el viaje se completo para navegar a la pantalla de resumen
        if (ride.status == 'completed' && _currentRide?.status != 'completed') {
          // Navegar a la pantalla de viaje completado
          Navigator.pushReplacementNamed(
            context,
            '/trip-completed',
            arguments: {'tripId': widget.rideId},
          );
          return;
        }

        // NO hacer Navigator.pop() automáticamente en cancelación
        // En su lugar, actualizar el estado y mostrar la pantalla de cancelado
        // El usuario puede navegar manualmente con el boton "Volver al Inicio"
        if (ride.status == 'cancelled' && _currentRide?.status != 'cancelled') {
          RtSnackbar.show(context, message: 'El viaje ha sido cancelado', type: RtSnackbarType.error);
        }

        setState(() {
          _currentRide = ride;
          _updateStatus();
          _setupMapMarkers();
        });

        // Por ahora no hay ubicación del conductor en TripModel
        // Se actualizara dinamicamente desde Firebase
      }
    });
  }

  void _updateStatus() {
    if (_currentRide == null) return;

    switch (_currentRide!.status) {
      case 'searching':
        _currentStatus = 'Buscando conductor...';
        break;
      case 'accepted':
        _currentStatus = 'Conductor asignado - En camino';
        break;
      case 'arrived':
        _currentStatus = 'Conductor ha llegado';
        break;
      case 'in_progress':
        _currentStatus = 'Viaje en curso';
        break;
      case 'completed':
        _currentStatus = 'Viaje completado';
        break;
      case 'cancelled':
        _currentStatus = 'Viaje cancelado';
        break;
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
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
        // Triple verificación para prevenir operaciones después de dispose
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
        // Triple verificación para prevenir operaciones después de dispose
        if (_isDisposed) {
          timer.cancel();
          return;
        }
        if (!mounted) {
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
      final driverLocation = await FirebaseService()
          .getDriverLocation(_currentRide!.driverId);

      if (driverLocation != null && mounted) {
        _updateDriverPosition(driverLocation);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error al actualizar ubicación del conductor', e, stackTrace);
    }
  }

  void _updateDriverPosition(LatLng position) {
    // Throttle: Solo actualizar si la posicion cambio más de 10 metros
    // Esto reduce los warnings de ImageReader y mejora el rendimiento
    if (_lastUpdatedDriverLatLng != null) {
      final distance = Geolocator.distanceBetween(
        _lastUpdatedDriverLatLng!.latitude,
        _lastUpdatedDriverLatLng!.longitude,
        position.latitude,
        position.longitude,
      );
      // Si el conductor se movio menos de 10 metros, no actualizar el mapa
      if (distance < 10) {
        return;
      }
    }

    _lastUpdatedDriverLatLng = position;

    setState(() {
      _driverLatLng = position;
    });
    _setupMapMarkers();
    _calculateDistances();
    _calculateRoute();
  }

  void _calculateDistances() {
    if (_currentPosition == null) return;

    if (_currentRide != null) {
      // Distancia al destino
      _distanceToDestination = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _currentRide!.destinationLocation.latitude,
        _currentRide!.destinationLocation.longitude,
      ) / 1000;

      // Distancia al pickup (si el viaje no ha empezado)
      if (_currentRide!.status == 'accepted' ||
          _currentRide!.status == 'arrived') {
        _distanceToPickup = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          _currentRide!.pickupLocation.latitude,
          _currentRide!.pickupLocation.longitude,
        ) / 1000;
      }
    }
  }

  Future<void> _calculateETA() async {
    if (_driverLatLng == null || _currentRide == null) return;

    try {
      // Simulacion de calculo de ETA (en produccion usar Google Directions API)
      double distance;

      if (_currentRide!.status == 'accepted' ||
          _currentRide!.status == 'arrived') {
        // Distancia del conductor al pickup
        distance = Geolocator.distanceBetween(
          _driverLatLng!.latitude,
          _driverLatLng!.longitude,
          _currentRide!.pickupLocation.latitude,
          _currentRide!.pickupLocation.longitude,
        ) / 1000;
      } else {
        // Distancia del conductor/usuario al destino
        distance = _distanceToDestination;
      }

      // Velocidad promedio estimada (30 km/h en ciudad)
      const averageSpeed = 30.0;
      final etaMinutes = (distance / averageSpeed * 60).round();

      if (mounted) {
        setState(() {
          _estimatedArrival = etaMinutes > 0
              ? '$etaMinutes min'
              : 'Muy pronto';
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error al calcular ETA', e, stackTrace);
    }
  }

  void _setupMapMarkers() {
    if (_currentRide == null) return;

    _markers.clear();

    // Marcador de origen
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

    // Marcador de destino
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
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ));

    // Marcador del conductor (si esta disponible)
    if (_driverLatLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driverLatLng!,
        infoWindow: InfoWindow(
          title: 'Conductor',
          snippet: _currentRide!.vehicleInfo?['driverName'] ?? 'Conductor asignado',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }

    // Marcador de posicion actual
    if (_currentPosition != null) {
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

    setState(() {});
  }

  Future<void> _calculateRoute() async {
    if (_currentRide == null) return;

    _polylines.clear();

    // En una implementacion real, usar Google Directions API
    // Por ahora, dibujamos linea directa
    List<LatLng> points = [];

    if (_driverLatLng != null && (_currentRide!.status == 'accepted' ||
        _currentRide!.status == 'arrived')) {
      // Ruta del conductor al pickup
      points = [
        _driverLatLng!,
        _currentRide!.pickupLocation,
      ];
    } else if (_currentRide!.status == 'in_progress') {
      // Ruta del pickup al destino
      points = [
        _currentRide!.pickupLocation,
        _currentRide!.destinationLocation,
      ];
    }

    if (points.isNotEmpty) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: RtColors.brand,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));

      setState(() {
        _routePoints = points;
      });
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
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  Future<void> _callDriver() async {
    // Intentar obtener teléfono de vehicleInfo o directamente de Firestore
    String? driverPhone = _currentRide?.vehicleInfo?['driverPhone'];

    // Si no esta en vehicleInfo, intentar obtener desde Firestore
    if ((driverPhone == null || driverPhone.isEmpty) && _currentRide?.driverId != null) {
      try {
        final driverData = await FirebaseService().getUserById(_currentRide!.driverId!);
        if (driverData != null) {
          driverPhone = driverData['phone'] as String?;
        }
      } catch (e) {
        AppLogger.error('Error obteniendo teléfono del conductor', e);
      }
    }

    if (driverPhone == null || driverPhone.isEmpty) {
      if (!mounted) return;
      RtSnackbar.show(context, message: 'Número de conductor no disponible', type: RtSnackbarType.warning);
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: driverPhone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _openChat() async {
    if (_currentRide?.driverId == null) return;

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
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: RtColors.error, size: 28),
              SizedBox(width: 12),
              Text('Emergencia', style: TextStyle(color: RtColors.error)),
            ],
          ),
          content: const Text(
            'Necesitas ayuda de emergencia? Esto notificara a nuestro equipo de soporte inmediatamente.',
          ),
          actions: [
            RtButton(
              label: 'Cancelar',
              onPressed: () => Navigator.pop(context),
              variant: RtButtonVariant.ghost,
              isFullWidth: false,
            ),
            RtButton(
              label: 'Activar Emergencia',
              onPressed: () async {
                Navigator.pop(context);
                await _activateEmergency();
              },
              variant: RtButtonVariant.danger,
              isFullWidth: false,
            ),
          ],
        );
      },
    );
  }

  Future<void> _activateEmergency() async {
    try {
      // Llamar a servicios de emergencia
      final Uri emergencyUri = Uri(scheme: 'tel', path: '911');
      if (await canLaunchUrl(emergencyUri)) {
        await launchUrl(emergencyUri);
      }

      // Notificar al sistema
      await FirebaseService().reportEmergency(
        widget.rideId,
        _currentPosition,
      );

      if (!mounted) return;
      RtSnackbar.show(context, message: 'Emergencia activada. Ayuda en camino.', type: RtSnackbarType.error);
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  Future<void> _cancelRide() async {
    if (_currentRide?.status == 'in_progress') {
      if (!mounted) return;
      RtSnackbar.show(context, message: 'No puedes cancelar un viaje en curso', type: RtSnackbarType.warning);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Viaje'),
        content: const Text('Estás seguro de que deseas cancelar este viaje?'),
        actions: [
          RtButton(
            label: 'No',
            onPressed: () => Navigator.pop(context, false),
            variant: RtButtonVariant.ghost,
            isFullWidth: false,
          ),
          RtButton(
            label: 'Sí, Cancelar',
            onPressed: () => Navigator.pop(context, true),
            variant: RtButtonVariant.danger,
            isFullWidth: false,
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseService().cancelRide(widget.rideId);
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
      }
    }
  }

  Widget _buildDriverInfo() {
    if (_currentRide?.driverId == null) return Container();

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: RtColors.brand.withValues(alpha: 0.1),
                  backgroundImage: _currentRide?.vehicleInfo?['driverPhoto'] != null
                      ? NetworkImage(_currentRide!.vehicleInfo?['driverPhoto'])
                      : null,
                  child: _currentRide?.vehicleInfo?['driverPhoto'] == null
                      ? const Icon(Icons.person, size: 30, color: RtColors.brand)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentRide?.vehicleInfo?['driverName'] ?? 'Conductor',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _currentRide?.vehicleInfo?['driverRating']?.toStringAsFixed(1) ?? '5.0',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      if (_currentRide?.vehicleInfo?['plate'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_currentRide?.vehicleInfo?['model']} - ${_currentRide?.vehicleInfo?['plate']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _callDriver,
                      icon: const Icon(Icons.phone),
                      style: IconButton.styleFrom(
                        backgroundColor: RtColors.brand,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _openChat,
                      icon: const Icon(Icons.chat),
                      style: IconButton.styleFrom(
                        backgroundColor: RtColors.neutral900,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [RtColors.brand, RtColors.brand.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: RtColors.brand.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentStatus,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ETA: $_estimatedArrival',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _distanceToDestination > 0
                      ? '${_distanceToDestination.toStringAsFixed(1)} km'
                      : '...',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (_currentRide?.status == 'accepted' ||
              _currentRide?.status == 'arrived') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.my_location, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Distancia al punto de recogida: ${_distanceToPickup.toStringAsFixed(1)} km',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Seccion de destino visible
          if (_currentRide?.destinationAddress != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag, color: Colors.red.shade300, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Destino',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _currentRide!.destinationAddress,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMap() {
    // Determinar la posicion inicial del mapa
    LatLng initialTarget;
    if (_currentRide != null) {
      initialTarget = LatLng(
        _currentRide!.pickupLocation.latitude,
        _currentRide!.pickupLocation.longitude,
      );
    } else if (_currentPosition != null) {
      initialTarget = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    } else {
      initialTarget = const LatLng(-12.0464, -77.0428); // Lima por defecto
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  setState(() {
                    _isMapLoaded = true;
                  });

                  // Centrar mapa en la ruta después de un delay
                  Future.delayed(const Duration(seconds: 1), () {
                    if (_routePoints.isNotEmpty) {
                      _centerMapOnRoute();
                    } else if (_currentRide != null) {
                      // Si no hay ruta, centrar en pickup y destino
                      _fitMapToPickupAndDestination();
                    }
                  });
                },
                initialCameraPosition: CameraPosition(
                  target: initialTarget,
                  zoom: 15,
                ),
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                trafficEnabled: true,
                buildingsEnabled: true,
              ),
              // Indicador de carga mientras el mapa no esta listo
              if (!_isMapLoaded)
                Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Cargando mapa...'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Método para centrar el mapa en pickup y destino
  Future<void> _fitMapToPickupAndDestination() async {
    if (_mapController == null || _currentRide == null) return;

    try {
      final bounds = LatLngBounds(
        southwest: LatLng(
          math.min(_currentRide!.pickupLocation.latitude, _currentRide!.destinationLocation.latitude),
          math.min(_currentRide!.pickupLocation.longitude, _currentRide!.destinationLocation.longitude),
        ),
        northeast: LatLng(
          math.max(_currentRide!.pickupLocation.latitude, _currentRide!.destinationLocation.latitude),
          math.max(_currentRide!.pickupLocation.longitude, _currentRide!.destinationLocation.longitude),
        ),
      );

      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      AppLogger.error('Error centrando mapa', e);
    }
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentRide?.status != 'completed' &&
              _currentRide?.status != 'cancelled') ...[
            Expanded(
              child: RtButton(
                label: 'Cancelar',
                icon: Icons.cancel,
                onPressed: _cancelRide,
                variant: RtButtonVariant.danger,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: RtButton(
              label: 'Emergencia',
              icon: Icons.warning,
              onPressed: _showEmergencyDialog,
              variant: RtButtonVariant.secondary,
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            onPressed: _centerMapOnRoute,
            backgroundColor: RtColors.brand,
            child: Icon(Icons.my_location, color: Theme.of(context).colorScheme.onPrimary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si el viaje esta cancelado, mostrar pantalla especial con boton para volver
    if (_currentRide?.status == 'cancelled') {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        appBar: const RtAppBar(
          title: 'Viaje Cancelado',
          variant: RtAppBarVariant.gradient,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel, size: 80, color: RtColors.error),
              const SizedBox(height: 24),
              const Text(
                'Este viaje ha sido cancelado',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                _currentRide?.cancelledBy == _currentRide?.driverId
                    ? 'El conductor canceló el viaje'
                    : 'El viaje fue cancelado',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              RtButton(
                label: 'Volver al Inicio',
                icon: Icons.home,
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                isFullWidth: false,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      appBar: RtAppBar(
        title: 'Seguimiento de Viaje',
        variant: RtAppBarVariant.gradient,
        actions: [
          if (_showDriverInfo)
            IconButton(
              onPressed: () {
                setState(() {
                  _showDriverInfo = !_showDriverInfo;
                });
              },
              icon: Icon(_showDriverInfo ? Icons.visibility_off : Icons.visibility),
            ),
        ],
      ),
      body: _currentRide == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando información del viaje...'),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  _buildStatusCard(),
                  if (_showDriverInfo && _currentRide?.driverId != null)
                    _buildDriverInfo(),
                  _buildMap(),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }
}
