import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../shared/utils/logger.dart';

/// Proveedor de servicios de ubicación
class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  String? _currentAddress;
  bool _isLoading = false;
  String? _error;

  // Getters
  Position? get currentPosition => _currentPosition;
  String? get currentAddress => _currentAddress;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLocation => _currentPosition != null;

  /// Verificar si los servicios de ubicación están habilitados
  Future<bool> checkLocationService() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setError('Los servicios de ubicación están deshabilitados');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _setError('Permisos de ubicación denegados');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _setError('Permisos de ubicación permanentemente denegados');
      return false;
    }

    return true;
  }

  /// Obtener ubicación actual
  Future<Position?> getCurrentLocation() async {
    try {
      _setLoading(true);
      _clearError();

      if (!await checkLocationService()) {
        _setLoading(false);
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentPosition = position;
      await _getAddressFromPosition(position);
      
      _setLoading(false);
      return position;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  /// Obtener dirección desde coordenadas
  Future<void> _getAddressFromPosition(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        _currentAddress = '${place.street}, ${place.locality}, ${place.country}';
        notifyListeners();
      }
    } catch (e) {
      // No es crítico si no se puede obtener la dirección
      if (kDebugMode) {
        Logger().warn('Error obteniendo dirección', error: e);
      }
    }
  }

  /// Obtener coordenadas desde una dirección
  Future<Position?> getLocationFromAddress(String address) async {
    try {
      _setLoading(true);
      _clearError();

      List<Location> locations = await locationFromAddress(address);
      
      if (locations.isNotEmpty) {
        final location = locations.first;
        final position = Position(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
        
        _setLoading(false);
        return position;
      }
      
      _setError('No se encontró la ubicación para: $address');
      _setLoading(false);
      return null;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  /// Stream de ubicación en tiempo real
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  /// Calcular distancia entre dos puntos
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Limpiar datos de ubicación
  void clearLocation() {
    _currentPosition = null;
    _currentAddress = null;
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}