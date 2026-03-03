import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_button.dart';
import '../../utils/logger.dart';

/// Pantalla para seleccionar una ubicación en el mapa con Google Maps
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

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _controller;
  LatLng? _selectedLocation;
  String _selectedAddress = 'Selecciona un punto en el mapa';
  bool _isLoading = true;
  bool _isGettingAddress = false;
  LatLng _currentCenter =
      const LatLng(-12.0464, -77.0428); // Lima, Peru por defecto

  @override
  void initState() {
    super.initState();
    _initializeMap();
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
      AppLogger.warning(
          'No se pudo obtener ubicación actual en map picker', e);
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
          _selectedAddress =
              '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
        }
      } else {
        _selectedAddress =
            '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
      }
    } catch (e) {
      AppLogger.error('Error obteniendo dirección desde coordenadas', e);
      _selectedAddress =
          '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
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
        appBar: RtAppBar(
          title: widget.title!,
          variant: RtAppBarVariant.gradient,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(RtColors.brand),
              ),
              const SizedBox(height: RtSpacing.base),
              Text(
                'Cargando mapa...',
                style: RtTypo.bodyLarge.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: RtAppBar(
        title: widget.title!,
        variant: RtAppBarVariant.gradient,
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: _confirmSelection,
              child: Text(
                'CONFIRMAR',
                style: RtTypo.labelLarge.copyWith(
                  color: RtColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Google Maps
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
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
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

          // Panel de información inferior
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: RtRadius.sheetTop,
                boxShadow: RtShadow.strong(),
              ),
              child: Padding(
                padding: const EdgeInsets.all(RtSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: RtColors.neutral300,
                          borderRadius: RtRadius.borderFull,
                        ),
                      ),
                    ),
                    const SizedBox(height: RtSpacing.base),

                    // Titulo
                    Text(
                      'Ubicación seleccionada',
                      style: RtTypo.headingSmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: RtSpacing.md),

                    // Dirección
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: RtColors.brand,
                          size: RtIconSize.sm,
                        ),
                        const SizedBox(width: RtSpacing.sm),
                        Expanded(
                          child: _isGettingAddress
                              ? Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          RtColors.brand,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: RtSpacing.sm),
                                    Text(
                                      'Obteniendo dirección...',
                                      style: RtTypo.bodyMedium.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  _selectedAddress,
                                  style: RtTypo.bodyMedium.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: RtSpacing.lg),

                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: RtButton(
                            label: 'Mi ubicación',
                            icon: Icons.my_location,
                            variant: RtButtonVariant.outlined,
                            onPressed: _centerOnCurrentLocation,
                          ),
                        ),
                        const SizedBox(width: RtSpacing.md),
                        Expanded(
                          child: RtButton(
                            label: 'Confirmar',
                            onPressed: _confirmSelection,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: RtSpacing.sm),
                  ],
                ),
              ),
            ),
          ),

          // Botones de zoom
          Positioned(
            bottom: 200,
            right: RtSpacing.base,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  elevation: 2,
                  onPressed: () {
                    _controller?.animateCamera(CameraUpdate.zoomIn());
                  },
                  heroTag: 'zoom_in_picker',
                  child: Icon(
                    Icons.add,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: RtSpacing.sm),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  elevation: 2,
                  onPressed: () {
                    _controller?.animateCamera(CameraUpdate.zoomOut());
                  },
                  heroTag: 'zoom_out_picker',
                  child: Icon(
                    Icons.remove,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
