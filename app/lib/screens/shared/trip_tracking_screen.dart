// ignore_for_file: deprecated_member_use, unused_field, unused_element, use_build_context_synchronously
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Core
import '../../core/config/app_config.dart';
import '../../core/theme/modern_theme.dart';

// Models
import '../../models/trip_model.dart';

// Providers
import '../../providers/auth_provider.dart';

// Services
import '../../services/firebase_service.dart';

// Utils
import '../../utils/logger.dart';
import '../../utils/map_marker_utils.dart';

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
  StreamSubscription? _rideUpdatesSubscription;
  Timer? _driverLocationTimer;
  Timer? _etaTimer;

  // ✅ Flag para prevenir operaciones después de dispose
  bool _isDisposed = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  TripModel? _currentRide;
  Position? _currentPosition;
  Position? _driverPosition;
  LatLng? _driverLatLng;
  double _driverHeading = 0.0; // Heading del conductor para rotación del marcador
  LatLng? _lastUpdatedDriverLatLng; // ✅ Para throttle de actualizaciones del mapa
  bool _isFollowingDriver = true; // Camera follows driver when true
  
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];

  // Iconos modernos para marcadores
  BitmapDescriptor? _originIcon;
  BitmapDescriptor? _destinationIcon;
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _currentLocationIcon;

  String _estimatedArrival = 'Calculando...';
  double _distanceToDestination = 0.0;
  double _distanceToPickup = 0.0;
  String _currentStatus = 'Buscando conductor...';
  bool _isMapLoaded = false;
  bool _showDriverInfo = true;

  // Verification state
  bool _isVerifyingCode = false;
  final TextEditingController _verificationCodeController = TextEditingController();
  
  // Colores del tema
  static const primaryColor = Color(0xFFFF6B00);
  static const accentColor = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadCustomIcons();
    _loadRideData();
    _startLocationTracking();
    _startDriverLocationUpdates();
    _startETAUpdates();
  }

  /// Cargar iconos modernos para marcadores
  Future<void> _loadCustomIcons() async {
    _originIcon = await MapMarkerUtils.getOriginIcon();
    _destinationIcon = await MapMarkerUtils.getDestinationIcon();
    _driverIcon = await MapMarkerUtils.getCarTopViewIcon();
    _currentLocationIcon = await MapMarkerUtils.getCurrentLocationIcon();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // ✅ Marcar como disposed ANTES de cancelar recursos
    _isDisposed = true;

    // Cancelar timers y suscripciones INMEDIATAMENTE
    _rideUpdatesSubscription?.cancel();
    _rideUpdatesSubscription = null;
    _driverLocationTimer?.cancel();
    _driverLocationTimer = null;
    _etaTimer?.cancel();
    _etaTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;

    _verificationCodeController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar datos del viaje: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _listenToRideUpdates() {
    _rideUpdatesSubscription?.cancel();
    _rideUpdatesSubscription = FirebaseService().listenToRideUpdates(widget.rideId, (ride) {
      if (mounted) {
        // Verificar si el viaje se completó para navegar a la pantalla de resumen
        if (ride.status == 'completed' && _currentRide?.status != 'completed') {
          // Navegar a la pantalla de viaje completado
          Navigator.pushReplacementNamed(
            context,
            '/trip-completed',
            arguments: {'tripId': widget.rideId},
          );
          return;
        }

        // ✅ CORREGIDO: NO hacer Navigator.pop() automáticamente en cancelación
        // En su lugar, actualizar el estado y mostrar la pantalla de cancelado
        // El usuario puede navegar manualmente con el botón "Volver al Inicio"
        if (ride.status == 'cancelled' && _currentRide?.status != 'cancelled') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El viaje ha sido cancelado'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          // NO hacer Navigator.pop() - dejar que la UI muestre pantalla de cancelado
        }

        setState(() {
          _currentRide = ride;
          _updateStatus();
          _setupMapMarkers();
        });
        _calculateRoute();
      }
    });
  }

  /// Whether the ride is in a pre-pickup phase (driver going to or at pickup)
  bool _isPrePickupStatus() {
    final s = _currentRide?.status;
    return s == 'accepted' || s == 'driver_arriving' || s == 'arrived' || s == 'waiting_verification';
  }

  /// Whether the ride is in transit (driving to destination)
  bool _isInTransitStatus() {
    final s = _currentRide?.status;
    return s == 'in_progress' || s == 'arriving_destination';
  }

  void _updateStatus() {
    if (_currentRide == null) return;

    switch (_currentRide!.status) {
      case 'searching':
        _currentStatus = 'Buscando conductor...';
      case 'accepted':
        _currentStatus = 'Conductor asignado - En camino';
      case 'driver_arriving':
        _currentStatus = 'Tu conductor ha llegado';
      case 'waiting_verification':
        _currentStatus = 'Verificación en proceso';
      case 'in_progress':
        _currentStatus = 'Viaje en curso';
      case 'arriving_destination':
        _currentStatus = 'Llegando al destino';
      case 'completed':
        _currentStatus = 'Viaje completado';
      case 'cancelled':
        _currentStatus = 'Viaje cancelado';
      case 'arrived': // legacy
        _currentStatus = 'Tu conductor ha llegado';
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
        // ✅ TRIPLE VERIFICACIÓN para prevenir operaciones después de dispose
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
        // ✅ TRIPLE VERIFICACIÓN para prevenir operaciones después de dispose
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
      final locationData = await FirebaseService()
          .getDriverLocationWithHeading(_currentRide!.driverId);

      if (locationData != null && mounted) {
        final driverLocation = LatLng(locationData['lat']!, locationData['lng']!);
        _driverHeading = locationData['heading'] ?? 0.0;
        _updateDriverPosition(driverLocation);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error al actualizar ubicación del conductor', e, stackTrace);
    }
  }

  void _updateDriverPosition(LatLng position) {
    // Throttle: Solo actualizar si la posición cambió más de 10 metros
    if (_lastUpdatedDriverLatLng != null) {
      final distance = Geolocator.distanceBetween(
        _lastUpdatedDriverLatLng!.latitude,
        _lastUpdatedDriverLatLng!.longitude,
        position.latitude,
        position.longitude,
      );
      if (distance < 10) return;
    }

    _lastUpdatedDriverLatLng = position;

    // Solo actualizar el marcador del conductor, no reconstruir todo el mapa
    setState(() {
      _driverLatLng = position;
      _markers.removeWhere((m) => m.markerId.value == 'driver');
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: position,
        infoWindow: InfoWindow(
          title: 'Conductor',
          snippet: _currentRide?.vehicleInfo?['driverName'] ?? 'Conductor asignado',
        ),
        icon: _driverIcon ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        rotation: _driverHeading,
      ));
    });

    // Camera follows driver with bearing (like Google Maps Navigation)
    if (_isFollowingDriver && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(
          target: position,
          zoom: 17.5,
          bearing: _driverHeading,
          tilt: 45.0,
        )),
      );
    }

    _calculateDistances();
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
      if (_isPrePickupStatus()) {
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
      // Simulación de cálculo de ETA (en producción usar Google Directions API)
      double distance;
      
      if (_isPrePickupStatus()) {
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

    // Marcador de origen (icono moderno)
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
      icon: _originIcon ?? BitmapDescriptor.defaultMarker,
    ));

    // Marcador de destino (icono moderno)
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
      icon: _destinationIcon ?? BitmapDescriptor.defaultMarker,
    ));

    // Marcador del conductor (icono moderno de auto)
    if (_driverLatLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driverLatLng!,
        infoWindow: InfoWindow(
          title: 'Conductor',
          snippet: _currentRide!.vehicleInfo?['driverName'] ?? 'Conductor asignado',
        ),
        icon: _driverIcon ?? BitmapDescriptor.defaultMarker,
      ));
    }

    // La ubicación del pasajero se muestra con el punto azul nativo de Google Maps
    // (myLocationEnabled: true), no necesita marcador custom adicional

    setState(() {});
  }

  Future<void> _calculateRoute() async {
    if (_currentRide == null) return;

    _polylines.clear();

    LatLng? origin;
    LatLng? destination;

    if (_driverLatLng != null && _isPrePickupStatus()) {
      origin = _driverLatLng!;
      destination = _currentRide!.pickupLocation;
    } else if (_isInTransitStatus()) {
      origin = _driverLatLng ?? _currentRide!.pickupLocation;
      destination = _currentRide!.destinationLocation;
    }

    if (origin != null && destination != null) {
      // Get real route from Directions API
      List<LatLng> points = await _getRoutePoints(origin, destination);

      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: primaryColor,
        width: 5,
      ));

      setState(() {
        _routePoints = points;
      });
    }
  }

  Future<List<LatLng>> _getRoutePoints(LatLng origin, LatLng destination) async {
    try {
      final polylinePoints = PolylinePoints(apiKey: AppConfig.googleMapsApiKey);
      final result = await polylinePoints.getRouteBetweenCoordinatesV2(
        request: RoutesApiRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          travelMode: TravelMode.driving,
        ),
      );
      if (result.primaryRoute?.polylinePoints case List<PointLatLng> points) {
        return points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
      }
    } catch (e) {
      debugPrint('Error getting route: $e');
    }
    // Fallback to direct line
    return [origin, destination];
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
    // ✅ CORREGIDO: Intentar obtener teléfono de vehicleInfo o directamente de Firestore
    String? driverPhone = _currentRide?.vehicleInfo?['driverPhone'];

    // Si no está en vehicleInfo, intentar obtener desde Firestore
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Número de conductor no disponible'),
          backgroundColor: Colors.orange,
        ),
      );
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
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Emergencia', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: const Text(
            '¿Necesitas ayuda de emergencia? Esto notificará a nuestro equipo de soporte inmediatamente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _activateEmergency();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Activar Emergencia'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergencia activada. Ayuda en camino.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al activar emergencia: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelRide() async {
    if (_currentRide?.status == 'in_progress') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes cancelar un viaje en curso'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Viaje'),
        content: const Text('¿Estás seguro de que deseas cancelar este viaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, Cancelar'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cancelar: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  backgroundImage: _currentRide?.vehicleInfo?['driverPhoto'] != null
                      ? NetworkImage(_currentRide!.vehicleInfo?['driverPhoto'])
                      : null,
                  child: _currentRide?.vehicleInfo?['driverPhoto'] == null
                      ? Icon(Icons.person, size: 30, color: primaryColor)
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
                          Icon(Icons.star, color: Colors.amber, size: 16),
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
                      iconSize: 20,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      style: IconButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _openChat,
                      icon: const Icon(Icons.chat),
                      iconSize: 20,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      style: IconButton.styleFrom(
                        backgroundColor: accentColor,
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

  /// Verify the driver code entered by the passenger
  Future<void> _verifyDriverCode() async {
    final code = _verificationCodeController.text.trim();
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el código de 4 dígitos'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_currentRide?.driverVerificationCode == null) return;

    setState(() => _isVerifyingCode = true);
    try {
      if (code == _currentRide!.driverVerificationCode) {
        await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
          'isDriverVerified': true,
        });
        if (mounted) {
          _verificationCodeController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Código verificado correctamente'), backgroundColor: Color(0xFFFF6B00)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Código incorrecto. Intenta de nuevo.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifyingCode = false);
    }
  }

  /// Build inline verification card (shown when driver has arrived)
  Widget _buildVerificationCard() {
    final passengerCode = _currentRide?.passengerVerificationCode ?? '----';
    final isDriverVerified = _currentRide?.isDriverVerified ?? false;
    final isPassengerVerified = _currentRide?.isPassengerVerified ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              Text(
                'Verificación Mutua',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Passenger's code (to tell the driver)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isPassengerVerified ? Icons.check_circle : Icons.info_outline,
                  color: isPassengerVerified ? primaryColor : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPassengerVerified ? 'Conductor te verificó' : 'Dile este código al conductor:',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                      ),
                      if (!isPassengerVerified)
                        Text(
                          passengerCode,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
                        ),
                    ],
                  ),
                ),
                if (isPassengerVerified)
                  Icon(Icons.check_circle, color: primaryColor, size: 28),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Driver code input (for passenger to verify)
          if (!isDriverVerified) ...[
            Text(
              'Ingresa el código del conductor:',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _verificationCodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '0000',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isVerifyingCode ? null : _verifyDriverCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isVerifyingCode
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verificar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  const Text('Conductor verificado', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
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
          if (_isPrePickupStatus()) ...[
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
          // Sección de destino visible
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
    // ✅ Determinar la posición inicial del mapa
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
                onCameraMoveStarted: () {
                  // User manually moved the map, stop auto-follow
                  if (_isFollowingDriver) {
                    setState(() => _isFollowingDriver = false);
                  }
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                trafficEnabled: true,
                buildingsEnabled: true,
              ),
              // Re-center button (visible when not following driver)
              if (!_isFollowingDriver && _driverLatLng != null)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    backgroundColor: primaryColor,
                    onPressed: () {
                      setState(() => _isFollowingDriver = true);
                      if (_driverLatLng != null && _mapController != null) {
                        _mapController!.animateCamera(
                          CameraUpdate.newCameraPosition(CameraPosition(
                            target: _driverLatLng!,
                            zoom: 17.5,
                            bearing: _driverHeading,
                            tilt: 45.0,
                          )),
                        );
                      }
                    },
                    child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                  ),
                ),
              // Chip overlay minimalista con ETA e info del viaje
              if (_isMapLoaded)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time,
                            color: primaryColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'ETA: $_estimatedArrival',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                        if (_distanceToDestination > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 1,
                            height: 14,
                            color: Colors.grey.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_distanceToDestination.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              // ✅ Indicador de carga mientras el mapa no está listo
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

  // ✅ Nuevo método para centrar el mapa en pickup y destino
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Compartir
              _buildActionChip(
                icon: Icons.share,
                label: 'Compartir',
                color: ModernTheme.rappiOrange,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Compartiendo viaje...')),
                  );
                },
              ),
              // Llamar al conductor
              _buildActionChip(
                icon: Icons.phone,
                label: 'Llamar',
                color: ModernTheme.success,
                onTap: _callDriver,
              ),
              // Chat
              _buildActionChip(
                icon: Icons.chat_bubble_outline,
                label: 'Chat',
                color: ModernTheme.info,
                onTap: _openChat,
              ),
              // Cancelar (solo si no está en progreso o completado)
              if (_currentRide?.status != 'completed')
                _buildActionChip(
                  icon: Icons.cancel_outlined,
                  label: 'Cancelar',
                  color: ModernTheme.error,
                  onTap: _cancelRide,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Si el viaje está cancelado, mostrar pantalla especial con botón para volver
    if (_currentRide?.status == 'cancelled') {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        appBar: AppBar(
          title: const Text('Viaje Cancelado'),
          backgroundColor: Colors.red,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel, size: 80, color: Colors.red),
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
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                icon: const Icon(Icons.home),
                label: const Text('Volver al Inicio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: Text(
          'Seguimiento de Viaje',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                  // Show verification card when driver has arrived
                  if (_currentRide?.status == 'driver_arriving' ||
                      _currentRide?.status == 'waiting_verification')
                    _buildVerificationCard(),
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