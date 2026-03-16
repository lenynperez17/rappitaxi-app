// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../widgets/animated/modern_animated_widgets.dart';
import '../shared/chat_screen.dart';
import '../shared/rating_dialog.dart';
import '../../services/sound_service.dart';

class TrackingScreen extends StatefulWidget {
  final String tripId;
  final String driverName;
  final String driverPhoto;
  final String vehicleInfo;
  final double driverRating;
  final String estimatedTime;
  final String pickupAddress;
  final String destinationAddress;
  final double tripPrice;
  // New parameters for real-time sync
  final String? driverId;
  final String? driverPhone;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;

  const TrackingScreen({
    super.key,
    required this.tripId,
    required this.driverName,
    required this.driverPhoto,
    required this.vehicleInfo,
    required this.driverRating,
    required this.estimatedTime,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.tripPrice,
    this.driverId,
    this.driverPhone,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
  });

  @override
  _TrackingScreenState createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Animations
  late AnimationController _bottomSheetController;
  late AnimationController _pulseController;
  late AnimationController _etaController;

  // Trip state - synced with Firestore
  String _tripStatus = 'arriving'; // arriving, arrived, ontrip, completed
  int _minutesRemaining = 5;
  double _distanceRemaining = 2.5;

  // Positions - initialized from parameters or defaults
  late LatLng _driverPosition;
  late LatLng _passengerPosition;
  late LatLng _destinationPosition;

  // Firestore subscription for real-time sync
  StreamSubscription<DocumentSnapshot>? _tripSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _etaTimer;
  bool _mapInitialized = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();

    debugPrint('TrackingScreen.initState()');
    debugPrint('   tripId: ${widget.tripId}');
    debugPrint('   driverName: ${widget.driverName}');
    debugPrint('   driverPhoto: ${widget.driverPhoto}');
    debugPrint('   vehicleInfo: ${widget.vehicleInfo}');
    debugPrint('   driverRating: ${widget.driverRating}');
    debugPrint('   driverId: ${widget.driverId}');
    debugPrint('   driverPhone: ${widget.driverPhone}');
    debugPrint('   tripPrice: ${widget.tripPrice}');

    // Initialize positions from parameters or defaults
    _passengerPosition = LatLng(
      widget.pickupLat ?? -12.0951,
      widget.pickupLng ?? -76.9870,
    );
    _destinationPosition = LatLng(
      widget.destinationLat ?? -12.1051,
      widget.destinationLng ?? -77.0070,
    );
    _driverPosition = _passengerPosition;

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

    // Start Firestore sync
    _listenToTripChanges();
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();

    // Release MapController to avoid ImageReader buffer warnings
    _mapController?.dispose();
    _mapController = null;

