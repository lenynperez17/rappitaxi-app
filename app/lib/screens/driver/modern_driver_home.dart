import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_badge.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/constants/credit_constants.dart';
import '../../core/widgets/mode_switch_button.dart';
import '../../models/price_negotiation_model.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/local_notification_service.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/logger.dart';
import '../../core/widgets/rt_animated_widgets.dart';
import 'active_trip_screen.dart';
import 'widgets/driver_menu_sheet.dart';
import 'widgets/driver_status_bar.dart';
import 'widgets/driver_trip_request_card.dart';

class ModernDriverHomeScreen extends StatefulWidget {
  const ModernDriverHomeScreen({super.key});

  @override
  State<ModernDriverHomeScreen> createState() => _ModernDriverHomeScreenState();
}

class _ModernDriverHomeScreenState extends State<ModernDriverHomeScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _driverId;

  // Controllers de animacion
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;

  // Estado
  bool _isOnline = false;
  bool _showRequestDetails = false;
  List<PriceNegotiation> _availableRequests = [];
  PriceNegotiation? _selectedRequest;
  Timer? _requestsTimer;

  // Flag para prevenir operaciones después de dispose
  bool _isDisposed = false;

  // GPS tracking en tiempo real
  Timer? _locationUpdateTimer;
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Control para seguir la ubicación del conductor en el mapa
  bool _followDriverLocation = true;

  // Listener en tiempo real para rides
  StreamSubscription<QuerySnapshot>? _ridesStreamSubscription;

  // Listener para viajes activos del conductor
  StreamSubscription<QuerySnapshot>? _activeRideSubscription;

  // Estadísticas del día
  double _todayEarnings = 0.0;
  int _todayTrips = 0;
  double _acceptanceRate = 0.0;

  // Sistema de créditos
  double _serviceCredits = 0.0;
  double _serviceFee = 1.0;
  double _minServiceCredits = CreditConstants.minServiceCredits;
  bool _hasEnoughCredits = false;
  bool _isCheckingCredits = true;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    );

    _pulseController.repeat(reverse: true);
    _initializeDriver();
    _loadRealRequests();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopLocationTracking();
    _stopRidesListener();
    _stopActiveRideListener();
    _mapController?.dispose();
    _mapController = null;
    _pulseController.dispose();
    _slideController.dispose();
    _requestsTimer?.cancel();
    _requestsTimer = null;
    super.dispose();
  }

  // ================================================================
  // INICIALIZACION
  // ================================================================

  Future<void> _initializeDriver() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final docProvider = Provider.of<DocumentProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        AppLogger.warning('No hay usuario autenticado');
        return;
      }

      _driverId = currentUser.id;
      AppLogger.info('Conductor inicializado: ${currentUser.fullName} (${currentUser.id})');

      await _cleanupZombieRides();
      if (!mounted) return;

      _startActiveRideListener();

      await _checkDriverCredits();
      if (!mounted) return;

      await docProvider.loadVerificationStatus(_driverId!);
      if (!mounted) return;

      await _loadTodayStats();
    } catch (e) {
      AppLogger.error('Error inicializando conductor: $e');
    }
  }

  Future<void> _cleanupZombieRides() async {
    if (_driverId == null) return;

    try {
      final now = DateTime.now();
      final thirtyMinutesAgo = now.subtract(const Duration(minutes: 30));

      AppLogger.info('Buscando rides zombie para conductor: $_driverId');

      final activeRides = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: _driverId)
          .where('status', whereIn: ['accepted', 'arriving', 'arrived'])
          .get();

      AppLogger.info('Encontrados ${activeRides.docs.length} rides activos del conductor');

      int cleanedCount = 0;
      for (var doc in activeRides.docs) {
        final data = doc.data();
        final acceptedAt = (data['acceptedAt'] as Timestamp?)?.toDate();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final rideStartTime = acceptedAt ?? createdAt;

        if (rideStartTime != null && rideStartTime.isBefore(thirtyMinutesAgo)) {
          await doc.reference.update({
            'status': 'cancelled',
            'cancelReason': 'auto_cleanup_stale_ride',
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancelledBy': 'system',
          });
          cleanedCount++;
        } else if (rideStartTime == null) {
          await doc.reference.update({
            'status': 'cancelled',
            'cancelReason': 'auto_cleanup_corrupt_ride',
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancelledBy': 'system',
          });
          cleanedCount++;
        }
      }

      if (cleanedCount > 0) {
        AppLogger.info('Total de rides zombie limpiados: $cleanedCount');
      }
    } catch (e) {
      AppLogger.warning('Error limpiando rides zombie: $e');
    }
  }

  // ================================================================
  // CREDITOS
  // ================================================================

  Future<void> _checkDriverCredits() async {
    if (_isDisposed) return;
    setState(() => _isCheckingCredits = true);

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final creditStatus = await walletProvider.checkCreditStatus();

      if (_isDisposed) return;

      setState(() {
        _serviceCredits = (creditStatus['currentCredits'] ?? 0.0).toDouble();
        _serviceFee = (creditStatus['serviceFee'] ?? 1.0).toDouble();
        _minServiceCredits = (creditStatus['minCredits'] ?? 5.0).toDouble();
        _hasEnoughCredits = creditStatus['hasEnoughCredits'] ?? false;
        _isCheckingCredits = false;
      });

      if (!_hasEnoughCredits) {
        AppLogger.warning('Conductor sin créditos suficientes para aceptar servicios');
      }
    } catch (e) {
      AppLogger.error('Error verificando créditos: $e');
      if (_isDisposed) return;
      setState(() {
        _hasEnoughCredits = false;
        _isCheckingCredits = false;
      });
    }
  }

  // ================================================================
  // GPS TRACKING
  // ================================================================

  Future<void> _startLocationTracking() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.warning('Permisos de ubicación denegados');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.error('Permisos de ubicación denegados permanentemente');
        return;
      }

      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!mounted || _isDisposed) return;

      setState(() {
        _currentLocation = LatLng(initialPosition.latitude, initialPosition.longitude);
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 16),
        ),
      );

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) async {
        if (_isDisposed || !mounted) return;

        final newLocation = LatLng(position.latitude, position.longitude);

        setState(() {
          _currentLocation = newLocation;
          _updateMapMarkers();
        });

        if (_followDriverLocation && _mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(newLocation));
        }

        if (_driverId != null && _isOnline) {
          await _updateLocationInFirebase(newLocation);
        }
      });

      AppLogger.info('GPS tracking iniciado');
    } catch (e) {
      AppLogger.error('Error iniciando GPS tracking: $e');
    }
  }

  void _stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  Future<void> _updateLocationInFirebase(LatLng location) async {
    try {
      if (_driverId == null) return;

      await _firestore.collection('drivers').doc(_driverId).update({
        'currentLocation': {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'isOnline': _isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.warning('Error actualizando ubicación en Firebase: $e');
    }
  }

  // ================================================================
  // LISTENERS DE RIDES
  // ================================================================

  void _startRidesListener() {
    try {
      if (_driverId == null) return;

      _ridesStreamSubscription = _firestore
          .collection('rides')
          .where('status', whereIn: ['requested', 'searching_driver'])
          .limit(100)
          .snapshots()
          .listen(
        (snapshot) async {
          if (_isDisposed || !mounted) return;

          List<PriceNegotiation> nearbyRides = [];

          for (var doc in snapshot.docs) {
            try {
              final data = doc.data();

              if (_currentLocation != null) {
                final pickupData = data['pickupLocation'];
                if (pickupData != null &&
                    pickupData['latitude'] != null &&
                    pickupData['longitude'] != null) {
                  final pickupLat = (pickupData['latitude'] as num).toDouble();
                  final pickupLng = (pickupData['longitude'] as num).toDouble();

                  final distanceInMeters = Geolocator.distanceBetween(
                    _currentLocation!.latitude,
                    _currentLocation!.longitude,
                    pickupLat,
                    pickupLng,
                  );

                  if (distanceInMeters <= 5000) {
                    final negotiation = PriceNegotiation(
                      id: doc.id,
                      passengerId: data['passengerId'] as String? ?? '',
                      selectedDriverId: null,
                      pickup: LocationPoint(
                        latitude: pickupLat,
                        longitude: pickupLng,
                        address: data['pickupAddress'] as String? ?? 'Dirección no disponible',
                      ),
                      destination: LocationPoint(
                        latitude: (data['destinationLocation']?['latitude'] as num?)?.toDouble() ?? 0.0,
                        longitude: (data['destinationLocation']?['longitude'] as num?)?.toDouble() ?? 0.0,
                        address: data['destinationAddress'] as String? ?? 'Destino no disponible',
                      ),
                      status: NegotiationStatus.waiting,
                      suggestedPrice: (data['fare'] as num?)?.toDouble() ?? 0.0,
                      offeredPrice: (data['fare'] as num?)?.toDouble() ?? 0.0,
                      distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
                      estimatedTime: (data['estimatedTime'] as num?)?.toInt() ?? 0,
                      passengerName: data['passengerName'] as String? ?? 'Pasajero',
                      passengerPhoto: data['passengerPhoto'] as String? ?? '',
                      passengerRating: (data['passengerRating'] as num?)?.toDouble() ?? 5.0,
                      driverOffers: [],
                      paymentMethod: data['paymentMethod'] == 'cash'
                          ? PaymentMethod.cash
                          : PaymentMethod.card,
                      notes: data['notes'] as String?,
                      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
                          DateTime.now().add(const Duration(minutes: 5)),
                    );

                    nearbyRides.add(negotiation);
                  }
                }
              }
            } catch (e) {
              AppLogger.error('Error procesando ride ${doc.id}: $e');
            }
          }

          if (!_isDisposed && mounted) {
            final existingIds = _availableRequests.map((r) => r.id).toSet();
            final newRides = nearbyRides.where((r) => !existingIds.contains(r.id)).toList();

            setState(() {
              _availableRequests.addAll(newRides);
              _updateMapMarkers();
            });

            if (newRides.isNotEmpty) {
              AppLogger.info('${newRides.length} rides cercanos detectados en tiempo real');

              final firstNewRide = newRides.first;
              LocalNotificationService().showRideRequestNotification(
                passengerName: firstNewRide.passengerName,
                pickupAddress: firstNewRide.pickup.address,
                price: firstNewRide.offeredPrice.toStringAsFixed(2),
              );
            }
          }
        },
        onError: (error) {
          AppLogger.error('Error en listener de rides: $error');
        },
      );
    } catch (e) {
      AppLogger.error('Error iniciando listener de rides: $e');
    }
  }

  void _stopRidesListener() {
    _ridesStreamSubscription?.cancel();
    _ridesStreamSubscription = null;
  }

  void _startActiveRideListener() {
    if (_driverId == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isRoleSwitchInProgress) return;
    if (authProvider.currentUser?.currentMode != 'driver') return;

    _activeRideSubscription?.cancel();

    _activeRideSubscription = _firestore
        .collection('rides')
        .where('driverId', isEqualTo: _driverId)
        .where('status', whereIn: ['accepted', 'arriving', 'arrived', 'in_progress'])
        .limit(1)
        .snapshots()
        .listen(
      (snapshot) {
        if (_isDisposed || !mounted) return;

        if (snapshot.docs.isNotEmpty) {
          final rideDoc = snapshot.docs.first;
          _navigateToActiveTrip(rideDoc.id, rideDoc.data());
        }
      },
      onError: (e) {
        AppLogger.error('Error en listener de viajes activos: $e');
      },
    );
  }

  void _stopActiveRideListener() {
    _activeRideSubscription?.cancel();
    _activeRideSubscription = null;
  }

  // ================================================================
  // NAVEGACION A VIAJE ACTIVO
  // ================================================================

  void _navigateToActiveTrip(String tripId, Map<String, dynamic> tripData) {
    if (!mounted) return;

    _activeRideSubscription?.cancel();

    final acceptedAt = (tripData['acceptedAt'] as Timestamp?)?.toDate();
    final createdAt = (tripData['createdAt'] as Timestamp?)?.toDate();
    final rideStartTime = acceptedAt ?? createdAt;
    final now = DateTime.now();

    if (rideStartTime != null && now.difference(rideStartTime).inMinutes > 30) {
      final minutesAgo = now.difference(rideStartTime).inMinutes;
      _showOldTripDialog(tripId, tripData, minutesAgo);
    } else {
      _doNavigateToActiveTrip(tripId, tripData);
    }
  }

  void _showOldTripDialog(String tripId, Map<String, dynamic> tripData, int minutesAgo) {
    if (!mounted) return;

    final passengerName = tripData['passengerName'] ?? 'Pasajero desconocido';
    final origin = tripData['originAddress'] ?? tripData['origin']?['address'] ?? 'Origen no disponible';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: RtColors.warning, size: 28),
            const SizedBox(width: RtSpacing.md),
            Expanded(
              child: Text('Viaje pendiente', style: RtTypo.headingSmall),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se encontro un viaje iniciado hace $minutesAgo minutos que no fue completado.',
              style: RtTypo.bodyMedium,
            ),
            const SizedBox(height: RtSpacing.base),
            Container(
              padding: RtSpacing.paddingMd,
              decoration: BoxDecoration(
                color: RtColors.neutral100,
                borderRadius: RtRadius.borderSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: RtColors.neutral600),
                      const SizedBox(width: RtSpacing.sm),
                      Expanded(
                        child: Text(
                          passengerName,
                          style: RtTypo.titleMedium.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RtSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 18, color: RtColors.success),
                      const SizedBox(width: RtSpacing.sm),
                      Expanded(
                        child: Text(
                          origin,
                          style: RtTypo.bodySmall.copyWith(color: RtColors.neutral600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: RtSpacing.base),
            Text(
              'Qué deseas hacer?',
              style: RtTypo.titleMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _cancelOldTrip(tripId);
            },
            child: Text('Cancelar viaje', style: TextStyle(color: RtColors.error)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _doNavigateToActiveTrip(tripId, tripData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: RtColors.success,
              shape: RoundedRectangleBorder(borderRadius: RtRadius.borderSm),
            ),
            child: const Text('Continuar viaje', style: TextStyle(color: RtColors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOldTrip(String tripId) async {
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      await _firestore.collection('rides').doc(tripId).update({
        'status': 'cancelled',
        'cancelReason': 'driver_cancelled_stale_ride',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': _driverId,
      });

      if (!mounted) return;
      Navigator.pop(context);

      RtSnackbar.show(context,
        message: 'Viaje cancelado correctamente',
        type: RtSnackbarType.success,
      );

      _startActiveRideListener();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      RtSnackbar.show(context,
        message: FirestoreErrorHandler.getSpanishMessage(e),
        type: RtSnackbarType.error,
      );
    }
  }

  void _doNavigateToActiveTrip(String tripId, Map<String, dynamic> tripData) {
    if (!mounted) return;

    final initialTrip = TripModel.fromMap(tripData, tripId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveTripScreen(tripId: tripId, initialTrip: initialTrip),
      ),
    );
  }

  // ================================================================
  // CARGA DE SOLICITUDES
  // ================================================================

  void _loadRealRequests() {
    _loadRequestsFromFirebase();
  }

  Future<void> _loadRequestsFromFirebase() async {
    try {
      if (_driverId == null) return;

      final requestsSnapshot = await _firestore
          .collection('negotiations')
          .where('status', isEqualTo: 'waiting')
          .limit(50)
          .get();

      List<PriceNegotiation> loadedRequests = [];
      final now = DateTime.now();
      for (var doc in requestsSnapshot.docs) {
        try {
          final negotiation = PriceNegotiation.fromMap(doc.id, doc.data());
          if (negotiation.expiresAt.isAfter(now)) {
            loadedRequests.add(negotiation);
          }
        } catch (e) {
          AppLogger.error('Error parseando solicitud ${doc.id}: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        final ridesFromListener = _availableRequests
            .where((r) => r.id.startsWith('rides/'))
            .toList();
        _availableRequests = [...loadedRequests, ...ridesFromListener];
        _updateMapMarkers();
      });

      _requestsTimer?.cancel();
      _requestsTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_isDisposed || !mounted) {
          timer.cancel();
          return;
        }
        if (_isOnline) {
          _loadRequestsFromFirebase();
        }
      });
    } catch (e) {
      AppLogger.error('Error cargando solicitudes: $e');
      if (!mounted) return;
      setState(() {
        _availableRequests = [];
        _updateMapMarkers();
      });
    }
  }

  // ================================================================
  // MARCADORES DEL MAPA
  // ================================================================

  void _updateMapMarkers() {
    _markers.clear();

    if (_currentLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Tu ubicación'),
        ),
      );
    }

    for (var request in _availableRequests) {
      _markers.add(
        Marker(
          markerId: MarkerId(request.id),
          position: LatLng(request.pickup.latitude, request.pickup.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          onTap: () => _selectRequest(request),
          infoWindow: InfoWindow(
            title: 'Recoger: ${request.passengerName}',
            snippet: request.pickup.address,
          ),
        ),
      );
    }
  }

  void _selectRequest(PriceNegotiation request) {
    setState(() {
      _selectedRequest = request;
      _showRequestDetails = true;
    });
    _slideController.forward();
  }

  // ================================================================
  // ACCIONES DE SOLICITUDES
  // ================================================================

  void _rejectRequest(PriceNegotiation request) async {
    try {
      await _firestore.collection('negotiations').doc(request.id).update({
        'status': 'rejected_by_driver',
        'rejectedBy': _driverId,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _showRequestDetails = false;
        _selectedRequest = null;
      });
      _slideController.reverse();

      if (!mounted) return;
      RtSnackbar.show(context,
        message: 'Solicitud rechazada',
        type: RtSnackbarType.warning,
      );
    } catch (e) {
      AppLogger.error('Error al rechazar solicitud: $e');
      if (!mounted) return;
      RtSnackbar.show(context,
        message: FirestoreErrorHandler.getSpanishMessage(e),
        type: RtSnackbarType.error,
      );
    }
  }

  void _acceptRequest(PriceNegotiation request) async {
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final hasCredits = await walletProvider.hasEnoughCreditsForService();

      if (!hasCredits) {
        _showNeedCreditsDialog();
        return;
      }

      // Generar códigos aleatorios de 4 dígitos con Random.secure()
      String generateVerificationCode() {
        final random = Random.secure();
        return (random.nextInt(9000) + 1000).toString();
      }

      final passengerCode = generateVerificationCode();
      String driverCode = generateVerificationCode();
      // Asegurar que los códigos no sean iguales
      while (driverCode == passengerCode) {
        driverCode = generateVerificationCode();
      }

      String? passengerPhone;
      try {
        final passengerDoc = await _firestore.collection('users').doc(request.passengerId).get();
        if (passengerDoc.exists) {
          final passengerData = passengerDoc.data();
          passengerPhone = passengerData?['phone'] ?? passengerData?['phoneNumber'];
        }
      } catch (e) {
        AppLogger.warning('No se pudo obtener el teléfono del pasajero: $e');
      }

      final rideId = await _firestore.runTransaction<String?>((transaction) async {
        final negotiationRef = _firestore.collection('negotiations').doc(request.id);
        final snapshot = await transaction.get(negotiationRef);

        if (!snapshot.exists) throw Exception('La solicitud ya no existe');

        final data = snapshot.data()!;
        if (data['driverId'] != null && data['driverId'].toString().isNotEmpty) {
          throw Exception('Otro conductor ya aceptó esta solicitud');
        }

        final status = data['status'] as String?;
        if (status != 'waiting' && status != 'negotiating') {
          throw Exception('La solicitud ya no está disponible');
        }

        final rideRef = _firestore.collection('rides').doc();

        transaction.set(rideRef, {
          'userId': request.passengerId,
          'driverId': _driverId,
          'negotiationId': request.id,
          'pickupLocation': {
            'latitude': request.pickup.latitude,
            'longitude': request.pickup.longitude,
          },
          'destinationLocation': {
            'latitude': request.destination.latitude,
            'longitude': request.destination.longitude,
          },
          'pickupAddress': request.pickup.address,
          'destinationAddress': request.destination.address,
          'estimatedFare': request.offeredPrice,
          'finalFare': request.offeredPrice,
          'estimatedDistance': request.distance,
          'status': 'accepted',
          'paymentMethod': request.paymentMethod.name,
          'requestedAt': FieldValue.serverTimestamp(),
          'acceptedAt': FieldValue.serverTimestamp(),
          'passengerVerificationCode': passengerCode,
          'driverVerificationCode': driverCode,
          'isPassengerVerified': false,
          'isDriverVerified': false,
          'vehicleInfo': {
            'passengerName': request.passengerName,
            'passengerPhoto': request.passengerPhoto,
            'passengerRating': request.passengerRating,
            'passengerPhone': passengerPhone,
          },
          'passengerInfo': {
            'name': request.passengerName,
            'photo': request.passengerPhoto,
            'rating': request.passengerRating,
            'phone': passengerPhone,
          },
          'driverInfo': {'driverId': _driverId},
        });

        transaction.update(negotiationRef, {
          'status': 'accepted',
          'driverId': _driverId,
          'rideId': rideRef.id,
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        return rideRef.id;
      });

      if (rideId != null) {
        final creditConsumed = await walletProvider.consumeCreditsForService(
          tripId: rideId,
          negotiationId: request.id,
        );

        if (creditConsumed) {
          await _checkDriverCredits();

          setState(() {
            _availableRequests.remove(request);
            _showRequestDetails = false;
          });

          await _loadTodayStats();
          _showAcceptedDialog(request, rideId);
        } else {
          await _firestore.runTransaction((transaction) async {
            transaction.update(_firestore.collection('rides').doc(rideId), {
              'status': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
              'cancelReason': 'credit_consumption_failed',
            });
            transaction.update(_firestore.collection('negotiations').doc(request.id), {
              'status': 'waiting',
              'driverId': FieldValue.delete(),
              'rideId': FieldValue.delete(),
              'acceptedAt': FieldValue.delete(),
            });
          });

          if (!mounted) return;
          RtSnackbar.show(context,
            message: 'Error al procesar créditos. Intenta de nuevo.',
            type: RtSnackbarType.error,
          );
        }
      }
    } on FirebaseException catch (e) {
      AppLogger.error('Error Firebase aceptando solicitud: ${e.code} - ${e.message}');
      if (!mounted) return;

      String errorMessage = 'Error al aceptar el viaje';
      if (e.code == 'failed-precondition') {
        errorMessage = 'Otro conductor ya aceptó esta solicitud';
      }

      RtSnackbar.show(context, message: errorMessage, type: RtSnackbarType.error);
    } catch (e) {
      AppLogger.error('Error aceptando solicitud: $e');
      if (!mounted) return;

      String errorMessage = 'Error al aceptar el viaje';
      if (e.toString().contains('ya acepto')) {
        errorMessage = 'Otro conductor ya aceptó esta solicitud';
      } else if (e.toString().contains('no está disponible')) {
        errorMessage = 'La solicitud ya no está disponible';
      }

      RtSnackbar.show(context, message: errorMessage, type: RtSnackbarType.error);
    }
  }

  // ================================================================
  // DIALOGOS
  // ================================================================

  void _showDriverMenu() {
    DriverMenuSheet.show(
      context,
      onLogout: _showLogoutConfirmation,
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Text('Cerrar Sesión', style: RtTypo.headingSmall),
        content: Text('Estás seguro de que deseas cerrar sesión?', style: RtTypo.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: RtColors.error),
            child: const Text('Cerrar Sesión', style: TextStyle(color: RtColors.white)),
          ),
        ],
      ),
    );
  }

  void _showNeedCreditsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderXl),
        title: Row(
          children: [
            Container(
              padding: RtSpacing.paddingSm,
              decoration: BoxDecoration(
                color: RtColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet, color: RtColors.warning, size: 28),
            ),
            const SizedBox(width: RtSpacing.md),
            Expanded(child: Text('Créditos insuficientes', style: RtTypo.headingSmall)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: RtSpacing.paddingMd,
              decoration: BoxDecoration(
                color: RtColors.warningLight,
                borderRadius: RtRadius.borderMd,
                border: Border.all(color: RtColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: RtColors.warning, size: RtIconSize.sm),
                  const SizedBox(width: RtSpacing.sm),
                  Expanded(
                    child: Text(
                      'Tu saldo actual: S/. ${_serviceCredits.toStringAsFixed(2)}',
                      style: RtTypo.titleMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RtSpacing.base),
            Text('Para aceptar servicios necesitas:', style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500)),
            const SizedBox(height: RtSpacing.sm),
            _buildCreditRequirement('Mínimo requerido', 'S/. ${_minServiceCredits.toStringAsFixed(2)}'),
            _buildCreditRequirement('Costo por servicio', 'S/. ${_serviceFee.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cerrar', style: TextStyle(color: RtColors.neutral500)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_card, size: 18),
            label: const Text('Recargar créditos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: RtColors.brand,
              foregroundColor: RtColors.white,
              shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(context, '/driver/recharge-credits').then((_) => _checkDriverCredits());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCreditRequirement(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500)),
          Text(value, style: RtTypo.titleMedium.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  void _showNegotiateDialog(PriceNegotiation request) {
    final priceController = TextEditingController(
      text: request.offeredPrice.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderXl),
        title: Row(
          children: [
            const Icon(Icons.price_change, color: RtColors.warning),
            const SizedBox(width: RtSpacing.sm),
            const Text('Proponer precio'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Precio del pasajero: S/ ${request.offeredPrice.toStringAsFixed(2)}',
              style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
            ),
            const SizedBox(height: RtSpacing.sm),
            Text(
              'Precio sugerido: S/ ${request.suggestedPrice.toStringAsFixed(2)}',
              style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
            ),
            const SizedBox(height: RtSpacing.base),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Tu propuesta (S/)',
                prefixText: 'S/ ',
                border: OutlineInputBorder(borderRadius: RtRadius.borderMd),
                focusedBorder: OutlineInputBorder(
                  borderRadius: RtRadius.borderMd,
                  borderSide: const BorderSide(color: RtColors.warning, width: 2),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: RtSpacing.sm),
            Text(
              'El pasajero recibirá tu oferta y podrá aceptar o rechazar.',
              style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar', style: TextStyle(color: RtColors.neutral500)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final proposedPrice = double.tryParse(priceController.text);
              if (proposedPrice == null || proposedPrice <= 0) {
                RtSnackbar.show(context, message: 'Ingresa un precio válido', type: RtSnackbarType.error);
                return;
              }
              Navigator.pop(dialogContext);
              await _sendCounterOffer(request, proposedPrice);
            },
            icon: const Icon(Icons.send),
            label: const Text('Enviar oferta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: RtColors.warning,
              foregroundColor: RtColors.white,
              shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCounterOffer(PriceNegotiation request, double proposedPrice) async {
    try {
      final driverDoc = await _firestore.collection('users').doc(_driverId).get();
      final driverData = driverDoc.data() ?? {};
      final vehicleInfo = driverData['vehicleInfo'] as Map<String, dynamic>? ?? {};

      final offer = {
        'driverId': _driverId,
        'driverName': driverData['fullName'] ?? 'Conductor',
        'driverPhoto': driverData['profilePhotoUrl'] ?? '',
        'driverRating': driverData['rating'] ?? 5.0,
        'vehicleModel': '${vehicleInfo['make'] ?? ''} ${vehicleInfo['model'] ?? ''}'.trim(),
        'vehiclePlate': vehicleInfo['plate'] ?? '',
        'vehicleColor': vehicleInfo['color'] ?? '',
        'acceptedPrice': proposedPrice,
        'estimatedArrival': 5,
        'offeredAt': DateTime.now().toIso8601String(),
        'status': 'pending',
        'completedTrips': driverData['totalTrips'] ?? 0,
        'acceptanceRate': 0.95,
      };

      await _firestore.collection('negotiations').doc(request.id).update({
        'status': 'negotiating',
        'driverOffers': FieldValue.arrayUnion([offer]),
      });

      setState(() {
        _showRequestDetails = false;
        _selectedRequest = null;
      });
      _slideController.reverse();

      if (!mounted) return;
      RtSnackbar.show(context,
        message: 'Oferta de S/ ${proposedPrice.toStringAsFixed(2)} enviada',
        type: RtSnackbarType.success,
      );

      _loadRequestsFromFirebase();
    } catch (e) {
      AppLogger.error('Error enviando contraoferta: $e');
      if (!mounted) return;
      RtSnackbar.show(context,
        message: FirestoreErrorHandler.getSpanishMessage(e),
        type: RtSnackbarType.error,
      );
    }
  }

  void _showAcceptedDialog(PriceNegotiation request, String rideId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderXl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(RtSpacing.lg),
              decoration: BoxDecoration(
                color: RtColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: RtColors.success, size: 48),
            ),
            const SizedBox(height: RtSpacing.lg),
            Text('Viaje aceptado!', style: RtTypo.headingMedium),
            const SizedBox(height: RtSpacing.sm),
            Text(
              'Dirigete al punto de recogida',
              style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
            ),
            const SizedBox(height: RtSpacing.base),
            Container(
              padding: RtSpacing.paddingMd,
              decoration: BoxDecoration(
                color: RtColors.neutral100,
                borderRadius: RtRadius.borderMd,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: request.passengerPhoto.isNotEmpty
                            ? NetworkImage(request.passengerPhoto)
                            : null,
                        child: request.passengerPhoto.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: RtSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(request.passengerName, style: RtTypo.titleMedium.copyWith(fontWeight: FontWeight.w600)),
                            Row(
                              children: [
                                const Icon(Icons.star, size: 14, color: RtColors.warning),
                                const SizedBox(width: RtSpacing.xs),
                                Text(request.passengerRating.toStringAsFixed(1), style: RtTypo.bodySmall),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'S/. ${request.offeredPrice.toStringAsFixed(2)}',
                        style: RtTypo.headingSmall.copyWith(color: RtColors.success),
                      ),
                    ],
                  ),
                  const SizedBox(height: RtSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: RtIconSize.xs, color: RtColors.success),
                      const SizedBox(width: RtSpacing.xs),
                      Expanded(
                        child: Text(
                          request.pickup.address,
                          style: RtTypo.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: RtSpacing.lg),
            AnimatedPulseButton(
              text: 'Ir al viaje',
              icon: Icons.navigation,
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.pushNamed(context, '/driver/active-trip', arguments: {'tripId': rideId});
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // ESTADISTICAS
  // ================================================================

  Future<void> _loadTodayStats() async {
    try {
      if (_driverId == null) return;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final tripsQuery = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: _driverId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .where('status', isEqualTo: 'completed')
          .get();

      double totalEarnings = 0.0;
      int tripCount = 0;

      for (var doc in tripsQuery.docs) {
        final data = doc.data();
        totalEarnings += (data['fare'] as num?)?.toDouble() ?? 0.0;
        tripCount++;
      }

      final negotiationsQuery = await _firestore
          .collection('negotiations')
          .where('driverId', isEqualTo: _driverId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      int acceptedCount = 0;
      int totalOffered = 0;

      for (var doc in negotiationsQuery.docs) {
        totalOffered++;
        if ((doc.data()['status'] as String?) == 'accepted') {
          acceptedCount++;
        }
      }

      double acceptanceRate = 0.0;
      if (totalOffered > 0) {
        acceptanceRate = (acceptedCount / totalOffered) * 100;
      }

      setState(() {
        _todayEarnings = totalEarnings;
        _todayTrips = tripCount;
        _acceptanceRate = acceptanceRate;
      });
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('permission') || errorMessage.contains('denied')) {
        AppLogger.debug('Conductor nuevo detectado. Sin historial de viajes aun.');
      } else {
        AppLogger.warning('Error cargando estadísticas del día: $e');
      }

      if (!_isDisposed && mounted) {
        setState(() {
          _todayEarnings = 0.0;
          _todayTrips = 0;
          _acceptanceRate = 0.0;
        });
      }
    }
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RtAppBar(
        title: 'Conductor - ${_isOnline ? "EN LINEA" : "DESCONECTADO"}',
        variant: RtAppBarVariant.gradient,
        showBackButton: false,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              final vehicleInfo = authProvider.currentUser?.vehicleInfo;
              final plate = vehicleInfo?['plate'] as String?;
              if (plate != null && plate.isNotEmpty) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: RtSpacing.xs),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: RtColors.white,
                    borderRadius: RtRadius.borderSm,
                    border: Border.all(color: RtColors.brand, width: 2),
                  ),
                  child: Text(
                    plate.toUpperCase(),
                    style: RtTypo.labelSmall.copyWith(
                      color: RtColors.neutral900,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const ModeSwitchButton(compact: true),
          const SizedBox(width: RtSpacing.xs),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: RtColors.white),
            onPressed: () => Navigator.pushNamed(context, '/driver/wallet'),
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: RtColors.white),
            onPressed: _showDriverMenu,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(-12.0851, -76.9770),
              zoom: 14,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            liteModeEnabled: false,
            buildingsEnabled: false,
            indoorViewEnabled: false,
            trafficEnabled: false,
            minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
            onCameraMoveStarted: () {
              if (_followDriverLocation) {
                setState(() => _followDriverLocation = false);
              }
            },
          ),

          // Boton para volver a centrar ubicación
          if (_isOnline && !_followDriverLocation && _currentLocation != null)
            Positioned(
              right: RtSpacing.base,
              bottom: _availableRequests.isNotEmpty ? 300 : 100,
              child: FloatingActionButton.small(
                heroTag: 'centerLocation',
                backgroundColor: RtColors.brand,
                onPressed: () {
                  setState(() => _followDriverLocation = true);
                  if (_currentLocation != null && _mapController != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(target: _currentLocation!, zoom: 16),
                      ),
                    );
                  }
                },
                child: const Icon(Icons.my_location, color: RtColors.white),
              ),
            ),

          // Panel superior con estado y estadísticas
          DriverStatusBar(
            isOnline: _isOnline,
            onOnlineChanged: (value) {
              setState(() {
                _isOnline = value;
                if (value) {
                  _startLocationTracking();
                  _startRidesListener();
                  _availableRequests = [];
                  _updateMapMarkers();
                  _checkDriverCredits();
                } else {
                  _stopLocationTracking();
                  _stopRidesListener();
                  _availableRequests.clear();
                  _markers.clear();
                }
              });
            },
            isCheckingCredits: _isCheckingCredits,
            hasEnoughCredits: _hasEnoughCredits,
            serviceCredits: _serviceCredits,
            minServiceCredits: _minServiceCredits,
            todayEarnings: _todayEarnings,
            todayTrips: _todayTrips,
            acceptanceRate: _acceptanceRate,
          ),

          // Lista de solicitudes activas
          if (_isOnline && _availableRequests.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(RtRadius.xl)),
                  boxShadow: RtShadow.strong(),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: RtSpacing.md),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: RtColors.neutral300,
                        borderRadius: RtRadius.borderFull,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(RtSpacing.lg),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Solicitudes disponibles', style: RtTypo.headingMedium),
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: RtBadge(
                                  label: '${_availableRequests.length}',
                                  color: RtColors.brand,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 210,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: RtSpacing.lg),
                        itemCount: _availableRequests.length,
                        itemBuilder: (context, index) {
                          return DriverTripRequestCard(
                            request: _availableRequests[index],
                            onTap: () => _selectRequest(_availableRequests[index]),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: RtSpacing.lg),
                  ],
                ),
              ),
            ),

          // Detalle de solicitud seleccionada
          if (_showRequestDetails && _selectedRequest != null) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showRequestDetails = false;
                    _selectedRequest = null;
                  });
                  _slideController.reverse();
                },
                child: AnimatedBuilder(
                  animation: _slideAnimation,
                  builder: (context, child) {
                    return Container(
                      color: RtColors.black.withValues(alpha: 0.3 * _slideAnimation.value),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 500 * (1 - _slideAnimation.value)),
                    child: GestureDetector(
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
                          setState(() {
                            _showRequestDetails = false;
                            _selectedRequest = null;
                          });
                          _slideController.reverse();
                        }
                      },
                      child: DriverTripDetailSheet(
                        request: _selectedRequest!,
                        onClose: () {
                          setState(() {
                            _showRequestDetails = false;
                            _selectedRequest = null;
                          });
                          _slideController.reverse();
                        },
                        onReject: () => _rejectRequest(_selectedRequest!),
                        onNegotiate: () => _showNegotiateDialog(_selectedRequest!),
                        onAccept: () => _acceptRequest(_selectedRequest!),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
