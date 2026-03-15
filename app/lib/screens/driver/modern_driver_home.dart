// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, library_private_types_in_public_api, unused_import, unreachable_switch_case
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animarker/flutter_map_marker_animation.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/credit_constants.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../core/widgets/mode_switch_button.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../models/price_negotiation_model.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/ride_provider.dart';
import '../../utils/logger.dart';
import '../../utils/map_marker_utils.dart';
import '../../services/sound_service.dart';
import '../../services/local_notification_service.dart';
import '../../services/road_snapping_service.dart';
import '../../generated/l10n/app_localizations.dart';
import 'driver_profile_screen.dart';
import 'active_trip_screen.dart';

class ModernDriverHomeScreen extends StatefulWidget {
  const ModernDriverHomeScreen({super.key});

  @override
  _ModernDriverHomeScreenState createState() => _ModernDriverHomeScreenState();
}

class _ModernDriverHomeScreenState extends State<ModernDriverHomeScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _mapCompleter = Completer<GoogleMapController>();
  final Set<Marker> _markers = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _driverId;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;

  // State
  int _currentTabIndex = 0; // 0 = Requests, 1 = Performance
  bool _isOnline = false;
  bool _showRequestDetails = false;
  List<PriceNegotiation> _availableRequests = [];
  PriceNegotiation? _selectedRequest;
  Timer? _requestsTimer;
  Timer? _countdownTimer;
  Timer? _uiRefreshTimer;

  // Prevent operations after dispose
  bool _isDisposed = false;

  // GPS tracking
  Timer? _locationUpdateTimer;
  LatLng? _currentLocation;
  double _currentHeading = 0.0;
  DateTime? _lastProgrammaticCameraMove;
  bool _isCameraAnimating = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Follow driver location on map
  final bool _followDriverLocation = true;

  // Offer acceptance listener
  StreamSubscription<DocumentSnapshot>? _myOfferSubscription;
  String? _pendingOfferTripId;

  // Track processed counter-offers
  final Set<String> _processedCounterOffers = {};

  // Verification listener
  StreamSubscription<DocumentSnapshot>? _verificationSubscription;

  // Real-time rides listener
  StreamSubscription<QuerySnapshot>? _ridesStreamSubscription;

  // Active ride subscription (Rapi Team)
  StreamSubscription<QuerySnapshot>? _activeRideSubscription;

  // Wallet provider for credits (Rapi Team)
  WalletProvider? _walletProvider;

  // Custom map markers
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _requestIcon;
  BitmapDescriptor? _passengerWaitingIcon;

  // Today stats
  double _todayEarnings = 0.0;
  int _todayTrips = 0;
  double _acceptanceRate = 0.0;

  // Credit system (Rapi Team)
  double _serviceCredits = 0.0;
  double _serviceFee = 1.0;
  double _minServiceCredits = CreditConstants.minServiceCredits;
  bool _hasEnoughCredits = false;
  bool _isCheckingCredits = true;

  // Offering overlay state
  String? _offeringOverlayText;
  double? _offeringPrice;
  PriceNegotiation? _offeringRequest;
  Timer? _offerProgressTimer;
  double _offerProgressValue = 1.0;

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
    _initializeDriver().then((_) {
      if (mounted) {
        _loadRealRequests();
      }
    }).catchError((e, stackTrace) {
      debugPrint('Error initializing driver home: $e');
    });
  }

  /// Load custom map marker icons
  Future<void> _loadCustomIcons() async {
    _carIcon = await MapMarkerUtils.getCarTopViewIcon();
    _requestIcon = await MapMarkerUtils.getRequestIcon();
    _passengerWaitingIcon = await MapMarkerUtils.getPassengerWaitingIcon();
    if (mounted) setState(() {});
  }

  Future<void> _initializeDriver() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final docProvider = Provider.of<DocumentProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        AppLogger.warning('No authenticated user');
        return;
      }

      _driverId = currentUser.id;
      AppLogger.info('Driver initialized: ${currentUser.fullName} (${currentUser.id})');

      // Listener for admin verification approval
      if (currentUser.driverStatus != 'approved') {
        _startVerificationListener(currentUser.id);
      }

      // Clean up zombie rides before starting listener
      await _cleanupZombieRides();
      if (!mounted) return;

      // Start active ride listener immediately
      _startActiveRideListener();

      // Check driver credits (Rapi Team)
      await _checkDriverCredits();
      if (!mounted) return;

      // Start real-time credit listener (Rapi Team)
      _startWalletListener();

      // Load document verification status
      await docProvider.loadVerificationStatus(_driverId!);
      if (!mounted) return;

      // Load initial stats
      await _loadTodayStats();
    } catch (e) {
      AppLogger.error('Error initializing driver: $e');
    }
  }

  // Clean up zombie rides (stale accepted rides that were never completed)
  Future<void> _cleanupZombieRides() async {
    if (_driverId == null) return;

    try {
      final now = DateTime.now();
      final thirtyMinutesAgo = now.subtract(const Duration(minutes: 30));

      AppLogger.info('Searching zombie rides for driver: $_driverId');

      final activeRides = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: _driverId)
          .where('status', whereIn: ['accepted', 'arriving', 'arrived'])
          .limit(50)
          .get();

      AppLogger.info('Found ${activeRides.docs.length} active rides for driver');

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
        AppLogger.info('Total zombie rides cleaned: $cleanedCount');
      }
    } catch (e) {
      AppLogger.warning('Error cleaning zombie rides: $e');
    }
  }

  // Credit system methods (Rapi Team)
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

      AppLogger.info('Driver credits: S/. $_serviceCredits (Min: S/. $_minServiceCredits, Cost/service: S/. $_serviceFee)');
    } catch (e) {
      AppLogger.error('Error checking credits: $e');
      if (_isDisposed) return;
      setState(() {
        _hasEnoughCredits = false;
        _isCheckingCredits = false;
      });
    }
  }

  void _startWalletListener() {
    _walletProvider = Provider.of<WalletProvider>(context, listen: false);
    _walletProvider?.addListener(_onWalletChanged);
  }

  void _onWalletChanged() {
    if (_isDisposed || !mounted) return;

    final wallet = _walletProvider?.wallet;
    if (wallet == null) return;

    final newCredits = wallet.serviceCredits;
    if (newCredits != _serviceCredits) {
      setState(() {
        _serviceCredits = newCredits;
        _hasEnoughCredits = newCredits >= _serviceFee && newCredits >= _minServiceCredits;
      });
    }
  }

  void _stopWalletListener() {
    _walletProvider?.removeListener(_onWalletChanged);
    _walletProvider = null;
  }

  /// Listen for admin verification approval
  void _startVerificationListener(String uid) {
    _verificationSubscription?.cancel();
    _verificationSubscription = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) async {
      if (_isDisposed || !mounted) return;
      final data = snapshot.data();
      if (data == null) return;

      final status = data['driverVerificationStatus'] as String?;
      if (status == 'verified' || status == 'approved') {
        _verificationSubscription?.cancel();
        _verificationSubscription = null;
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.reloadUserData();
        if (mounted) setState(() {});
      }
    });
  }

  // Active ride listener (Rapi Team)
  void _startActiveRideListener() {
    if (_driverId == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isRoleSwitchInProgress) return;
    if (authProvider.currentUser?.currentMode != 'driver') return;

    _activeRideSubscription?.cancel();

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

          _navigateToActiveTrip(rideId, rideData);
        }
      },
      onError: (e) {
        AppLogger.error('Error in active ride listener: $e');
      },
    );
  }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Viaje pendiente', style: TextStyle(fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se encontro un viaje iniciado hace $minutesAgo minutos que no fue completado.', style: TextStyle(fontSize: 15)),
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
                  Row(children: [
                    Icon(Icons.person, size: 18, color: Colors.grey.shade700),
                    SizedBox(width: 8),
                    Expanded(child: Text(passengerName, style: TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  ]),
                  SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.location_on, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(child: Text(origin, style: TextStyle(fontSize: 13, color: Colors.grey.shade700), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text('Que deseas hacer?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _cancelOldTrip(tripId);
            },
            child: Text('Cancelar viaje', style: TextStyle(color: Colors.red)),
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

  Future<void> _cancelOldTrip(String tripId) async {
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(child: CircularProgressIndicator()),
      );

      await _firestore.collection('rides').doc(tripId).update({
        'status': 'cancelled',
        'cancelReason': 'driver_cancelled_stale_ride',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': _driverId,
      });

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('Viaje cancelado correctamente')),
          ]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      _startActiveRideListener();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cancelar: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  void _doNavigateToActiveTrip(String tripId, Map<String, dynamic> tripData) {
    if (!mounted) return;

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
      if (mounted) {
        _startActiveRideListener();
      }
    });
  }

  void _stopActiveRideListener() {
    _activeRideSubscription?.cancel();
    _activeRideSubscription = null;
  }

  void _showDriverMenu() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person, color: AppColors.rappiOrange),
              title: Text('Mi Perfil', style: TextStyle(color: AppColors.getTextPrimary(context))),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/profile');
              },
            ),
            ListTile(
              leading: Icon(Icons.analytics, color: AppColors.rappiOrange),
              title: Text('Metricas', style: TextStyle(color: AppColors.getTextPrimary(context))),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/metrics');
              },
            ),
            ListTile(
              leading: Icon(Icons.history, color: AppColors.rappiOrange),
              title: Text('Historial', style: TextStyle(color: AppColors.getTextPrimary(context))),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/transactions-history');
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: AppColors.error),
              title: Text('Cerrar Sesion', style: TextStyle(color: AppColors.getTextPrimary(context))),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;

    _stopLocationTracking();
    _stopRidesListener();
    _stopActiveRideListener();
    _stopWalletListener();

    _mapController?.dispose();
    _mapController = null;

    _pulseController.dispose();
    _slideController.dispose();
    _requestsTimer?.cancel();
    _requestsTimer = null;
    _countdownTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _countdownTimer = null;
    _uiRefreshTimer = null;
    _myOfferSubscription?.cancel();
    _myOfferSubscription = null;
    _offerProgressTimer?.cancel();
    _offerProgressTimer = null;
    _verificationSubscription?.cancel();
    _verificationSubscription = null;
    super.dispose();
  }

  void _startUIRefreshTimer() {
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted && !_isDisposed && _availableRequests.isNotEmpty) {
        setState(() {});
      }
    });
  }

  /// Listen for passenger accepting driver's offer -> navigate to active trip
  void _listenForOfferAcceptance(String tripId) {
    _myOfferSubscription?.cancel();
    _pendingOfferTripId = tripId;

    _myOfferSubscription = _firestore
        .collection('rides')
        .doc(tripId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || _isDisposed) return;

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        final acceptedDriverId = data['driverId'] as String?;

        // Check for counter-offers directed at this driver
        final counterOffers = data['passengerCounterOffers'] as List<dynamic>? ?? [];
        for (final offer in counterOffers) {
          final offerMap = offer as Map<String, dynamic>;
          final offerDriverId = offerMap['driverId'] as String?;
          final offerTimestamp = offerMap['timestamp'] as String?;

          if (offerDriverId == _driverId && offerTimestamp != null) {
            final offerKey = '${tripId}_$offerTimestamp';
            if (!_processedCounterOffers.contains(offerKey)) {
              _processedCounterOffers.add(offerKey);
              final counterPrice = (offerMap['counterPrice'] as num?)?.toDouble() ?? 0.0;
              _showCounterOfferDialog(tripId, data, counterPrice);
            }
          }
        }

        // Check if offer was rejected (removed from driverOffers array)
        if (status == 'requested' && _driverId != null) {
          final driverOffers = data['driverOffers'] as List<dynamic>? ?? [];
          final myOfferStillExists = driverOffers.any((o) => (o as Map<String, dynamic>)['driverId'] == _driverId);
          if (!myOfferStillExists && _offeringOverlayText != null) {
            _myOfferSubscription?.cancel();
            _myOfferSubscription = null;
            _offerProgressTimer?.cancel();
            setState(() {
              _pendingOfferTripId = null;
              _offeringOverlayText = null;
              _offeringPrice = null;
              _offeringRequest = null;
              _offerProgressValue = 1.0;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('El pasajero rechazo tu oferta'), backgroundColor: Colors.orange),
              );
            }
            return;
          }
        }

        // If passenger accepted THIS driver's offer
        if (status == 'accepted' && acceptedDriverId == _driverId) {
          _myOfferSubscription?.cancel();
          _myOfferSubscription = null;
          _offerProgressTimer?.cancel();
          _pendingOfferTripId = null;
          _offeringOverlayText = null;
          _offeringPrice = null;
          _offeringRequest = null;
          _offerProgressValue = 1.0;

          SoundService().play(AppSound.rideAccepted);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tu oferta fue aceptada! Ve a recoger al pasajero'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 3),
            ),
          );

          // Navigate using active trip screen (Rapi Team)
          _doNavigateToActiveTrip(tripId, data);
        }
        // If ride was cancelled or expired
        else if (status == 'cancelled' || status == 'expired') {
          _myOfferSubscription?.cancel();
          _myOfferSubscription = null;
          _pendingOfferTripId = null;
        }
      }
    }, onError: (e) {
      print('Error in offer listener: $e');
    });
  }

  // GPS tracking
  Future<void> _startLocationTracking() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.warning('Location permissions denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.error('Location permissions permanently denied');
        return;
      }

      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!mounted || _isDisposed) return;

      setState(() {
        _currentLocation = LatLng(initialPosition.latitude, initialPosition.longitude);
        _updateMapMarkers();
      });

      _lastProgrammaticCameraMove = DateTime.now();
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 16),
        ),
      );

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) async {
        if (_isDisposed || !mounted) return;

        final newLocation = LatLng(position.latitude, position.longitude);

        // Calculate heading from position change
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
        if (position.speed > 0.5 && position.heading >= 0 && position.heading <= 360) {
          _currentHeading = position.heading;
        }

        // Snap to road (Rapi Team)
        final snappedLocation = await RoadSnappingService.instance.snapToRoad(newLocation);

        setState(() {
          _currentLocation = snappedLocation;
          _updateMapMarkers();
        });

        // Follow driver with bearing rotation
        if (_followDriverLocation && _mapController != null && !_isCameraAnimating) {
          _isCameraAnimating = true;
          _lastProgrammaticCameraMove = DateTime.now();
          try {
            await _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: snappedLocation, bearing: _currentHeading, zoom: 17, tilt: 50),
              ),
            );
          } catch (_) {
          } finally {
            _isCameraAnimating = false;
          }
        }

        if (_driverId != null && _isOnline) {
          await _updateLocationInFirebase(newLocation);
        }
      });
    } catch (e) {
      AppLogger.error('Error starting GPS tracking: $e');
    }
  }

  void _stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _locationUpdateTimer?.cancel();
    RoadSnappingService.instance.reset();
    _locationUpdateTimer = null;
  }

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
    } catch (e) {
      AppLogger.warning('Error updating location in Firebase: $e');
    }
  }

  // Real-time rides listener (Rapi Team)
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
                if (pickupData != null && pickupData['latitude'] != null && pickupData['longitude'] != null) {
                  final pickupLat = (pickupData['latitude'] as num).toDouble();
                  final pickupLng = (pickupData['longitude'] as num).toDouble();

                  final distanceInMeters = Geolocator.distanceBetween(
                    _currentLocation!.latitude, _currentLocation!.longitude,
                    pickupLat, pickupLng,
                  );

                  if (distanceInMeters <= 5000) {
                    final negotiation = PriceNegotiation(
                      id: doc.id,
                      passengerId: data['passengerId'] as String? ?? '',
                      selectedDriverId: null,
                      pickup: LocationPoint(
                        latitude: pickupLat,
                        longitude: pickupLng,
                        address: data['pickupAddress'] as String? ?? 'Direccion no disponible',
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
                      paymentMethod: data['paymentMethod'] == 'cash' ? PaymentMethod.cash : PaymentMethod.card,
                      notes: data['notes'] as String?,
                      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(minutes: 5)),
                    );

                    nearbyRides.add(negotiation);
                  }
                }
              }
            } catch (e) {
              AppLogger.error('Error processing ride ${doc.id}: $e');
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
              SoundService().play(AppSound.rideRequest);
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
          AppLogger.error('Error in rides listener: $error');
        },
      );
    } catch (e) {
      AppLogger.error('Error starting rides listener: $e');
    }
  }

  void _stopRidesListener() {
    _ridesStreamSubscription?.cancel();
    _ridesStreamSubscription = null;
  }

  void _loadRealRequests() {
    _loadRequestsFromFirebase();
  }

  Future<void> _loadRequestsFromFirebase() async {
    try {
      if (_driverId == null) return;

      // Load from 'negotiations' collection (Rapi Team InDrive-style)
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
          AppLogger.error('Error parsing request ${doc.id}: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        // Keep rides from the listener, only update negotiations
        final ridesFromListener = _availableRequests.where((r) => r.id.startsWith('rides/')).toList();
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
      AppLogger.error('Error loading requests: $e');
      if (!mounted) return;
      setState(() {
        _availableRequests = [];
        _updateMapMarkers();
      });
    }
  }

  void _updateMapMarkers() {
    _markers.clear();

    // Driver location marker
    if (_currentLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: _currentLocation!,
          icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          flat: true,
          anchor: const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(title: 'Tu ubicacion'),
        ),
      );
    }

    // Request markers
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

    // Show as modal bottom sheet (inDrive-style)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RequestDetailBottomSheet(
        request: request,
        onAccept: () {
          Navigator.pop(ctx);
          _acceptRequest(request);
        },
        onSkip: () {
          Navigator.pop(ctx);
        },
        onNegotiate: ({double? initialPrice}) {
          Navigator.pop(ctx);
          _showNegotiateDialog(request, initialPrice: initialPrice);
        },
        formatPrice: _formatPrice,
        getAvatarColor: _getAvatarColor,
      ),
    ).whenComplete(() {
      _countdownTimer?.cancel();
      setState(() {
        _showRequestDetails = false;
        _selectedRequest = null;
      });
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted && !_isDisposed && _showRequestDetails) {
        setState(() {});
      }
    });
  }

  /// Send driver's offer to passenger (inDrive flow)
  void _acceptRequest(PriceNegotiation request, {double? customPrice}) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Check credits before accepting (Rapi Team)
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final hasCredits = await walletProvider.hasEnoughCreditsForService();

      if (!hasCredits) {
        _showNeedCreditsDialog();
        return;
      }

      // Get passenger phone from Firestore
      String? passengerPhone;
      try {
        final passengerDoc = await _firestore.collection('users').doc(request.passengerId).get();
        if (passengerDoc.exists) {
          final passengerData = passengerDoc.data();
          passengerPhone = passengerData?['phone'] ?? passengerData?['phoneNumber'];
        }
      } catch (e) {
        AppLogger.warning('Could not get passenger phone: $e');
      }

      // Cancel active ride listener before transaction to avoid race condition
      _activeRideSubscription?.cancel();

      // Use transaction to prevent multiple drivers accepting (Rapi Team)
      final rideId = await _firestore.runTransaction<String?>((transaction) async {
        final negotiationRef = _firestore.collection('negotiations').doc(request.id);
        final snapshot = await transaction.get(negotiationRef);

        if (!snapshot.exists) {
          throw Exception('La solicitud ya no existe');
        }

        final data = snapshot.data()!;

        if (data['driverId'] != null && data['driverId'].toString().isNotEmpty) {
          throw Exception('Otro conductor ya acepto esta solicitud');
        }

        final status = data['status'] as String?;
        if (status != 'waiting' && status != 'negotiating') {
          throw Exception('La solicitud ya no esta disponible');
        }

        // Use exact pickup location (Rapi Team - revealed only after acceptance)
        final exactPickup = data['exactPickup'] as Map<String, dynamic>?;
        final pickupLat = exactPickup?['latitude'] ?? request.pickup.latitude;
        final pickupLng = exactPickup?['longitude'] ?? request.pickup.longitude;
        final pickupAddress = exactPickup?['address'] ?? request.pickup.address;

        final rideRef = _firestore.collection('rides').doc();

        transaction.set(rideRef, {
          'passengerId': request.passengerId,
          'userId': request.passengerId,
          'driverId': _driverId,
          'negotiationId': request.id,
          'pickupLocation': {
            'latitude': pickupLat,
            'longitude': pickupLng,
          },
          'destinationLocation': {
            'latitude': request.destination.latitude,
            'longitude': request.destination.longitude,
          },
          'pickupAddress': pickupAddress,
          'destinationAddress': request.destination.address,
          'estimatedFare': customPrice ?? request.offeredPrice,
          'finalFare': customPrice ?? request.offeredPrice,
          'estimatedDistance': request.distance,
          'status': 'accepted',
          'paymentMethod': request.paymentMethod.name,
          'requestedAt': FieldValue.serverTimestamp(),
          'acceptedAt': FieldValue.serverTimestamp(),
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
          'driverInfo': {
            'driverId': _driverId,
          },
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
        // Consume credits after successful acceptance (Rapi Team)
        final creditConsumed = await walletProvider.consumeCreditsForService(
          tripId: rideId,
          negotiationId: request.id,
        );

        if (creditConsumed) {
          AppLogger.info('Credits consumed for accepted service');
          await _checkDriverCredits();

          setState(() {
            _availableRequests.remove(request);
            _showRequestDetails = false;
          });

          await _loadTodayStats();

          if (mounted) {
            final rideDoc = await _firestore.collection('rides').doc(rideId).get();
            if (rideDoc.exists) {
              _doNavigateToActiveTrip(rideId, rideDoc.data()!);
            }
          }
        } else {
          // Rollback if credit consumption failed (Rapi Team)
          AppLogger.warning('Credit consumption failed, reverting ride');

          try {
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
          } catch (rollbackError) {
            AppLogger.error('CRITICAL: Rollback failed: $rollbackError');
          }

          messenger.showSnackBar(
            const SnackBar(content: Text('Error al procesar creditos. Intenta de nuevo.'), backgroundColor: ModernTheme.error),
          );
        }
      }
    } on FirebaseException catch (e) {
      AppLogger.error('Firebase error accepting request: ${e.code} - ${e.message}');
      if (!mounted) return;
      String errorMessage = e.code == 'permission-denied'
          ? 'Error de permisos. Contacta soporte.'
          : e.code == 'failed-precondition' || e.code == 'aborted'
              ? 'Otro conductor ya acepto esta solicitud'
              : 'Error: ${e.message ?? e.code}';
      messenger.showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: AppColors.error));
    } catch (e) {
      AppLogger.error('Error accepting request: $e');
      if (!mounted) return;
      String errorMessage = e.toString().contains('ya acepto')
          ? 'Otro conductor ya acepto esta solicitud'
          : e.toString().contains('no esta disponible')
              ? 'La solicitud ya no esta disponible'
              : 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      messenger.showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: AppColors.error));
    }
  }

  /// Show "Offering your fare" overlay and listen for response
  void _showOfferingOverlay(PriceNegotiation request, double price) {
    _offerProgressTimer?.cancel();
    setState(() {
      _offeringOverlayText = 'active';
      _offeringPrice = price;
      _offeringRequest = request;
      _offerProgressValue = 1.0;
    });
    const totalSeconds = 60;
    int elapsed = 0;
    _offerProgressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsed++;
      if (!mounted || _pendingOfferTripId != request.id) {
        timer.cancel();
        return;
      }
      if (elapsed >= totalSeconds) {
        timer.cancel();
        _removeMyOfferFromFirestore(request.id);
        _myOfferSubscription?.cancel();
        _myOfferSubscription = null;
        setState(() {
          _offeringOverlayText = null;
          _offeringPrice = null;
          _offeringRequest = null;
          _pendingOfferTripId = null;
          _offerProgressValue = 1.0;
        });
        return;
      }
      setState(() {
        _offerProgressValue = 1.0 - (elapsed / totalSeconds);
      });
    });
  }

  Future<void> _removeMyOfferFromFirestore(String tripId) async {
    if (_driverId == null) return;
    try {
      final rideDoc = await _firestore.collection('rides').doc(tripId).get();
      if (!rideDoc.exists) return;
      final offers = (rideDoc.data()?['driverOffers'] as List<dynamic>? ?? [])
          .where((o) => (o as Map<String, dynamic>)['driverId'] != _driverId)
          .toList();
      await _firestore.collection('rides').doc(tripId).update({'driverOffers': offers});
    } catch (e) {
      debugPrint('Error removing expired offer: $e');
    }
  }

  // Need credits dialog (Rapi Team)
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
            const Expanded(child: Text('Creditos insuficientes', style: TextStyle(fontSize: 18))),
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
              child: Row(children: [
                const Icon(Icons.info_outline, color: ModernTheme.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Tu saldo actual: S/. ${_serviceCredits.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Para aceptar servicios necesitas:', style: TextStyle(color: context.secondaryText)),
            const SizedBox(height: 8),
            _buildCreditRequirement('Minimo requerido', 'S/. ${_minServiceCredits.toStringAsFixed(2)}'),
            _buildCreditRequirement('Costo por servicio', 'S/. ${_serviceFee.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(children: [
                Icon(Icons.lightbulb_outline, color: ModernTheme.rappiOrange, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Recarga creditos para seguir aceptando viajes y ganando dinero', style: TextStyle(fontSize: 12))),
              ]),
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
            label: const Text('Recargar creditos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // Negotiate dialog
  void _showNegotiateDialog(PriceNegotiation request, {double? initialPrice}) {
    final priceController = TextEditingController(
      text: (initialPrice ?? request.offeredPrice).toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.getSurface(context),
          title: Text('Hacer contra-oferta', style: TextStyle(color: AppColors.getTextPrimary(context))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Precio del pasajero: S/ ${request.offeredPrice.toStringAsFixed(2)}',
                    style: TextStyle(color: AppColors.getTextSecondary(context))),
                SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.getTextPrimary(context)),
                  decoration: InputDecoration(
                    labelText: 'Tu oferta',
                    prefixText: 'S/ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.rappiOrange),
              onPressed: () {
                Navigator.pop(ctx);
                _submitCounterOffer(request, priceController.text);
              },
              child: Text('Enviar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitCounterOffer(PriceNegotiation request, String priceText) async {
    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Precio invalido'), backgroundColor: AppColors.error),
      );
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final vehicleInfo = authProvider.currentUser?.vehicleInfo;

      // Read existing offers and remove previous from this driver
      final rideDoc = await _firestore.collection('rides').doc(request.id).get();
      final existingOffers = (rideDoc.data()?['driverOffers'] as List<dynamic>? ?? [])
          .where((o) => (o as Map<String, dynamic>)['driverId'] != _driverId)
          .toList();

      existingOffers.add({
        'driverId': _driverId,
        'driverName': authProvider.currentUser?.fullName ?? 'Conductor',
        'driverPhoto': authProvider.currentUser?.profilePhotoUrl ?? '',
        'driverPhone': authProvider.currentUser?.phone ?? '',
        'driverRating': authProvider.currentUser?.rating ?? 5.0,
        'vehicleModel': vehicleInfo?['model'] ?? '',
        'vehiclePlate': vehicleInfo?['plate'] ?? '',
        'vehicleColor': vehicleInfo?['color'] ?? '',
        'vehicleBrand': vehicleInfo?['brand'] ?? '',
        'offeredPrice': price,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await _firestore.collection('rides').doc(request.id).update({
        'driverOffers': existingOffers,
        'status': 'negotiating',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Oferta enviada: S/ ${price.toStringAsFixed(2)} - Esperando respuesta...'),
          backgroundColor: AppColors.success,
        ),
      );

      _listenForOfferAcceptance(request.id);

      _countdownTimer?.cancel();
      setState(() {
        _showRequestDetails = false;
        _selectedRequest = null;
      });
      _slideController.reverse();
    } catch (e) {
      print('Error sending offer: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar oferta'), backgroundColor: AppColors.error),
      );
    }
  }

  // Counter-offer dialog
  void _showCounterOfferDialog(String tripId, Map<String, dynamic> tripData, double counterPrice) {
    if (!mounted) return;

    final passengerName = tripData['passengerName'] as String? ?? 'Pasajero';
    final originalPrice = (tripData['offeredPrice'] as num?)?.toDouble() ?? 0.0;
    final origin = tripData['originAddress'] as String? ?? 'Origen';
    final destination = tripData['destinationAddress'] as String? ?? 'Destino';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.local_offer, color: AppColors.rappiOrange, size: 28),
          SizedBox(width: 12),
          Expanded(child: Text('Nueva Contraoferta!', style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold))),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('De: $passengerName', style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.w600, fontSize: 16)),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.getBackground(context), borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.trip_origin, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text(origin, style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text(destination, style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ]),
              ),
              SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                Column(children: [
                  Text('Tu oferta', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12)),
                  Text('S/ ${originalPrice.toStringAsFixed(2)}', style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.lineThrough)),
                ]),
                Icon(Icons.arrow_forward, color: AppColors.rappiOrange),
                Column(children: [
                  Text('Contraoferta', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12)),
                  Text('S/ ${counterPrice.toStringAsFixed(2)}', style: TextStyle(color: AppColors.success, fontSize: 22, fontWeight: FontWeight.bold)),
                ]),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _rejectCounterOffer(tripId, counterPrice);
            },
            child: Text('Rechazar', style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _acceptCounterOffer(tripId, tripData, counterPrice);
            },
            child: Text('Aceptar S/ ${counterPrice.toStringAsFixed(2)}', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptCounterOffer(String tripId, Map<String, dynamic> tripData, double counterPrice) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userVehicleInfo = authProvider.currentUser?.vehicleInfo;

      await _firestore.collection('rides').doc(tripId).update({
        'status': 'accepted',
        'driverId': _driverId,
        'driverName': authProvider.currentUser?.fullName ?? 'Conductor',
        'driverPhone': authProvider.currentUser?.phone ?? '',
        'driverPhoto': authProvider.currentUser?.profilePhotoUrl ?? '',
        'finalPrice': counterPrice,
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedPrice': counterPrice,
        'vehicleInfo': {
          'driverName': authProvider.currentUser?.fullName ?? 'Conductor',
          'driverPhoto': authProvider.currentUser?.profilePhotoUrl ?? '',
          'driverPhone': authProvider.currentUser?.phone ?? '',
          'driverRating': authProvider.currentUser?.rating ?? 5.0,
          'model': userVehicleInfo?['model'] ?? '',
          'plate': userVehicleInfo?['plate'] ?? '',
          'color': userVehicleInfo?['color'] ?? '',
          'brand': userVehicleInfo?['make'] ?? userVehicleInfo?['brand'] ?? '',
        },
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Viaje aceptado por S/ ${counterPrice.toStringAsFixed(2)}!'), backgroundColor: AppColors.success),
      );

      // Navigate using Rapi Team active trip screen
      _doNavigateToActiveTrip(tripId, tripData);
    } catch (e) {
      print('Error accepting counter-offer: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aceptar contraoferta'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _rejectCounterOffer(String tripId, double counterPrice) async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contraoferta de S/ ${counterPrice.toStringAsFixed(2)} rechazada'), backgroundColor: ModernTheme.warning),
      );
    } catch (e) {
      print('Error rejecting counter-offer: $e');
    }
  }

  void _toggleOnline() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (!_isOnline && currentUser != null && currentUser.driverStatus != 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentUser.driverStatus == 'pending_approval'
              ? 'Tu cuenta esta pendiente de aprobacion.'
              : currentUser.driverStatus == 'rejected'
                  ? 'Tu solicitud fue rechazada. Contacta soporte.'
                  : 'Debes completar tu verificacion como conductor.'),
          backgroundColor: ModernTheme.warning,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isOnline = !_isOnline;
      if (_isOnline) {
        _startLocationTracking();
        _startRidesListener();
        _availableRequests = [];
        _updateMapMarkers();
        _loadRequestsFromFirebase();
        _startUIRefreshTimer();
        _checkDriverCredits();
      } else {
        _stopLocationTracking();
        _stopRidesListener();
        _requestsTimer?.cancel();
        _requestsTimer = null;
        _uiRefreshTimer?.cancel();
        _uiRefreshTimer = null;
        _availableRequests.clear();
        _markers.clear();
      }
    });
  }

  Widget _buildDriverDrawer(dynamic currentUser) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Profile header
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverProfileScreen()));
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.rappiOrange.withOpacity(0.2),
                      backgroundImage: currentUser?.profilePhotoUrl != null && currentUser!.profilePhotoUrl!.isNotEmpty
                          ? NetworkImage(currentUser.profilePhotoUrl!)
                          : null,
                      child: currentUser?.profilePhotoUrl == null || currentUser!.profilePhotoUrl!.isEmpty
                          ? Text(
                              (currentUser?.fullName ?? 'C')[0].toUpperCase(),
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.rappiOrange),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser?.fullName ?? 'Conductor',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
                          ),
                          Row(children: [
                            ...List.generate(5, (i) => Icon(Icons.star, size: 16, color: Colors.amber[700])),
                            const SizedBox(width: 6),
                            Text(
                              '${(currentUser?.rating ?? 5.0).toStringAsFixed(2)} (${currentUser?.totalTrips ?? 0})',
                              style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(Icons.directions_car, 'Ciudad', () => Navigator.pop(context)),
                  _buildDrawerItem(Icons.account_balance_wallet_outlined, 'Cartera', () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/driver/wallet');
                  }),
                  _buildDrawerItem(Icons.notifications_outlined, 'Notificaciones', () {
                    Navigator.pop(context);
                    // Navigate to notifications if route exists
                  }),
                  _buildDrawerItem(Icons.shield_outlined, 'Seguridad', () {
                    Navigator.pop(context);
                  }),
                  _buildDrawerItem(Icons.settings_outlined, 'Configuracion', () {
                    Navigator.pop(context);
                  }),
                  _buildDrawerItem(Icons.info_outline, 'Ayuda', () {
                    Navigator.pop(context);
                    launchUrl(Uri.parse('https://rapiteam.com/ayuda'), mode: LaunchMode.externalApplication);
                  }),
                ],
              ),
            ),

            // Mode switch button at bottom
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    authProvider.switchMode('passenger');
                    Navigator.pushReplacementNamed(context, '/passenger/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rappiOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Modo pasajero', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.getTextSecondary(context), size: 24),
      title: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final rideProvider = Provider.of<RideProvider>(context);
    final currentUser = authProvider.currentUser;
    final hasActiveTrip = rideProvider.hasActiveTrip;

    // Block unverified driver
    if (currentUser != null && currentUser.driverStatus != 'approved') {
      return _buildPendingVerificationScreen();
    }

    return PopScope(
      canPop: !hasActiveTrip,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && hasActiveTrip) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No puedes salir mientras tienes un viaje activo'), backgroundColor: Colors.orange),
          );
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildDriverDrawer(currentUser),
        body: SafeArea(
          child: _currentTabIndex == 1
            ? _buildPerformanceTab()
            : Stack(
            children: [
              Column(
                children: [
                  // TOP BAR: hamburger + status badge + settings
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _scaffoldKey.currentState?.openDrawer(),
                          child: Icon(Icons.menu, size: 28, color: AppColors.getTextPrimary(context)),
                        ),
                        const SizedBox(width: 16),
                        // Status badge
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _toggleOnline(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: _isOnline
                                      ? (hasActiveTrip ? AppColors.error : AppColors.rappiOrange)
                                      : AppColors.getBorder(context),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _isOnline
                                          ? (hasActiveTrip ? AppColors.error : AppColors.rappiOrange)
                                          : AppColors.getTextSecondary(context),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _isOnline ? (hasActiveTrip ? 'Ocupado' : 'Libre') : 'Fuera de linea',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Credits indicator
                        if (!_isCheckingCredits)
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/driver/wallet'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _hasEnoughCredits
                                    ? AppColors.rappiOrange.withOpacity(0.1)
                                    : ModernTheme.warning.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.account_balance_wallet, size: 16,
                                    color: _hasEnoughCredits ? AppColors.rappiOrange : ModernTheme.warning),
                                const SizedBox(width: 4),
                                Text(
                                  'S/. ${_serviceCredits.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _hasEnoughCredits ? AppColors.rappiOrange : ModernTheme.warning,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        const SizedBox(width: 8),
                        const ModeSwitchButton(compact: true),
                      ],
                    ),
                  ),

                  // Credit warning banner
                  if (!_isCheckingCredits && !_hasEnoughCredits)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: ModernTheme.warning.withOpacity(0.15),
                      child: InkWell(
                        onTap: () => Navigator.pushNamed(context, '/driver/recharge-credits').then((_) => _checkDriverCredits()),
                        child: Row(children: [
                          Icon(Icons.warning_amber, color: ModernTheme.warning, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Creditos insuficientes. Toca para recargar.',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: ModernTheme.warning, size: 22),
                        ]),
                      ),
                    )
                  // Info banner when online
                  else if (_isOnline)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: AppColors.rappiOrange.withOpacity(0.1),
                      child: Row(children: [
                        Icon(Icons.info_outline, color: Colors.black87, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Resuelve estos problemas para evitar perder las mejores solicitudes',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.black54, size: 22),
                      ]),
                    ),

                  // Document verification banner
                  Consumer<DocumentProvider>(
                    builder: (context, docProvider, _) {
                      final status = docProvider.verificationStatus;
                      if (status == null || status.isEmpty) return const SizedBox.shrink();
                      final isVerified = status['isVerified'] == true;
                      final verificationStatus = status['verificationStatus']?.toString() ?? 'pending';
                      if (isVerified || verificationStatus == 'approved') return const SizedBox.shrink();
                      Color bannerColor;
                      String title;
                      IconData icon;
                      switch (verificationStatus) {
                        case 'under_review':
                          bannerColor = ModernTheme.info;
                          title = 'Documentos en revision';
                          icon = Icons.hourglass_empty;
                          break;
                        case 'rejected':
                          bannerColor = ModernTheme.error;
                          title = 'Documentos rechazados';
                          icon = Icons.error_outline;
                          break;
                        default:
                          bannerColor = ModernTheme.warning;
                          title = 'Documentos pendientes';
                          icon = Icons.description_outlined;
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: bannerColor.withOpacity(0.12),
                        child: InkWell(
                          onTap: () => Navigator.pushNamed(context, '/driver/documents'),
                          child: Row(children: [
                            Icon(icon, color: bannerColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Icon(Icons.chevron_right, color: bannerColor),
                          ]),
                        ),
                      );
                    },
                  ),

                  // Content area
                  Expanded(
                    child: _isOnline && _availableRequests.isNotEmpty
                      ? Stack(children: [
                          ListView.separated(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: _availableRequests.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.getBorder(context)),
                            itemBuilder: (context, index) {
                              return _buildRequestCard(_availableRequests[index]);
                            },
                          ),
                        ])
                      : _isOnline
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search, size: 64, color: AppColors.getTextSecondary(context).withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text('Buscando solicitudes...', style: TextStyle(fontSize: 18, color: AppColors.getTextSecondary(context))),
                                const SizedBox(height: 8),
                                Text('Las solicitudes de viaje apareceran aqui', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context).withOpacity(0.6))),
                              ],
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.power_settings_new, size: 80, color: AppColors.getTextSecondary(context).withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text('Estas fuera de linea', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                                const SizedBox(height: 8),
                                Text('Activa tu estado para recibir solicitudes', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () => _toggleOnline(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  ),
                                  child: Text('Conectarse', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
              // Offering overlay (blur + text)
              if (_offeringOverlayText != null) ...[
                Positioned.fill(
                  bottom: _offeringRequest != null ? 280 : 0,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Container(color: AppColors.getSurface(context).withOpacity(0.55)),
                    ),
                  ),
                ),
                Positioned(
                  left: 16, right: 16, top: 0,
                  bottom: _offeringRequest != null ? 320 : 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Text(
                        'Ofreciendo tu tarifa\nS/ ${_offeringPrice?.toStringAsFixed(2) ?? '0.00'}.\nEspera la respuesta del pasajero',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context), height: 1.3),
                      ),
                    ),
                  ),
                ),
                if (_offeringRequest != null)
                  Positioned(left: 10, right: 10, bottom: 8, child: _buildOfferingBottomCard()),
              ],
            ],
          ),
        ),
        bottomNavigationBar: _offeringOverlayText != null ? null : Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.getBorder(context), width: 0.5))),
          child: BottomNavigationBar(
            currentIndex: _currentTabIndex,
            onTap: (index) => setState(() { _currentTabIndex = index; }),
            selectedItemColor: AppColors.getTextPrimary(context),
            unselectedItemColor: AppColors.getTextSecondary(context),
            backgroundColor: AppColors.getSurface(context),
            elevation: 0,
            items: [
              BottomNavigationBarItem(icon: const Icon(Icons.list_alt), label: 'Solicitudes de viaje'),
              BottomNavigationBarItem(icon: const Icon(Icons.grid_view_rounded), label: 'Desempeno'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfferingBottomCard() {
    final req = _offeringRequest!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundImage: req.passengerPhoto.isNotEmpty ? NetworkImage(req.passengerPhoto) : null,
                    backgroundColor: Colors.orange,
                    child: req.passengerPhoto.isEmpty
                        ? Text(req.passengerName.isNotEmpty ? req.passengerName[0].toUpperCase() : 'P',
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 80,
                    child: Text(
                      req.passengerName.isNotEmpty ? req.passengerName.split(' ').first : 'Pasajero',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
                      textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(req.passengerRating.toStringAsFixed(2), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextSecondary(context))),
                    const SizedBox(width: 2),
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                  ]),
                  Text('(${0})', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context))),
                  const SizedBox(height: 3),
                  Text('${DateTime.now().difference(req.createdAt).inSeconds} seg.',
                      style: const TextStyle(fontSize: 12, color: AppColors.rappiOrange, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('~${(req.distance / 1000).toStringAsFixed(1)}km', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
                      Text('S/ ${_offeringPrice?.toStringAsFixed(2) ?? '0.00'}',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context), height: 1.2)),
                      const SizedBox(height: 10),
                      // Origin A
                      Row(children: [
                        Container(width: 22, height: 22, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                            child: const Center(child: Text('A', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(req.pickup.address, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.getTextPrimary(context)), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 8),
                      // Destination B
                      Row(children: [
                        Container(width: 22, height: 22, decoration: const BoxDecoration(color: Color(0xFFE91E63), shape: BoxShape.circle),
                            child: const Center(child: Text('B', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(req.destination.address, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.getTextPrimary(context)), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 10),
                      // Payment badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: req.paymentMethod == PaymentMethod.cash ? const Color(0xFF7B1FA2)
                              : req.paymentMethod == PaymentMethod.cash ? const Color(0xFF00C853)
                              : const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          req.paymentMethod == PaymentMethod.cash ? 'Yape'
                              : req.paymentMethod == PaymentMethod.cash ? 'Plin'
                              : req.paymentMethod == PaymentMethod.card ? 'Tarjeta' : 'Efectivo',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Progress bar
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: LinearProgressIndicator(
              value: _offerProgressValue,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _offerProgressValue > 0.5 ? const Color(0xFF4CAF50)
                    : _offerProgressValue > 0.25 ? const Color(0xFFFFC107) : const Color(0xFFF44336),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab() {
    // Simple performance view since Rapi Team doesn't have DriverPerformanceScreen
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 64, color: AppColors.rappiOrange.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('Desempeno', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _buildStatistic('Ganancias', 'S/ ${_todayEarnings.toStringAsFixed(2)}', Icons.monetization_on),
              _buildStatistic('Viajes', '$_todayTrips', Icons.directions_car),
              _buildStatistic('Aceptacion', '${_acceptanceRate.toStringAsFixed(0)}%', Icons.thumb_up),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingVerificationScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verificacion Pendiente'),
        actions: [ModeSwitchButton(compact: true)],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top_rounded, size: 80, color: Colors.orange),
              SizedBox(height: 24),
              Text('Verificacion en Proceso', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              SizedBox(height: 16),
              Text(
                'Tu cuenta de conductor esta siendo revisada por nuestro equipo. Una vez aprobada, podras comenzar a recibir viajes.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(children: [
                    Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 20), SizedBox(width: 8), Text('Documentos enviados')]),
                    SizedBox(height: 8),
                    Row(children: [Icon(Icons.pending, color: Colors.orange, size: 20), SizedBox(width: 8), Text('Revision en proceso')]),
                    SizedBox(height: 8),
                    Row(children: [Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 20), SizedBox(width: 8), Text('Aprobacion pendiente')]),
                  ]),
                ),
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/driver/documents'),
                icon: Icon(Icons.folder_open),
                label: Text('Ver mis documentos'),
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
              ),
              SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  await authProvider.reloadUserData();
                  if (mounted) setState(() {});
                },
                icon: Icon(Icons.refresh),
                label: Text('Verificar estado'),
                style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatistic(String label, String value, IconData icon) {
    return Column(children: [
      Icon(icon, color: AppColors.rappiOrange, size: 24),
      SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
      Text(label, style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context))),
    ]);
  }

  String _formatPrice(double price) {
    if (price == price.roundToDouble()) return 'S/ ${price.toInt()}';
    return 'S/ ${price.toStringAsFixed(2)}';
  }

  Widget _buildRequestCard(PriceNegotiation request) {
    final isFairPrice = request.offeredPrice >= request.suggestedPrice;
    final initial = request.passengerName.isNotEmpty ? request.passengerName[0].toUpperCase() : 'P';

    final ageMinutes = DateTime.now().difference(request.createdAt).inMinutes;
    final timeLabel = ageMinutes < 1 ? 'Ahora\nmismo' : '$ageMinutes min.';

    String paymentLabel;
    Color paymentColor;
    switch (request.paymentMethod) {
      case PaymentMethod.cash:
        paymentLabel = 'Yape'; paymentColor = const Color(0xFF6B21A8);
      case PaymentMethod.cash:
        paymentLabel = 'Plin'; paymentColor = const Color(0xFF00BFA5);
      case PaymentMethod.card:
        paymentLabel = 'Tarjeta'; paymentColor = const Color(0xFF1565C0);
      case PaymentMethod.wallet:
        paymentLabel = 'Billetera'; paymentColor = AppColors.rappiOrange;
      default:
        paymentLabel = 'Efectivo'; paymentColor = const Color(0xFF4CAF50);
    }

    return _SwipeableRequestCard(
      request: request,
      isFairPrice: isFairPrice,
      initial: initial,
      timeLabel: timeLabel,
      paymentLabel: paymentLabel,
      paymentColor: paymentColor,
      onTap: () => _selectRequest(request),
      onHide: () {
        setState(() { _availableRequests.removeWhere((r) => r.id == request.id); });
      },
      onReport: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Queja enviada')));
      },
      onSelectOnMap: () => _selectRequest(request),
      formatPrice: _formatPrice,
    );
  }

  Color _getAvatarColor(String initial) {
    final colors = [
      const Color(0xFFE8A0BF), const Color(0xFFB5D8CC), const Color(0xFFF4C2C2),
      const Color(0xFFC3B1E1), const Color(0xFFFFD700), const Color(0xFF87CEEB),
    ];
    return colors[initial.codeUnitAt(0) % colors.length];
  }

  Future<void> _loadTodayStats() async {
    try {
      if (_driverId == null) return;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

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

      final negotiationsQuery = await _firestore
          .collection('negotiations')
          .where('driverId', isEqualTo: _driverId)
          .where('requestedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('requestedAt', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(100)
          .get();

      int acceptedCount = 0;
      int totalOffered = negotiationsQuery.docs.length;
      for (var doc in negotiationsQuery.docs) {
        if ((doc.data()['status'] as String?) == 'accepted') acceptedCount++;
      }

      double acceptanceRate = totalOffered > 0 ? (acceptedCount / totalOffered) * 100 : 0.0;

      if (!mounted || _isDisposed) return;

      setState(() {
        _todayEarnings = totalEarnings;
        _todayTrips = tripCount;
        _acceptanceRate = acceptanceRate;
      });
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _todayEarnings = 0.0;
          _todayTrips = 0;
          _acceptanceRate = 0.0;
        });
      }
    }
  }
}

