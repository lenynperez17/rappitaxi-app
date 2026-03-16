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
import '../../core/constants/app_colors.dart';

// Models
import '../../models/trip_model.dart';

// Providers
import '../../providers/auth_provider.dart';

// Services
import '../../services/firebase_service.dart';
import '../../services/sound_service.dart';

// Utils
import '../../utils/logger.dart';
import '../../utils/map_marker_utils.dart';

// Screens
import 'chat_screen.dart';
import 'rating_dialog.dart';

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

  // Flag to prevent operations after dispose
  bool _isDisposed = false;

  // Animations - Plus App style
  late AnimationController _bottomSheetController;
  late AnimationController _pulseController;
  late AnimationController _etaController;

  TripModel? _currentRide;
  Position? _currentPosition;
  Position? _driverPosition;
  LatLng? _driverLatLng;
  double _driverHeading = 0.0;
  LatLng? _lastUpdatedDriverLatLng;
  bool _isFollowingDriver = true;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];

  // Custom marker icons
  BitmapDescriptor? _originIcon;
  BitmapDescriptor? _destinationIcon;
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _currentLocationIcon;

  String _estimatedArrival = 'Calculando...';
  int _minutesRemaining = 0;
  double _distanceToDestination = 0.0;
  double _distanceToPickup = 0.0;
  String _currentStatus = 'Buscando conductor...';
  bool _isMapLoaded = false;
  bool _isCompleting = false;

  // Verification state
  bool _isVerifyingCode = false;
  final TextEditingController _verificationCodeController =
      TextEditingController();

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

  void _initializeAnimations() {
    _bottomSheetController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _etaController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
  }

  /// Load custom marker icons
  Future<void> _loadCustomIcons() async {
    _originIcon = await MapMarkerUtils.getOriginIcon();
    _destinationIcon = await MapMarkerUtils.getDestinationIcon();
    _driverIcon = await MapMarkerUtils.getCarTopViewIcon();
    _currentLocationIcon = await MapMarkerUtils.getCurrentLocationIcon();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _isDisposed = true;

    _rideUpdatesSubscription?.cancel();
    _rideUpdatesSubscription = null;
    _driverLocationTimer?.cancel();
    _driverLocationTimer = null;
    _etaTimer?.cancel();
    _etaTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;

    _verificationCodeController.dispose();
    _bottomSheetController.dispose();
    _pulseController.dispose();
    _etaController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DATA LOADING & FIRESTORE LISTENERS (unchanged business logic)
  // ---------------------------------------------------------------------------

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
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _listenToRideUpdates() {
    _rideUpdatesSubscription?.cancel();
    _rideUpdatesSubscription =
        FirebaseService().listenToRideUpdates(widget.rideId, (ride) {
      if (mounted) {
        // Navigate to completed screen
        if (ride.status == 'completed' && _currentRide?.status != 'completed') {
          if (!_isCompleting) {
            _showRatingDialog();
          }
          return;
        }

        // Show cancelled state
        if (ride.status == 'cancelled' && _currentRide?.status != 'cancelled') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El viaje ha sido cancelado'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Show driver arrived notification
        if ((ride.status == 'driver_arriving' || ride.status == 'arrived') &&
            _currentRide?.status != ride.status) {
          _showArrivedNotification();
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

  bool _isPrePickupStatus() {
    final s = _currentRide?.status;
    return s == 'accepted' ||
        s == 'driver_arriving' ||
        s == 'arrived' ||
        s == 'waiting_verification';
  }

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
        _currentStatus = 'Conductor en camino';
      case 'driver_arriving':
        _currentStatus = 'El conductor ha llegado';
      case 'waiting_verification':
        _currentStatus = 'Verificacion en proceso';
      case 'in_progress':
        _currentStatus = 'En camino al destino';
      case 'arriving_destination':
        _currentStatus = 'Llegando al destino';
      case 'completed':
        _currentStatus = 'Viaje completado';
      case 'cancelled':
        _currentStatus = 'Viaje cancelado';
      case 'arrived':
        _currentStatus = 'El conductor ha llegado';
    }
  }

  // ---------------------------------------------------------------------------
  // LOCATION TRACKING (unchanged)
  // ---------------------------------------------------------------------------

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
      AppLogger.error('Error al obtener ubicacion', e, stackTrace);
    }
  }

  void _startDriverLocationUpdates() {
    _driverLocationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) {
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
        final driverLocation =
            LatLng(locationData['lat']!, locationData['lng']!);
        _driverHeading = locationData['heading'] ?? 0.0;
        _updateDriverPosition(driverLocation);
      }
    } catch (e, stackTrace) {
      AppLogger.error(
          'Error al actualizar ubicacion del conductor', e, stackTrace);
    }
  }

  void _updateDriverPosition(LatLng position) {
    // Throttle: only update if position changed more than 10 meters
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

    setState(() {
      _driverLatLng = position;
      _markers.removeWhere((m) => m.markerId.value == 'driver');
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: position,
        infoWindow: InfoWindow(
          title: 'Conductor',
          snippet:
              _currentRide?.vehicleInfo?['driverName'] ?? 'Conductor asignado',
        ),
        icon: _driverIcon ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        rotation: _driverHeading,
      ));
    });

    // Camera follows driver
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

  // ---------------------------------------------------------------------------
  // DISTANCE & ETA CALCULATIONS (unchanged)
  // ---------------------------------------------------------------------------

  void _calculateDistances() {
    if (_currentPosition == null) return;

    if (_currentRide != null) {
      _distanceToDestination = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            _currentRide!.destinationLocation.latitude,
            _currentRide!.destinationLocation.longitude,
          ) /
          1000;

      if (_isPrePickupStatus()) {
        _distanceToPickup = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              _currentRide!.pickupLocation.latitude,
              _currentRide!.pickupLocation.longitude,
            ) /
            1000;
      }

      // Update minutes remaining for the header badge
      final relevantDistance =
          _isInTransitStatus() ? _distanceToDestination : _distanceToPickup;
      _minutesRemaining = (relevantDistance / 0.5).ceil(); // ~30km/h average
    }
  }

  Future<void> _calculateETA() async {
    if (_driverLatLng == null || _currentRide == null) return;

    try {
      double distance;

      if (_isPrePickupStatus()) {
        distance = Geolocator.distanceBetween(
              _driverLatLng!.latitude,
              _driverLatLng!.longitude,
              _currentRide!.pickupLocation.latitude,
              _currentRide!.pickupLocation.longitude,
            ) /
            1000;
      } else {
        distance = _distanceToDestination;
      }

      const averageSpeed = 30.0;
      final etaMinutes = (distance / averageSpeed * 60).round();

      if (mounted) {
        setState(() {
          _estimatedArrival =
              etaMinutes > 0 ? '$etaMinutes min' : 'Muy pronto';
          _minutesRemaining = etaMinutes > 0 ? etaMinutes : 1;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error al calcular ETA', e, stackTrace);
    }
  }

  // ---------------------------------------------------------------------------
  // MAP MARKERS & ROUTE (unchanged)
  // ---------------------------------------------------------------------------

  void _setupMapMarkers() {
    if (_currentRide == null) return;

    _markers.clear();

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

    if (_driverLatLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driverLatLng!,
        infoWindow: InfoWindow(
          title: 'Conductor',
          snippet: _currentRide!.vehicleInfo?['driverName'] ??
              'Conductor asignado',
        ),
        icon: _driverIcon ?? BitmapDescriptor.defaultMarker,
      ));
    }

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
      List<LatLng> points = await _getRoutePoints(origin, destination);

      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: AppColors.rappiOrange,
        width: 5,
      ));

      setState(() {
        _routePoints = points;
      });
    }
  }

  Future<List<LatLng>> _getRoutePoints(
      LatLng origin, LatLng destination) async {
    try {
      final polylinePoints =
          PolylinePoints(apiKey: AppConfig.googleMapsApiKey);
      final result = await polylinePoints.getRouteBetweenCoordinatesV2(
        request: RoutesApiRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination:
              PointLatLng(destination.latitude, destination.longitude),
          travelMode: TravelMode.driving,
        ),
      );
      if (result.primaryRoute?.polylinePoints
          case List<PointLatLng> points) {
        return points.map((p) => LatLng(p.latitude, p.longitude)).toList();
      }
    } catch (e) {
      debugPrint('Error getting route: $e');
    }
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

  Future<void> _fitMapToPickupAndDestination() async {
    if (_mapController == null || _currentRide == null) return;

    try {
      final bounds = LatLngBounds(
        southwest: LatLng(
          math.min(_currentRide!.pickupLocation.latitude,
              _currentRide!.destinationLocation.latitude),
          math.min(_currentRide!.pickupLocation.longitude,
              _currentRide!.destinationLocation.longitude),
        ),
        northeast: LatLng(
          math.max(_currentRide!.pickupLocation.latitude,
              _currentRide!.destinationLocation.latitude),
          math.max(_currentRide!.pickupLocation.longitude,
              _currentRide!.destinationLocation.longitude),
        ),
      );

      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      AppLogger.error('Error centrando mapa', e);
    }
  }

  // ---------------------------------------------------------------------------
  // ACTIONS (unchanged business logic)
  // ---------------------------------------------------------------------------

  Future<void> _callDriver() async {
    String? driverPhone = _currentRide?.vehicleInfo?['driverPhone'];

    if ((driverPhone == null || driverPhone.isEmpty) &&
        _currentRide?.driverId != null) {
      try {
        final driverData =
            await FirebaseService().getUserById(_currentRide!.driverId!);
        if (driverData != null) {
          driverPhone = driverData['phone'] as String?;
        }
      } catch (e) {
        AppLogger.error('Error obteniendo telefono del conductor', e);
      }
    }

    if (driverPhone == null || driverPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Telefono no disponible'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: driverPhone);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se puede realizar la llamada'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error calling driver: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se puede realizar la llamada'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
            otherUserName:
                _currentRide!.vehicleInfo?['driverName'] ?? 'Conductor',
            otherUserRole: 'driver',
            otherUserId: _currentRide!.driverId,
          ),
        ),
      );
    }
  }

  void _showArrivedNotification() {
    SoundService().play(AppSound.driverArrived);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.directions_car_rounded, color: AppColors.white),
            SizedBox(width: 12),
            Text('Tu conductor ha llegado'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        action: SnackBarAction(
          label: 'OK',
          textColor: AppColors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showEmergencyOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Opciones de emergencia',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.call, color: AppColors.error),
              title: const Text('Llamar al 911'),
              onTap: () async {
                Navigator.pop(context);
                await _activateEmergency();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.share_location, color: AppColors.warning),
              title: const Text('Compartir ubicacion con contactos'),
              onTap: () {
                Navigator.pop(context);
                _shareLocation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: AppColors.rappiOrange),
              title: const Text('Reportar un problema'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel,
                  color: AppColors.getTextSecondary(context)),
              title: const Text('Cancelar viaje'),
              onTap: () {
                Navigator.pop(context);
                _cancelRide();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activateEmergency() async {
    try {
      final Uri emergencyUri = Uri(scheme: 'tel', path: '911');
      if (await canLaunchUrl(emergencyUri)) {
        await launchUrl(emergencyUri);
      }

      await FirebaseService().reportEmergency(
        widget.rideId,
        _currentPosition,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergencia activada. Ayuda en camino.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al activar emergencia: $e'),
          backgroundColor: AppColors.error,
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
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Cancelar viaje'),
        content:
            const Text('Estas seguro que deseas cancelar el viaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Si, cancelar'),
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
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _shareLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Compartiendo ubicacion en vivo'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  /// Show rating dialog when trip finishes
  void _showRatingDialog() {
    _isCompleting = true;
    final driverName =
        _currentRide?.vehicleInfo?['driverName'] ?? 'Conductor';
    final driverPhoto = _currentRide?.vehicleInfo?['driverPhoto'] ?? '';

    RatingDialog.show(
      context: context,
      driverName: driverName,
      driverPhoto: driverPhoto,
      tripId: widget.rideId,
      onSubmit: (rating, comment, tags) {
        debugPrint('Rating submitted: $rating stars, tags: $tags');
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }

  // Verification logic
  Future<void> _verifyDriverCode() async {
    final code = _verificationCodeController.text.trim();
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa el codigo de 4 digitos'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_currentRide?.driverVerificationCode == null) return;

    setState(() => _isVerifyingCode = true);
    try {
      if (code == _currentRide!.driverVerificationCode) {
        await FirebaseFirestore.instance
            .collection('rides')
            .doc(widget.rideId)
            .update({
          'isDriverVerified': true,
        });
        if (mounted) {
          _verificationCodeController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Codigo verificado correctamente'),
              backgroundColor: AppColors.rappiOrange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Codigo incorrecto. Intenta de nuevo.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifyingCode = false);
    }
  }

  // ===========================================================================
  // BUILD - Plus App Visual Design
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    // Cancelled state - special screen
    if (_currentRide?.status == 'cancelled') {
      return _buildCancelledScreen();
    }

    // Loading state
    if (_currentRide == null) {
      return Scaffold(
        body: Container(
          color: AppColors.getSurface(context),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.rappiOrange),
                SizedBox(height: 16),
                Text('Cargando informacion del viaje...'),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          _buildFullScreenMap(),

          // Pulse indicator on map (when driver is moving)
          if (_isPrePickupStatus() || _isInTransitStatus())
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              left: MediaQuery.of(context).size.width * 0.45,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 60 + (20 * _pulseController.value),
                    height: 60 + (20 * _pulseController.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.rappiOrange.withValues(
                        alpha: 0.3 * (1 - _pulseController.value),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Header with status, ETA, distance
          SafeArea(
            child: _buildHeader(),
          ),

          // Re-center button
          if (!_isFollowingDriver && _driverLatLng != null)
            Positioned(
              right: 16,
              bottom: _getBottomSheetHeight() + 16,
              child: FloatingActionButton.small(
                backgroundColor: AppColors.rappiOrange,
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
                child: const Icon(Icons.my_location,
                    color: Colors.white, size: 20),
              ),
            ),

          // Animated bottom sheet with driver info
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _bottomSheetController,
              builder: (context, child) {
                return Transform.translate(
                  offset:
                      Offset(0, 400 * (1 - _bottomSheetController.value)),
                  child: _buildDriverInfoSheet(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double _getBottomSheetHeight() {
    // Approximate height of the bottom sheet
    if (_currentRide?.status == 'driver_arriving' ||
        _currentRide?.status == 'waiting_verification') {
      return 480;
    }
    return 380;
  }

  // ---------------------------------------------------------------------------
  // Cancelled screen
  // ---------------------------------------------------------------------------

  Widget _buildCancelledScreen() {
    return Scaffold(
      backgroundColor: AppColors.getSurface(context),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cancel_rounded,
                      size: 60, color: AppColors.error),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Viaje cancelado',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  _currentRide?.cancelledBy == _currentRide?.driverId
                      ? 'El conductor cancelo el viaje'
                      : 'El viaje fue cancelado',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Volver al inicio',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.rappiOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Full-screen map (no rounded corners, edge-to-edge)
  // ---------------------------------------------------------------------------

  Widget _buildFullScreenMap() {
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
      initialTarget = const LatLng(-12.0464, -77.0428);
    }

    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        setState(() {
          _isMapLoaded = true;
        });

        Future.delayed(const Duration(seconds: 1), () {
          if (_routePoints.isNotEmpty) {
            _centerMapOnRoute();
          } else if (_currentRide != null) {
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
    );
  }

  // ---------------------------------------------------------------------------
  // Header card (status + ETA + distance) - Plus App style
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.getCardShadow(),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.getInputFill(context),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back,
                  color: AppColors.getTextPrimary(context), size: 20),
            ),
          ),
          const SizedBox(width: 12),
          // Status and ETA
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentStatus,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: _etaController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1 + (0.1 * _etaController.value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppColors.rappiOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _minutesRemaining > 0
                              ? '$_minutesRemaining min • ${(_isInTransitStatus() ? _distanceToDestination : _distanceToPickup).toStringAsFixed(1)} km'
                              : _estimatedArrival,
                          style: const TextStyle(
                            color: AppColors.rappiOrange,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Share location button
          GestureDetector(
            onTap: _shareLocation,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.getInputFill(context),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.share_location,
                  color: AppColors.getTextPrimary(context), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom sheet with driver info - Plus App style
  // ---------------------------------------------------------------------------

  Widget _buildDriverInfoSheet() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: AppColors.getCardShadow(elevation: 4),
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
              color: AppColors.getBorder(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Arrived banner
          if (_currentRide?.status == 'driver_arriving' ||
              _currentRide?.status == 'arrived')
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'El conductor te esta esperando',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Verification card (if driver arrived)
          if (_currentRide?.status == 'driver_arriving' ||
              _currentRide?.status == 'waiting_verification')
            _buildVerificationCard(),

          // Driver info card
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    // Driver photo with orange border
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.rappiOrange,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundColor:
                            AppColors.rappiOrange.withValues(alpha: 0.1),
                        backgroundImage:
                            _currentRide?.vehicleInfo?['driverPhoto'] !=
                                    null
                                ? NetworkImage(
                                    _currentRide!
                                        .vehicleInfo!['driverPhoto'],
                                  )
                                : null,
                        child:
                            _currentRide?.vehicleInfo?['driverPhoto'] ==
                                    null
                                ? const Icon(Icons.person,
                                    size: 30,
                                    color: AppColors.rappiOrange)
                                : null,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Driver name, rating, vehicle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _currentRide
                                          ?.vehicleInfo?['driverName'] ??
                                      'Conductor',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber
                                      .withValues(alpha: 0.2),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      _currentRide
                                              ?.vehicleInfo?[
                                                  'driverRating']
                                              ?.toStringAsFixed(1) ??
                                          '5.0',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (_currentRide?.vehicleInfo?['plate'] !=
                              null)
                            Text(
                              '${_currentRide?.vehicleInfo?['model'] ?? ''} - ${_currentRide?.vehicleInfo?['plate']}',
                              style: TextStyle(
                                color:
                                    AppColors.getTextSecondary(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                        ],
                      ),
                    ),

                    // Action buttons column (call, chat, emergency)
                    Column(
                      children: [
                        // Call button
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.rappiOrange
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.call,
                              color: AppColors.rappiOrange,
                            ),
                            onPressed: _callDriver,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Chat button
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.rappiOrangeDark
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.message,
                              color: AppColors.rappiOrangeDark,
                            ),
                            onPressed: _openChat,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Emergency button
                        Container(
                          decoration: BoxDecoration(
                            color:
                                AppColors.error.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.warning_rounded,
                              color: AppColors.error,
                            ),
                            onPressed: _showEmergencyOptions,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Route info: Pickup (green) -> Destination (red) with connector line
                _buildRouteInfo(),

                // Cancel / complete trip button
                if (_currentRide?.status != 'completed' &&
                    _currentRide?.status != 'cancelled') ...[
                  const SizedBox(height: 16),
                  if (_isInTransitStatus())
                    // In-transit: no cancel, just informational
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.rappiOrange
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_rounded,
                              color: AppColors.rappiOrange, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Viaje en curso',
                            style: TextStyle(
                              color: AppColors.rappiOrange,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_isPrePickupStatus())
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _cancelRide,
                        icon: const Icon(Icons.cancel_outlined,
                            size: 18),
                        label: const Text('Cancelar viaje'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(
                              color: AppColors.error, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Route info card: Pickup (green) -> Destination (red) with connector line
  // ---------------------------------------------------------------------------

  Widget _buildRouteInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Origin
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.success,
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
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                    Text(
                      _currentRide?.pickupAddress ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Connector line
          Container(
            margin: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
            width: 2,
            height: 20,
            color: AppColors.getBorder(context),
          ),

          // Destination
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.error,
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
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                    Text(
                      _currentRide?.destinationAddress ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Price and payment method
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    color: AppColors.rappiOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'S/ ${(_currentRide?.finalFare ?? _currentRide?.estimatedFare ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.rappiOrange,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.getInputFill(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.money,
                      size: 16,
                      color: AppColors.getTextSecondary(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currentRide?.paymentMethod ?? 'Efectivo',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(context),
                      ),
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

  // ---------------------------------------------------------------------------
  // Verification card (inline inside bottom sheet)
  // ---------------------------------------------------------------------------

  Widget _buildVerificationCard() {
    final passengerCode =
        _currentRide?.passengerVerificationCode ?? '----';
    final isDriverVerified = _currentRide?.isDriverVerified ?? false;
    final isPassengerVerified =
        _currentRide?.isPassengerVerified ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.rappiOrange.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.rappiOrange.withValues(alpha: 0.15),
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
              const Icon(Icons.verified_user,
                  color: AppColors.rappiOrange, size: 24),
              const SizedBox(width: 8),
              Text(
                'Verificacion Mutua',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Passenger code (to tell the driver)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.rappiOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isPassengerVerified
                      ? Icons.check_circle
                      : Icons.info_outline,
                  color: isPassengerVerified
                      ? AppColors.rappiOrange
                      : AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPassengerVerified
                            ? 'Conductor te verifico'
                            : 'Dile este codigo al conductor:',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextSecondary(context)),
                      ),
                      if (!isPassengerVerified)
                        Text(
                          passengerCode,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8),
                        ),
                    ],
                  ),
                ),
                if (isPassengerVerified)
                  const Icon(Icons.check_circle,
                      color: AppColors.rappiOrange, size: 28),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Driver code input
          if (!isDriverVerified) ...[
            Text(
              'Ingresa el codigo del conductor:',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getTextSecondary(context)),
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
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '0000',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed:
                      _isVerifyingCode ? null : _verifyDriverCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rappiOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isVerifyingCode
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Verificar',
                          style:
                              TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.rappiOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle,
                      color: AppColors.rappiOrange, size: 20),
                  SizedBox(width: 8),
                  Text('Conductor verificado',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
