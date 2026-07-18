import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_service.dart';
import 'maps_service.dart' as backend;

/// Servicio de Google Maps (thin wrapper).
///
/// Ronda 214 CRÍTICO/SECURITY: la versión anterior de este archivo (728
/// líneas) hacía llamadas directas a `maps.googleapis.com` con
/// `_googleMapsApiKey` INCRUSTADA en el APK. Cualquiera con acceso al
/// binario podía extraerla en minutos y usarla para consumir el cuota de
/// Google → factura inflada por terceros.
///
/// Ahora TODAS las llamadas a Google pasan por el backend Rapi Team
/// (`api/src/app/api/maps/*` que cascadea OSRM → Mapbox → Google con la key
/// oculta, costo ~$0). La API pública de esta clase se mantiene idéntica
/// para no romper callers (LocationProvider, modern_driver_home).
///
/// Métodos migrados:
///   - `getPlaceAutocomplete` → `MapsService.autocomplete`
///   - `getDirections`        → `MapsService.getDirections`
///
/// Métodos deprecados (sin equivalente en backend; devuelven error
/// explícito para que el caller sepa migrar o quitar el feature):
///   - `geocodeAddress`, `reverseGeocode`, `searchNearbyPlaces`,
///     `getDistanceMatrix`.
///
/// Métodos independientes de Google (siguen funcionando):
///   - `getCurrentLocation` (Geolocator/OS).
class GoogleMapsService {
  static final GoogleMapsService _instance = GoogleMapsService._internal();
  factory GoogleMapsService() => _instance;
  GoogleMapsService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final backend.MapsService _backend = backend.MapsService();

  bool _initialized = false;

  /// El parámetro `googleMapsApiKey` se ignora — la key vive en el backend.
  /// Se mantiene el signature para no romper callers.
  Future<void> initialize({
    required String googleMapsApiKey,
  }) async {
    if (_initialized) return;
    try {
      // La key ya no se guarda en cliente. Firebase para logEvent solo.
      await _firebaseService.initialize();
      _initialized = true;
      debugPrint('🗺️ GoogleMapsService: init (llamadas via backend proxy)');
      await _firebaseService.analytics
          .logEvent(name: 'google_maps_service_initialized');
    } catch (e) {
      debugPrint('🗺️ GoogleMapsService: Error initializing - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      rethrow;
    }
  }

  /// Ubicación actual del dispositivo — Geolocator, no Google.
  Future<LocationResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.error('Los servicios de ubicación están deshabilitados');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.error('Permisos de ubicación denegados');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return LocationResult.error(
          'Permisos de ubicación denegados permanentemente',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      );
    } catch (e) {
      debugPrint('🗺️ GoogleMapsService.getCurrentLocation: $e');
      return LocationResult.error('Error obteniendo ubicación: $e');
    }
  }

  /// DEPRECATED: no hay endpoint de forward geocode en el backend.
  /// Use el flujo autocomplete → placeDetails que ya devuelve coordenadas.
  Future<GeocodingResult> geocodeAddress(String address) async {
    debugPrint(
      '🗺️ geocodeAddress deprecated — usar autocomplete + placeDetails',
    );
    return GeocodingResult.error(
      'Método no disponible. Usar getPlaceAutocomplete + placeDetails.',
    );
  }

  /// DEPRECATED: no hay endpoint de reverse geocode en el backend.
  /// Los callers de LocationProvider ya toleran null/error acá.
  Future<ReverseGeocodingResult> reverseGeocode(double lat, double lng) async {
    debugPrint('🗺️ reverseGeocode deprecated — backend no expone endpoint');
    return ReverseGeocodingResult.error('Reverse geocode no disponible.');
  }

  /// Autocomplete via backend proxy (cascade Mapbox/Google).
  Future<AutocompleteResult> getPlaceAutocomplete(
    String input, {
    String language = 'es',
    String? country,
  }) async {
    if (input.trim().length < 2) return AutocompleteResult.success(const []);
    try {
      final preds = await _backend.autocomplete(
        input,
        languageCode: language,
        countryCode: country ?? 'pe',
      );
      return AutocompleteResult.success(
        preds
            .map((p) => PlacePrediction(
                  placeId: p.placeId,
                  description: p.description,
                  mainText: p.mainText,
                  secondaryText: p.secondaryText,
                  types: const [],
                ))
            .toList(growable: false),
      );
    } catch (e) {
      debugPrint('🗺️ getPlaceAutocomplete: $e');
      return AutocompleteResult.error('Error obteniendo sugerencias');
    }
  }

  /// Direcciones via backend proxy (cascade OSRM/Mapbox/Google).
  Future<DirectionsResult> getDirections({
    required LatLng origin,
    required LatLng destination,
    TravelMode mode = TravelMode.driving,
    bool avoidTolls = false,
    bool avoidHighways = false,
    bool avoidFerries = false,
  }) async {
    try {
      final modeStr = switch (mode) {
        TravelMode.walking => 'walking',
        TravelMode.bicycling => 'cycling',
        _ => 'driving',
      };
      final route = await _backend.getDirections(
        origin: origin,
        destination: destination,
        mode: modeStr,
      );
      if (route == null || route.points.isEmpty) {
        return DirectionsResult.error('No se pudo calcular la ruta');
      }
      return DirectionsResult.success(
        polylinePoints: route.points,
        distance: '${(route.distanceMeters / 1000).toStringAsFixed(2)} km',
        distanceValue: route.distanceMeters,
        duration: '${(route.durationSeconds / 60).round()} min',
        durationValue: route.durationSeconds,
        startAddress: null,
        endAddress: null,
        steps: const <DirectionStep>[],
      );
    } catch (e) {
      debugPrint('🗺️ getDirections: $e');
      return DirectionsResult.error('Error obteniendo direcciones');
    }
  }

  /// DEPRECATED: backend no expone /nearby-places. Feature no crítico
  /// (nunca se usó en la UI, solo estaba disponible en la API).
  Future<PlacesSearchResult> searchNearbyPlaces({
    required LatLng location,
    required double radius,
    required String type,
    String? keyword,
  }) async {
    debugPrint('🗺️ searchNearbyPlaces deprecated — no disponible');
    return PlacesSearchResult.success(const <PlaceInfo>[]);
  }

  /// DEPRECATED: backend no expone /distance-matrix. Se puede aproximar
  /// llamando getDirections por par.
  Future<DistanceMatrixResult> getDistanceMatrix({
    required List<LatLng> origins,
    required List<LatLng> destinations,
    TravelMode mode = TravelMode.driving,
  }) async {
    debugPrint('🗺️ getDistanceMatrix deprecated — no disponible');
    return DistanceMatrixResult.error('Distance matrix no disponible.');
  }

  bool get isInitialized => _initialized;
  // API key ya no vive en cliente — devuelve string vacío para compat.
  String get apiKey => '';
}

