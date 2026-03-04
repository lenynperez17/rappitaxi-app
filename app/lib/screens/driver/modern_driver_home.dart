// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart'; // ✅ NUEVO
import 'dart:async';
import 'dart:math' as math;
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../core/widgets/mode_switch_button.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../models/price_negotiation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/document_provider.dart';

import '../../utils/logger.dart';
import '../../utils/map_marker_utils.dart';
import 'package:flutter_animarker/flutter_map_marker_animation.dart';
import '../../services/local_notification_service.dart';
import '../../services/road_snapping_service.dart';
import '../../models/trip_model.dart';
import '../../core/constants/credit_constants.dart';
import 'active_trip_screen.dart';
class ModernDriverHomeScreen extends StatefulWidget {
  const ModernDriverHomeScreen({super.key});

  @override
  State<ModernDriverHomeScreen> createState() => _ModernDriverHomeScreenState();
}

class _ModernDriverHomeScreenState extends State<ModernDriverHomeScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _mapCompleter = Completer<GoogleMapController>();
  final Set<Marker> _markers = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _driverId; // Se obtendrá del usuario autenticado

  // Controllers de animación
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

  // ✅ Flag para prevenir operaciones después de dispose
  bool _isDisposed = false;

  // ✅ GPS TRACKING EN TIEMPO REAL
  Timer? _locationUpdateTimer;
  LatLng? _currentLocation;
  double _currentHeading = 0.0; // Heading del GPS para rotación del marcador
  DateTime? _lastProgrammaticCameraMove; // Timestamp to distinguish programmatic vs user camera moves
  bool _isCameraAnimating = false; // Prevent overlapping camera animations
  StreamSubscription<Position>? _positionStreamSubscription;

  // ✅ NUEVO: Control para seguir la ubicación del conductor en el mapa
  bool _followDriverLocation = true;

  // ✅ LISTENER EN TIEMPO REAL PARA RIDES
  StreamSubscription<QuerySnapshot>? _ridesStreamSubscription;

  // ✅ NUEVO: Listener para viajes activos del conductor (cuando ya tiene un viaje asignado)
  StreamSubscription<QuerySnapshot>? _activeRideSubscription;

  // ✅ NUEVO: Referencia al WalletProvider para escuchar cambios de créditos en tiempo real
  WalletProvider? _walletProvider;

  // ✅ Iconos premium para marcadores
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _requestIcon;
  BitmapDescriptor? _passengerWaitingIcon;

  // Estadísticas del día
  double _todayEarnings = 0.0;
  int _todayTrips = 0;
  // Acceptance rate is calculated dynamically from Firebase when needed

  // ✅ SISTEMA DE CRÉDITOS
  double _serviceCredits = 0.0;
  double _serviceFee = 1.0;
  double _minServiceCredits = CreditConstants.minServiceCredits; // ✅ Usa constante centralizada
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
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    );
    
    _pulseController.repeat(reverse: true);
    _loadCustomIcons();
    _initializeDriver();
    _loadRealRequests();
  }

  /// Cargar iconos premium para marcadores
  Future<void> _loadCustomIcons() async {
    _carIcon = await MapMarkerUtils.getCarTopViewIcon();
    _requestIcon = await MapMarkerUtils.getRequestIcon();
    _passengerWaitingIcon = await MapMarkerUtils.getPassengerWaitingIcon();
    if (mounted) setState(() {});
  }
  
  Future<void> _initializeDriver() async {
    try {
      // ✅ OBTENER TODOS LOS PROVIDERS ANTES DE CUALQUIER AWAIT
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final docProvider = Provider.of<DocumentProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        AppLogger.warning('⚠️ No hay usuario autenticado');
        return;
      }

      // ✅ CORREGIDO: Usar ID real del usuario (NO mock/placeholder)
      _driverId = currentUser.id;
      AppLogger.info('✅ Conductor inicializado: ${currentUser.fullName} (${currentUser.id})');

      // ✅ NUEVO: Limpiar rides "zombie" ANTES de iniciar el listener
      // Esto evita que aparezca "Yendo al punto de recogida" por rides antiguos no completados
      await _cleanupZombieRides();
      if (!mounted) return;

      // ✅ NUEVO: Iniciar listener de viajes activos INMEDIATAMENTE
      // Esto detectará si el conductor ya tiene un viaje asignado
      _startActiveRideListener();

      // ✅ VERIFICAR CRÉDITOS DEL CONDUCTOR
      await _checkDriverCredits();
      if (!mounted) return;

      // ✅ NUEVO: Iniciar listener de créditos en tiempo real
      _startWalletListener();

      // ✅ CARGAR ESTADO DE VERIFICACIÓN DE DOCUMENTOS
      await docProvider.loadVerificationStatus(_driverId!);
      if (!mounted) return;

      // Cargar estadísticas iniciales
      await _loadTodayStats();
    } catch (e) {
      AppLogger.error('Error inicializando conductor: $e');
    }
  }

  // ✅ MEJORADO: Limpiar rides "zombie" (viajes aceptados que nunca se completaron)
  // ✅ FIX 2026-01-05: Reducido a 30 minutos y agregado logging detallado
  Future<void> _cleanupZombieRides() async {
    if (_driverId == null) return;

    try {
      final now = DateTime.now();
      // ✅ REDUCIDO: De 2 horas a 30 minutos para ser más agresivo con los zombies
      final thirtyMinutesAgo = now.subtract(const Duration(minutes: 30));

      AppLogger.info('🧹 Buscando rides zombie para conductor: $_driverId');

      // Buscar rides activos del conductor (con limit para cumplir reglas Firestore)
      final activeRides = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: _driverId)
          .where('status', whereIn: ['accepted', 'arriving', 'arrived'])
          .limit(50) // ✅ Cumple regla Firestore: limit <= 100
          .get();

      AppLogger.info('🧹 Encontrados ${activeRides.docs.length} rides activos del conductor');

      int cleanedCount = 0;
      for (var doc in activeRides.docs) {
        final data = doc.data();
        final acceptedAt = (data['acceptedAt'] as Timestamp?)?.toDate();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final status = data['status'] as String?;
        final passengerId = data['passengerId'] as String?;

        // Usar acceptedAt o createdAt, el que esté disponible
        final rideStartTime = acceptedAt ?? createdAt;

        AppLogger.info('🔍 Ride ${doc.id}: status=$status, acceptedAt=$acceptedAt, createdAt=$createdAt, passengerId=$passengerId');

        // Si el ride fue creado/aceptado hace más de 30 minutos, limpiarlo
        if (rideStartTime != null && rideStartTime.isBefore(thirtyMinutesAgo)) {
          await doc.reference.update({
            'status': 'cancelled',
            'cancelReason': 'auto_cleanup_stale_ride',
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancelledBy': 'system',
          });
          cleanedCount++;
          final minutesAgo = now.difference(rideStartTime).inMinutes;
          AppLogger.info('🧹 Ride zombie limpiado: ${doc.id} (creado hace $minutesAgo minutos)');
        } else if (rideStartTime == null) {
          // Si no tiene fecha, también limpiarlo (datos corruptos)
          await doc.reference.update({
            'status': 'cancelled',
            'cancelReason': 'auto_cleanup_corrupt_ride',
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancelledBy': 'system',
          });
          cleanedCount++;
          AppLogger.info('🧹 Ride corrupto limpiado (sin fecha): ${doc.id}');
        } else {
          // Ride reciente, NO limpiar pero logear para debug
          final minutesAgo = now.difference(rideStartTime).inMinutes;
          AppLogger.warning('⚠️ Ride reciente NO limpiado: ${doc.id} (hace $minutesAgo min) - Se mostrará ActiveTripScreen');
        }
      }

      if (cleanedCount > 0) {
        AppLogger.info('🧹 Total de rides zombie limpiados: $cleanedCount');
      } else if (activeRides.docs.isEmpty) {
        AppLogger.info('✅ No hay rides activos para este conductor');
      }
    } catch (e) {
      AppLogger.warning('Error limpiando rides zombie: $e');
      // No lanzar excepción, continuar con el flujo normal
    }
  }

  // ✅ VERIFICAR CRÉDITOS DEL CONDUCTOR
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

      AppLogger.info('💳 Créditos del conductor: S/. $_serviceCredits (Mínimo: S/. $_minServiceCredits, Costo/servicio: S/. $_serviceFee)');

      if (!_hasEnoughCredits) {
        AppLogger.warning('⚠️ Conductor sin créditos suficientes para aceptar servicios');
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

  // ✅ NUEVO: Listener de créditos en tiempo real
  // Cuando el admin da créditos, se actualiza automáticamente sin necesidad de refrescar
  void _startWalletListener() {
    _walletProvider = Provider.of<WalletProvider>(context, listen: false);
    _walletProvider?.addListener(_onWalletChanged);
    AppLogger.info('👂 Listener de créditos iniciado');
  }

  // ✅ NUEVO: Callback cuando cambian los créditos en el WalletProvider
  void _onWalletChanged() {
    if (_isDisposed || !mounted) return;

    final wallet = _walletProvider?.wallet;
    if (wallet == null) return;

    final newCredits = wallet.serviceCredits;
    final minCredits = _minServiceCredits;
    final serviceFee = _serviceFee;

    // Solo actualizar si cambió el valor
    if (newCredits != _serviceCredits) {
      AppLogger.info('💳 Créditos actualizados en tiempo real: S/. $newCredits');

      setState(() {
        _serviceCredits = newCredits;
        _hasEnoughCredits = newCredits >= serviceFee && newCredits >= minCredits;
      });
    }
  }

  // ✅ NUEVO: Detener listener de créditos
  void _stopWalletListener() {
    _walletProvider?.removeListener(_onWalletChanged);
    _walletProvider = null;
    AppLogger.info('🛑 Listener de créditos detenido');
  }

  void _showDriverMenu() {
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
              leading: const Icon(Icons.person, color: ModernTheme.rappiOrange),
              title: const Text('Mi Perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics, color: ModernTheme.rappiOrange),
              title: const Text('Métricas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/metrics');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: ModernTheme.rappiOrange),
              title: const Text('Historial'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/transactions-history');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: ModernTheme.error),
              title: const Text('Cerrar Sesión'),
              onTap: () {
                Navigator.pop(context);
                _showLogoutConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Confirmación de logout
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // ✅ Marcar como disposed ANTES de cancelar recursos
    _isDisposed = true;

    // ✅ DETENER GPS TRACKING
    _stopLocationTracking();

    // ✅ DETENER LISTENER DE RIDES
    _stopRidesListener();

    // ✅ DETENER LISTENER DE VIAJES ACTIVOS
    _stopActiveRideListener();

    // ✅ DETENER LISTENER DE CRÉDITOS
    _stopWalletListener();

    // ✅ Liberar MapController para evitar ImageReader buffer warnings
    _mapController?.dispose();
    _mapController = null;

    _pulseController.dispose();
    _slideController.dispose();
    _requestsTimer?.cancel();
    _requestsTimer = null;
    super.dispose();
  }

  // ✅ NUEVO: Iniciar tracking GPS en tiempo real
  Future<void> _startLocationTracking() async {
    try {
      // Verificar permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.warning('⚠️ Permisos de ubicación denegados');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.error('❌ Permisos de ubicación denegados permanentemente');
        return;
      }

      // Obtener ubicación inicial
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted || _isDisposed) return;

      setState(() {
        _currentLocation = LatLng(initialPosition.latitude, initialPosition.longitude);
        _updateMapMarkers();
      });

      // Mover cámara a ubicación actual
      _lastProgrammaticCameraMove = DateTime.now();
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation!,
            zoom: 16,
          ),
        ),
      );

      // Iniciar stream de actualizaciones de ubicación
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters for smoother tracking
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) async {
        if (_isDisposed || !mounted) return;

        final newLocation = LatLng(position.latitude, position.longitude);

        // Update heading: always calculate from position change first (most reliable),
        // then override with GPS heading if available and valid
        if (_currentLocation != null) {
          final dLat = newLocation.latitude - _currentLocation!.latitude;
          final dLng = newLocation.longitude - _currentLocation!.longitude;
          if (dLat.abs() > 0.00001 || dLng.abs() > 0.00001) {
            final y = math.sin(dLng * math.pi / 180) * math.cos(newLocation.latitude * math.pi / 180);
            final x = math.cos(_currentLocation!.latitude * math.pi / 180) * math.sin(newLocation.latitude * math.pi / 180) -
                math.sin(_currentLocation!.latitude * math.pi / 180) * math.cos(newLocation.latitude * math.pi / 180) * math.cos(dLng * math.pi / 180);
            _currentHeading = (math.atan2(y, x) * 180 / math.pi + 360) % 360;
          }
        }
        // Override with GPS heading if available (more accurate on real devices)
        if (position.speed > 0.5 && position.heading >= 0 && position.heading <= 360) {
          _currentHeading = position.heading;
        }

        // ✅ Snap GPS position to nearest road (Uber-style road snapping)
        final snappedLocation = await RoadSnappingService.instance.snapToRoad(newLocation);

        AppLogger.debug('🧭 Heading: ${_currentHeading.toStringAsFixed(1)}° | Speed: ${position.speed.toStringAsFixed(1)} m/s | Snapped: ${snappedLocation != newLocation}');

        setState(() {
          _currentLocation = snappedLocation;
          _updateMapMarkers();
        });

        // ✅ Follow driver with bearing rotation (Google Maps-like navigation view)
        if (_followDriverLocation && _mapController != null && !_isCameraAnimating) {
          _isCameraAnimating = true;
          _lastProgrammaticCameraMove = DateTime.now();
          try {
            await _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: snappedLocation,
                  bearing: _currentHeading,
                  zoom: 17,
                  tilt: 50,
                ),
              ),
            );
          } catch (_) {
            // Camera animation cancelled by new animation - safe to ignore
          } finally {
            _isCameraAnimating = false;
          }
        }

        // ✅ ACTUALIZAR ubicación en Firebase cada 10 segundos
        if (_driverId != null && _isOnline) {
          await _updateLocationInFirebase(newLocation);
        }

        AppLogger.debug('📍 Ubicación actualizada: ${position.latitude}, ${position.longitude}');
      });

      AppLogger.info('✅ GPS tracking iniciado');
    } catch (e) {
      AppLogger.error('❌ Error iniciando GPS tracking: $e');
    }
  }

  // ✅ NUEVO: Detener tracking GPS
  void _stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _locationUpdateTimer?.cancel();
    RoadSnappingService.instance.reset();
    _locationUpdateTimer = null;
    AppLogger.debug('🛑 GPS tracking detenido');
  }

  // ✅ NUEVO: Actualizar ubicación del conductor en Firebase
  Future<void> _updateLocationInFirebase(LatLng location) async {
    try {
      if (_driverId == null) return;

      await _firestore.collection('drivers').doc(_driverId).set({
        'currentLocation': {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'heading': _currentHeading,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'isOnline': _isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // print('✅ Ubicación actualizada en Firebase'); // Comentado para reducir logs
    } catch (e) {
      AppLogger.warning('⚠️ Error actualizando ubicación en Firebase: $e');
    }
  }

  // ✅ NUEVO: Iniciar listener en tiempo real para rides
  void _startRidesListener() {
    try {
      if (_driverId == null) {
        AppLogger.warning('⚠️ No se puede iniciar listener de rides: driverId es null');
        return;
      }

      // ✅ Escuchar rides con status 'requested' o 'searching_driver' en tiempo real
      // ✅ IMPORTANTE: limit(100) requerido por las reglas de Firestore
      _ridesStreamSubscription = _firestore
          .collection('rides')
          .where('status', whereIn: ['requested', 'searching_driver'])
          .limit(100)
          .snapshots()
          .listen(
        (snapshot) async {
          // ✅ Verificar que no esté disposed ni desmontado
          if (_isDisposed || !mounted) return;

          List<PriceNegotiation> nearbyRides = [];

          for (var doc in snapshot.docs) {
            try {
              final data = doc.data();

              // ✅ Filtrar rides cercanos a la ubicación actual del conductor
              if (_currentLocation != null) {
                // Obtener coordenadas del pickup del ride
                final pickupData = data['pickupLocation'];
                if (pickupData != null &&
                    pickupData['latitude'] != null &&
                    pickupData['longitude'] != null) {
                  final pickupLat = (pickupData['latitude'] as num).toDouble();
                  final pickupLng = (pickupData['longitude'] as num).toDouble();

                  // Calcular distancia entre conductor y punto de recogida
                  final distanceInMeters = Geolocator.distanceBetween(
                    _currentLocation!.latitude,
                    _currentLocation!.longitude,
                    pickupLat,
                    pickupLng,
                  );

                  // ✅ Solo mostrar rides dentro de un radio de 5km (5000 metros)
                  if (distanceInMeters <= 5000) {
                    // Convertir ride a PriceNegotiation para usar la UI existente
                    final negotiation = PriceNegotiation(
                      id: doc.id,
                      passengerId: data['passengerId'] as String? ?? '',
                      selectedDriverId: null, // Sin conductor asignado aún
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
                      passengerPhoto: data['passengerPhoto'] as String? ?? 'https://via.placeholder.com/150',
                      passengerRating: (data['passengerRating'] as num?)?.toDouble() ?? 5.0,
                      driverOffers: [], // Sin ofertas aún para nuevo ride
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

          // ✅ Actualizar lista de solicitudes disponibles
          if (!_isDisposed && mounted) {
            // ✅ Detectar nuevos rides para enviar notificación
            final existingIds = _availableRequests.map((r) => r.id).toSet();
            final newRides = nearbyRides.where((r) => !existingIds.contains(r.id)).toList();

            setState(() {
              _availableRequests.addAll(newRides);
              _updateMapMarkers();
            });

            // ✅ NUEVO: Enviar notificación con sonido para cada nuevo ride
            if (newRides.isNotEmpty) {
              AppLogger.info('✅ ${newRides.length} rides cercanos detectados en tiempo real');

              // Enviar notificación para el primer nuevo ride
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
          AppLogger.error('❌ Error en listener de rides: $error');
        },
      );

      AppLogger.info('✅ Listener de rides iniciado');
    } catch (e) {
      AppLogger.error('❌ Error iniciando listener de rides: $e');
    }
  }

  // ✅ NUEVO: Detener listener de rides
  void _stopRidesListener() {
    _ridesStreamSubscription?.cancel();
    _ridesStreamSubscription = null;
    AppLogger.debug('🛑 Listener de rides detenido');
  }

  // ✅ NUEVO: Iniciar listener para viajes activos del conductor
  void _startActiveRideListener() {
    if (_driverId == null) {
      AppLogger.warning('⚠️ No hay driverId para listener de viajes activos');
      return;
    }

    // ✅ FIX: Validar que el usuario está en modo conductor y no hay cambio de rol en progreso
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isRoleSwitchInProgress) {
      AppLogger.warning('⚠️ Cambio de rol en progreso, no iniciar listener');
      return;
    }
    if (authProvider.currentUser?.currentMode != 'driver') {
      AppLogger.warning('⚠️ Usuario no está en modo conductor, no iniciar listener');
      return;
    }

    // Cancelar cualquier listener anterior
    _activeRideSubscription?.cancel();

    AppLogger.info('🔄 Iniciando listener de viajes activos para conductor: $_driverId');

    // Escuchar viajes donde el conductor está asignado y el status es activo
    _activeRideSubscription = _firestore
        .collection('rides')
        .where('driverId', isEqualTo: _driverId)
        .where('status', whereIn: ['accepted', 'driver_arriving', 'waiting_verification', 'in_progress'])
        .limit(1)
        .snapshots()
        .listen(
      (snapshot) {
        if (_isDisposed || !mounted) return;

        if (snapshot.docs.isNotEmpty) {
          final rideDoc = snapshot.docs.first;
          final rideData = rideDoc.data();
          final rideId = rideDoc.id;
          final status = rideData['status'] as String?;

          AppLogger.info('🚗 Viaje activo detectado: $rideId (status: $status)');

          // Navegar a la pantalla de viaje activo
          _navigateToActiveTrip(rideId, rideData);
        }
      },
      onError: (e) {
        AppLogger.error('❌ Error en listener de viajes activos: $e');
      },
    );
  }

  // ✅ MEJORADO: Verificar si el viaje es reciente o zombie antes de navegar
  // FIX 2026-01-05: Preguntar al usuario si quiere continuar con viajes antiguos
  void _navigateToActiveTrip(String tripId, Map<String, dynamic> tripData) {
    if (!mounted) return;

    // Detener listener para evitar navegaciones múltiples
    _activeRideSubscription?.cancel();

    // Verificar la antigüedad del viaje
    final acceptedAt = (tripData['acceptedAt'] as Timestamp?)?.toDate();
    final createdAt = (tripData['createdAt'] as Timestamp?)?.toDate();
    final rideStartTime = acceptedAt ?? createdAt;
    final now = DateTime.now();

    // Si el viaje tiene más de 30 minutos, preguntar al usuario
    if (rideStartTime != null && now.difference(rideStartTime).inMinutes > 30) {
      final minutesAgo = now.difference(rideStartTime).inMinutes;
      AppLogger.warning('⚠️ Viaje antiguo detectado: $tripId (hace $minutesAgo minutos)');

      // Mostrar diálogo preguntando qué hacer
      _showOldTripDialog(tripId, tripData, minutesAgo);
    } else {
      // Viaje reciente, navegar directamente
      AppLogger.info('🚗 Navegando a viaje activo: $tripId');
      _doNavigateToActiveTrip(tripId, tripData);
    }
  }

  // ✅ NUEVO: Mostrar diálogo para viajes antiguos
  void _showOldTripDialog(String tripId, Map<String, dynamic> tripData, int minutesAgo) {
    if (!mounted) return;

    final passengerName = tripData['passengerName'] ?? 'Pasajero desconocido';
    final origin = tripData['originAddress'] ?? tripData['origin']?['address'] ?? 'Origen no disponible';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Viaje pendiente',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se encontró un viaje iniciado hace $minutesAgo minutos que no fue completado.',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, size: 18, color: Colors.grey.shade700),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          passengerName,
                          style: TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on, size: 18, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          origin,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              '¿Qué deseas hacer?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _cancelOldTrip(tripId);
            },
            child: Text(
              'Cancelar viaje',
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _doNavigateToActiveTrip(tripId, tripData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Continuar viaje', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Cancelar viaje antiguo
  Future<void> _cancelOldTrip(String tripId) async {
    if (!mounted) return;

    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Cancelar el viaje en Firestore
      await _firestore.collection('rides').doc(tripId).update({
        'status': 'cancelled',
        'cancelReason': 'driver_cancelled_stale_ride',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': _driverId,
      });

      if (!mounted) return;

      // Cerrar loading
      Navigator.pop(context);

      AppLogger.info('🧹 Viaje antiguo cancelado exitosamente: $tripId');

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Viaje cancelado correctamente')),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Reiniciar el listener para detectar nuevos viajes
      _startActiveRideListener();

    } catch (e) {
      if (!mounted) return;

      // Cerrar loading si está abierto
      Navigator.pop(context);

      AppLogger.error('❌ Error cancelando viaje antiguo: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Error al cancelar: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ✅ SEPARADO: Navegación real a la pantalla de viaje activo
  void _doNavigateToActiveTrip(String tripId, Map<String, dynamic> tripData) {
    if (!mounted) return;

    AppLogger.info('🚗 Navegando a viaje activo: $tripId');

    // Crear TripModel desde los datos del documento
    final initialTrip = TripModel.fromMap(tripData, tripId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveTripScreen(
          tripId: tripId,
          initialTrip: initialTrip,
          initialLocation: _currentLocation,
        ),
      ),
    ).then((_) {
      // ✅ FIX: Reiniciar listener cuando el conductor regresa del viaje
      if (mounted) {
        _startActiveRideListener();
      }
    });
  }

  // ✅ NUEVO: Detener listener de viajes activos
  void _stopActiveRideListener() {
    _activeRideSubscription?.cancel();
    _activeRideSubscription = null;
    AppLogger.debug('🛑 Listener de viajes activos detenido');
  }
  
  void _loadRealRequests() {
    // ✅ CORREGIDO: Cargar solicitudes siempre (no solo cuando está online)
    // El conductor debe ver las solicitudes disponibles para poder ponerse online
    _loadRequestsFromFirebase();
  }
  
  Future<void> _loadRequestsFromFirebase() async {
    try {
      // ✅ Cargar solicitudes reales de 'negotiations' desde Firebase
      // ⚡ Este método trabaja EN CONJUNTO con _startRidesListener()
      // - Timer polling: Carga de 'negotiations' (negociaciones de precio estilo InDriver)
      // - Stream listener: Escucha 'rides' en tiempo real (viajes directos)
      if (_driverId == null) {
        AppLogger.warning('⚠️ No hay driverId configurado');
        return;
      }

      // ✅ CORREGIDO: Buscar en colección 'negotiations' donde el pasajero crea las solicitudes
      // Sin filtro de expiresAt en query (puede ser String o Timestamp en datos viejos)
      final requestsSnapshot = await _firestore
          .collection('negotiations')
          .where('status', isEqualTo: 'waiting')
          .limit(50)
          .get();

      AppLogger.info('📋 Encontradas ${requestsSnapshot.docs.length} solicitudes en Firestore');

      List<PriceNegotiation> loadedRequests = [];
      final now = DateTime.now();
      for (var doc in requestsSnapshot.docs) {
        try {
          final negotiation = PriceNegotiation.fromMap(doc.id, doc.data());
          // ✅ Filtrar expirados en el cliente (soporta String y Timestamp)
          if (negotiation.expiresAt.isAfter(now)) {
            loadedRequests.add(negotiation);
          }
        } catch (e) {
          AppLogger.error('Error parseando solicitud ${doc.id}: $e');
        }
      }

      AppLogger.info('✅ ${loadedRequests.length} solicitudes válidas (no expiradas)');

      if (!mounted) return;

      setState(() {
        // ✅ IMPORTANTE: Mantener rides del listener, solo actualizar negotiations
        // Filtrar para mantener solo los rides (de la colección 'rides')
        final ridesFromListener = _availableRequests.where((r) =>
          r.id.startsWith('rides/')).toList();

        _availableRequests = [...loadedRequests, ...ridesFromListener];
        _updateMapMarkers();
      });

      // ✅ Configurar timer para actualizaciones periódicas de 'negotiations'
      // El listener en tiempo real maneja automáticamente los rides
      _requestsTimer?.cancel();
      _requestsTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        // ✅ TRIPLE VERIFICACIÓN para prevenir polling después de dispose
        if (_isDisposed) {
          timer.cancel();
          return;
        }
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_isOnline) {
          _loadRequestsFromFirebase();
        }
      });
    } catch (e) {
      AppLogger.error('Error cargando solicitudes: $e');
      // En caso de error, mantener lista vacía (conductor nuevo o sin solicitudes)
      if (!mounted) return;
      setState(() {
        _availableRequests = [];
        _updateMapMarkers();
      });
    }
  }
  
  
  void _updateMapMarkers() {
    _markers.clear();

    // ✅ Marcador de la ubicación actual del conductor (icono moderno)
    if (_currentLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: _currentLocation!,
          icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          flat: true,
          anchor: const Offset(0.5, 0.5),
          // rotation handled by Animarker (useRotation: true) for smooth bearing animation
          infoWindow: const InfoWindow(title: 'Tu ubicación'),
        ),
      );
    }

    // Marcadores de solicitudes disponibles (icono de pasajero esperando taxi)
    for (var request in _availableRequests) {
      _markers.add(
        Marker(
          markerId: MarkerId(request.id),
          position: LatLng(request.pickup.latitude, request.pickup.longitude),
          icon: _passengerWaitingIcon ?? _requestIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
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

  // Rechazar solicitud de viaje
  void _rejectRequest(PriceNegotiation request) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Actualizar estado en Firestore
      await _firestore.collection('negotiations').doc(request.id).update({
        'status': 'rejected_by_driver',
        'rejectedBy': _driverId,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Cerrar el panel de detalles
      setState(() {
        _showRequestDetails = false;
        _selectedRequest = null;
      });
      _slideController.reverse();

      // Mostrar confirmación
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Solicitud rechazada'),
          backgroundColor: ModernTheme.warning,
          duration: Duration(seconds: 2),
        ),
      );

      AppLogger.info('Solicitud ${request.id} rechazada por conductor $_driverId');
    } catch (e) {
      AppLogger.error('Error al rechazar solicitud: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al rechazar: $e'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  void _acceptRequest(PriceNegotiation request) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // ✅ VERIFICAR CRÉDITOS ANTES DE ACEPTAR
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final hasCredits = await walletProvider.hasEnoughCreditsForService();

      if (!hasCredits) {
        // Mostrar diálogo para recargar créditos
        _showNeedCreditsDialog();
        return;
      }

      // Generar código de verificación del pasajero
      String generateVerificationCode() {
        final random = math.Random();
        String code = '';
        for (int i = 0; i < 4; i++) {
          code += random.nextInt(10).toString();
        }
        return code;
      }

      final passengerCode = generateVerificationCode();
      final driverCode = generateVerificationCode();

      // ✅ NUEVO: Obtener teléfono del pasajero desde Firestore
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

      // ✅ FIX: Cancelar listener de rides activos ANTES de la transacción
      // para evitar race condition entre listener y _acceptRequest
      _activeRideSubscription?.cancel();

      // ✅ CORRECCIÓN RACE CONDITION: Usar transaction para evitar que múltiples conductores acepten
      final rideId = await _firestore.runTransaction<String?>((transaction) async {
        final negotiationRef = _firestore.collection('negotiations').doc(request.id);
        final snapshot = await transaction.get(negotiationRef);

        if (!snapshot.exists) {
          throw Exception('La solicitud ya no existe');
        }

        final data = snapshot.data()!;

        // ✅ VALIDAR que no tenga conductor asignado (otro conductor ya aceptó)
        if (data['driverId'] != null && data['driverId'].toString().isNotEmpty) {
          throw Exception('Otro conductor ya aceptó esta solicitud');
        }

        // ✅ CORREGIDO: Validar status correcto (waiting = esperando, negotiating = en negociación)
        final status = data['status'] as String?;
        if (status != 'waiting' && status != 'negotiating') {
          throw Exception('La solicitud ya no está disponible');
        }

        // Crear registro de viaje dentro de la transacción
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
          // Códigos de verificación mutua
          'passengerVerificationCode': passengerCode,
          'driverVerificationCode': driverCode,
          'isPassengerVerified': false,
          'isDriverVerified': false,
          // ✅ CORREGIDO: Info del pasajero con nombre de campo correcto + teléfono
          'vehicleInfo': {
            'passengerName': request.passengerName,
            'passengerPhoto': request.passengerPhoto,
            'passengerRating': request.passengerRating,
            'passengerPhone': passengerPhone, // ✅ NUEVO: Teléfono del pasajero
          },
          // ✅ NUEVO: Info del pasajero separada
          'passengerInfo': {
            'name': request.passengerName,
            'photo': request.passengerPhoto,
            'rating': request.passengerRating,
            'phone': passengerPhone, // ✅ NUEVO: Teléfono del pasajero
          },
          // ✅ NUEVO: Info del conductor (se cargará después)
          'driverInfo': {
            'driverId': _driverId,
          },
        });

        // ✅ ASIGNAR conductor atómicamente
        transaction.update(negotiationRef, {
          'status': 'accepted',
          'driverId': _driverId,
          'rideId': rideRef.id,
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        return rideRef.id; // Retornar el ID del viaje
      });

      if (rideId != null) {
        // ✅ CONSUMIR CRÉDITOS DESPUÉS DE ACEPTAR EXITOSAMENTE
        final creditConsumed = await walletProvider.consumeCreditsForService(
          tripId: rideId,
          negotiationId: request.id,
        );

        if (creditConsumed) {
          AppLogger.info('✅ Créditos consumidos por servicio aceptado');
          // Actualizar créditos locales
          await _checkDriverCredits();

          setState(() {
            _availableRequests.remove(request);
            _showRequestDetails = false;
          });

          // Recargar estadísticas
          await _loadTodayStats();

          // ✅ FIX: Navegar directamente a ActiveTripScreen sin dialog intermedio
          // Esto evita la race condition con el listener de rides activos
          AppLogger.info('📍 Preparando navegación a ActiveTripScreen, mounted=$mounted');
          if (mounted) {
            final rideDoc = await _firestore.collection('rides').doc(rideId).get();
            AppLogger.info('📍 Ride doc exists=${rideDoc.exists}, id=$rideId');
            if (rideDoc.exists) {
              _doNavigateToActiveTrip(rideId, rideDoc.data()!);
            }
          }
        } else {
          // ✅ COMPENSACIÓN: Si falla el consumo de créditos, cancelar el viaje asignado
          AppLogger.warning('⚠️ Fallo el consumo de créditos, revirtiendo viaje asignado');

          try {
            await _firestore.runTransaction((transaction) async {
              // Revertir el ride
              transaction.update(_firestore.collection('rides').doc(rideId), {
                'status': 'cancelled',
                'cancelledAt': FieldValue.serverTimestamp(),
                'cancelReason': 'credit_consumption_failed',
              });

              // Revertir la negociación
              transaction.update(_firestore.collection('negotiations').doc(request.id), {
                'status': 'waiting',
                'driverId': FieldValue.delete(),
                'rideId': FieldValue.delete(),
                'acceptedAt': FieldValue.delete(),
              });
            });
          } catch (rollbackError) {
            AppLogger.error('CRITICAL: Rollback de viaje/negociación falló: $rollbackError');
          }

          messenger.showSnackBar(
            const SnackBar(
              content: Text('Error al procesar créditos. Intenta de nuevo.'),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      }
    } on FirebaseException catch (e) {
      AppLogger.error('Error Firebase aceptando solicitud: ${e.code} - ${e.message}');
      if (!mounted) return;

      String errorMessage;
      if (e.code == 'permission-denied') {
        errorMessage = 'Error de permisos. Contacta soporte. (${e.code})';
      } else if (e.code == 'failed-precondition' || e.code == 'aborted') {
        errorMessage = 'Otro conductor ya aceptó esta solicitud';
      } else if (e.code == 'not-found') {
        errorMessage = 'La solicitud ya no existe';
      } else {
        errorMessage = 'Error: ${e.message ?? e.code}';
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: ModernTheme.error,
        ),
      );
    } catch (e) {
      AppLogger.error('Error aceptando solicitud: $e');
      if (!mounted) return;

      String errorMessage;
      if (e.toString().contains('ya aceptó')) {
        errorMessage = 'Otro conductor ya aceptó esta solicitud';
      } else if (e.toString().contains('no está disponible')) {
        errorMessage = 'La solicitud ya no está disponible';
      } else if (e.toString().contains('ya no existe')) {
        errorMessage = 'La solicitud ya no existe';
      } else {
        errorMessage = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  // ✅ DIÁLOGO CUANDO NO TIENE CRÉDITOS SUFICIENTES
  void _showNeedCreditsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ModernTheme.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet, color: ModernTheme.warning, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Créditos insuficientes',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ModernTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: ModernTheme.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tu saldo actual: S/. ${_serviceCredits.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Para aceptar servicios necesitas:',
              style: TextStyle(color: context.secondaryText),
            ),
            const SizedBox(height: 8),
            _buildCreditRequirement('Mínimo requerido', 'S/. ${_minServiceCredits.toStringAsFixed(2)}'),
            _buildCreditRequirement('Costo por servicio', 'S/. ${_serviceFee.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: ModernTheme.rappiOrange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recarga créditos para seguir aceptando viajes y ganando dinero',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cerrar', style: TextStyle(color: context.secondaryText)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_card, size: 18),
            label: const Text('Recargar créditos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              // Navegar a pantalla de recarga de créditos y refrescar al volver
              Navigator.pushNamed(context, '/driver/recharge-credits').then((_) => _checkDriverCredits());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCreditRequirement(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.secondaryText, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ✅ NUEVO: Diálogo para negociar precio con el pasajero
  void _showNegotiateDialog(PriceNegotiation request) {
    final priceController = TextEditingController(
      text: request.offeredPrice.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.price_change, color: ModernTheme.warning),
            const SizedBox(width: 8),
            const Text('Proponer precio'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Precio del pasajero: S/ ${request.offeredPrice.toStringAsFixed(2)}',
              style: TextStyle(color: context.secondaryText),
            ),
            const SizedBox(height: 8),
            Text(
              'Precio sugerido: S/ ${request.suggestedPrice.toStringAsFixed(2)}',
              style: TextStyle(color: context.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Tu propuesta (S/)',
                prefixText: 'S/ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ModernTheme.warning, width: 2),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'El pasajero recibirá tu oferta y podrá aceptar o rechazar.',
              style: TextStyle(fontSize: 12, color: context.secondaryText),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar', style: TextStyle(color: context.secondaryText)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final proposedPrice = double.tryParse(priceController.text);
              if (proposedPrice == null || proposedPrice <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ingresa un precio válido'),
                    backgroundColor: ModernTheme.error,
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext);
              await _sendCounterOffer(request, proposedPrice);
            },
            icon: const Icon(Icons.send),
            label: const Text('Enviar oferta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Enviar contraoferta al pasajero
  Future<void> _sendCounterOffer(PriceNegotiation request, double proposedPrice) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Obtener datos del conductor
      final driverDoc = await _firestore.collection('users').doc(_driverId).get();
      final driverData = driverDoc.data() ?? {};
      final vehicleInfo = driverData['vehicleInfo'] as Map<String, dynamic>? ?? {};

      // Crear la oferta del conductor
      // ✅ CORREGIDO: Usar DateTime.now() porque FieldValue.serverTimestamp() no funciona en arrayUnion
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

      // Actualizar la negociación en Firestore
      await _firestore.collection('negotiations').doc(request.id).update({
        'status': 'negotiating',
        'driverOffers': FieldValue.arrayUnion([offer]),
      });

      setState(() {
        _showRequestDetails = false;
        _selectedRequest = null;
      });
      _slideController.reverse();

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Oferta de S/ ${proposedPrice.toStringAsFixed(2)} enviada'),
            ],
          ),
          backgroundColor: ModernTheme.success,
        ),
      );

      // Recargar solicitudes
      _loadRequestsFromFirebase();
    } catch (e) {
      AppLogger.error('Error enviando contraoferta: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al enviar oferta: $e'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // UI: Mapa fullscreen - sin AppBar, todo dentro del Stack
      body: Stack(
        children: [
          // Mapa con animación suave del carro
          Animarker(
            mapId: _mapCompleter.future.then<int>((c) => c.mapId),
            curve: Curves.easeInOut,
            duration: const Duration(milliseconds: 1200),
            useRotation: true, // Auto-rotate marker toward movement direction (Uber-style)
            markers: {..._markers},
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(-12.0851, -76.9770),
                zoom: 14,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (!_mapCompleter.isCompleted) {
                  _mapCompleter.complete(controller);
                }
              },
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              liteModeEnabled: false,
              buildingsEnabled: false,
              indoorViewEnabled: false,
              trafficEnabled: false,
              minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
              onCameraMoveStarted: () {
                // Only stop following if the user manually dragged the map
                // Ignore camera moves triggered by our own animateCamera (within 2s window)
                if (_lastProgrammaticCameraMove != null &&
                    DateTime.now().difference(_lastProgrammaticCameraMove!).inMilliseconds < 2000) {
                  return;
                }
                if (_followDriverLocation) {
                  setState(() {
                    _followDriverLocation = false;
                  });
                }
              },
            ),
          ),

          // ✅ NUEVO: Botón para volver a centrar en la ubicación del conductor
          if (_isOnline && !_followDriverLocation && _currentLocation != null)
            Positioned(
              right: 16,
              // Position above the bottom bar (bar height ~72px + safe area + spacing)
              bottom: _availableRequests.isNotEmpty ? 400 : (72 + MediaQuery.of(context).padding.bottom + 16),
              child: FloatingActionButton.small(
                heroTag: 'centerLocation',
                backgroundColor: ModernTheme.rappiOrange,
                onPressed: () {
                  setState(() {
                    _followDriverLocation = true;
                  });
                  if (_currentLocation != null && _mapController != null) {
                    _lastProgrammaticCameraMove = DateTime.now();
                    _mapController!.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: _currentLocation!,
                          bearing: _currentHeading,
                          zoom: 17,
                          tilt: 50,
                        ),
                      ),
                    );
                  }
                },
                child: const Icon(Icons.my_location, color: Colors.white),
              ),
            ),
          
          // UI: Status chip flotante top-left + acciones top-right
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Status chip online/offline en top-left
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isOnline
                              ? ModernTheme.success
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: ModernTheme.getCardShadow(context),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isOnline
                                    ? Colors.white
                                    : context.secondaryText,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isOnline ? 'En linea' : 'Desconectado',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _isOnline
                                    ? Colors.white
                                    : context.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Acciones en top-right
                      Row(
                        children: [
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, _) {
                              final vehicleInfo = authProvider.currentUser?.vehicleInfo;
                              final plate = vehicleInfo?['plate'] as String?;
                              if (plate != null && plate.isNotEmpty) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: ModernTheme.rappiOrange, width: 2),
                                    boxShadow: ModernTheme.getCardShadow(context),
                                  ),
                                  child: Text(
                                    plate.toUpperCase(),
                                    style: const TextStyle(
                                      color: ModernTheme.rappiBlack,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              shape: BoxShape.circle,
                              boxShadow: ModernTheme.getCardShadow(context),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.account_balance_wallet, color: ModernTheme.rappiOrange),
                              onPressed: () => Navigator.pushNamed(context, '/driver/wallet'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              shape: BoxShape.circle,
                              boxShadow: ModernTheme.getCardShadow(context),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.menu, color: context.primaryText),
                              onPressed: () => _showDriverMenu(),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const ModeSwitchButton(compact: true),
                        ],
                      ),
                    ],
                  ),
                ),

                // Banners de creditos y documentos inline (version compacta)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  // ✅ BANNER DE CRÉDITOS INSUFICIENTES
                  if (!_isCheckingCredits && !_hasEnoughCredits)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color.lerp(Theme.of(context).colorScheme.surface, ModernTheme.warning, 0.12)!,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ModernTheme.warning.withValues(alpha: 0.5)),
                      ),
                      child: InkWell(
                        onTap: () => Navigator.pushNamed(context, '/driver/recharge-credits').then((_) => _checkDriverCredits()),
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ModernTheme.warning.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.account_balance_wallet, color: ModernTheme.warning, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Créditos de servicio insuficientes',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Créditos: S/. ${_serviceCredits.toStringAsFixed(2)} (mín: S/. ${_minServiceCredits.toStringAsFixed(2)}) • Toca para recargar',
                                    style: TextStyle(fontSize: 11, color: context.secondaryText),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: ModernTheme.warning),
                          ],
                        ),
                      ),
                    ),

                  // ✅ MOSTRAR SALDO DE CRÉDITOS (cuando tiene saldo)
                  if (!_isCheckingCredits && _hasEnoughCredits)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color.lerp(Theme.of(context).colorScheme.surface, ModernTheme.rappiOrange, 0.12)!,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_balance_wallet, color: ModernTheme.rappiOrange, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Créditos: S/. ${_serviceCredits.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: ModernTheme.rappiOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Banner documentos pendientes
                  Consumer<DocumentProvider>(
                    builder: (context, docProvider, _) {
                      final status = docProvider.verificationStatus;
                      if (status == null || status.isEmpty) return const SizedBox.shrink();
                      final isVerified = status['isVerified'] == true;
                      final verificationStatus = status['verificationStatus']?.toString() ?? 'pending';
                      if (isVerified || verificationStatus == 'approved') return const SizedBox.shrink();
                      Color bannerColor;
                      String title;
                      String subtitle;
                      IconData icon;
                      switch (verificationStatus) {
                        case 'under_review':
                          bannerColor = ModernTheme.info;
                          title = 'Documentos en revisión';
                          subtitle = 'Te notificaremos cuando sean aprobados';
                          icon = Icons.hourglass_empty;
                          break;
                        case 'rejected':
                          bannerColor = ModernTheme.error;
                          title = 'Documentos rechazados';
                          subtitle = 'Revisa y vuelve a subir los documentos';
                          icon = Icons.error_outline;
                          break;
                        default:
                          bannerColor = ModernTheme.warning;
                          title = 'Documentos pendientes';
                          subtitle = 'Completa tu documentación para trabajar';
                          icon = Icons.description_outlined;
                      }
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => Navigator.pushNamed(context, '/driver/documents'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color.lerp(Theme.of(context).colorScheme.surface, bannerColor, 0.12)!,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: bannerColor.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: bannerColor.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, color: bannerColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text(subtitle, style: TextStyle(fontSize: 11, color: context.secondaryText)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: bannerColor),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // UI: Bottom bar fija con switch grande online/offline
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? ModernTheme.success
                      : Theme.of(context).colorScheme.surface,
                  boxShadow: ModernTheme.getFloatingShadow(context),
                ),
                // Extend background behind home indicator with extra bottom padding
                padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isOnline ? 'Estas en linea' : 'Estas desconectado',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isOnline ? Colors.white : context.primaryText,
                            ),
                          ),
                          if (_isOnline)
                            Text(
                              'Ganancias hoy: S/. ${_todayEarnings.toStringAsFixed(2)} · $_todayTrips viajes',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            )
                          else
                            Text(
                              'Activa para recibir solicitudes',
                              style: TextStyle(fontSize: 12, color: context.secondaryText),
                            ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 1.3,
                      child: Switch(
                        value: _isOnline,
                        onChanged: (value) {
                          setState(() {
                            _isOnline = value;
                            if (value) {
                              _startLocationTracking();
                              _startRidesListener();
                              _availableRequests = [];
                              _checkDriverCredits();
                            } else {
                              _stopLocationTracking();
                              _stopRidesListener();
                              _availableRequests.clear();
                              _markers.clear();
                            }
                          });
                        },
                        activeThumbColor: Colors.white,
                        activeTrackColor: ModernTheme.rappiOrange,
                        inactiveThumbColor: Colors.grey.shade400,
                        inactiveTrackColor: Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
              ),
          ),
          // Lista de solicitudes activas (flota above the bottom bar)
          if (_isOnline && _availableRequests.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              // 72px bar content + SafeArea bottom + 8px spacing
              bottom: 72 + MediaQuery.of(context).padding.bottom + 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: ModernTheme.getFloatingShadow(context),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Título con contador de solicitudes
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Solicitudes disponibles',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: context.primaryText,
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: ModernTheme.primaryOrange,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_availableRequests.length}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Lista horizontal de solicitudes
                    SizedBox(
                      height: 210, // ✅ Aumentado para mostrar tarjetas completas
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _availableRequests.length,
                        itemBuilder: (context, index) {
                          return _buildRequestCard(_availableRequests[index]);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          
          // Detalle de solicitud seleccionada
          if (_showRequestDetails && _selectedRequest != null) ...[
            // ✅ Fondo oscuro para cerrar al tocar fuera
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
                      color: Colors.black.withValues(alpha: 0.3 * _slideAnimation.value),
                    );
                  },
                ),
              ),
            ),
            // Panel de detalle
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
                        // ✅ Cerrar al arrastrar hacia abajo
                        if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
                          setState(() {
                            _showRequestDetails = false;
                            _selectedRequest = null;
                          });
                          _slideController.reverse();
                        }
                      },
                      child: _buildRequestDetailSheet(_selectedRequest!),
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
  
  Widget _buildRequestCard(PriceNegotiation request) {
    final timeRemaining = request.timeRemaining;
    final isExpired = timeRemaining.isNegative || timeRemaining.inSeconds <= 0;
    final isUrgent = !isExpired && timeRemaining.inMinutes < 2;
    
    return AnimatedElevatedCard(
      onTap: () => _selectRequest(request),
      borderRadius: 16,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: isUrgent
            ? LinearGradient(
                colors: [ModernTheme.warning.withValues(alpha: 0.1), Theme.of(context).colorScheme.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con foto y rating
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: (request.passengerPhoto.isNotEmpty && request.passengerPhoto.startsWith('http'))
                      ? NetworkImage(request.passengerPhoto)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.passengerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: ModernTheme.accentYellow),
                          const SizedBox(width: 2),
                          Text(
                            request.passengerRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Precio ofrecido
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ModernTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'S/. ${request.offeredPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: ModernTheme.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Información del viaje
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: ModernTheme.success),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.pickup.address,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.flag, size: 16, color: ModernTheme.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.destination.address,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const Spacer(),
            
            // Footer con distancia y tiempo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.route, size: 14, color: context.secondaryText),
                    const SizedBox(width: 4),
                    Text(
                      '${request.distance.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.secondaryText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.access_time, size: 14, color: context.secondaryText),
                    const SizedBox(width: 4),
                    Text(
                      '${request.estimatedTime} min',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.secondaryText,
                      ),
                    ),
                  ],
                ),
                // Tiempo restante
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired ? ModernTheme.error : (isUrgent ? ModernTheme.warning : ModernTheme.info),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isExpired
                        ? 'Expirado'
                        : '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestDetailSheet(PriceNegotiation request) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: ModernTheme.getFloatingShadow(context),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ Handle con botón de cerrar
          Stack(
            alignment: Alignment.center,
            children: [
              // Handle central
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Botón X a la derecha
              Positioned(
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showRequestDetails = false;
                      _selectedRequest = null;
                    });
                    _slideController.reverse();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: context.secondaryText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Información del pasajero
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: (request.passengerPhoto.isNotEmpty && request.passengerPhoto.startsWith('http'))
                    ? NetworkImage(request.passengerPhoto)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.passengerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: ModernTheme.accentYellow),
                        const SizedBox(width: 4),
                        Text(
                          request.passengerRating.toStringAsFixed(1),
                          style: TextStyle(color: context.secondaryText),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          request.paymentMethod == PaymentMethod.cash
                            ? Icons.money
                            : Icons.credit_card,
                          size: 16,
                          color: context.secondaryText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          request.paymentMethod == PaymentMethod.cash
                            ? 'Efectivo'
                            : 'Tarjeta',
                          style: TextStyle(color: context.secondaryText),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Precio grande
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: ModernTheme.successGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'S/. ${request.offeredPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          
          // Detalles del viaje
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
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
                              color: context.secondaryText,
                            ),
                          ),
                          Text(
                            request.pickup.address,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Container(
                    height: 30,
                    width: 1,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                              color: context.secondaryText,
                            ),
                          ),
                          Text(
                            request.destination.address,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          
          // Información adicional
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoChip(Icons.route, '${request.distance.toStringAsFixed(1)} km'),
              _buildInfoChip(Icons.access_time, '${request.estimatedTime} min'),
              _buildInfoChip(
                Icons.timer,
                request.timeRemaining.isNegative || request.timeRemaining.inSeconds <= 0
                    ? 'Expirado'
                    : '${request.timeRemaining.inMinutes}:${(request.timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
              ),
            ],
          ),
          
          if (request.notes != null && request.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: ModernTheme.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.notes!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Botones de acción - 3 opciones: Rechazar, Negociar, Aceptar
          Column(
            children: [
              // Fila superior: Rechazar y Negociar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectRequest(request),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(color: ModernTheme.error),
                        foregroundColor: ModernTheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showNegotiateDialog(request),
                      icon: const Icon(Icons.price_change, size: 18),
                      label: const Text('Negociar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(color: ModernTheme.warning),
                        foregroundColor: ModernTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Fila inferior: Aceptar (ancho completo)
              SizedBox(
                width: double.infinity,
                child: AnimatedPulseButton(
                  text: 'Aceptar viaje',
                  icon: Icons.check,
                  color: ModernTheme.success,
                  onPressed: () => _acceptRequest(request),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.secondaryText),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: context.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _loadTodayStats() async {
    try {
      if (_driverId == null) return;

      // Obtener fecha de hoy
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Consultar viajes del conductor del día actual
      final tripsQuery = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: _driverId)
          .where('requestedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('requestedAt', isLessThan: Timestamp.fromDate(endOfDay))
          .where('status', isEqualTo: 'completed')
          .limit(100)
          .get();

      double totalEarnings = 0.0;
      int tripCount = 0;

      for (var doc in tripsQuery.docs) {
        final data = doc.data();
        final fare = ((data['finalFare'] ?? data['estimatedFare'] ?? 0) as num).toDouble();
        totalEarnings += fare;
        tripCount++;
      }

      // ✅ NUEVO: Calcular tasa de aceptación basada en 'negotiations'
      // Contar solicitudes aceptadas vs rechazadas del conductor
      final negotiationsQuery = await _firestore
          .collection('negotiations')
          .where('driverId', isEqualTo: _driverId)
          .where('requestedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('requestedAt', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(100)
          .get();

      int totalOffered = negotiationsQuery.docs.length;

      setState(() {
        _todayEarnings = totalEarnings;
        _todayTrips = tripCount;
      });

      // Si no hay viajes, mostrar mensaje informativo
      if (tripCount == 0) {
        AppLogger.debug('ℹ️ No hay viajes completados hoy. Empieza a aceptar solicitudes!');
      }

      if (totalOffered == 0) {
        AppLogger.debug('ℹ️ No hay solicitudes recibidas hoy. Tasa de aceptación: N/A');
      }
    } catch (e) {
      // Detectar si es error de permisos (conductor nuevo) o error real
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('permission') || errorMessage.contains('denied')) {
        AppLogger.debug('ℹ️ Conductor nuevo detectado. Sin historial de viajes aún.');
      } else {
        AppLogger.warning('⚠️ Error cargando estadísticas del día: $e');
      }

      // En todos los casos, mostrar valores en 0 (conductor nuevo o error)
      if (!_isDisposed && mounted) {
        setState(() {
          _todayEarnings = 0.0;
          _todayTrips = 0;
        });
      }
    }
  }
  
}