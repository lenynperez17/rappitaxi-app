import 'package:flutter/material.dart';
// ignore_for_file: library_private_types_in_public_api
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../widgets/common/rappi_app_bar.dart';
import '../../utils/logger.dart';
import '../../utils/map_marker_utils.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String? title;

  const MapPickerScreen({
    super.key,
    this.initialLocation,
    this.title = 'Seleccionar ubicación',
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _controller;
  LatLng? _selectedLocation;
  String _selectedAddress = 'Selecciona un punto en el mapa';
  bool _isLoading = true;
  bool _isGettingAddress = false;
  LatLng _currentCenter = const LatLng(-12.0464, -77.0428); // Lima, Perú por defecto

  // Icono moderno para marcador
  BitmapDescriptor? _selectedIcon;

  // Controlador de animacion de bounce para el pin central
  late AnimationController _pinAnimController;
  late Animation<double> _pinAnimation;

  @override
  void initState() {
    super.initState();
    _loadCustomIcon();
    _initializeMap();

    // Animacion de bounce para el pin
    _pinAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _pinAnimation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _pinAnimController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadCustomIcon() async {
    _selectedIcon = await MapMarkerUtils.getOriginIcon();
    if (mounted) setState(() {});
  }

  Future<void> _initializeMap() async {
    try {
      // Usar ubicación inicial si se proporciona
      if (widget.initialLocation != null) {
        _currentCenter = widget.initialLocation!;
        _selectedLocation = widget.initialLocation!;
        await _getAddressFromCoordinates(_selectedLocation!);
      } else {
        // Intentar obtener ubicación actual
        await _getCurrentLocation();
      }
    } catch (e) {
      AppLogger.error('Error inicializando mapa picker', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestedPermission = await Geolocator.requestPermission();
        if (requestedPermission == LocationPermission.denied) {
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _currentCenter = LatLng(position.latitude, position.longitude);
      AppLogger.info('Ubicación actual obtenida para map picker');
    } catch (e) {
      AppLogger.warning('No se pudo obtener ubicación actual en map picker', e);
    }
  }

  Future<void> _getAddressFromCoordinates(LatLng location) async {
    setState(() {
      _isGettingAddress = true;
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final addressComponents = [
          placemark.street,
          placemark.subLocality,
          placemark.locality,
          placemark.subAdministrativeArea,
          placemark.administrativeArea,
        ].where((component) => component != null && component.isNotEmpty);

        _selectedAddress = addressComponents.join(', ');
        if (_selectedAddress.isEmpty) {
          _selectedAddress = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
        }
      } else {
        _selectedAddress = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
      }
    } catch (e) {
      AppLogger.error('Error obteniendo dirección desde coordenadas', e);
      _selectedAddress = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
    } finally {
      setState(() {
        _isGettingAddress = false;
      });
    }
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    _getAddressFromCoordinates(location);
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      Navigator.of(context).pop({
        'location': _selectedAddress,
        'coordinates': {
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude,
        },
      });
    }
  }

  Future<void> _centerOnCurrentLocation() async {
    if (_controller == null) return;

    try {
      await _getCurrentLocation();
      await _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentCenter,
            zoom: 16.0,
          ),
        ),
      );
      
      // Seleccionar automáticamente la ubicación actual
      setState(() {
        _selectedLocation = _currentCenter;
      });
      await _getAddressFromCoordinates(_currentCenter);
      
      AppLogger.info('Mapa centrado en ubicación actual');
    } catch (e) {
      AppLogger.error('Error centrando mapa en ubicación actual', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: RappiAppBar(title: widget.title!),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
              ),
              SizedBox(height: 16),
              Text(
                'Cargando mapa...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Google Maps - fullscreen
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 15.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              _controller = controller;
            },
            onTap: _onMapTapped,
            markers: _selectedLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _selectedLocation!,
                      icon: _selectedIcon ?? BitmapDescriptor.defaultMarker,
                      infoWindow: const InfoWindow(
                        title: 'Ubicación seleccionada',
                      ),
                    ),
                  }
                : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Search bar flotante arriba con sombra
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Botón de regreso
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: context.primaryText),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                // Search bar
                Expanded(
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              color: ModernTheme.rappiOrange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _isGettingAddress
                                ? Row(
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            ModernTheme.rappiOrange,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Obteniendo dirección...',
                                          style: TextStyle(fontSize: 13)),
                                    ],
                                  )
                                : Text(
                                    _selectedAddress,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _selectedLocation != null
                                          ? context.primaryText
                                          : context.secondaryText,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Pin animado (bounce) en el centro del mapa
          Center(
            child: AnimatedBuilder(
              animation: _pinAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _pinAnimation.value - 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ModernTheme.rappiOrange,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: ModernTheme.rappiOrange
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.location_on,
                            color: Colors.white, size: 28),
                      ),
                      // Sombra del pin en el suelo
                      Container(
                        width: 10,
                        height: 4,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Botones de zoom (lado derecho, arriba del bottom bar)
          Positioned(
            bottom: 160,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  onPressed: () {
                    _controller?.animateCamera(CameraUpdate.zoomIn());
                  },
                  heroTag: 'zoom_in_picker',
                  child: Icon(Icons.add, color: context.primaryText),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  onPressed: () {
                    _controller?.animateCamera(CameraUpdate.zoomOut());
                  },
                  heroTag: 'zoom_out_picker',
                  child: Icon(Icons.remove, color: context.primaryText),
                ),
              ],
            ),
          ),

          // Bottom bar fija con botones de accion
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: ModernTheme.getCardShadow(context),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _centerOnCurrentLocation,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text('Mi ubicación'),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: ModernTheme.rappiOrange),
                            foregroundColor: ModernTheme.rappiOrange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _confirmSelection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ModernTheme.rappiOrange,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Confirmar',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pinAnimController.dispose();
    _controller?.dispose();
    super.dispose();
  }
}