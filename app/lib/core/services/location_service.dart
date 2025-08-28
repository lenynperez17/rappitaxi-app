import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../shared/models/location_model.dart';
import '../utils/logger.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Obtener ubicación actual
  Future<Position?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Logger.warning('Permisos de ubicación denegados');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Logger.warning('Permisos de ubicación denegados permanentemente');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      return position;
    } catch (e) {
      Logger.error('Error obteniendo ubicación actual', e);
      return null;
    }
  }

  // Buscar lugares
  Future<List<LocationModel>> searchPlaces(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      // Usar geocoding para buscar lugares
      final locations = await locationFromAddress(query, localeIdentifier: 'es_ES');
      
      final results = <LocationModel>[];
      
      for (final location in locations.take(5)) {
        try {
          final placemarks = await placemarkFromCoordinates(
            location.latitude, 
            location.longitude,
          );
          
          if (placemarks.isNotEmpty) {
            final placemark = placemarks.first;
            final address = _formatAddress(placemark);
            
            results.add(LocationModel(
              name: placemark.name ?? query,
              address: address,
              latitude: location.latitude,
              longitude: location.longitude,
              city: placemark.locality ?? 'Lima',
              country: placemark.country ?? 'Perú',
            ));
          }
        } catch (e) {
          Logger.warning('Error procesando resultado de búsqueda', e);
        }
      }

      return results;
    } catch (e) {
      Logger.error('Error buscando lugares', e);
      return [];
    }
  }

  // Obtener dirección desde coordenadas
  Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return _formatAddress(placemark);
      }
      
      return null;
    } catch (e) {
      Logger.error('Error obteniendo dirección desde coordenadas', e);
      return null;
    }
  }

  // Calcular distancia entre dos puntos
  double calculateDistance(
    double lat1, double lon1, 
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Verificar si los servicios de ubicación están habilitados
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Obtener stream de ubicación en tiempo real
  Stream<Position> getLocationStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  // Formatear dirección desde placemark
  String _formatAddress(Placemark placemark) {
    final components = <String>[];
    
    if (placemark.street?.isNotEmpty == true) {
      components.add(placemark.street!);
    }
    
    if (placemark.name?.isNotEmpty == true && placemark.name != placemark.street) {
      components.add(placemark.name!);
    }
    
    if (placemark.locality?.isNotEmpty == true) {
      components.add(placemark.locality!);
    }
    
    if (placemark.administrativeArea?.isNotEmpty == true && 
        placemark.administrativeArea != placemark.locality) {
      components.add(placemark.administrativeArea!);
    }
    
    return components.isNotEmpty ? components.join(', ') : 'Dirección desconocida';
  }

  // Obtener ubicaciones favoritas (desde caché o preferencias)
  Future<List<LocationModel>> getFavoriteLocations() async {
    try {
      // TODO: Implementar carga desde SharedPreferences o Firebase
      return [
        LocationModel(
          name: 'Casa',
          address: 'Mi dirección de casa',
          latitude: -12.0464,
          longitude: -77.0428,
          city: 'Lima',
          country: 'Perú',
        ),
        LocationModel(
          name: 'Trabajo',
          address: 'Mi dirección de trabajo',
          latitude: -12.0464,
          longitude: -77.0428,
          city: 'Lima',
          country: 'Perú',
        ),
      ];
    } catch (e) {
      Logger.error('Error obteniendo ubicaciones favoritas', e);
      return [];
    }
  }
}