    _bottomSheetController.dispose();
    _pulseController.dispose();
    _etaController.dispose();
    _etaTimer?.cancel();
    super.dispose();
  }

  /// Listen to real-time trip changes from Firestore
  void _listenToTripChanges() {
    _tripSubscription = _firestore
        .collection('rides')
        .doc(widget.tripId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (!snapshot.exists) {
        debugPrint('TrackingScreen: Trip does not exist, exiting...');
        Navigator.of(context).pop();
        return;
      }

      final data = snapshot.data()!;
      final status = data['status'] as String? ?? 'accepted';
      final driverLoc = data['driverLocation'] as GeoPoint?;

      setState(() {
        // Map Firestore status to local state
        _tripStatus = _mapFirestoreStatus(status);

        // Update driver location if available
        if (driverLoc != null) {
          _driverPosition = LatLng(driverLoc.latitude, driverLoc.longitude);
          _updateDriverMarker();
          _updateRoute();
        }

        // Calculate distance and estimated time
        if (driverLoc != null) {
          _distanceRemaining = _calculateDistanceKm(
            _driverPosition,
            _tripStatus == 'ontrip' ? _destinationPosition : _passengerPosition,
          );
          _minutesRemaining = (_distanceRemaining * 2).ceil();
        }
      });

      // Show notification if driver arrived
      if (status == 'arrived' || status == 'driver_arrived') {
        _showArrivedNotification();
      }

      // If trip completed, show rating dialog
      if (status == 'completed' && !_isCompleting) {
        _showRatingDialog();
      }
    }, onError: (error) {
      debugPrint('TrackingScreen: Error listening to trip: $error');
    });
  }

  /// Map Firestore status to local UI state
  String _mapFirestoreStatus(String status) {
    switch (status) {
      case 'accepted':
      case 'driver_arriving':
        return 'arriving';
      case 'arrived':
      case 'driver_arrived':
        return 'arrived';
      case 'in_progress':
        return 'ontrip';
      case 'completed':
        return 'completed';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'arriving';
    }
  }

  /// Update driver marker on the map
  void _updateDriverMarker() {
    _markers.removeWhere((m) => m.markerId.value == 'driver');
    _markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: _driverPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: widget.driverName,
          snippet: widget.vehicleInfo,
        ),
      ),
    );

    // Center map if controller is available
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(_getBounds(), 100),
    );
  }

  /// Update route on the map
  void _updateRoute() {
    _polylines.clear();

    List<LatLng> routePoints;

    if (_tripStatus == 'ontrip') {
      // During trip: driver -> destination
      routePoints = [_driverPosition, _destinationPosition];
    } else {
      // Waiting for driver: always show trip route (pickup -> destination)
      routePoints = [_passengerPosition, _destinationPosition];
    }

    debugPrint('Polyline: ${routePoints.first} -> ${routePoints.last}');

    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: routePoints,
        color: Colors.blue,
        width: 5,
      ),
    );
  }

  /// Calculate distance in kilometers between two points
  double _calculateDistanceKm(LatLng pos1, LatLng pos2) {
    const double earthRadius = 6371; // km
    final double dLat = _toRadians(pos2.latitude - pos1.latitude);
    final double dLon = _toRadians(pos2.longitude - pos1.longitude);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(pos1.latitude)) *
            math.cos(_toRadians(pos2.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  void _setupMap() {
    // Setup initial markers
    _markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: _driverPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: widget.driverName,
          snippet: widget.vehicleInfo,
        ),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('passenger'),
        position: _passengerPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: 'Tu ubicacion',
          snippet: widget.pickupAddress,
        ),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: _destinationPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Destino',
          snippet: widget.destinationAddress,
        ),
      ),
    );

    // Setup initial route
    _updateRoute();
  }

  /// Show rating dialog when trip finishes
  void _showRatingDialog() {
    _isCompleting = true;
    RatingDialog.show(
      context: context,
      driverName: widget.driverName,
      driverPhoto: widget.driverPhoto,
      tripId: widget.tripId,
      onSubmit: (rating, comment, tags) {
        debugPrint('Rating submitted: $rating stars, tags: $tags');
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }

  LatLngBounds _getBounds() {
    double minLat = math.min(
      _driverPosition.latitude,
      math.min(_passengerPosition.latitude, _destinationPosition.latitude),
    );
    double maxLat = math.max(
      _driverPosition.latitude,
      math.max(_passengerPosition.latitude, _destinationPosition.latitude),
    );
    double minLng = math.min(
      _driverPosition.longitude,
      math.min(_passengerPosition.longitude, _destinationPosition.longitude),
    );
    double maxLng = math.max(
      _driverPosition.longitude,
      math.max(_passengerPosition.longitude, _destinationPosition.longitude),
    );

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
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

  @override
  Widget build(BuildContext context) {
    // Initialize map only once when context is available
    if (!_mapInitialized) {
      _setupMap();
      _mapInitialized = true;
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map with tracking
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _driverPosition,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              // Center on markers
              Future.delayed(const Duration(milliseconds: 500), () {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngBounds(_getBounds(), 100),
                );
              });
            },
            onTap: (_) => FocusScope.of(context).unfocus(),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            liteModeEnabled: false,
            buildingsEnabled: false,
            indoorViewEnabled: false,
            trafficEnabled: false,
            minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
          ),

          // Driver position pulse indicator
          if (_tripStatus == 'arriving' || _tripStatus == 'ontrip')
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
                      color: AppColors.rappiOrange.withValues(alpha:
                        0.3 * (1 - _pulseController.value),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Header with trip info
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.getCardShadow(),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getStatusText(),
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
                                  color: AppColors.rappiOrange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$_minutesRemaining min • ${_distanceRemaining.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    color: AppColors.rappiOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_location),
                    onPressed: _shareLocation,
                  ),
                ],
              ),
            ),
          ),

          // Bottom sheet with driver info
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _bottomSheetController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 300 * (1 - _bottomSheetController.value)),
                  child: _buildDriverInfoSheet(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfoSheet() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: AppColors.getCardShadow(),
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

          // Trip status
          if (_tripStatus == 'arrived')
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
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'El conductor te esta esperando',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _tripStatus = 'ontrip');
                    },
                    child: const Text('Iniciar viaje'),
                  ),
                ],
              ),
            ),

          // Driver info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    // Driver photo
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
                        backgroundImage: NetworkImage(widget.driverPhoto),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Driver data
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.driverName,
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
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
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
                                      widget.driverRating.toString(),
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
                          Text(
                            widget.vehicleInfo,
                            style: TextStyle(
                              color: AppColors.getTextSecondary(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),

                    // Action buttons (call, chat, emergency)
                    Column(
                      children: [
                        // Call button
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.rappiOrange.withValues(alpha: 0.1),
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
                            color: AppColors.rappiOrangeDark.withValues(alpha: 0.1),
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
                            color: AppColors.error.withValues(alpha: 0.1),
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

                // Trip details
                Container(
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
                                  widget.pickupAddress,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
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
                                  widget.destinationAddress,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
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
                              Text(
                                'S/ ${widget.tripPrice.toStringAsFixed(2)}',
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
                                  'Efectivo',
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
                ),

                if (_tripStatus == 'ontrip') ...[
                  const SizedBox(height: 16),
                  AnimatedPulseButton(
                    text: 'Finalizar viaje',
                    icon: Icons.check_circle,
                    onPressed: _completeTrip,
                    color: AppColors.success,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText() {
    switch (_tripStatus) {
      case 'arriving':
        return 'Conductor en camino';
      case 'arrived':
        return 'El conductor ha llegado';
      case 'ontrip':
        return 'En camino al destino';
      case 'completed':
        return 'Viaje completado';
      default:
        return '';
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

  /// Call driver with url_launcher
  Future<void> _callDriver() async {
    if (widget.driverPhone == null || widget.driverPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Telefono no disponible'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: widget.driverPhone);

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

  /// Open chat with driver
  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserName: widget.driverName,
          otherUserRole: 'driver',
          otherUserId: widget.driverId,
          rideId: widget.tripId,
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              onTap: () {
                Navigator.pop(context);
                // Call emergency
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_location, color: AppColors.warning),
              title: const Text('Compartir ubicacion con contactos'),
              onTap: () {
                Navigator.pop(context);
                // Share location
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.orange),
              title: const Text('Reportar un problema'),
              onTap: () {
                Navigator.pop(context);
                // Report
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel, color: AppColors.getTextSecondary(context)),
              title: const Text('Cancelar viaje'),
              onTap: () {
                Navigator.pop(context);
                _cancelTrip();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _cancelTrip() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Cancelar viaje'),
        content: const Text('Estas seguro que deseas cancelar el viaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                // Update status in Firestore
                await _firestore.collection('rides').doc(widget.tripId).update({
                  'status': 'cancelled',
                  'cancelledAt': FieldValue.serverTimestamp(),
                  'cancelledBy': 'passenger',
                });

                if (mounted) {
                  // Cancel Firestore listener before navigating to prevent double-pop
                  _tripSubscription?.cancel();
                  _tripSubscription = null;
                  Navigator.pop(context);
                }
              } catch (e) {
                debugPrint('Error cancelling trip: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al cancelar: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Si, cancelar'),
          ),
        ],
      ),
    );
  }

  /// Complete trip and update Firestore
  Future<void> _completeTrip() async {
    if (_isCompleting) return;
    _isCompleting = true;

    try {
      // Update status in Firestore
      await _firestore.collection('rides').doc(widget.tripId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Trip completed in Firestore');
    } catch (e) {
      _isCompleting = false;
      debugPrint('Error completing trip: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al completar viaje: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
