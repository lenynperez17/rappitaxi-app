import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:rappitaxi_app/shared/utils/logger.dart';
import '../../../../../shared/providers/riverpod_compat.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../../shared/models/location_model.dart';
import '../../../../shared/models/ride_model.dart';
import '../../../home/presentation/providers/location_provider.dart';
import '../providers/driver_status_provider.dart';
import '../widgets/navigation_instructions_widget.dart';
import '../widgets/ride_progress_widget.dart';
import '../../../chat/presentation/screens/chat_screen.dart';

class DriverNavigationScreen extends ConsumerStatefulWidget {
  final RideModel ride;

  const DriverNavigationScreen({
    super.key,
    required this.ride,
  });

  @override
  ConsumerState<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends ConsumerState<DriverNavigationScreen> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  StreamSubscription<Position>? _positionStream;
  
  LatLng? _currentPosition;
  List<LatLng> _routePoints = [];
  String _currentInstruction = "Iniciando navegación...";
  double _distanceToDestination = 0.0;
  int _estimatedTimeMinutes = 0;
  bool _hasArrivedAtPickup = false;
  bool _isNavigatingToDestination = false;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initializeNavigation() async {
    await _getCurrentLocation();
    await _createRoute();
    _startLocationTracking();
  }

  Future<void> _getCurrentLocation() async {
    final position = await ref.read(currentLocationProvider.future);
    if (position != null) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    }
  }

  Future<void> _createRoute() async {
    if (_currentPosition == null) return;

    final destination = _isNavigatingToDestination 
        ? widget.ride.destination 
        : widget.ride.pickup;

    if (destination == null) return;

    try {
      final polylinePoints = PolylinePoints();
      final result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: 'CONFIGURAR_EN_PRODUCCION', // Usar API key real de Google Maps
        request: PolylineRequest(
          origin: PointLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        setState(() {
          _routePoints = result.points
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
          
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: _routePoints,
              color: AppTheme.primaryColor,
              width: 4,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          };
        });

        await _createMarkers();
        await _calculateDistanceAndTime();
      }
    } catch (e) {
      Logger.error('Error creating route', e);
      _showErrorSnackBar('Error al crear la ruta de navegación');
    }
  }

  Future<void> _createMarkers() async {
    final markers = <Marker>{};

    // Marcador de posición actual
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_position'),
          position: _currentPosition!,
          icon: await BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(size: Size(48, 48)),
            'assets/icons/driver_marker.png',
          ).catchError((_) => BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)),
          infoWindow: const InfoWindow(title: 'Tu ubicación'),
        ),
      );
    }

    // Marcador de destino
    final destination = _isNavigatingToDestination 
        ? widget.ride.destination 
        : widget.ride.pickup;

    if (destination != null) {
      markers.add(
        Marker(
          markerId: MarkerId(_isNavigatingToDestination ? 'destination' : 'pickup'),
          position: LatLng(destination.latitude, destination.longitude),
          icon: await BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(size: Size(48, 48)),
            _isNavigatingToDestination 
                ? 'assets/icons/destination_marker.png'
                : 'assets/icons/pickup_marker.png',
          ).catchError((_) => BitmapDescriptor.defaultMarkerWithHue(
            _isNavigatingToDestination 
                ? BitmapDescriptor.hueRed 
                : BitmapDescriptor.hueGreen
          )),
          infoWindow: InfoWindow(
            title: _isNavigatingToDestination ? 'Destino' : 'Recogida',
            snippet: destination.address,
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _startLocationTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Actualizar cada 10 metros
      ),
    ).listen((Position position) {
      final newPosition = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _currentPosition = newPosition;
      });

      _updateNavigation(newPosition);
      _updateMapCamera(newPosition);
    });
  }

  void _updateNavigation(LatLng currentPosition) {
    final destination = _isNavigatingToDestination 
        ? widget.ride.destination 
        : widget.ride.pickup;

    if (destination == null) return;

    final distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      destination.latitude,
      destination.longitude,
    );

    setState(() {
      _distanceToDestination = distance / 1000; // Convertir a kilómetros
      _estimatedTimeMinutes = (_distanceToDestination * 2).round(); // Estimación básica
    });

    // Verificar si ha llegado al destino (dentro de 50 metros)
    if (distance < 50) {
      if (!_isNavigatingToDestination && !_hasArrivedAtPickup) {
        // Llegó al punto de recogida
        _arrivedAtPickup();
      } else if (_isNavigatingToDestination) {
        // Llegó al destino final
        _arrivedAtDestination();
      }
    }

    // Actualizar instrucciones de navegación
    _updateNavigationInstructions(currentPosition, destination);
  }

  void _updateNavigationInstructions(LatLng current, LocationModel destination) {
    final bearing = Geolocator.bearingBetween(
      current.latitude,
      current.longitude,
      destination.latitude,
      destination.longitude,
    );

    String instruction;
    if (_distanceToDestination > 1) {
      instruction = "Continúa ${_getDirectionFromBearing(bearing)} por ${_distanceToDestination.toStringAsFixed(1)} km";
    } else {
      instruction = "En ${(_distanceToDestination * 1000).round()} metros ${_getDirectionFromBearing(bearing)}";
    }

    if (_currentInstruction != instruction) {
      setState(() {
        _currentInstruction = instruction;
      });
    }
  }

  String _getDirectionFromBearing(double bearing) {
    if (bearing >= -22.5 && bearing < 22.5) return "al norte";
    if (bearing >= 22.5 && bearing < 67.5) return "al noreste";
    if (bearing >= 67.5 && bearing < 112.5) return "al este";
    if (bearing >= 112.5 && bearing < 157.5) return "al sureste";
    if (bearing >= 157.5 || bearing < -157.5) return "al sur";
    if (bearing >= -157.5 && bearing < -112.5) return "al suroeste";
    if (bearing >= -112.5 && bearing < -67.5) return "al oeste";
    if (bearing >= -67.5 && bearing < -22.5) return "al noroeste";
    return "adelante";
  }

  void _updateMapCamera(LatLng position) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(position),
    );
  }

  Future<void> _calculateDistanceAndTime() async {
    if (_routePoints.isEmpty) return;

    double totalDistance = 0;
    for (int i = 0; i < _routePoints.length - 1; i++) {
      totalDistance += Geolocator.distanceBetween(
        _routePoints[i].latitude,
        _routePoints[i].longitude,
        _routePoints[i + 1].latitude,
        _routePoints[i + 1].longitude,
      );
    }

    setState(() {
      _distanceToDestination = totalDistance / 1000;
      _estimatedTimeMinutes = (_distanceToDestination * 2).round();
    });
  }

  void _arrivedAtPickup() {
    setState(() {
      _hasArrivedAtPickup = true;
    });

    _showArrivalDialog(
      'Has llegado al punto de recogida',
      '¿Has recogido al pasajero?',
      () {
        _startNavigationToDestination();
      },
    );
  }

  void _arrivedAtDestination() {
    _showArrivalDialog(
      'Has llegado al destino',
      '¿El viaje ha sido completado?',
      () {
        _completeRide();
      },
    );
  }

  void _startNavigationToDestination() {
    setState(() {
      _isNavigatingToDestination = true;
      _hasArrivedAtPickup = true;
    });

    // Actualizar estado del viaje
    final rideActions = ref.read(currentRideActionsProvider);
    rideActions.startRide(widget.ride.id);

    // Recrear ruta hacia el destino
    _createRoute();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navegando hacia el destino'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _completeRide() {
    final rideActions = ref.read(currentRideActionsProvider);
    rideActions.completeRide(widget.ride.id);

    Navigator.of(context).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Viaje completado exitosamente!'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _showArrivalDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No todavía'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text('Sí, continuar'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? const LatLng(-12.0464, -77.0428),
              zoom: 16,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            compassEnabled: true,
            trafficEnabled: true,
          ),

          // Instrucciones de navegación en la parte superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: NavigationInstructionsWidget(
              instruction: _currentInstruction,
              distance: _distanceToDestination,
              estimatedTime: _estimatedTimeMinutes,
              isNavigatingToDestination: _isNavigatingToDestination,
            ).animate().slideY(begin: -1, end: 0),
          ),

          // Progress del viaje en la parte inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: RideProgressWidget(
              ride: widget.ride,
              hasArrivedAtPickup: _hasArrivedAtPickup,
              isNavigatingToDestination: _isNavigatingToDestination,
              onCancelRide: () => _showCancelRideDialog(),
              onCallPassenger: () => _callPassenger(),
              onMessagePassenger: () => _messagePassenger(),
            ).animate().slideY(begin: 1, end: 0),
          ),

          // Botón de centrar ubicación
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.4,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              onPressed: () {
                if (_currentPosition != null) {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLng(_currentPosition!),
                  );
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelRideDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar viaje'),
        content: const Text('¿Estás seguro de que quieres cancelar este viaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              final rideActions = ref.read(currentRideActionsProvider);
              rideActions.cancelRide(widget.ride.id, 'Cancelado por el conductor');
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }

  void _callPassenger() {
    // TODO: Implementar llamada al pasajero
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Llamando al pasajero...'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }

  void _messagePassenger() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(ride: widget.ride),
      ),
    );
  }
}