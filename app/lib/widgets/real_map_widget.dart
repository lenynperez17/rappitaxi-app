import 'package:flutter/material.dart';
// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui' as ui;
import '../utils/logger.dart';

class RealMapWidget extends StatefulWidget {
  final Function(LatLng)? onLocationSelected;
  final bool showCurrentLocation;
  final bool enableInteraction;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  final Set<Polyline>? polylines;
  final double? zoom;
  final LatLng? initialCenter;

  const RealMapWidget({
    super.key,
    this.onLocationSelected,
    this.showCurrentLocation = true,
    this.enableInteraction = true,
    this.pickupLocation,
    this.dropoffLocation,
    this.polylines,
    this.zoom = 14.0,
    this.initialCenter,
  });

  @override
  State<RealMapWidget> createState() => _RealMapWidgetState();
}

class _RealMapWidgetState extends State<RealMapWidget> {
  GoogleMapController? _controller;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  LatLng _currentCenter = const LatLng(-12.0464, -77.0428); // Lima, Perú por defecto

  // ✅ Iconos 3D personalizados
  BitmapDescriptor? _passengerIcon;
  BitmapDescriptor? _destinationIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomIcons();
    _initializeMap();
  }

  // ✅ Cargar iconos 3D desde assets
  Future<void> _loadCustomIcons() async {
    try {
      _passengerIcon = await _getBitmapFromAsset('assets/images/markers/passenger_3d.png', 60);
      _destinationIcon = await _getBitmapFromAsset('assets/images/markers/destination_3d.png', 60);
      if (mounted) {
        _updateMarkers();
        setState(() {});
      }
    } catch (e) {
      AppLogger.warning('Error cargando iconos 3D: $e');
    }
  }

  // ✅ Convertir asset PNG a BitmapDescriptor
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

  Future<void> _initializeMap() async {
    try {
      // Usar ubicación inicial proporcionada o ubicación actual
      if (widget.initialCenter != null) {
        _currentCenter = widget.initialCenter!;
      } else if (widget.showCurrentLocation) {
        await _getCurrentLocation();
      }

      _updateMarkers();
      
      setState(() {
        _isLoading = false;
      });
      
      AppLogger.info('Mapa real inicializado correctamente');
    } catch (e) {
      AppLogger.error('Error inicializando mapa real', e);
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
      AppLogger.info('Ubicación actual obtenida: ${_currentCenter.latitude}, ${_currentCenter.longitude}');
    } catch (e) {
      AppLogger.warning('No se pudo obtener la ubicación actual', e);
      // Mantener Lima, Perú como centro por defecto
    }
  }

  void _updateMarkers() {
    _markers.clear();

    // ✅ Marcador de recogida (pasajero) - Icono 3D
    if (widget.pickupLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.pickupLocation!,
          icon: _passengerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(
            title: 'Punto de recogida',
            snippet: 'Aquí te recogeremos',
          ),
          zIndexInt: 2,
        ),
      );
    }

    // ✅ Marcador de destino - Icono 3D
    if (widget.dropoffLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: widget.dropoffLocation!,
          icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(
            title: 'Destino',
            snippet: 'Tu destino',
          ),
          zIndexInt: 1,
        ),
      );
    }
  }

  Future<void> _centerOnLocation() async {
    if (_controller == null) return;

    try {
      await _getCurrentLocation();
      await _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentCenter,
            zoom: widget.zoom!,
          ),
        ),
      );
      AppLogger.info('Mapa centrado en ubicación actual');
    } catch (e) {
      AppLogger.error('Error centrando mapa en ubicación', e);
    }
  }

  Future<void> _zoomIn() async {
    if (_controller == null) return;
    
    try {
      await _controller!.animateCamera(CameraUpdate.zoomIn());
    } catch (e) {
      AppLogger.error('Error haciendo zoom in', e);
    }
  }

  Future<void> _zoomOut() async {
    if (_controller == null) return;
    
    try {
      await _controller!.animateCamera(CameraUpdate.zoomOut());
    } catch (e) {
      AppLogger.error('Error haciendo zoom out', e);
    }
  }

  @override
  void didUpdateWidget(RealMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Actualizar marcadores si las ubicaciones cambiaron
    if (widget.pickupLocation != oldWidget.pickupLocation ||
        widget.dropoffLocation != oldWidget.dropoffLocation) {
      _updateMarkers();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Cargando mapa...',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Google Maps
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentCenter,
            zoom: widget.zoom!,
          ),
          onMapCreated: (GoogleMapController controller) {
            _controller = controller;
            AppLogger.info('Google Map creado correctamente');
          },
          markers: _markers,
          polylines: widget.polylines ?? {},
          myLocationEnabled: widget.showCurrentLocation,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          gestureRecognizers: widget.enableInteraction 
            ? <Factory<OneSequenceGestureRecognizer>>{} 
            : <Factory<OneSequenceGestureRecognizer>>{},
          onTap: widget.enableInteraction && widget.onLocationSelected != null
            ? (LatLng position) {
                widget.onLocationSelected!(position);
                AppLogger.info('Ubicación seleccionada: ${position.latitude}, ${position.longitude}');
              }
            : null,
        ),

        // Controles del mapa
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón de zoom in
              FloatingActionButton(
                mini: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                onPressed: _zoomIn,
                heroTag: 'zoom_in',
                child: Icon(Icons.add, color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 8),

              // Botón de zoom out
              FloatingActionButton(
                mini: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                onPressed: _zoomOut,
                heroTag: 'zoom_out',
                child: Icon(Icons.remove, color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 8),

              // Botón de ubicación actual
              if (widget.showCurrentLocation)
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  onPressed: _centerOnLocation,
                  heroTag: 'my_location',
                  child: Icon(
                    Icons.my_location,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}