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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import 'package:flutter_animarker/flutter_map_marker_animation.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/modern_theme.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../shared/rating_dialog.dart';
import '../shared/chat_screen.dart';
import '../../utils/map_marker_utils.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Completer para Animarker
  final Completer<GoogleMapController> _mapCompleter = Completer<GoogleMapController>();
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot>? _tripSubscription;
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
  bool _isFollowingDriver = true; // Toggle for camera follow
  // UI: control de colapso del bottom sheet
  bool _isPanelExpanded = true;

  // Para verificación de código
  final TextEditingController _codeController = TextEditingController();

  // Animaciones
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint('🚗 ActiveTripScreen.initState - tripId=${widget.tripId}, hasInitialTrip=${widget.initialTrip != null}, initialLocation=${widget.initialLocation}');
    // Use initial location from home screen for immediate marker display
    if (widget.initialLocation != null) {
      _currentLocation = widget.initialLocation;
    }
    _initAnimations();
    _loadCarIcon();
    _loadTrip();
    _startLocationTracking();
    _listenToTripUpdates();
  }

  /// Cargar iconos modernos para el mapa
  Future<void> _loadCarIcon() async {
    try {
      _carIcon = await MapMarkerUtils.getCarTopViewIcon();
      _pickupIcon = await MapMarkerUtils.getOriginIcon();
      _destinationIcon = await MapMarkerUtils.getDestinationIcon();
      if (mounted && !_isDisposed) setState(() {});
    } catch (e) {
      debugPrint('⚠️ Error cargando iconos de mapa: $e');
    }
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tripSubscription?.cancel();
    _positionSubscription?.cancel();
    _locationUpdateTimer?.cancel();
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
        // ✅ FIX: Agregar timeout para evitar congelamiento
        final tripDoc = await _firestore.collection('rides').doc(widget.tripId).get()
            .timeout(const Duration(seconds: 15), onTimeout: () {
              throw TimeoutException('Timeout cargando viaje');
            });
        if (tripDoc.exists && mounted) {
          setState(() {
            _currentTrip = TripModel.fromJson({
              'id': tripDoc.id,
              ...tripDoc.data()!,
            });
            _updateTripState();
          });
        }
      } on TimeoutException catch (e) {
        debugPrint('⏱️ $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error de conexión. Reintentando...'),
              backgroundColor: ModernTheme.warning,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error cargando viaje: $e');
      }
    }
    _updateMapMarkers();
  }

  void _listenToTripUpdates() {
    _tripSubscription = _firestore
        .collection('rides')
        .doc(widget.tripId)
        .snapshots()
        .listen((snapshot) {
      if (_isDisposed || !mounted) return;

      if (snapshot.exists) {
        setState(() {
          _currentTrip = TripModel.fromJson({
            'id': snapshot.id,
            ...snapshot.data()!,
          });
          _updateTripState();
          _updateMapMarkers();
        });
      }
    });
  }

  void _updateTripState() {
    if (_currentTrip == null) return;

    switch (_currentTrip!.status) {
      case 'accepted':
        _tripState = DriverTripState.goingToPickup;
        break;
      case 'driver_arriving':
        _tripState = DriverTripState.arrivedAtPickup;
        break;
      case 'waiting_verification':
        // Verification removed - treat as in_progress
        _tripState = DriverTripState.inProgress;
        break;
      case 'in_progress':
        _tripState = DriverTripState.inProgress;
        break;
      case 'arriving_destination':
        _tripState = DriverTripState.arrivedAtDestination;
        break;
      case 'completed':
        _tripState = DriverTripState.completed;
        break;
      default:
        _tripState = DriverTripState.goingToPickup;
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
      debugPrint('Error iniciando tracking de ubicación: $e');
    }
  }

  Future<void> _updateLocationInFirebase() async {
    if (_currentLocation == null || _currentTrip == null) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final driverId = authProvider.currentUser?.id;

      if (driverId != null) {
        // Escribir en el ride Y en drivers (para que el pasajero pueda leer la ubicación)
        await Future.wait([
          _firestore.collection('rides').doc(widget.tripId).update({
            'driverLocation': {
              'latitude': _currentLocation!.latitude,
              'longitude': _currentLocation!.longitude,
              'heading': _currentHeading,
              'timestamp': FieldValue.serverTimestamp(),
            },
          }).timeout(const Duration(seconds: 10), onTimeout: () {
            debugPrint('⏱️ Timeout actualizando ubicación en ride');
          }),
          _firestore.collection('drivers').doc(driverId).update({
            'currentLocation': {
              'latitude': _currentLocation!.latitude,
              'longitude': _currentLocation!.longitude,
              'heading': _currentHeading,
              'timestamp': FieldValue.serverTimestamp(),
            },
          }).timeout(const Duration(seconds: 10), onTimeout: () {
            debugPrint('⏱️ Timeout actualizando ubicación en drivers');
          }),
        ]);
      }
    } on TimeoutException {
      debugPrint('⏱️ Timeout en actualización de ubicación');
    } catch (e) {
      debugPrint('Error actualizando ubicación: $e');
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
        icon: _carIcon ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        rotation: _currentHeading,
        infoWindow: const InfoWindow(title: 'Tu ubicación'),
      ));
    }

    // Marcador de recogida (icono moderno verde)
    _markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: LatLng(
        _currentTrip!.pickupLocation.latitude,
        _currentTrip!.pickupLocation.longitude,
      ),
      icon: _pickupIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(
        title: 'Punto de recogida',
        snippet: _currentTrip!.pickupAddress,
      ),
    ));

    // Marcador de destino (icono moderno rojo)
    _markers.add(Marker(
      markerId: const MarkerId('destination'),
      position: LatLng(
        _currentTrip!.destinationLocation.latitude,
        _currentTrip!.destinationLocation.longitude,
      ),
      icon: _destinationIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(
        title: 'Destino',
        snippet: _currentTrip!.destinationAddress,
      ),
    ));

    // Dibujar ruta
    _drawRoute();

    // Camera follows driver with dynamic bearing (only if toggle is on)
    if (_isFollowingDriver && _mapController != null && _currentLocation != null) {
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

  Future<void> _drawRoute() async {
    if (_currentTrip == null) {
      debugPrint('🚗 _drawRoute: _currentTrip es NULL');
      return;
    }

    debugPrint('🚗 _drawRoute: estado=${_tripState.name}, origin=$_currentLocation');
    _polylines.clear();

    LatLng? origin = _currentLocation;
    LatLng destination;

    if (_tripState == DriverTripState.goingToPickup ||
        _tripState == DriverTripState.arrivedAtPickup ||
        _tripState == DriverTripState.waitingVerification) {
      destination = LatLng(
        _currentTrip!.pickupLocation.latitude,
        _currentTrip!.pickupLocation.longitude,
      );
    } else {
      destination = LatLng(
        _currentTrip!.destinationLocation.latitude,
        _currentTrip!.destinationLocation.longitude,
      );
    }

    if (origin != null) {
      // Get real route from Directions API
      final routePoints = await _getRoutePoints(origin, destination);
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: routePoints,
        color: ModernTheme.rappiOrange,
        width: 5,
      ));
      if (mounted) setState(() {});
    }
  }

  Future<List<LatLng>> _getRoutePoints(LatLng origin, LatLng destination) async {
    try {
      debugPrint('🚗 _getRoutePoints: from=$origin to=$destination');
      final polylinePoints = PolylinePoints(apiKey: AppConfig.googleMapsApiKey);
      final result = await polylinePoints.getRouteBetweenCoordinatesV2(
        request: RoutesApiRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          travelMode: TravelMode.driving,
        ),
      );
      if (result.primaryRoute?.polylinePoints case List<PointLatLng> points) {
        debugPrint('🚗 Route OK: ${points.length} points');
        return points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
      }
      debugPrint('🚗 Route: no primaryRoute found, errorMessage=${result.errorMessage}');
    } catch (e) {
      debugPrint('🚗 Error getting route: $e');
    }
    return [origin, destination];
  }

  // ==================== ACCIONES DEL CONDUCTOR ====================

  /// Marcar que el conductor llegó al punto de recogida
  Future<void> _markArrived() async {
    setState(() => _isLoading = true);

    try {
      // ✅ FIX: Agregar timeout
      await _firestore.collection('rides').doc(widget.tripId).update({
        'status': 'driver_arriving',
        'arrivedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Timeout marcando llegada');
      });

      // Enviar notificación al pasajero
      await _sendNotification(
        userId: _currentTrip!.userId,
        title: '¡Tu conductor ha llegado!',
        body: 'Tu conductor está esperándote en el punto de recogida.',
        data: {'tripId': widget.tripId, 'type': 'driver_arrived'},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Has marcado tu llegada. El pasajero ha sido notificado.'),
            backgroundColor: ModernTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: ModernTheme.error,
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
                color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user, color: ModernTheme.rappiOrange),
            ),
            const SizedBox(width: 12),
            const Text('Verificar Pasajero'),
          ],
        ),
        content: Column(
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
                  borderSide: const BorderSide(color: ModernTheme.rappiOrange, width: 2),
                ),
              ),
            ),
          ],
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
              backgroundColor: ModernTheme.rappiOrange,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El código debe tener 4 dígitos'),
          backgroundColor: ModernTheme.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ FIX: Agregar timeout
      final tripDoc = await _firestore.collection('rides').doc(widget.tripId).get()
          .timeout(const Duration(seconds: 15), onTimeout: () {
            throw TimeoutException('Timeout verificando código');
          });
      final tripData = tripDoc.data();

      if (tripData == null) throw Exception('Viaje no encontrado');

      final passengerCode = tripData['passengerVerificationCode'] ?? tripData['verificationCode'];

      // ✅ FIX: Validar que el código no sea null antes de comparar
      if (passengerCode == null || passengerCode.toString().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El pasajero aún no tiene código asignado'),
              backgroundColor: ModernTheme.warning,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (code == passengerCode) {
        // Código correcto - marcar verificación y cambiar status (con timeout)
        await _firestore.collection('rides').doc(widget.tripId).update({
          'isPassengerVerified': true,
          'passengerVerifiedAt': FieldValue.serverTimestamp(),
          'status': 'waiting_verification',
        }).timeout(const Duration(seconds: 15), onTimeout: () {
          throw TimeoutException('Timeout guardando verificación');
        });

        _codeController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Pasajero verificado correctamente!'),
              backgroundColor: ModernTheme.success,
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
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verificando: $e'),
            backgroundColor: ModernTheme.error,
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
            Icon(Icons.qr_code, color: ModernTheme.rappiOrange),
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
                color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ModernTheme.rappiOrange, width: 2),
              ),
              child: Text(
                driverCode,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                  color: ModernTheme.rappiOrange,
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
              backgroundColor: ModernTheme.rappiOrange,
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

    try {
      // Verificar que ambas partes estén verificadas (con timeout)
      final tripDoc = await _firestore.collection('rides').doc(widget.tripId).get()
          .timeout(const Duration(seconds: 15), onTimeout: () {
            throw TimeoutException('Timeout verificando estado del viaje');
          });
      final tripData = tripDoc.data();

      final isPassengerVerified = tripData?['isPassengerVerified'] ?? false;
      final isDriverVerified = tripData?['isDriverVerified'] ?? false;

      if (!isPassengerVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Primero debes verificar el código del pasajero'),
            backgroundColor: ModernTheme.warning,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      if (!isDriverVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El pasajero aún no ha verificado tu código'),
            backgroundColor: ModernTheme.warning,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // ✅ FIX: Agregar timeout
      await _firestore.collection('rides').doc(widget.tripId).update({
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
        'verificationCompletedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Timeout iniciando viaje');
      });

      // Notificar al pasajero
      await _sendNotification(
        userId: _currentTrip!.userId,
        title: '¡Viaje iniciado!',
        body: 'Tu viaje ha comenzado. Disfruta del trayecto.',
        data: {'tripId': widget.tripId, 'type': 'trip_started'},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Viaje iniciado! Dirígete al destino.'),
            backgroundColor: ModernTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error iniciando viaje: $e'),
            backgroundColor: ModernTheme.error,
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
              backgroundColor: ModernTheme.success,
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

      // ✅ FIX: Agregar timeout
      await _firestore.collection('rides').doc(widget.tripId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'finalFare': finalFare,
      }).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Timeout completando viaje');
      });

      // Notificar al pasajero
      await _sendNotification(
        userId: _currentTrip!.userId,
        title: '¡Viaje completado!',
        body: 'Has llegado a tu destino. ¡Gracias por viajar con nosotros!',
        data: {'tripId': widget.tripId, 'type': 'trip_completed'},
      );

      if (mounted) {
        // Mostrar diálogo de resumen y calificación
        _showTripCompletedDialog(finalFare);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finalizando viaje: $e'),
            backgroundColor: ModernTheme.error,
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ModernTheme.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: ModernTheme.success,
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
              'Ganancia: S/. ${finalFare.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: ModernTheme.rappiOrange,
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
                    '${((_currentTrip?.estimatedDistance ?? 0) / 1000).toStringAsFixed(1)} km',
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
                  backgroundColor: ModernTheme.rappiOrange,
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
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ModernTheme.rappiOrange),
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
      driverName: _currentTrip?.vehicleInfo?['passengerName'] ?? 'Pasajero',
      driverPhoto: _currentTrip?.vehicleInfo?['passengerPhoto'] ?? '',
      tripId: widget.tripId,
      onSubmit: (rating, comment, tags) async {
        // Guardar calificación del conductor hacia el pasajero
        await _firestore.collection('rides').doc(widget.tripId).update({
          'driverRating': rating,
          'driverComment': comment,
          'driverRatingTags': tags,
          'driverRatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );
  }

  /// Enviar notificación a un usuario mediante Firestore
  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': body,
        'data': data ?? {},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error enviando notificación: $e');
    }
  }

  // ==================== COMUNICACIÓN CON PASAJERO ====================

  Future<void> _callPassenger() async {
    final phone = _currentTrip?.vehicleInfo?['passengerPhone'] as String?;
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Número de teléfono no disponible'),
            backgroundColor: ModernTheme.warning,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Error al llamar: $e');
    }
  }

  void _openPassengerChat() {
    if (_currentTrip == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserName: _currentTrip!.vehicleInfo?['passengerName'] ?? 'Pasajero',
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
    final canLeave = _tripState == DriverTripState.completed;
    return PopScope(
      canPop: canLeave,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBackPressed();
      },
      child: Scaffold(
      body: Stack(
        children: [
          // Mapa con animación de marcador (estilo Uber/DiDi)
          Animarker(
            mapId: _mapCompleter.future.then<int>((c) => c.mapId),
            curve: Curves.easeInOut,
            duration: const Duration(milliseconds: 1500),
            useRotation: false, // Rotación manual via heading del GPS
            markers: _markers,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentLocation ?? const LatLng(-12.0464, -77.0428),
                zoom: 15,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (!_mapCompleter.isCompleted) {
                  _mapCompleter.complete(controller);
                }
              },
              onCameraMoveStarted: () {
                // User manually moved the map - stop following driver
                if (_isFollowingDriver) {
                  setState(() => _isFollowingDriver = false);
                }
              },
              polylines: _polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // UI: Card superior con avatar y nombre del pasajero
          if (_currentTrip != null)
            SafeArea(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: ModernTheme.getCardShadow(context),
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: ModernTheme.getCardShadow(context),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _handleBackPressed,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: ModernTheme.rappiOrange.withValues(alpha: 0.15),
                      backgroundImage: _currentTrip?.vehicleInfo?['passengerPhoto'] != null
                          ? NetworkImage(_currentTrip!.vehicleInfo!['passengerPhoto'])
                          : null,
                      child: _currentTrip?.vehicleInfo?['passengerPhoto'] == null
                          ? const Icon(Icons.person, color: ModernTheme.rappiOrange)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentTrip?.vehicleInfo?['passengerName'] ?? 'Pasajero',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, size: 13, color: Colors.amber),
                              const SizedBox(width: 3),
                              Text(
                                '${_currentTrip?.vehicleInfo?['passengerRating']?.toStringAsFixed(1) ?? '5.0'}',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Call passenger button
                    IconButton(
                      icon: const Icon(Icons.call, color: ModernTheme.success),
                      onPressed: _callPassenger,
                    ),
                    // Chat with passenger button
                    IconButton(
                      icon: const Icon(Icons.message, color: ModernTheme.primaryBlue),
                      onPressed: _openPassengerChat,
                    ),
                    // Navigate button
                    IconButton(
                      icon: const Icon(Icons.navigation, color: ModernTheme.rappiOrange),
                      onPressed: _openNavigation,
                    ),
                  ],
                ),
              ),
            )
          else
            // Sin viaje: solo botón back
            SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: ModernTheme.getCardShadow(context),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _handleBackPressed,
                  ),
                ),
              ),
            ),

          // Re-center FAB (shown when user moves the map manually)
          if (!_isFollowingDriver)
            Positioned(
              right: 16,
              bottom: 320,
              child: FloatingActionButton.small(
                heroTag: 'recenter',
                backgroundColor: Theme.of(context).colorScheme.surface,
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
                child: const Icon(Icons.my_location, color: ModernTheme.rappiOrange),
              ),
            ),

          // Panel inferior
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomPanel(),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: ModernTheme.rappiOrange),
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildBottomPanel() {
    // UI: Bottom sheet colapsable con handle interactivo
    return GestureDetector(
      onTap: () => setState(() => _isPanelExpanded = !_isPanelExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: ModernTheme.getFloatingShadow(context),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle colapsable
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Estado del viaje (siempre visible)
            _buildStatusIndicator(),

            // Contenido colapsable
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isPanelExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),

                  // Información de ubicación
                  _buildLocationInfo(),

                  const SizedBox(height: 20),

                  // Botón de acción principal
                  _buildMainActionButton(),

                  const SizedBox(height: 12),

                  // Botones secundarios
                  _buildSecondaryButtons(),
                ],
              ),
              secondChild: const SizedBox(height: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (_tripState) {
      case DriverTripState.goingToPickup:
        statusText = 'Yendo al punto de recogida';
        statusColor = ModernTheme.info;
        statusIcon = Icons.directions_car;
        break;
      case DriverTripState.arrivedAtPickup:
        statusText = 'Has llegado - Esperando pasajero';
        statusColor = ModernTheme.warning;
        statusIcon = Icons.place;
        break;
      case DriverTripState.waitingVerification:
        statusText = 'Verificación en proceso';
        statusColor = ModernTheme.warning;
        statusIcon = Icons.verified_user;
        break;
      case DriverTripState.inProgress:
        statusText = 'Viaje en curso';
        statusColor = ModernTheme.rappiOrange;
        statusIcon = Icons.local_taxi;
        break;
      case DriverTripState.arrivedAtDestination:
        statusText = 'Has llegado al destino';
        statusColor = ModernTheme.success;
        statusIcon = Icons.flag;
        break;
      case DriverTripState.completed:
        statusText = 'Viaje completado';
        statusColor = ModernTheme.success;
        statusIcon = Icons.check_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Icon(statusIcon, color: statusColor),
              );
            },
          ),
          const SizedBox(width: 12),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: ModernTheme.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recogida',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      _currentTrip?.pickupAddress ?? 'Cargando...',
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Container(
              height: 20,
              width: 2,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          ),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: ModernTheme.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destino',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      _currentTrip?.destinationAddress ?? 'Cargando...',
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButton() {
    String buttonText;
    IconData buttonIcon;
    VoidCallback? onPressed;
    Color buttonColor = ModernTheme.rappiOrange;

    switch (_tripState) {
      case DriverTripState.goingToPickup:
        buttonText = 'He llegado al punto de recogida';
        buttonIcon = Icons.place;
        onPressed = _markArrived;
        break;
      case DriverTripState.arrivedAtPickup:
        buttonText = 'Iniciar viaje';
        buttonIcon = Icons.play_arrow;
        onPressed = _startTrip;
        buttonColor = ModernTheme.rappiOrange;
        break;
      case DriverTripState.waitingVerification:
        // Verification removed - treat same as arrivedAtPickup
        buttonText = 'Iniciar viaje';
        buttonIcon = Icons.play_arrow;
        onPressed = _startTrip;
        break;
      case DriverTripState.inProgress:
        buttonText = 'Finalizar viaje';
        buttonIcon = Icons.flag;
        onPressed = _completeTrip;
        buttonColor = ModernTheme.success;
        break;
      case DriverTripState.arrivedAtDestination:
        buttonText = 'Confirmar llegada';
        buttonIcon = Icons.check_circle;
        onPressed = _completeTrip;
        buttonColor = ModernTheme.success;
        break;
      case DriverTripState.completed:
        buttonText = 'Viaje completado';
        buttonIcon = Icons.check_circle;
        onPressed = null;
        break;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(buttonIcon),
        label: Text(
          buttonText,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openNavigation,
                icon: const Icon(Icons.navigation),
                label: const Text('Navegar'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // Mostrar diálogo de emergencia o cancelación
                  _showEmergencyOptions();
                },
                icon: const Icon(Icons.warning, color: ModernTheme.error),
                label: const Text('Emergencia', style: TextStyle(color: ModernTheme.error)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: ModernTheme.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        // Botón para completar viaje manualmente (cuando está en progreso)
        if (_tripState == DriverTripState.inProgress) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _forceCompleteTrip,
              icon: const Icon(Icons.check_circle_outline, color: ModernTheme.success),
              label: const Text(
                'Completar viaje manualmente',
                style: TextStyle(color: ModernTheme.success),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: ModernTheme.success),
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

  /// Forzar completar viaje manualmente (sin depender del GPS)
  Future<void> _forceCompleteTrip() async {
    // Confirmar con más énfasis que es manual
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: ModernTheme.warning),
            SizedBox(width: 8),
            Text('Completar manualmente'),
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
              backgroundColor: ModernTheme.success,
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: ModernTheme.error),
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
              leading: const Icon(Icons.support_agent, color: ModernTheme.warning),
              title: const Text('Contactar soporte'),
              onTap: () {
                Navigator.pop(context);
                // Abrir chat de soporte
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: ModernTheme.error),
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

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Viaje'),
        content: const Text(
          '¿Estás seguro de que deseas cancelar este viaje? '
          'Esto puede afectar tu tasa de aceptación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelTrip();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelTrip() async {
    setState(() => _isLoading = true);

    try {
      // ✅ FIX: Agregar timeout
      await _firestore.collection('rides').doc(widget.tripId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'driver',
        'cancellationReason': 'Cancelado por el conductor',
      }).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Timeout cancelando viaje');
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelando viaje: $e'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
