import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

/// Snaps GPS coordinates to the nearest road using Google Maps Roads API.
///
/// Features: debounce (3s), position buffering, caching, and fallback to raw GPS.
class RoadSnappingService {
  RoadSnappingService._();
  static final RoadSnappingService instance = RoadSnappingService._();

  // Google Maps Roads API key (same as Maps SDK key in AndroidManifest/Info.plist)
  static const String _apiKey = 'AIzaSyBSNK-cUnPCHof9ObXq0whK0ffSyCfJTqY';
  static const String _baseUrl = 'https://roads.googleapis.com/v1/snapToRoads';

  // Buffer of recent raw GPS positions for batch snapping
  final List<LatLng> _positionBuffer = [];
  static const int _maxBufferSize = 5;

  // Debounce: minimum interval between API calls
  DateTime? _lastApiCall;
  static const Duration _debounceInterval = Duration(seconds: 3);

  // Cache: last snapped result
  LatLng? _lastSnappedPosition;
  LatLng? _lastRawPosition;
  static const double _cacheThresholdMeters = 10.0;

  // Stats
  int _apiCallCount = 0;
  int _cacheHitCount = 0;

  /// Add a raw GPS position and get a road-snapped position back.
  ///
  /// Returns the snapped position if available, or the raw position as fallback.
  Future<LatLng> snapToRoad(LatLng rawPosition) async {
    // Add to buffer
    _positionBuffer.add(rawPosition);
    if (_positionBuffer.length > _maxBufferSize) {
      _positionBuffer.removeAt(0);
    }

    // Check cache: if we haven't moved much, return cached snap
    if (_lastSnappedPosition != null && _lastRawPosition != null) {
      final distance = _approximateDistance(_lastRawPosition!, rawPosition);
      if (distance < _cacheThresholdMeters) {
        _cacheHitCount++;
        return _lastSnappedPosition!;
      }
    }

    // Debounce: skip API call if too recent
    final now = DateTime.now();
    if (_lastApiCall != null && now.difference(_lastApiCall!) < _debounceInterval) {
      // Return last snapped position or raw as fallback
      return _lastSnappedPosition ?? rawPosition;
    }

    // Call Roads API
    try {
      _lastApiCall = now;
      final snapped = await _callSnapToRoads();
      if (snapped != null) {
        _lastSnappedPosition = snapped;
        _lastRawPosition = rawPosition;
        _apiCallCount++;
        if (_apiCallCount % 50 == 0) {
          AppLogger.debug('🛣️ RoadSnap stats: $apiCallCount API calls, $_cacheHitCount cache hits');
        }
        return snapped;
      }
    } catch (e) {
      AppLogger.error('🛣️ Road snap failed: $e');
    }

    // Fallback to raw GPS
    return rawPosition;
  }

  /// Call the Google Maps Roads API with buffered positions.
  Future<LatLng?> _callSnapToRoads() async {
    if (_positionBuffer.isEmpty) return null;

    // Build path parameter from buffered positions
    final path = _positionBuffer
        .map((p) => '${p.latitude},${p.longitude}')
        .join('|');

    final url = Uri.parse('$_baseUrl?path=$path&interpolate=false&key=$_apiKey');

    final response = await http.get(url).timeout(
      const Duration(seconds: 3),
      onTimeout: () => http.Response('{"error": "timeout"}', 408),
    );

    if (response.statusCode != 200) {
      AppLogger.warning('🛣️ Roads API returned ${response.statusCode}');
      return null;
    }

    final data = json.decode(response.body);
    final snappedPoints = data['snappedPoints'] as List?;

    if (snappedPoints == null || snappedPoints.isEmpty) return null;

    // Return the last snapped point (most recent position)
    final lastPoint = snappedPoints.last;
    final location = lastPoint['location'];
    return LatLng(
      (location['latitude'] as num).toDouble(),
      (location['longitude'] as num).toDouble(),
    );
  }

  /// Approximate distance in meters between two LatLng points (Equirectangular).
  double _approximateDistance(LatLng a, LatLng b) {
    const metersPerDegree = 111320.0;
    final dLat = (b.latitude - a.latitude) * metersPerDegree;
    final dLng = (b.longitude - a.longitude) * metersPerDegree * 0.85; // cos correction for ~12° lat
    return (dLat * dLat + dLng * dLng).abs();
  }

  /// Reset state (call when driver goes offline).
  void reset() {
    _positionBuffer.clear();
    _lastSnappedPosition = null;
    _lastRawPosition = null;
    _lastApiCall = null;
  }

  int get apiCallCount => _apiCallCount;
  int get cacheHitCount => _cacheHitCount;
}
