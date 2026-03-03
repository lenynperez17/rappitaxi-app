import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../services/tracking_service.dart';
import '../../services/firebase_service.dart';
import '../../utils/firestore_error_handler.dart';

/// PANTALLA DE TRACKING EN TIEMPO REAL - RAPITEAM
/// ===============================================
///
/// Funcionalidades implementadas:
/// - Mapa de Google Maps con ubicación en tiempo real
/// - Tracking del conductor cada 5 segundos
/// - ETA dinamico que se actualiza automáticamente
/// - Ruta planificada vs ruta real
/// - Alertas de desvios de ruta
/// - Iconos personalizados para conductor y pasajero
/// - Información detallada del viaje en tiempo real
/// - Reconexión automatica si se pierde la conexión
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
  LatLng? _destination;

  // Información del viaje
  DateTime? _estimatedArrival;
  double _totalDistance = 0;
  bool _hasDeviation = false;

  // Iconos personalizados
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
      _showErrorSnackBar(FirestoreErrorHandler.getSpanishMessage(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCustomIcons() async {
    try {
      _driverIcon = await _createCustomIcon('auto', RtColors.info);
      _destinationIcon = await _createCustomIcon('meta', RtColors.error);
    } catch (e) {
      debugPrint('Error cargando iconos: $e');
      // Usar iconos por defecto si hay error
      _driverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      _destinationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  Future<BitmapDescriptor> _createCustomIcon(String emoji, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 100.0;

    // Dibujar circulo de fondo
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      paint,
    );

    // Dibujar borde
    final borderPaint = Paint()
      ..color = RtColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      borderPaint,
    );

    // Dibujar texto en lugar de emoji
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: emoji,
        style: const TextStyle(fontSize: 40),
      ),
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
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
        _showErrorSnackBar('No se encontro información de tracking para este viaje');
      }
    } catch (e) {
      _showErrorSnackBar(FirestoreErrorHandler.getSpanishMessage(e));
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
      _showErrorSnackBar(FirestoreErrorHandler.getSpanishMessage(e));
    }
  }

  Future<void> _handleTrackingUpdate(TrackingUpdate update) async {
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

    // Actualizar cámara si sigue al conductor
    if (_followDriver && _currentDriverLocation != null) {
      await _updateCameraToFollowDriver();
    }

    // Mostrar alerta si hay desvio
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
            title: 'Conductor',
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
            title: 'Destino',
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
            color: _hasDeviation ? RtColors.warning : RtColors.info,
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
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentDriverLocation!, 16.0),
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
    RtSnackbar.show(
      context,
      message: 'El conductor se ha desviado ${deviationDistance.toInt()}m de la ruta. Ruta recalculada automáticamente.',
      type: RtSnackbarType.warning,
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    RtSnackbar.show(context, message: message, type: RtSnackbarType.error);
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
      body: Stack(
        children: [
          // Mapa de Google Maps
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            initialCameraPosition: CameraPosition(
              target: _currentDriverLocation ?? const LatLng(-12.0464, -77.0428), // Lima, Peru
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

          // Panel de información superior
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: _buildInfoPanel(),
          ),

          // Botones de accion inferiores
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFollowButton(),
                const SizedBox(height: 8),
                _buildCenterButton(),
                const SizedBox(height: 8),
                _buildRefreshButton(),
              ],
            ),
          ),

          // Boton de regresar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // Overlay de carga
          if (_isLoading)
            Container(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Siguiendo tu viaje',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _hasDeviation ? RtColors.warning : RtColors.success,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _hasDeviation ? 'DESVIADO' : 'EN RUTA',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.access_time,
                    label: 'ETA',
                    value: _formatETA(),
                    color: RtColors.info,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.straighten,
                    label: 'Distancia',
                    value: _formatDistance(_totalDistance),
                    color: RtColors.success,
                  ),
                ),
                if (_hasDeviation)
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.warning,
                      label: 'Estado',
                      value: 'Desviado',
                      color: RtColors.warning,
                    ),
                  ),
              ],
            ),
          ],
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
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
      backgroundColor: _followDriver
          ? RtColors.info
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
      backgroundColor: RtColors.success,
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
      backgroundColor: RtColors.warning,
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
