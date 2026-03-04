import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/google_maps_service.dart';
import '../core/config/app_config.dart';

/// Provider real para ubicación ✅ IMPLEMENTACIÓN REAL
class LocationProvider with ChangeNotifier {
  final GoogleMapsService _mapsService = GoogleMapsService();
  
  LatLng? _currentLocation;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentAddress;
  bool _locationServiceEnabled = false;
  bool _permissionGranted = false;

  // Getters
  LatLng? get currentLocation => _currentLocation;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentAddress => _currentAddress;
  bool get locationServiceEnabled => _locationServiceEnabled;
  bool get permissionGranted => _permissionGranted;

  /// Inicializar provider
  Future<void> initialize() async {
    try {
      // API Key desde configuración centralizada
      await _mapsService.initialize(googleMapsApiKey: AppConfig.googleMapsApiKey);
      await getCurrentLocation();
    } catch (e) {
      debugPrint('LocationProvider: Error initializing - $e');
      _setError('Error inicializando servicio de ubicación');
    }
  }

  /// Obtener ubicación actual
  Future<void> getCurrentLocation() async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _mapsService.getCurrentLocation();
      
      if (result.success) {
        _currentLocation = LatLng(result.latitude!, result.longitude!);
        _locationServiceEnabled = true;
        _permissionGranted = true;
        
        // Obtener dirección de la ubicación
        await _updateCurrentAddress();
        
        _setLoading(false);
      } else {
        _setError(result.error ?? 'Error obteniendo ubicación');
        _locationServiceEnabled = false;
        _permissionGranted = false;
        _setLoading(false);
      }
    } catch (e) {
      _setError('Error de ubicación: $e');
      _setLoading(false);
    }
  }

  /// Actualizar dirección actual
  Future<void> _updateCurrentAddress() async {
    if (_currentLocation == null) return;

    try {
      final result = await _mapsService.reverseGeocode(
        _currentLocation!.latitude, 
        _currentLocation!.longitude
      );
      
      if (result.success) {
        _currentAddress = result.formattedAddress;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('LocationProvider: Error getting address - $e');
    }
  }

  /// Buscar lugar por dirección
  Future<LatLng?> searchLocation(String address) async {
    try {
      final result = await _mapsService.geocodeAddress(address);
      
      if (result.success) {
        return LatLng(result.latitude!, result.longitude!);
      } else {
        _setError(result.error ?? 'No se encontró la dirección');
        return null;
      }
    } catch (e) {
      _setError('Error buscando ubicación: $e');
      return null;
    }
  }

  /// Obtener sugerencias de autocompletado
  Future<List<Map<String, dynamic>>> getPlaceAutocomplete(String input) async {
    try {
      final result = await _mapsService.getPlaceAutocomplete(input);
      
      if (result.success) {
        return result.predictions!.map((prediction) => {
          'placeId': prediction.placeId,
          'description': prediction.description,
          'mainText': prediction.mainText,
          'secondaryText': prediction.secondaryText,
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('LocationProvider: Error getting autocomplete - $e');
      return [];
    }
  }

  /// Obtener direcciones entre dos puntos
  Future<Map<String, dynamic>?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final result = await _mapsService.getDirections(
        origin: origin,
        destination: destination,
      );
      
      if (result.success) {
        return {
          'polylinePoints': result.polylinePoints,
          'distance': result.distance,
          'duration': result.duration,
          'distanceValue': result.distanceValue,
          'durationValue': result.durationValue,
          'steps': result.steps,
        };
      } else {
        _setError(result.error ?? 'Error obteniendo direcciones');
        return null;
      }
    } catch (e) {
      _setError('Error calculando ruta: $e');
      return null;
    }
  }

  /// Buscar lugares cercanos
  Future<List<Map<String, dynamic>>> searchNearbyPlaces({
    required String type,
    double radius = 1000,
  }) async {
    if (_currentLocation == null) return [];

    try {
      final result = await _mapsService.searchNearbyPlaces(
        location: _currentLocation!,
        radius: radius,
        type: type,
      );
      
      if (result.success) {
        return result.places!.map((place) => {
          'placeId': place.placeId,
          'name': place.name,
          'vicinity': place.vicinity,
          'latitude': place.latitude,
          'longitude': place.longitude,
          'rating': place.rating,
          'types': place.types,
          'isOpen': place.isOpen,
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('LocationProvider: Error searching nearby places - $e');
      return [];
    }
  }

  /// Actualizar ubicación manualmente
  void updateLocation(LatLng newLocation) {
    _currentLocation = newLocation;
    _updateCurrentAddress();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}