import 'package:flutter/material.dart';
// ignore_for_file: library_private_types_in_public_api
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../services/tracking_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/loading_overlay.dart';
import '../../utils/map_marker_utils.dart';

/// PANTALLA DE TRACKING EN TIEMPO REAL - RAPPI TEAM
/// ===============================================
/// 
/// Funcionalidades implementadas:
/// 🗺️ Mapa de Google Maps con ubicación en tiempo real
/// 📍 Tracking del conductor cada 5 segundos
/// 🕐 ETA dinámico que se actualiza automáticamente
/// 🛣️ Ruta planificada vs ruta real
/// ⚠️ Alertas de desvíos de ruta
/// 🚗 Íconos personalizados para conductor y pasajero
/// 📊 Información detallada del viaje en tiempo real
/// 🔄 Reconexión automática si se pierde la conexión
class LiveTrackingMapScreen extends StatefulWidget {
  final String rideId;
  final String userType; // 'passenger' o 'driver'
  final String userId;

  const LiveTrackingMapScreen({
    super.key,
    required this.rideId,
    required this.userType,
    required this.userId,
  });

  @override
  State<LiveTrackingMapScreen> createState() => _LiveTrackingMapScreenState();
}

class _LiveTrackingMapScreenState extends State<LiveTrackingMapScreen>
    with WidgetsBindingObserver {
  final TrackingService _trackingService = TrackingService();
  final FirebaseService _firebaseService = FirebaseService();

  GoogleMapController? _mapController;
  bool _isLoading = true;
  TrackingInfo? _trackingInfo;
  StreamSubscription<TrackingUpdate>? _trackingSubscription;

  // Estado del mapa
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _currentDriverLocation;
  LatLng? _previousDriverLocation;
  double _driverHeading = 0.0;
  LatLng? _destination;

  // Información del viaje
  DateTime? _estimatedArrival;
  double _totalDistance = 0;
  bool _hasDeviation = false;

  // Íconos personalizados
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _destinationIcon;

  // Control de la cámara
  bool _followDriver = true;
  Timer? _cameraUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trackingSubscription?.cancel();
    _cameraUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconnectTracking();
    }
  }

  Future<void> _initializeServices() async {
    setState(() => _isLoading = true);

    try {
      await _trackingService.initialize();
      
      await _loadCustomIcons();
      await _loadTrackingInfo();
      await _startTrackingUpdates();

    } catch (e) {
      _showErrorSnackBar('Error inicializando servicios: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCustomIcons() async {
    try {
      _driverIcon = await MapMarkerUtils.getCarTopViewIcon();
      _destinationIcon = await MapMarkerUtils.getDestinationIcon();
    } catch (e) {
      debugPrint('Error cargando íconos: $e');
      // Usar íconos por defecto si hay error
      _driverIcon = BitmapDescriptor.defaultMarker;
      _destinationIcon = BitmapDescriptor.defaultMarker;
    }
  }

  Future<void> _loadTrackingInfo() async {
    try {
      _trackingInfo = await _trackingService.getActiveTrackingByRide(widget.rideId);
      
      if (!mounted) return;
      if (_trackingInfo != null) {
        setState(() {
          _currentDriverLocation = _trackingInfo!.currentLocation;
          _destination = _trackingInfo!.destination;
          _estimatedArrival = _trackingInfo!.estimatedArrival;
          _totalDistance = _trackingInfo!.totalDistance;
        });

        await _updateMapMarkersAndRoute();
        await _centerMapOnRoute();
      } else {
        _showErrorSnackBar('No se encontró información de tracking para este viaje');
      }
    } catch (e) {
      _showErrorSnackBar('Error cargando información de tracking: $e');
    }
  }

  Future<void> _startTrackingUpdates() async {
    try {
      _trackingSubscription = _trackingService
          .getTrackingUpdates(widget.rideId)
          .listen(
        (update) async {
          await _handleTrackingUpdate(update);
        },
        onError: (error) {
          debugPrint('Error en stream de tracking: $error');
          _reconnectTracking();
        },
      );

      await _firebaseService.analytics.logEvent(
        name: 'tracking_started_map_view',
        parameters: {
          'ride_id': widget.rideId,
          'user_type': widget.userType,
        },
      );
    } catch (e) {
      _showErrorSnackBar('Error iniciando actualizaciones de tracking: $e');
    }
  }

  Future<void> _handleTrackingUpdate(TrackingUpdate update) async {
    if (!mounted) return;
    setState(() {
      if (update.currentLocation != null) {
        _currentDriverLocation = update.currentLocation;
      }
      if (update.estimatedArrival != null) {
        _estimatedArrival = update.estimatedArrival;
      }
      _hasDeviation = update.hasDeviated;
    });

    await _updateMapMarkersAndRoute();
    if (!mounted) return;

    // Actualizar cámara si sigue al conductor
    if (_followDriver && _currentDriverLocation != null) {
      await _updateCameraToFollowDriver();
    }
    if (!mounted) return;

    // Mostrar alerta si hay desvío
    if (update.hasDeviated && update.deviationDistance != null) {
      _showDeviationAlert(update.deviationDistance!);
    }
  }

  Future<void> _updateMapMarkersAndRoute() async {
    final Set<Marker> newMarkers = {};
    final Set<Polyline> newPolylines = {};

    // Marker del conductor
    if (_currentDriverLocation != null && _driverIcon != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _currentDriverLocation!,
          icon: _driverIcon!,
          infoWindow: const InfoWindow(
            title: '🚗 Conductor',
            snippet: 'Ubicación actual',
          ),
        ),
      );
    }

    // Marker del destino
    if (_destination != null && _destinationIcon != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination!,
          icon: _destinationIcon!,
          infoWindow: const InfoWindow(
            title: '🏁 Destino',
            snippet: 'Punto de llegada',
          ),
        ),
      );
    }

    // Obtener y dibujar ruta
    if (_currentDriverLocation != null && _destination != null) {
      final routePolyline = await _trackingService.getRoutePolyline(
        _currentDriverLocation!,
        _destination!,
      );

      if (routePolyline != null) {
        newPolylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: _decodePolyline(routePolyline),
            color: _hasDeviation ? ModernTheme.warning : ModernTheme.info,
            width: 5,
            patterns: _hasDeviation ? [PatternItem.dash(20), PatternItem.gap(10)] : [],
          ),
        );
      }
    }

    setState(() {
      _markers = newMarkers;
      _polylines = newPolylines;
    });
  }

  Future<void> _centerMapOnRoute() async {
    if (_mapController == null || _currentDriverLocation == null || _destination == null) {
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(_currentDriverLocation!.latitude, _destination!.latitude),
        math.min(_currentDriverLocation!.longitude, _destination!.longitude),
      ),
      northeast: LatLng(
        math.max(_currentDriverLocation!.latitude, _destination!.latitude),
        math.max(_currentDriverLocation!.longitude, _destination!.longitude),
      ),
    );

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  Future<void> _updateCameraToFollowDriver() async {
    if (_mapController != null && _currentDriverLocation != null) {
      // Calculate bearing from previous to current position
      if (_previousDriverLocation != null) {
        final lat1 = _previousDriverLocation!.latitude * math.pi / 180;
        final lat2 = _currentDriverLocation!.latitude * math.pi / 180;
        final dLng = (_currentDriverLocation!.longitude - _previousDriverLocation!.longitude) * math.pi / 180;
        final y = math.sin(dLng) * math.cos(lat2);
        final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
        _driverHeading = (math.atan2(y, x) * 180 / math.pi + 360) % 360;
      }
      _previousDriverLocation = _currentDriverLocation;

      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(
          target: _currentDriverLocation!,
          zoom: 17.5,
          bearing: _driverHeading,
          tilt: 45.0,
        )),
      );
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polyline;
  }

  Future<void> _reconnectTracking() async {
    try {
      await _trackingSubscription?.cancel();
      await Future.delayed(const Duration(seconds: 2));
      await _startTrackingUpdates();
    } catch (e) {
      debugPrint('Error reconectando tracking: $e');
    }
  }

  void _showDeviationAlert(double deviationDistance) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: Theme.of(context).colorScheme.onPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'El conductor se ha desviado ${deviationDistance.toInt()}m de la ruta. '
                'Ruta recalculada automáticamente.',
              ),
            ),
          ],
        ),
        backgroundColor: ModernTheme.warning,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'VER',
          textColor: Theme.of(context).colorScheme.onPrimary,
          onPressed: () {
            if (_currentDriverLocation != null) {
              _centerMapOnRoute();
            }
          },
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ModernTheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _formatETA() {
    if (_estimatedArrival == null) return 'Calculando...';
    
    final now = DateTime.now();
    final difference = _estimatedArrival!.difference(now);
    
    if (difference.isNegative) {
      return 'Arribando';
    }
    
    final minutes = difference.inMinutes;
    if (minutes < 1) {
      return 'Menos de 1 min';
    } else if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}min';
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toInt()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Stack(
          children: [
            // Mapa fullscreen
            GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _currentDriverLocation ??
                    const LatLng(-12.0464, -77.0428), // Lima, Peru
                zoom: 14.0,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
            ),

            // Boton de regresar semi-transparente
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: context.primaryText),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),

            // Botones de accion flotantes semi-transparentes (derecha)
            Positioned(
              bottom: 160,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSemiTransparentFAB(_buildFollowButton()),
                  const SizedBox(height: 8),
                  _buildSemiTransparentFAB(_buildCenterButton()),
                  const SizedBox(height: 8),
                  _buildSemiTransparentFAB(_buildRefreshButton()),
                ],
              ),
            ),

            // Info bar minimalista translucida en la parte inferior
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildMinimalInfoBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSemiTransparentFAB(Widget fab) {
    return Opacity(opacity: 0.88, child: fab);
  }

  Widget _buildMinimalInfoBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.access_time,
                    label: 'ETA',
                    value: _formatETA(),
                    color: ModernTheme.info,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.straighten,
                    label: 'Distancia',
                    value: _formatDistance(_totalDistance),
                    color: ModernTheme.success,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: _buildInfoItem(
                    icon: _hasDeviation ? Icons.warning : Icons.check_circle,
                    label: 'Estado',
                    value: _hasDeviation ? 'Desviado' : 'En ruta',
                    color: _hasDeviation ? ModernTheme.warning : ModernTheme.success,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.secondaryText,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFollowButton() {
    return FloatingActionButton(
      mini: true,
      backgroundColor: _followDriver ? ModernTheme.info : context.secondaryText,
      onPressed: () {
        setState(() {
          _followDriver = !_followDriver;
        });
        if (_followDriver && _currentDriverLocation != null) {
          _updateCameraToFollowDriver();
        }
      },
      child: Icon(
        Icons.my_location,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildCenterButton() {
    return FloatingActionButton(
      mini: true,
      backgroundColor: ModernTheme.success,
      onPressed: _centerMapOnRoute,
      child: Icon(
        Icons.center_focus_strong,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildRefreshButton() {
    return FloatingActionButton(
      mini: true,
      backgroundColor: ModernTheme.warning,
      onPressed: () async {
        setState(() => _isLoading = true);
        await _loadTrackingInfo();
        setState(() => _isLoading = false);
      },
      child: Icon(
        Icons.refresh,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}