/// Enums

enum TravelMode { driving, walking, bicycling, transit }

/// Clases de resultados

class LocationResult {
  final bool success;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime? timestamp;
  final String? error;

  LocationResult.success({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  }) : success = true, error = null;

  LocationResult.error(this.error)
      : success = false,
        latitude = null,
        longitude = null,
        accuracy = null,
        timestamp = null;
}

class GeocodingResult {
  final bool success;
  final double? latitude;
  final double? longitude;
  final String? formattedAddress;
  final String? placeId;
  final String? error;

  GeocodingResult.success({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    required this.placeId,
  }) : success = true, error = null;

  GeocodingResult.error(this.error)
      : success = false,
        latitude = null,
        longitude = null,
        formattedAddress = null,
        placeId = null;
}

class ReverseGeocodingResult {
  final bool success;
  final String? formattedAddress;
  final String? streetNumber;
  final String? route;
  final String? locality;
  final String? administrativeArea;
  final String? country;
  final String? postalCode;
  final String? placeId;
  final String? error;

  ReverseGeocodingResult.success({
    required this.formattedAddress,
    this.streetNumber,
    this.route,
    this.locality,
    this.administrativeArea,
    this.country,
    this.postalCode,
    this.placeId,
  }) : success = true, error = null;

  ReverseGeocodingResult.error(this.error)
      : success = false,
        formattedAddress = null,
        streetNumber = null,
        route = null,
        locality = null,
        administrativeArea = null,
        country = null,
        postalCode = null,
        placeId = null;
}

class DirectionsResult {
  final bool success;
  final List<LatLng>? polylinePoints;
  final String? distance;
  final int? distanceValue;
  final String? duration;
  final int? durationValue;
  final String? startAddress;
  final String? endAddress;
  final List<DirectionStep>? steps;
  final String? error;

  DirectionsResult.success({
    required this.polylinePoints,
    required this.distance,
    required this.distanceValue,
    required this.duration,
    required this.durationValue,
    required this.startAddress,
    required this.endAddress,
    required this.steps,
  }) : success = true, error = null;

  DirectionsResult.error(this.error)
      : success = false,
        polylinePoints = null,
        distance = null,
        distanceValue = null,
        duration = null,
        durationValue = null,
        startAddress = null,
        endAddress = null,
        steps = null;
}

class PlacesSearchResult {
  final bool success;
  final List<PlaceInfo>? places;
  final String? error;

  PlacesSearchResult.success(this.places) : success = true, error = null;

  PlacesSearchResult.error(this.error)
      : success = false,
        places = null;
}

class AutocompleteResult {
  final bool success;
  final List<PlacePrediction>? predictions;
  final String? error;

  AutocompleteResult.success(this.predictions) : success = true, error = null;

  AutocompleteResult.error(this.error)
      : success = false,
        predictions = null;
}

class DistanceMatrixResult {
  final bool success;
  final List<DistanceElement>? elements;
  final String? error;

  DistanceMatrixResult.error(this.error)
      : success = false,
        elements = null;
}

/// Clases de datos

class DirectionStep {
  final String instruction;
  final String distance;
  final String duration;
  final LatLng startLocation;
  final LatLng endLocation;

  DirectionStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
  });
}

class PlaceInfo {
  final String placeId;
  final String name;
  final String? vicinity;
  final double latitude;
  final double longitude;
  final double? rating;
  final int? priceLevel;
  final List<String> types;
  final bool? isOpen;
  final String? photoReference;

  PlaceInfo({
    required this.placeId,
    required this.name,
    this.vicinity,
    required this.latitude,
    required this.longitude,
    this.rating,
    this.priceLevel,
    required this.types,
    this.isOpen,
    this.photoReference,
  });
}

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String? secondaryText;
  final List<String> types;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    this.secondaryText,
    required this.types,
  });
}

class DistanceElement {
  final int originIndex;
  final int destinationIndex;
  final String distance;
  final int distanceValue;
  final String duration;
  final int durationValue;

  DistanceElement({
    required this.originIndex,
    required this.destinationIndex,
    required this.distance,
    required this.distanceValue,
    required this.duration,
    required this.durationValue,
  });
}
