// Pantalla de viaje activo para el conductor
// Muestra el estado actual del viaje y permite al conductor:
// - Marcar que llego al punto de recogida
// - Verificar código del pasajero
// - Iniciar el viaje
// - Finalizar el viaje

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../core/design/design_system.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_button.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/firestore_error_handler.dart';
import '../shared/chat_screen.dart';
import '../shared/rating_dialog.dart';

/// Estados del viaje desde la perspectiva del conductor
enum DriverTripState {
  goingToPickup,    // Yendo al punto de recogida
  arrivedAtPickup,  // Llego al punto de recogida
  waitingVerification, // Esperando verificación mutua
  inProgress,       // Viaje en curso
  arrivedAtDestination, // Llego al destino
  completed,        // Viaje completado
}

class ActiveTripScreen extends StatefulWidget {
  final String tripId;
  final TripModel? initialTrip;

  const ActiveTripScreen({
    super.key,
    required this.tripId,
    this.initialTrip,
  });

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot>? _tripSubscription;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _locationUpdateTimer;

  TripModel? _currentTrip;
  DriverTripState _tripState = DriverTripState.goingToPickup;
  LatLng? _currentLocation;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  bool _isLoading = false;
  bool _isDisposed = false;

  // Para verificación de código
  final TextEditingController _codeController = TextEditingController();

  // Animaciones
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadTrip();
    _startLocationTracking();
    _listenToTripUpdates();
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
    if (widget.initialTrip != null) {
      setState(() {
        _currentTrip = widget.initialTrip;
        _updateTripState();
      });
    } else {
      try {
        final tripDoc = await _firestore.collection('rides').doc(widget.tripId).get();
        if (tripDoc.exists && mounted) {
          setState(() {
            _currentTrip = TripModel.fromJson({
              'id': tripDoc.id,
              ...tripDoc.data()!,
            });
            _updateTripState();
          });
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
        _tripState = DriverTripState.waitingVerification;
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
        await _firestore.collection('rides').doc(widget.tripId).update({
          'driverLocation': {
            'latitude': _currentLocation!.latitude,
            'longitude': _currentLocation!.longitude,
            'timestamp': FieldValue.serverTimestamp(),
          },
        });
      }
    } catch (e) {
      debugPrint('Error actualizando ubicación: $e');
    }
  }

