// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../utils/map_marker_utils.dart';
import 'dart:async';

class RealMapWidget extends StatefulWidget {
  final Function(LatLng)? onLocationSelected;
  final bool showCurrentLocation;
  final bool enableInteraction;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  final Set<Polyline>? polylines;

  const RealMapWidget({
    super.key,
    this.onLocationSelected,
    this.showCurrentLocation = true,
    this.enableInteraction = true,
    this.pickupLocation,
    this.dropoffLocation,
    this.polylines,
  });

  @override
  _RealMapWidgetState createState() => _RealMapWidgetState();
}

class _RealMapWidgetState extends State<RealMapWidget> {
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  StreamSubscription<Position>? _locationSubscription;

  // Iconos modernos
  BitmapDescriptor? _currentLocationIcon;
  BitmapDescriptor? _originIcon;
  BitmapDescriptor? _destinationIcon;

  // Lima, Perú como ubicación por defecto
  static const LatLng _defaultLocation = LatLng(-12.0464, -77.0428);

  @override
  void initState() {
    super.initState();
    _loadCustomIcons();
    _initializeLocation();
  }

  Future<void> _loadCustomIcons() async {
    _currentLocationIcon = await MapMarkerUtils.getCurrentLocationIcon();
    _originIcon = await MapMarkerUtils.getOriginIcon();
    _destinationIcon = await MapMarkerUtils.getDestinationIcon();
    if (mounted) {
      _setupMarkers();
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _initializeLocation() async {
    if (widget.showCurrentLocation) {
      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentPosition = position;
        });
        _animateToPosition(position);
        
        // Suscribirse a actualizaciones de ubicación
        _locationSubscription = _locationService.locationStream.listen((position) {
          if (mounted) {
            setState(() {
              _currentPosition = position;
              _updateCurrentLocationMarker();
            });
          }
        });
        
        _locationService.startLocationTracking();
      }
    }
  }

  void _setupMarkers() {
    final markers = <Marker>{};

    // Marcador de ubicación actual (icono moderno con halo)
    if (_currentPosition != null && widget.showCurrentLocation) {
      markers.add(
        Marker(
          markerId: MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: _currentLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: 'Mi ubicación'),
        ),
      );
    }

    // Marcador de punto de recogida (icono verde moderno)
    if (widget.pickupLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('pickup'),
          position: widget.pickupLocation!,
          icon: _originIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Punto de recogida'),
        ),
      );
    }

    // Marcador de destino (pin rojo moderno)
    if (widget.dropoffLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('dropoff'),
          position: widget.dropoffLocation!,
          icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destino'),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _updateCurrentLocationMarker() {
    if (_currentPosition != null && widget.showCurrentLocation) {
      final marker = Marker(
        markerId: MarkerId('current_location'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: _currentLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: 'Mi ubicación'),
      );

      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'current_location');
        _markers.add(marker);
      });
    }
  }

  void _animateToPosition(Position position) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        16.0,
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // Si hay ubicaciones de pickup y dropoff, ajustar la cámara
    if (widget.pickupLocation != null && widget.dropoffLocation != null) {
      _fitBounds();
    }
  }

  void _fitBounds() {
    if (widget.pickupLocation != null && widget.dropoffLocation != null) {
      final bounds = _locationService.getBounds(
        widget.pickupLocation!,
        widget.dropoffLocation!,
      );
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    }
  }

  void _onTap(LatLng location) {
    if (widget.enableInteraction && widget.onLocationSelected != null) {
      widget.onLocationSelected!(location);
      
      // Agregar marcador temporal
      setState(() {
        _markers.add(
          Marker(
            markerId: MarkerId('selected_location'),
            position: location,
            icon: _originIcon ?? BitmapDescriptor.defaultMarker,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Actualizar marcadores cuando cambien las props
    _setupMarkers();

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _currentPosition != null
                ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                : _defaultLocation,
            zoom: 15.0,
          ),
          myLocationEnabled: false, // Usamos nuestro propio marcador
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          markers: _markers,
          polylines: widget.polylines ?? {},
          onTap: widget.enableInteraction ? _onTap : null,
          style: '''
          [
            {
              "featureType": "poi.business",
              "stylers": [{"visibility": "off"}]
            },
            {
              "featureType": "transit",
              "elementType": "labels.icon",
              "stylers": [{"visibility": "off"}]
            }
          ]
          ''',
        ),
        
        // Botón de centrar en ubicación actual
        if (widget.showCurrentLocation)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              onPressed: () {
                if (_currentPosition != null) {
                  _animateToPosition(_currentPosition!);
                }
              },
              child: Icon(
                Icons.my_location,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          
        // Indicador de carga
        if (_currentPosition == null && widget.showCurrentLocation)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Obteniendo ubicación...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}