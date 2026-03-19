import 'dart:math';
import 'package:flutter/material.dart';
// ignore_for_file: library_private_types_in_public_api
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../utils/map_marker_utils.dart';
import '../../utils/logger.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String? title;

  const MapPickerScreen({
    super.key,
    this.initialLocation,
    this.title,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _controller;
  String? _selectedAddress;
  bool _isLoading = true;
  bool _isGettingAddress = false;
  LatLng _currentCenter = const LatLng(-12.0464, -77.0428);
  LatLng _mapCenter = const LatLng(-12.0464, -77.0428);
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      if (widget.initialLocation != null) {
        _currentCenter = widget.initialLocation!;
        _mapCenter = widget.initialLocation!;
        await _getAddressFromCoordinates(_mapCenter);
      } else {
        await _getCurrentLocation();
        _mapCenter = _currentCenter;
        await _getAddressFromCoordinates(_mapCenter);
      }
      await _generateRefDots(_currentCenter);
    } catch (e) {
      AppLogger.error('Error initializing map picker', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateRefDots(LatLng center) async {
    final icon = await MapMarkerUtils.getReferencePointIcon();
    final random = Random();
    const int dotCount = 7;

    for (int i = 0; i < dotCount; i++) {
      final angle = (i / dotCount) * 2 * pi + (random.nextDouble() - 0.5) * 0.4;
      final dist = 0.0003 + random.nextDouble() * 0.0008;
      final pos = LatLng(
        center.latitude + cos(angle) * dist,
        center.longitude + sin(angle) * dist,
      );
      _markers.add(Marker(
        markerId: MarkerId('ref_dot_$i'),
        position: pos,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 1,
      ));
    }
    if (mounted) setState(() {});
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _currentCenter = LatLng(position.latitude, position.longitude);
    } catch (e) {
      AppLogger.warning('Could not get current location', e);
    }
  }

  Future<void> _getAddressFromCoordinates(LatLng location) async {
    setState(() => _isGettingAddress = true);
    try {
      final placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.street, p.subLocality, p.locality]
            .where((c) => c != null && c.isNotEmpty);
        _selectedAddress = parts.isNotEmpty
            ? parts.join(', ')
            : '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
      } else {
        _selectedAddress = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
      }
    } catch (e) {
      _selectedAddress = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
    } finally {
      if (mounted) setState(() => _isGettingAddress = false);
    }
  }

  void _confirmSelection() {
    Navigator.of(context).pop({
      'location': _selectedAddress,
      'coordinates': {
        'lat': _mapCenter.latitude,
        'lng': _mapCenter.longitude,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 16.0,
            ),
            onMapCreated: (controller) => _controller = controller,
            onCameraMove: (position) {
              _mapCenter = position.target;
            },
            onCameraIdle: () {
              _getAddressFromCoordinates(_mapCenter);
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Center pin (fixed, doesn't move with map)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: Icon(
                Icons.location_on,
                size: 48,
                color: Colors.orange.shade700,
              ),
            ),
          ),

          // Address badge (floating above center pin)
          if (_selectedAddress != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 100),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _isGettingAddress
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _selectedAddress!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ),

          // Back button (top left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
              ),
            ),
          ),

          // "Listo" button (bottom, full width, orange Rappi style)
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _confirmSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Listo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
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
    _controller?.dispose();
    super.dispose();
  }
}
