import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';

class NavigationScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;

  const NavigationScreen({super.key, this.tripData});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;

  // Estilo personalizado del mapa
  static const String _mapStyle = '''
  [
    {
      "featureType": "poi",
      "elementType": "labels",
      "stylers": [{"visibility": "off"}]
    }
  ]
  ''';
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Controladores de animacion
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;

  // Estado de navegación
  bool _isNavigating = false;
  final bool _showInstructions = true;
  String _currentInstruction = 'Calculando ruta...';
  String _nextInstruction = '';
  double _distanceToNext = 0;
  int _estimatedTime = 0;
  double _totalDistance = 0;
  int _totalTime = 0;

  // Simulacion de ubicación actual
  LatLng _currentLocation = const LatLng(-12.0851, -76.9770);
  final LatLng _destination = const LatLng(-12.0951, -76.9870);
  Timer? _locationTimer;

  // Flag para prevenir operaciones después de dispose
  bool _isDisposed = false;

  // Iconos 3D personalizados para markers
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _passengerIcon;
  BitmapDescriptor? _destinationIcon;

  // Instrucciones de ruta
  List<RouteInstruction> _instructions = [];
  int _currentInstructionIndex = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    );

    _slideController.forward();
    _loadCustomIcons();
    _initializeRoute();
  }

  // Cargar iconos 3D desde assets
  Future<void> _loadCustomIcons() async {
    try {
      _carIcon = await _getBitmapFromAsset('assets/images/markers/car_3d.png', 80);
      _passengerIcon = await _getBitmapFromAsset('assets/images/markers/passenger_3d.png', 70);
      _destinationIcon = await _getBitmapFromAsset('assets/images/markers/destination_3d.png', 70);

      if (mounted && !_isDisposed) {
        setState(() {});
        _drawRoute();
      }
    } catch (e) {
      debugPrint('Error cargando iconos 3D: $e');
    }
  }

  // Convertir asset PNG a BitmapDescriptor con tamano personalizado
  Future<BitmapDescriptor> _getBitmapFromAsset(String path, int width) async {
    final ByteData data = await rootBundle.load(path);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ByteData? byteData = await fi.image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  @override
  void dispose() {
    _isDisposed = true;

    _pulseController.dispose();
    _slideController.dispose();
    _locationTimer?.cancel();
    _locationTimer = null;
    _mapController?.dispose();
    super.dispose();
  }

  void _initializeRoute() {
    _instructions = [
      RouteInstruction(
        instruction: 'Dirigete hacia el norte por Av. Principal',
        distance: 250,
        duration: 60,
        turnIcon: Icons.arrow_upward,
        position: const LatLng(-12.0851, -76.9770),
      ),
      RouteInstruction(
        instruction: 'Gira a la derecha en Calle 2',
        distance: 500,
        duration: 120,
        turnIcon: Icons.turn_right,
        position: const LatLng(-12.0861, -76.9780),
      ),
      RouteInstruction(
        instruction: 'Continua recto por 800 metros',
        distance: 800,
        duration: 180,
        turnIcon: Icons.straight,
        position: const LatLng(-12.0881, -76.9800),
      ),
      RouteInstruction(
        instruction: 'Gira a la izquierda en Av. Secundaria',
        distance: 400,
        duration: 90,
        turnIcon: Icons.turn_left,
        position: const LatLng(-12.0901, -76.9820),
      ),
      RouteInstruction(
        instruction: 'En la rotonda, toma la segunda salida',
        distance: 200,
        duration: 45,
        turnIcon: Icons.rotate_right,
        position: const LatLng(-12.0921, -76.9840),
      ),
      RouteInstruction(
        instruction: 'Tu destino esta a la derecha',
        distance: 50,
        duration: 15,
        turnIcon: Icons.location_on,
        position: const LatLng(-12.0941, -76.9860),
      ),
    ];

    _totalDistance = _instructions.fold(0, (sum, inst) => sum + inst.distance);
    _totalTime = _instructions.fold(0, (sum, inst) => sum + inst.duration);

    _updateCurrentInstruction();
    _drawRoute();
  }

  void _updateCurrentInstruction() {
    if (_currentInstructionIndex < _instructions.length) {
      final current = _instructions[_currentInstructionIndex];
      _currentInstruction = current.instruction;
      _distanceToNext = current.distance.toDouble();
      _estimatedTime = current.duration;

      if (_currentInstructionIndex + 1 < _instructions.length) {
        _nextInstruction = _instructions[_currentInstructionIndex + 1].instruction;
      } else {
        _nextInstruction = 'Llegando al destino';
      }
    }
  }

  void _drawRoute() {
    List<LatLng> routePoints = _instructions.map((inst) => inst.position).toList();
    routePoints.add(_destination);

    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: routePoints,
        color: RtColors.brand,
        width: 6,
        patterns: [],
      ),
    );

    _markers.clear();

    // Marker del carro (conductor)
    _markers.add(
      Marker(
        markerId: const MarkerId('car'),
        position: _currentLocation,
        icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Tu ubicación'),
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 3,
      ),
    );

    // Marker del pasajero
    if (_instructions.isNotEmpty) {
      _markers.add(
        Marker(
          markerId: const MarkerId('passenger'),
          position: _instructions.first.position,
          icon: _passengerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pasajero'),
          zIndexInt: 2,
        ),
      );
    }

    // Marker del destino
    _markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: _destination,
        icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Destino'),
        zIndexInt: 1,
      ),
    );

    setState(() {});
  }

  void _startNavigation() {
    setState(() {
      _isNavigating = true;
    });

    _locationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (!mounted) {
        timer.cancel();
        return;
      }

      _simulateMovement();
    });
  }

  void _simulateMovement() {
    if (!mounted || _isDisposed) return;

    if (_currentInstructionIndex < _instructions.length - 1) {
      setState(() {
        _distanceToNext -= 50;
        _estimatedTime = math.max(0, _estimatedTime - 2);

        if (_distanceToNext <= 50) {
          _currentInstructionIndex++;
          _updateCurrentInstruction();
          _showVoiceNotification();
        }

        _currentLocation = _instructions[_currentInstructionIndex].position;
        _updateLocationMarker();
      });
    } else {
      _arriveAtDestination();
    }
  }

  void _updateLocationMarker() {
    _markers.removeWhere((marker) => marker.markerId.value == 'car');
    _markers.add(
      Marker(
        markerId: const MarkerId('car'),
        position: _currentLocation,
        icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 3,
      ),
    );
  }

  void _showVoiceNotification() {
    RtSnackbar.show(context, message: _currentInstruction, type: RtSnackbarType.info);
  }

  void _arriveAtDestination() {
    _locationTimer?.cancel();
    setState(() {
      _isNavigating = false;
      _currentInstruction = 'Has llegado a tu destino!';
    });

    _showArrivalDialog();
  }

  void _showArrivalDialog() {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: RtColors.success, size: 32),
            const SizedBox(width: 12),
            const Text('Llegaste!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Has llegado a tu destino exitosamente.'),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.route, size: 20, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Text('${(_totalDistance / 1000).toStringAsFixed(1)} km'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer, size: 20, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Text('${(_totalTime / 60).round()} min'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 16,
              tilt: 45,
              bearing: 90,
            ),
            style: _mapStyle,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            buildingsEnabled: true,
            trafficEnabled: true,
          ),

          // Barra de navegación superior
          SafeArea(
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -100 * (1 - _slideAnimation.value)),
                  child: _buildNavigationBar(),
                );
              },
            ),
          ),

          // Panel de instrucciones inferior
          if (_showInstructions)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 200 * (1 - _slideAnimation.value)),
                    child: _buildInstructionPanel(),
                  );
                },
              ),
            ),

          // Botones flotantes
          Positioned(
            right: 16,
            bottom: _showInstructions ? 280 : 100,
            child: Column(
              children: [
                _buildFloatingButton(
                  Icons.my_location,
                  () => _recenterMap(),
                ),
                const SizedBox(height: 12),
                _buildFloatingButton(
                  Icons.layers,
                  () => _toggleMapType(),
                ),
                const SizedBox(height: 12),
                _buildFloatingButton(
                  Icons.volume_up,
                  () => _toggleVoice(),
                ),
              ],
            ),
          ),

          // Boton de retroceso
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: RtShadow.soft(),
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RtColors.brand,
        borderRadius: BorderRadius.circular(20),
        boxShadow: RtShadow.medium(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Instruccion actual
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _currentInstructionIndex < _instructions.length
                      ? _instructions[_currentInstructionIndex].turnIcon
                      : Icons.location_on,
                  color: colorScheme.surface,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentInstruction,
                      style: TextStyle(
                        color: colorScheme.surface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${_distanceToNext.round()} m',
                          style: TextStyle(
                            color: colorScheme.surface.withValues(alpha: 0.7),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '$_estimatedTime seg',
                          style: TextStyle(
                            color: colorScheme.surface.withValues(alpha: 0.7),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Barra de progreso
          Container(
            margin: const EdgeInsets.only(top: 12),
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: (_currentInstructionIndex + 1) / _instructions.length,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.surface),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionPanel() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: RtShadow.medium(),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Info del viaje
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoItem(
                Icons.route,
                '${(_totalDistance / 1000).toStringAsFixed(1)} km',
                'Distancia total',
              ),
              Container(
                width: 1,
                height: 40,
                color: colorScheme.onSurface.withValues(alpha: 0.18),
              ),
              _buildInfoItem(
                Icons.timer,
                '${(_totalTime / 60).round()} min',
                'Tiempo estimado',
              ),
              Container(
                width: 1,
                height: 40,
                color: colorScheme.onSurface.withValues(alpha: 0.18),
              ),
              _buildInfoItem(
                Icons.speed,
                '45 km/h',
                'Velocidad',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Vista previa de la siguiente instruccion
          if (_nextInstruction.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.subdirectory_arrow_right,
                      color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Luego:',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const Text(
                          '',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _nextInstruction,
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
            ),
          const SizedBox(height: 20),

          // Botones de accion
          Row(
            children: [
              Expanded(
                child: RtButton(
                  label: _isNavigating ? 'Navegando...' : 'Iniciar',
                  icon: _isNavigating ? Icons.pause : Icons.play_arrow,
                  onPressed: _isNavigating ? null : _startNavigation,
                ),
              ),
              const SizedBox(width: 12),
              RtButton(
                label: 'Cancelar',
                icon: Icons.close,
                variant: RtButtonVariant.danger,
                isFullWidth: false,
                onPressed: _cancelNavigation,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, color: RtColors.brand, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingButton(IconData icon, VoidCallback onPressed) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        shape: BoxShape.circle,
        boxShadow: RtShadow.soft(),
      ),
      child: IconButton(
        icon: Icon(icon, color: RtColors.brand),
        onPressed: onPressed,
      ),
    );
  }

  void _recenterMap() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation,
          zoom: 16,
          tilt: 45,
          bearing: 90,
        ),
      ),
    );
  }

  void _toggleMapType() {
    RtSnackbar.show(context, message: 'Cambiar tipo de mapa', type: RtSnackbarType.info);
  }

  void _toggleVoice() {
    RtSnackbar.show(context, message: 'Instrucciones de voz activadas', type: RtSnackbarType.info);
  }

  void _cancelNavigation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar navegación'),
        content: const Text('Estás seguro de que deseas cancelar la navegación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: RtColors.error,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }

}

class RouteInstruction {
  final String instruction;
  final double distance;
  final int duration;
  final IconData turnIcon;
  final LatLng position;

  const RouteInstruction({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.turnIcon,
    required this.position,
  });
}