/// Swipeable request card: swipe right = hide, swipe left = reveal action buttons
class _SwipeableRequestCard extends StatefulWidget {
  final PriceNegotiation request;
  final bool isFairPrice;
  final String initial;
  final String timeLabel;
  final String paymentLabel;
  final Color paymentColor;
  final VoidCallback onTap;
  final VoidCallback onHide;
  final VoidCallback onReport;
  final VoidCallback onSelectOnMap;
  final String Function(double) formatPrice;

  const _SwipeableRequestCard({
    required this.request,
    required this.isFairPrice,
    required this.initial,
    required this.timeLabel,
    required this.paymentLabel,
    required this.paymentColor,
    required this.onTap,
    required this.onHide,
    required this.onReport,
    required this.onSelectOnMap,
    required this.formatPrice,
  });

  @override
  State<_SwipeableRequestCard> createState() => _SwipeableRequestCardState();
}

class _SwipeableRequestCardState extends State<_SwipeableRequestCard> {
  double _dragOffset = 0;
  bool _actionsRevealed = false;

  double get _actionWidth => MediaQuery.of(context).size.width;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.primaryDelta!;
      _dragOffset = _dragOffset.clamp(-_actionWidth, 300.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset > 100) {
      widget.onHide();
    } else if (_dragOffset < -80) {
      setState(() {
        _dragOffset = -_actionWidth;
        _actionsRevealed = true;
      });
    } else {
      setState(() {
        _dragOffset = 0;
        _actionsRevealed = false;
      });
    }
  }

  void _closeActions() {
    setState(() {
      _dragOffset = 0;
      _actionsRevealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Right swipe background
        Positioned.fill(
          child: Row(children: [
            Expanded(
              child: Container(
                color: AppColors.error,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 30),
                child: Text('Ocultar', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ]),
        ),
        // Left swipe action buttons
        Positioned(
          top: 0, bottom: 0, right: 0, width: _actionWidth,
          child: Row(children: [
            _ActionButton(icon: Icons.warning_amber, label: 'Queja', color: const Color(0xFFFF9800), onTap: () { _closeActions(); widget.onReport(); }),
            _ActionButton(icon: Icons.visibility_off, label: 'Ocultar', color: AppColors.error, onTap: () { _closeActions(); widget.onHide(); }),
            _ActionButton(icon: Icons.location_on, label: 'Seleccionar en\nel mapa', color: const Color(0xFF2196F3), onTap: () { _closeActions(); widget.onSelectOnMap(); }),
          ]),
        ),
        // Foreground card
        GestureDetector(
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: AnimatedContainer(
            duration: _dragOffset == 0 || _dragOffset == -_actionWidth ? const Duration(milliseconds: 200) : Duration.zero,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: Material(
              color: AppColors.getSurface(context),
              child: InkWell(
                onTap: _actionsRevealed ? _closeActions : widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Avatar + name + rating + time
                      SizedBox(
                        width: 80,
                        child: Column(children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: _getAvatarColor(widget.initial),
                            backgroundImage: widget.request.passengerPhoto.isNotEmpty ? NetworkImage(widget.request.passengerPhoto) : null,
                            child: widget.request.passengerPhoto.isEmpty
                                ? Text(widget.initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22))
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(widget.request.passengerName.split(' ').first,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(context)),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(widget.request.passengerRating.toStringAsFixed(2),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                          ]),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.star, size: 14, color: Colors.amber[700]),
                            const SizedBox(width: 2),
                            Text('(0)', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(context))),
                          ]),
                          const SizedBox(height: 4),
                          Text(widget.timeLabel, style: TextStyle(fontSize: 11, color: AppColors.rappiOrange, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                        ]),
                      ),
                      const SizedBox(width: 8),

                      // Right: distance, price, addresses, payment
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('~${widget.request.distance.toStringAsFixed(1)}km', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
                            Row(children: [
                              Text(widget.formatPrice(widget.request.offeredPrice),
                                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context), height: 1.2)),
                              if (widget.isFairPrice) ...[
                                const SizedBox(width: 8),
                                Text('Precio justo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.rappiOrange)),
                              ],
                            ]),
                            const SizedBox(height: 6),
                            Text(widget.request.pickup.address, style: TextStyle(fontSize: 14, color: AppColors.getTextPrimary(context)), maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text(widget.request.destination.address, style: TextStyle(fontSize: 14, color: AppColors.getTextPrimary(context)), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(color: widget.paymentColor, borderRadius: BorderRadius.circular(6)),
                              child: Text(widget.paymentLabel, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),

                      // Three dots menu
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: AppColors.getTextSecondary(context), size: 22),
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          if (value == 'hide') {
                            widget.onHide();
                          } else if (value == 'report') {
                            widget.onReport();
                          } else if (value == 'map') {
                            widget.onSelectOnMap();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'report', child: Row(children: [const Icon(Icons.warning_amber, color: AppColors.rappiOrange, size: 20), const SizedBox(width: 8), Text('Queja')])),
                          PopupMenuItem(value: 'hide', child: Row(children: [const Icon(Icons.visibility_off, color: AppColors.rappiOrange, size: 20), const SizedBox(width: 8), Text('Ocultar')])),
                          PopupMenuItem(value: 'map', child: Row(children: [const Icon(Icons.location_on, color: AppColors.rappiOrange, size: 20), const SizedBox(width: 8), Text('Seleccionar en el mapa')])),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getAvatarColor(String initial) {
    final colors = [
      const Color(0xFFE91E63), const Color(0xFF9C27B0), const Color(0xFF673AB7),
      const Color(0xFF3F51B5), const Color(0xFF2196F3), const Color(0xFF00BCD4),
      const Color(0xFF009688), const Color(0xFF4CAF50), const Color(0xFFFF9800),
    ];
    return colors[initial.codeUnitAt(0) % colors.length];
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: color,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for ride request detail (inDrive-style)
class _RequestDetailBottomSheet extends StatefulWidget {
  final PriceNegotiation request;
  final VoidCallback onAccept;
  final VoidCallback onSkip;
  final void Function({double? initialPrice}) onNegotiate;
  final String Function(double) formatPrice;
  final Color Function(String) getAvatarColor;

  const _RequestDetailBottomSheet({
    required this.request,
    required this.onAccept,
    required this.onSkip,
    required this.onNegotiate,
    required this.formatPrice,
    required this.getAvatarColor,
  });

  @override
  State<_RequestDetailBottomSheet> createState() => _RequestDetailBottomSheetState();
}

class _RequestDetailBottomSheetState extends State<_RequestDetailBottomSheet> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final isFairPrice = request.offeredPrice >= request.suggestedPrice;
    final initial = request.passengerName.isNotEmpty ? request.passengerName[0].toUpperCase() : 'P';
    final ageMinutes = DateTime.now().difference(request.createdAt).inMinutes;
    final timeLabel = ageMinutes < 1 ? 'Ahora' : '$ageMinutes min.';
    final price1 = request.offeredPrice + 2.0;
    final price2 = request.offeredPrice + 3.0;

    String paymentLabel;
    Color paymentColor;
    switch (request.paymentMethod) {
      case PaymentMethod.cash:
        paymentLabel = 'Yape'; paymentColor = const Color(0xFF6B21A8);
      case PaymentMethod.cash:
        paymentLabel = 'Plin'; paymentColor = const Color(0xFF00BFA5);
      case PaymentMethod.card:
        paymentLabel = 'Tarjeta'; paymentColor = const Color(0xFF1565C0);
      case PaymentMethod.wallet:
        paymentLabel = 'Billetera'; paymentColor = AppColors.rappiOrange;
      default:
        paymentLabel = 'Efectivo'; paymentColor = const Color(0xFF4CAF50);
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Center(child: Text('Solicitud de viaje',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(context)))),
            ),

            // Map with route
            SizedBox(
              height: 200,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    (request.pickup.latitude + request.destination.latitude) / 2,
                    (request.pickup.longitude + request.destination.longitude) / 2,
                  ),
                  zoom: 11.5,
                ),
                markers: {
                  Marker(markerId: const MarkerId('pickup'), position: LatLng(request.pickup.latitude, request.pickup.longitude),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
                  Marker(markerId: const MarkerId('destination'), position: LatLng(request.destination.latitude, request.destination.longitude),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
                },
                polylines: {
                  Polyline(polylineId: const PolylineId('route'), points: [
                    LatLng(request.pickup.latitude, request.pickup.longitude),
                    LatLng(request.destination.latitude, request.destination.longitude),
                  ], color: const Color(0xFF4CAF50), width: 4),
                },
                zoomControlsEnabled: false, scrollGesturesEnabled: false, rotateGesturesEnabled: false,
                tiltGesturesEnabled: false, myLocationButtonEnabled: false, mapToolbarEnabled: false,
              ),
            ),

            // Passenger info row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Column(children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: widget.getAvatarColor(initial),
                        backgroundImage: request.passengerPhoto.isNotEmpty ? NetworkImage(request.passengerPhoto) : null,
                        child: request.passengerPhoto.isEmpty
                            ? Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)) : null,
                      ),
                      const SizedBox(height: 4),
                      Text(request.passengerName.split(' ').first,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(context)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.star, size: 14, color: Colors.amber[700]),
                        const SizedBox(width: 2),
                        Text(request.passengerRating.toStringAsFixed(1),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                      ]),
                      Text(timeLabel, style: TextStyle(fontSize: 11, color: AppColors.rappiOrange, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('~${request.distance.toStringAsFixed(1)}km', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
                        Row(children: [
                          Text(widget.formatPrice(request.offeredPrice),
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context), height: 1.2)),
                          if (isFairPrice) ...[
                            const SizedBox(width: 8),
                            Text('Precio justo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.rappiOrange)),
                          ],
                        ]),
                        const SizedBox(height: 6),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(width: 22, height: 22, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                              child: const Center(child: Text('A', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
                          const SizedBox(width: 8),
                          Expanded(child: Text(request.pickup.address,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.getTextPrimary(context)), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        ]),
                        const SizedBox(height: 6),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(width: 22, height: 22, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                              child: const Center(child: Text('B', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
                          const SizedBox(width: 8),
                          Expanded(child: Text(request.destination.address,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.getTextPrimary(context)), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        ]),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(color: paymentColor, borderRadius: BorderRadius.circular(6)),
                          child: Text(paymentLabel, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Timer progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: request.timeRemaining.inSeconds > 0 ? (request.timeRemaining.inSeconds / 150).clamp(0.0, 1.0) : 0.0,
                  backgroundColor: AppColors.getInputFill(context),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC8E636)),
                  minHeight: 6,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Accept button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC8E636),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Aceptar por ${widget.formatPrice(request.offeredPrice)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Offer your fare
            Center(child: Text('Ofrece tu tarifa', style: TextStyle(fontSize: 15, color: AppColors.getTextSecondary(context)))),
            const SizedBox(height: 10),

            // Price pills + pencil
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: SizedBox(height: 50, child: OutlinedButton(
                  onPressed: () => widget.onNegotiate(initialPrice: price1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.getTextPrimary(context),
                    side: BorderSide(color: AppColors.getBorder(context)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(widget.formatPrice(price1), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))))),
                const SizedBox(width: 10),
                Expanded(child: SizedBox(height: 50, child: OutlinedButton(
                  onPressed: () => widget.onNegotiate(initialPrice: price2),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.getTextPrimary(context),
                    side: BorderSide(color: AppColors.getBorder(context)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(widget.formatPrice(price2), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))))),
                const SizedBox(width: 10),
                SizedBox(height: 50, width: 60, child: OutlinedButton(
                  onPressed: () => widget.onNegotiate(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.getTextPrimary(context),
                    side: BorderSide(color: AppColors.getBorder(context)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.zero),
                  child: Icon(Icons.edit, size: 22, color: AppColors.getTextSecondary(context)))),
              ]),
            ),

            const SizedBox(height: 12),

            // Skip button
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onSkip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getInputFill(context),
                    foregroundColor: AppColors.getTextPrimary(context),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text('Omitir', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
