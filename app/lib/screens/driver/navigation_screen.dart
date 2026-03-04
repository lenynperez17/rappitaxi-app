// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../utils/map_marker_utils.dart';

class NavigationScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;
  
  const NavigationScreen({super.key, this.tripData});
  
  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> 
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;
  
  // Navigation state
  bool _isNavigating = false;
  final bool _showInstructions = true;
  String _currentInstruction = 'Calculando ruta...';
  String _nextInstruction = '';
  double _distanceToNext = 0;
  int _estimatedTime = 0;
  double _totalDistance = 0;
  int _totalTime = 0;
  
  // Current location - initialized from tripData or defaults
  late LatLng _currentLocation;
  late LatLng _destination;
  Timer? _locationTimer;
  double _currentBearing = 0.0; // Dynamic bearing for camera and marker rotation
  LatLng? _previousLocation; // For calculating bearing between points

  // ✅ Flag para prevenir operaciones después de dispose
  bool _isDisposed = false;

  // ✅ Iconos 3D personalizados para markers
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _passengerIcon;
  BitmapDescriptor? _destinationIcon;

  // Route instructions
  List<RouteInstruction> _instructions = [];
  int _currentInstructionIndex = 0;
  
  @override
  void initState() {
    super.initState();

    // Extract real coordinates from tripData if available
    final data = widget.tripData;
    if (data != null) {
      final pickupLat = data['pickupLat'] as double?;
      final pickupLng = data['pickupLng'] as double?;
      final destLat = data['destLat'] as double?;
      final destLng = data['destLng'] as double?;
      _currentLocation = LatLng(pickupLat ?? -12.0464, pickupLng ?? -77.0428);
      _destination = LatLng(destLat ?? -12.0464, destLng ?? -77.0428);
    } else {
      // Fallback to Lima center
      _currentLocation = LatLng(-12.0464, -77.0428);
      _destination = LatLng(-12.0464, -77.0428);
    }

    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 500),
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

  // ✅ Cargar iconos modernos desde MapMarkerUtils
  Future<void> _loadCustomIcons() async {
    try {
      _carIcon = await MapMarkerUtils.getCarTopViewIcon();
      _passengerIcon = await MapMarkerUtils.getPassengerIcon();
      _destinationIcon = await MapMarkerUtils.getDestinationIcon();

      if (mounted && !_isDisposed) {
        setState(() {});
        _drawRoute(); // Redibujar con iconos nuevos
      }
    } catch (e) {
      print('Error cargando iconos 3D: $e');
    }
  }

  // ✅ Convertir asset PNG a BitmapDescriptor con tamaño personalizado
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
    // ✅ Marcar como disposed ANTES de cancelar recursos
    _isDisposed = true;

    _pulseController.dispose();
    _slideController.dispose();
    _locationTimer?.cancel();
    _locationTimer = null;
    _mapController?.dispose();
    super.dispose();
  }
  
  void _initializeRoute() {
    // Simulate route instructions
    _instructions = [
      RouteInstruction(
        instruction: 'Dirígete hacia el norte por Av. Principal',
        distance: 250,
        duration: 60,
        turnIcon: Icons.arrow_upward,
        position: LatLng(-12.0851, -76.9770),
      ),
      RouteInstruction(
        instruction: 'Gira a la derecha en Calle 2',
        distance: 500,
        duration: 120,
        turnIcon: Icons.turn_right,
        position: LatLng(-12.0861, -76.9780),
      ),
      RouteInstruction(
        instruction: 'Continúa recto por 800 metros',
        distance: 800,
        duration: 180,
        turnIcon: Icons.straight,
        position: LatLng(-12.0881, -76.9800),
      ),
      RouteInstruction(
        instruction: 'Gira a la izquierda en Av. Secundaria',
        distance: 400,
        duration: 90,
        turnIcon: Icons.turn_left,
        position: LatLng(-12.0901, -76.9820),
      ),
      RouteInstruction(
        instruction: 'En la rotonda, toma la segunda salida',
        distance: 200,
        duration: 45,
        turnIcon: Icons.rotate_right,
        position: LatLng(-12.0921, -76.9840),
      ),
      RouteInstruction(
        instruction: 'Tu destino está a la derecha',
        distance: 50,
        duration: 15,
        turnIcon: Icons.location_on,
        position: LatLng(-12.0941, -76.9860),
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
    // Create route polyline
    List<LatLng> routePoints = _instructions.map((inst) => inst.position).toList();
    routePoints.add(_destination);

    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: PolylineId('route'),
        points: routePoints,
        color: ModernTheme.rappiOrange,
        width: 6,
        patterns: [],
      ),
    );

    _markers.clear();

    // ✅ Marker del carro (conductor) - Icono moderno
    _markers.add(
      Marker(
        markerId: MarkerId('car'),
        position: _currentLocation,
        icon: _carIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(title: 'Tu ubicación'),
        anchor: Offset(0.5, 0.5),
        zIndex: 3,
      ),
    );

    // ✅ Marker del pasajero - Icono moderno
    if (_instructions.isNotEmpty) {
      _markers.add(
        Marker(
          markerId: MarkerId('passenger'),
          position: _instructions.first.position,
          icon: _passengerIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(title: 'Pasajero'),
          zIndex: 2,
        ),
      );
    }

    // ✅ Marker del destino - Icono moderno
    _markers.add(
      Marker(
        markerId: MarkerId('destination'),
        position: _destination,
        icon: _destinationIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(title: 'Destino'),
        zIndex: 1,
      ),
    );

    setState(() {});
  }
  
  void _startNavigation() {
    setState(() {
      _isNavigating = true;
    });
    
    // Simulate location updates
    _locationTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      // ✅ TRIPLE VERIFICACIÓN para prevenir simulación después de dispose
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
    // ✅ Verificar mounted antes de setState
    if (!mounted || _isDisposed) return;

    if (_currentInstructionIndex < _instructions.length - 1) {
      setState(() {
        _distanceToNext -= 50; // Reduce 50 meters
        _estimatedTime = math.max(0, _estimatedTime - 2);
        
        if (_distanceToNext <= 50) {
          _currentInstructionIndex++;
          _updateCurrentInstruction();
          
          // Voice instruction simulation
          _showVoiceNotification();
        }
        
        // Update current location marker
        _currentLocation = _instructions[_currentInstructionIndex].position;
        _updateLocationMarker();
      });
    } else {
      _arriveAtDestination();
    }
  }
  
  void _updateLocationMarker() {
    // Calculate bearing from previous location
    if (_previousLocation != null) {
      final lat1 = _previousLocation!.latitude * math.pi / 180;
      final lat2 = _currentLocation.latitude * math.pi / 180;
      final dLng = (_currentLocation.longitude - _previousLocation!.longitude) * math.pi / 180;
      final y = math.sin(dLng) * math.cos(lat2);
      final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
      _currentBearing = (math.atan2(y, x) * 180 / math.pi + 360) % 360;
    }
    _previousLocation = _currentLocation;

    _markers.removeWhere((marker) => marker.markerId.value == 'car');
    _markers.add(
      Marker(
        markerId: MarkerId('car'),
        position: _currentLocation,
        icon: _carIcon ?? BitmapDescriptor.defaultMarker,
        anchor: Offset(0.5, 0.5),
        flat: true,
        rotation: _currentBearing,
        zIndex: 3,
      ),
    );

    // Camera follows car with dynamic bearing (like Google Maps Navigation)
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(
        target: _currentLocation,
        zoom: 17.5,
        bearing: _currentBearing,
        tilt: 45.0,
      )),
    );
  }
  
  void _showVoiceNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.volume_up, color: Theme.of(context).colorScheme.surface),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                _currentInstruction,
                style: TextStyle(color: Theme.of(context).colorScheme.surface),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  void _arriveAtDestination() {
    _locationTimer?.cancel();
    setState(() {
      _isNavigating = false;
      _currentInstruction = '¡Has llegado a tu destino!';
    });
    
    _showArrivalDialog();
  }
  
  void _showArrivalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: ModernTheme.success, size: 32),
            SizedBox(width: 12),
            Text('¡Llegaste!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Has llegado a tu destino exitosamente.'),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.route, size: 20, color: context.secondaryText),
                SizedBox(width: 8),
                Text('${(_totalDistance / 1000).toStringAsFixed(1)} km'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer, size: 20, color: context.secondaryText),
                SizedBox(width: 8),
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
            child: Text('Finalizar'),
          ),
        ],
      ),
    );
  }
  
  /// Maneja el intento de salir de la navegación
  void _handleBackPressed() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Salir de la navegación'),
        content: const Text('¿Deseas salir de la navegación? El viaje seguirá activo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('Sí, salir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBackPressed();
      },
      child: Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 17.5,
              tilt: 45,
              bearing: _currentBearing,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _applyMapStyle();
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
          
          // Top navigation bar
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
          
          // Bottom instruction panel
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
          
          // Floating action buttons
          Positioned(
            right: 16,
            bottom: _showInstructions ? 280 : 100,
            child: Column(
              children: [
                _buildFloatingButton(
                  Icons.my_location,
                  () => _recenterMap(),
                ),
                SizedBox(height: 12),
                _buildFloatingButton(
                  Icons.layers,
                  () => _toggleMapType(),
                ),
                SizedBox(height: 12),
                _buildFloatingButton(
                  Icons.volume_up,
                  () => _toggleVoice(),
                ),
              ],
            ),
          ),
          
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: ModernTheme.getCardShadow(context),
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: context.primaryText),
                onPressed: _handleBackPressed,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
  
  Widget _buildNavigationBar() {
    // UI: top bar semi-transparente con instrucciones turn-by-turn
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModernTheme.rappiOrange.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: ModernTheme.getFloatingShadow(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current instruction
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _currentInstructionIndex < _instructions.length
                      ? _instructions[_currentInstructionIndex].turnIcon
                      : Icons.location_on,
                  color: Theme.of(context).colorScheme.surface,
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentInstruction,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.surface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${_distanceToNext.round()} m',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 16),
                        Text(
                          '$_estimatedTime seg',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
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
          
          // Progress bar
          Container(
            margin: EdgeInsets.only(top: 12),
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: (_currentInstructionIndex + 1) / _instructions.length,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.surface),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInstructionPanel() {
    // UI: Mini-card de destino en la parte inferior (compacta)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ModernTheme.getFloatingShadow(context),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.secondaryText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16),
          
          // Trip info
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
                color: context.secondaryText.withValues(alpha: 0.3),
              ),
              _buildInfoItem(
                Icons.timer,
                '${(_totalTime / 60).round()} min',
                'Tiempo estimado',
              ),
              Container(
                width: 1,
                height: 40,
                color: context.secondaryText.withValues(alpha: 0.3),
              ),
              _buildInfoItem(
                Icons.speed,
                '45 km/h',
                'Velocidad',
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Next instruction preview
          if (_nextInstruction.isNotEmpty)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.subdirectory_arrow_right, 
                    color: context.secondaryText),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Luego:',
                          style: TextStyle(
                            color: context.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _nextInstruction,
                          style: TextStyle(
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
          SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isNavigating ? null : _startNavigation,
                  icon: Icon(_isNavigating ? Icons.pause : Icons.play_arrow),
                  label: Text(_isNavigating ? 'Navegando...' : 'Iniciar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.rappiOrange,
                    foregroundColor: Theme.of(context).colorScheme.surface,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _cancelNavigation,
                icon: Icon(Icons.close),
                label: Text('Cancelar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.error,
                  foregroundColor: Theme.of(context).colorScheme.surface,
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: ModernTheme.rappiOrange, size: 24),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.primaryText,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.secondaryText,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFloatingButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: IconButton(
        icon: Icon(icon, color: ModernTheme.rappiOrange),
        onPressed: onPressed,
      ),
    );
  }
  
  void _recenterMap() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation,
          zoom: 17.5,
          tilt: 45,
          bearing: _currentBearing,
        ),
      ),
    );
  }
  
  void _toggleMapType() {
    // Toggle between normal and satellite view
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cambiar tipo de mapa'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  void _toggleVoice() {
    // Toggle voice instructions
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Instrucciones de voz activadas'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  void _cancelNavigation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancelar navegación'),
        content: Text('¿Estás seguro de que deseas cancelar la navegación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: ModernTheme.error,
            ),
            child: Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }
  
  void _applyMapStyle() {
    // Apply custom map style
    const String mapStyle = '''
    [
      {
        "featureType": "poi",
        "elementType": "labels",
        "stylers": [{"visibility": "off"}]
      }
    ]
    ''';
    _mapController?.setMapStyle(mapStyle);
  }
}

class RouteInstruction {
  final String instruction;
  final double distance;
  final int duration;
  final IconData turnIcon;
  final LatLng position;
  
  RouteInstruction({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.turnIcon,
    required this.position,
  });
}