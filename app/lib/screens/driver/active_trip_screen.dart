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
import 'package:flutter/services.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
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
              backgroundColor: AppColors.warning,
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
        color: AppColors.rappiOrange,
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
      // ✅ FIX: Agregar timeout
      await _firestore.collection('rides').doc(widget.tripId).update({
        'status': 'driver_arriving',
        'arrivedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Timeout marcando llegada');
      });

      // Start waiting timer
      _startWaitingTimer();

      // Enviar notificación al pasajero
      await _sendNotification(
        userId: _currentTrip!.userId,
        title: '¡Tu conductor ha llegado!',
        body: 'Tu conductor está esperándote en el punto de recogida.',
        data: {'tripId': widget.tripId, 'type': 'driver_arrived'},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Has llegado. Espera al pasajero y toca "Pasajero a bordo" cuando suba.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
                  borderSide: const BorderSide(color: AppColors.rappiOrange, width: 2),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El código debe tener 4 dígitos'),
          backgroundColor: AppColors.warning,
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
              backgroundColor: AppColors.warning,
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
            content: Text('Error verificando: $e'),
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
      // ✅ FIX: Agregar timeout
      await _firestore.collection('rides').doc(widget.tripId).update({
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
        'waitingTimeSeconds': _waitingSeconds,
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
            content: Text('Error iniciando viaje: $e'),
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
        content: Column(
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
              'Ganancia: S/. ${finalFare.toStringAsFixed(2)}',
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
            backgroundColor: AppColors.warning,
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
            // Map with animated marker (Uber/DiDi style)
            Animarker(
              mapId: _mapCompleter.future.then<int>((c) => c.mapId),
              curve: Curves.easeInOut,
              duration: const Duration(milliseconds: 1500),
              useRotation: false,
              markers: _markers,
              child: GoogleMap(
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
                polylines: _polylines,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: true,
                buildingsEnabled: true,
              ),
            ),

            // Top gradient overlay with top bar
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
                      AppColors.getSurface(context),
                      AppColors.getSurface(context),
                      AppColors.getSurface(context).withValues(alpha: 0.85),
                      AppColors.getSurface(context).withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.4, 0.7, 1.0],
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
            Positioned(
              left: 16,
              bottom: 380,
              child: _buildNavigatorPill(),
            ),

            // Floating round buttons (right side)
            Positioned(
              right: 16,
              bottom: 390,
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
              child: _buildPassengerBottomSheet(),
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
    final passengerName = _currentTrip?.vehicleInfo?['passengerName'] as String? ?? 'Pasajero';
    final passengerPhoto = _currentTrip?.vehicleInfo?['passengerPhoto'] as String?;
    final passengerRating = (_currentTrip?.vehicleInfo?['passengerRating'] as num?)?.toDouble() ?? 5.0;

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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 14),
                const SizedBox(width: 2),
                Text(
                  passengerRating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
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
                  _currentTrip?.paymentMethod ?? 'Efectivo',
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
            _buildActionCircleButton(
              icon: Icons.phone,
              color: AppColors.ctaGreen,
              onPressed: _callPassenger,
            ),
            const SizedBox(height: 10),
            _buildActionCircleButton(
              icon: Icons.chat_bubble_outline,
              color: AppColors.ctaGreen,
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
        child: Icon(icon, size: 24, color: Colors.black87),
      ),
    );
  }

  // ==================== PRICE ROW ====================

  Widget _buildPriceRow() {
    final fare = _currentTrip?.estimatedFare ?? 0.0;
    final paymentMethod = _currentTrip?.paymentMethod ?? 'Efectivo';
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
            backgroundColor: AppColors.success,
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
      // State 2: waiting for passenger -> "Pasajero a bordo" (lime green)
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _startTrip,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ctaGreen,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Pasajero a bordo',
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
            backgroundColor: const Color(0xFF1A73E8),
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
              backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