  void _updateMapMarkers() {
    if (_currentTrip == null) return;

    _markers.clear();

    // Marcador de ubicación actual del conductor
    if (_currentLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Tu ubicación'),
      ));
    }

    // Marcador de recogida
    _markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: LatLng(
        _currentTrip!.pickupLocation.latitude,
        _currentTrip!.pickupLocation.longitude,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: 'Punto de recogida',
        snippet: _currentTrip!.pickupAddress,
      ),
    ));

    // Marcador de destino
    _markers.add(Marker(
      markerId: const MarkerId('destination'),
      position: LatLng(
        _currentTrip!.destinationLocation.latitude,
        _currentTrip!.destinationLocation.longitude,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: 'Destino',
        snippet: _currentTrip!.destinationAddress,
      ),
    ));

    // Dibujar ruta
    _drawRoute();
  }

  void _drawRoute() {
    if (_currentTrip == null) return;

    _polylines.clear();

    List<LatLng> routePoints = [];

    if (_currentLocation != null) {
      routePoints.add(_currentLocation!);
    }

    if (_tripState == DriverTripState.goingToPickup ||
        _tripState == DriverTripState.arrivedAtPickup ||
        _tripState == DriverTripState.waitingVerification) {
      routePoints.add(LatLng(
        _currentTrip!.pickupLocation.latitude,
        _currentTrip!.pickupLocation.longitude,
      ));
    } else {
      routePoints.add(LatLng(
        _currentTrip!.pickupLocation.latitude,
        _currentTrip!.pickupLocation.longitude,
      ));
      routePoints.add(LatLng(
        _currentTrip!.destinationLocation.latitude,
        _currentTrip!.destinationLocation.longitude,
      ));
    }

    if (routePoints.length >= 2) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: routePoints,
        color: RtColors.brand,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
    }
  }

  // ==================== ACCIONES DEL CONDUCTOR ====================

  /// Marcar que el conductor llego al punto de recogida
  Future<void> _markArrived() async {
    setState(() => _isLoading = true);

    try {
      await _firestore.collection('rides').doc(widget.tripId).update({
        'status': 'driver_arriving',
        'arrivedAt': FieldValue.serverTimestamp(),
      });

      await _sendNotification(
        userId: _currentTrip!.userId,
        title: 'Tu conductor ha llegado!',
        body: 'Tu conductor esta esperandote en el punto de recogida.',
        data: {'tripId': widget.tripId, 'type': 'driver_arrived'},
      );

      if (mounted) {
        RtSnackbar.show(context, message: 'Has marcado tu llegada. El pasajero ha sido notificado.', type: RtSnackbarType.success);
      }
    } catch (e) {
      if (mounted) {
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Mostrar dialogo para ingresar código del pasajero
  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: RtColors.brandSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user, color: RtColors.brand),
            ),
            const SizedBox(width: RtSpacing.md),
            Text('Verificar Pasajero', style: RtTypo.headingSmall),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ingresa el código de 4 dígitos que te proporcionara el pasajero:',
              textAlign: TextAlign.center,
              style: RtTypo.bodyMedium,
            ),
            const SizedBox(height: RtSpacing.lg),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: RtTypo.displayLarge.copyWith(letterSpacing: 10),
              decoration: InputDecoration(
                hintText: '----',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: RtRadius.borderMd,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: RtRadius.borderMd,
                  borderSide: const BorderSide(color: RtColors.brand, width: 2),
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
              backgroundColor: RtColors.brand,
              foregroundColor: RtColors.white,
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
      if (!mounted) return;
      RtSnackbar.show(context, message: 'El código debe tener 4 dígitos', type: RtSnackbarType.warning);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tripDoc = await _firestore.collection('rides').doc(widget.tripId).get();
      final tripData = tripDoc.data();

      if (tripData == null) throw Exception('Viaje no encontrado');

      final passengerCode = tripData['passengerVerificationCode'] ?? tripData['verificationCode'];

      if (code == passengerCode) {
        await _firestore.collection('rides').doc(widget.tripId).update({
          'isPassengerVerified': true,
          'passengerVerifiedAt': FieldValue.serverTimestamp(),
        });

        _codeController.clear();

        if (mounted) {
          RtSnackbar.show(context, message: 'Pasajero verificado correctamente!', type: RtSnackbarType.success);
          _showDriverCodeDialog();
        }
      } else {
        if (mounted) {
          RtSnackbar.show(context, message: 'Código incorrecto. Intentalo de nuevo.', type: RtSnackbarType.error);
        }
      }
    } catch (e) {
      if (mounted) {
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
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
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Row(
          children: [
            const Icon(Icons.qr_code, color: RtColors.brand),
            const SizedBox(width: RtSpacing.md),
            Text('Tu Código de Verificación', style: RtTypo.headingSmall),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Muestra este código al pasajero para que lo verifique:',
              textAlign: TextAlign.center,
              style: RtTypo.bodyMedium,
            ),
            const SizedBox(height: RtSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              decoration: BoxDecoration(
                color: RtColors.brandSurface,
                borderRadius: RtRadius.borderLg,
                border: Border.all(color: RtColors.brand, width: 2),
              ),
              child: Text(
                driverCode,
                style: RtTypo.displayLarge.copyWith(
                  fontSize: 40,
                  letterSpacing: 12,
                  color: RtColors.brand,
                ),
              ),
            ),
            const SizedBox(height: RtSpacing.base),
            Text(
              'Una vez que el pasajero verifique este código, podrás iniciar el viaje.',
              textAlign: TextAlign.center,
              style: RtTypo.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: RtColors.brand,
              foregroundColor: RtColors.white,
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
      final tripDoc = await _firestore.collection('rides').doc(widget.tripId).get();
      final tripData = tripDoc.data();

      final isPassengerVerified = tripData?['isPassengerVerified'] ?? false;
      final isDriverVerified = tripData?['isDriverVerified'] ?? false;

      if (!isPassengerVerified) {
        if (!mounted) return;
        RtSnackbar.show(context, message: 'Primero debes verificar el código del pasajero', type: RtSnackbarType.warning);
        setState(() => _isLoading = false);
        return;
      }

      if (!isDriverVerified) {
        if (!mounted) return;
        RtSnackbar.show(context, message: 'El pasajero aún no ha verificado tu código', type: RtSnackbarType.warning);
        setState(() => _isLoading = false);
        return;
      }

      await _firestore.collection('rides').doc(widget.tripId).update({
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
        'verificationCompletedAt': FieldValue.serverTimestamp(),
      });

      await _sendNotification(
        userId: _currentTrip!.userId,
        title: 'Viaje iniciado!',
        body: 'Tu viaje ha comenzado. Disfruta del trayecto.',
        data: {'tripId': widget.tripId, 'type': 'trip_started'},
      );

      if (mounted) {
        RtSnackbar.show(context, message: 'Viaje iniciado! Dirigete al destino.', type: RtSnackbarType.success);
      }
    } catch (e) {
      if (mounted) {
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Finalizar el viaje
  Future<void> _completeTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Text('Finalizar Viaje', style: RtTypo.headingSmall),
        content: Text(
          'Estás seguro de que has llegado al destino y deseas finalizar el viaje?',
          style: RtTypo.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: RtColors.success,
              foregroundColor: RtColors.white,
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

      await _firestore.collection('rides').doc(widget.tripId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'finalFare': finalFare,
      });

      await _sendNotification(
        userId: _currentTrip!.userId,
        title: 'Viaje completado!',
        body: 'Has llegado a tu destino. Gracias por viajar con nosotros!',
        data: {'tripId': widget.tripId, 'type': 'trip_completed'},
      );

      if (mounted) {
        _showTripCompletedDialog(finalFare);
      }
    } catch (e) {
      if (mounted) {
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
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
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(RtSpacing.lg),
              decoration: const BoxDecoration(
                color: RtColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: RtColors.success,
                size: 60,
              ),
            ),
            const SizedBox(height: RtSpacing.lg),
            Text(
              'Viaje Completado!',
              style: RtTypo.displaySmall,
            ),
            const SizedBox(height: RtSpacing.sm),
            Text(
              'Ganancia: S/. ${finalFare.toStringAsFixed(2)}',
              style: RtTypo.headingMedium.copyWith(color: RtColors.brand),
            ),
            const SizedBox(height: RtSpacing.xl),
            // Resumen del viaje
            Container(
              padding: RtSpacing.paddingBase,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: RtRadius.borderMd,
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
            const SizedBox(height: RtSpacing.xl),
            RtButton(
              label: 'Calificar Pasajero',
              icon: Icons.star,
              onPressed: () {
                Navigator.pop(context);
                _showRatingDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: RtColors.brand),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: RtTypo.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  value,
                  style: RtTypo.titleMedium,
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

  // ==================== UTILIDADES ====================

  Future<void> _callPassenger() async {
    String? phone = _currentTrip?.vehicleInfo?['passengerPhone'];
    phone ??= _currentTrip?.vehicleInfo?['phone'];

    if (phone == null || phone.isEmpty) {
      final passengerId = _currentTrip?.userId;
      if (passengerId != null) {
        try {
          final passengerDoc = await _firestore.collection('users').doc(passengerId).get();
          if (passengerDoc.exists) {
            final data = passengerDoc.data();
            phone = data?['phone'] ?? data?['phoneNumber'];
          }
        } catch (e) {
          debugPrint('Error obteniendo teléfono del pasajero: $e');
        }
      }
    }

    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      RtSnackbar.show(context, message: 'Número de teléfono no disponible', type: RtSnackbarType.warning);
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  void _openChat() {
    if (_currentTrip == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          rideId: widget.tripId,
          otherUserName: _currentTrip!.vehicleInfo?['passengerName'] ?? 'Pasajero',
          otherUserRole: 'passenger',
          otherUserId: _currentTrip!.userId,
        ),
      ),
    );
  }

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

    final encodedAddress = Uri.encodeComponent(destinationAddress);

    final Uri mapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$encodedAddress&destination_place_id=&travelmode=driving',
    );

    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    } else {
      final Uri fallbackUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=driving',
      );
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(-12.0464, -77.0428),
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // AppBar transparente
          SafeArea(
            child: Container(
              margin: RtSpacing.paddingBase,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: RtShadow.soft(),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: RtShadow.soft(),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.navigation),
                      onPressed: _openNavigation,
                    ),
                  ),
                ],
              ),
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
              color: RtColors.black.withValues(alpha: 0.45),
              child: const Center(
                child: CircularProgressIndicator(color: RtColors.brand),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: RtRadius.sheetTop,
        boxShadow: RtShadow.medium(),
      ),
      padding: const EdgeInsets.all(RtSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: RtColors.neutral300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: RtSpacing.base),

          // Estado del viaje
          _buildStatusIndicator(),

          const SizedBox(height: RtSpacing.base),

          // Información del pasajero
          if (_currentTrip != null) _buildPassengerInfo(),

          const SizedBox(height: RtSpacing.base),

          // Información de ubicación
          _buildLocationInfo(),

          const SizedBox(height: RtSpacing.lg),

          // Boton de accion principal
          _buildMainActionButton(),

          const SizedBox(height: RtSpacing.md),

          // Botones secundarios
          _buildSecondaryButtons(),
        ],
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
        statusColor = RtColors.info;
        statusIcon = Icons.directions_car;
        break;
      case DriverTripState.arrivedAtPickup:
        statusText = 'Has llegado - Esperando pasajero';
        statusColor = RtColors.warning;
        statusIcon = Icons.place;
        break;
      case DriverTripState.waitingVerification:
        statusText = 'Verificación en proceso';
        statusColor = RtColors.warning;
        statusIcon = Icons.verified_user;
        break;
      case DriverTripState.inProgress:
        statusText = 'Viaje en curso';
        statusColor = RtColors.brand;
        statusIcon = Icons.local_taxi;
        break;
      case DriverTripState.arrivedAtDestination:
        statusText = 'Has llegado al destino';
        statusColor = RtColors.success;
        statusIcon = Icons.flag;
        break;
      case DriverTripState.completed:
        statusText = 'Viaje completado';
        statusColor = RtColors.success;
        statusIcon = Icons.check_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: RtSpacing.lg, vertical: RtSpacing.md),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: RtRadius.borderFull,
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
          const SizedBox(width: RtSpacing.md),
          Text(
            statusText,
            style: RtTypo.labelLarge.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerInfo() {
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundImage: _currentTrip?.vehicleInfo?['passengerPhoto'] != null
              ? NetworkImage(_currentTrip!.vehicleInfo!['passengerPhoto'])
              : null,
          child: _currentTrip?.vehicleInfo?['passengerPhoto'] == null
              ? const Icon(Icons.person)
              : null,
        ),
        const SizedBox(width: RtSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentTrip?.vehicleInfo?['passengerName'] ?? 'Pasajero',
                style: RtTypo.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  const Icon(Icons.star, size: 14, color: RtColors.warning),
                  const SizedBox(width: RtSpacing.xs),
                  Text(
                    '${_currentTrip?.vehicleInfo?['passengerRating']?.toStringAsFixed(1) ?? '5.0'}',
                    style: RtTypo.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _callPassenger,
          icon: const Icon(Icons.phone),
          style: IconButton.styleFrom(
            backgroundColor: RtColors.brand,
            foregroundColor: RtColors.white,
          ),
        ),
        const SizedBox(width: RtSpacing.sm),
        IconButton(
          onPressed: _openChat,
          icon: const Icon(Icons.chat),
          style: IconButton.styleFrom(
            backgroundColor: RtColors.info,
            foregroundColor: RtColors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: RtSpacing.paddingBase,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: RtRadius.borderLg,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: RtColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: RtSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recogida',
                      style: RtTypo.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      _currentTrip?.pickupAddress ?? 'Cargando...',
                      style: RtTypo.bodyMedium,
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
                  color: RtColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: RtSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destino',
                      style: RtTypo.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      _currentTrip?.destinationAddress ?? 'Cargando...',
                      style: RtTypo.bodyMedium,
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
    Color buttonColor = RtColors.brand;

    switch (_tripState) {
      case DriverTripState.goingToPickup:
        buttonText = 'He llegado al punto de recogida';
        buttonIcon = Icons.place;
        onPressed = _markArrived;
        break;
      case DriverTripState.arrivedAtPickup:
        buttonText = 'Verificar código del pasajero';
        buttonIcon = Icons.verified_user;
        onPressed = _showVerificationDialog;
        buttonColor = RtColors.warning;
        break;
      case DriverTripState.waitingVerification:
        buttonText = 'Iniciar viaje';
        buttonIcon = Icons.play_arrow;
        onPressed = _startTrip;
        break;
      case DriverTripState.inProgress:
        buttonText = 'Finalizar viaje';
        buttonIcon = Icons.flag;
        onPressed = _completeTrip;
        buttonColor = RtColors.success;
        break;
      case DriverTripState.arrivedAtDestination:
        buttonText = 'Confirmar llegada';
        buttonIcon = Icons.check_circle;
        onPressed = _completeTrip;
        buttonColor = RtColors.success;
        break;
      case DriverTripState.completed:
        buttonText = 'Viaje completado';
        buttonIcon = Icons.check_circle;
        onPressed = null;
        break;
    }

    // Mapear color a variante de RtButton
    RtButtonVariant variant;
    if (buttonColor == RtColors.error) {
      variant = RtButtonVariant.danger;
    } else if (buttonColor == RtColors.success) {
      variant = RtButtonVariant.primary;
    } else {
      variant = RtButtonVariant.primary;
    }

    return RtButton(
      label: buttonText,
      icon: buttonIcon,
      onPressed: onPressed,
      variant: variant,
      size: RtButtonSize.large,
    );
  }

  Widget _buildSecondaryButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: RtButton(
                label: 'Navegar',
                icon: Icons.navigation,
                variant: RtButtonVariant.outlined,
                onPressed: _openNavigation,
              ),
            ),
            const SizedBox(width: RtSpacing.md),
            Expanded(
              child: RtButton(
                label: 'Emergencia',
                icon: Icons.warning,
                variant: RtButtonVariant.danger,
                onPressed: _showEmergencyOptions,
              ),
            ),
          ],
        ),
        // Boton para completar viaje manualmente (cuando esta en progreso)
        if (_tripState == DriverTripState.inProgress) ...[
          const SizedBox(height: RtSpacing.md),
          RtButton(
            label: 'Completar viaje manualmente',
            icon: Icons.check_circle_outline,
            variant: RtButtonVariant.outlined,
            onPressed: _forceCompleteTrip,
          ),
        ],
      ],
    );
  }

  /// Forzar completar viaje manualmente (sin depender del GPS)
  Future<void> _forceCompleteTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: RtColors.warning),
            const SizedBox(width: RtSpacing.sm),
            Text('Completar manualmente', style: RtTypo.headingSmall),
          ],
        ),
        content: Text(
          'Estás seguro de que el pasajero ya llego a su destino?\n\n'
          'Usa esta opcion solo si el GPS no detecto la llegada correctamente.',
          style: RtTypo.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: RtColors.success,
              foregroundColor: RtColors.white,
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
      shape: RoundedRectangleBorder(
        borderRadius: RtRadius.sheetTop,
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(RtSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: RtColors.error),
              title: Text('Llamar a emergencias (105)', style: RtTypo.titleMedium),
              onTap: () async {
                Navigator.pop(context);
                final Uri phoneUri = Uri(scheme: 'tel', path: '105');
                if (await canLaunchUrl(phoneUri)) {
                  await launchUrl(phoneUri);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent, color: RtColors.warning),
              title: Text('Contactar soporte', style: RtTypo.titleMedium),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: RtColors.error),
              title: Text('Cancelar viaje', style: RtTypo.titleMedium),
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
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Text('Cancelar Viaje', style: RtTypo.headingSmall),
        content: Text(
          'Estás seguro de que deseas cancelar este viaje? '
          'Esto puede afectar tu tasa de aceptación.',
          style: RtTypo.bodyMedium,
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
              backgroundColor: RtColors.error,
              foregroundColor: RtColors.white,
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
      await _firestore.collection('rides').doc(widget.tripId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'driver',
        'cancellationReason': 'Cancelado por el conductor',
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
