import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// Servicio completo para integración con Google Maps API
/// Maneja geocoding, rutas, distancias y lugares
class GoogleMapsService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  
  // API Key desde variables de entorno o valor por defecto
  static const String _apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyB2lHyFVQhey6C1Dib1mDBijVGopWvvhGg'
  );
  
  static final Logger _logger = Logger();
  
  // Cache para evitar llamadas repetidas
  static final Map<String, dynamic> _cache = {};
  static const Duration _cacheTimeout = Duration(minutes: 10);

  /// Convierte una dirección en coordenadas geográficas
  static Future<LatLng?> geocodeAddress(String address) async {
    if (address.isEmpty) return null;
    
    try {
      final cacheKey = 'geocode_$address';
      if (_cache.containsKey(cacheKey)) {
        final cached = _cache[cacheKey];
        if (DateTime.now().difference(cached['timestamp']).inMinutes < 10) {
          if (kDebugMode) {
            _logger.info('Geocoding desde cache', data: {'address': address});
          }
          return cached['result'];
        }
      }

      final encodedAddress = Uri.encodeComponent(address);
      final url = '$_baseUrl/geocode/json?address=$encodedAddress&key=$_apiKey&language=es';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final result = LatLng(location['lat'], location['lng']);
          
          // Guardar en cache
          _cache[cacheKey] = {
            'result': result,
            'timestamp': DateTime.now(),
          };
          
          _logger.info('Geocoding exitoso', data: {
            'address': address,
            'lat': result.latitude,
            'lng': result.longitude
          });
          
          return result;
        } else {
          _logger.warn('No se encontraron resultados para geocoding', data: {
            'address': address,
            'status': data['status']
          });
          return null;
        }
      } else {
        _logger.error('Error en geocoding HTTP', data: {
          'statusCode': response.statusCode,
          'body': response.body
        });
        return null;
      }
    } catch (e) {
      _logger.error('Error en geocodeAddress', error: e);
      return null;
    }
  }

  /// Convierte coordenadas geográficas en una dirección
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final cacheKey = 'reverse_${lat}_$lng';
      if (_cache.containsKey(cacheKey)) {
        final cached = _cache[cacheKey];
        if (DateTime.now().difference(cached['timestamp']).inMinutes < 10) {
          if (kDebugMode) {
            _logger.info('Reverse geocoding desde cache');
          }
          return cached['result'];
        }
      }

      final url = '$_baseUrl/geocode/json?latlng=$lat,$lng&key=$_apiKey&language=es';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0]['formatted_address'];
          
          // Guardar en cache
          _cache[cacheKey] = {
            'result': result,
            'timestamp': DateTime.now(),
          };
          
          _logger.info('Reverse geocoding exitoso', data: {
            'lat': lat,
            'lng': lng,
            'address': result
          });
          
          return result;
        }
      }
      return null;
    } catch (e) {
      _logger.error('Error en reverseGeocode', error: e);
      return null;
    }
  }

  /// Calcula la ruta óptima entre dos puntos
  static Future<Map<String, dynamic>?> calculateRoute(
    LatLng origin,
    LatLng destination, {
    String travelMode = 'driving',
    bool avoidTolls = false,
    bool avoidHighways = false,
  }) async {
    try {
      final cacheKey = 'route_${origin.latitude}_${origin.longitude}_${destination.latitude}_${destination.longitude}_$travelMode';
      
      if (_cache.containsKey(cacheKey)) {
        final cached = _cache[cacheKey];
        if (DateTime.now().difference(cached['timestamp']).inMinutes < 5) {
          if (kDebugMode) {
            _logger.info('Ruta desde cache');
          }
          return cached['result'];
        }
      }

      String url = '$_baseUrl/directions/json?'
          'origin=${origin.latitude},${origin.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'mode=$travelMode&'
          'key=$_apiKey&'
          'language=es&'
          'region=pe';

      if (avoidTolls) url += '&avoid=tolls';
      if (avoidHighways) url += '&avoid=highways';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          final result = {
            'distance': {
              'text': leg['distance']['text'],
              'value': leg['distance']['value'], // metros
            },
            'duration': {
              'text': leg['duration']['text'],
              'value': leg['duration']['value'], // segundos
            },
            'polyline': route['overview_polyline']['points'],
            'bounds': route['bounds'],
            'steps': leg['steps'],
            'start_address': leg['start_address'],
            'end_address': leg['end_address'],
          };
          
          // Guardar en cache
          _cache[cacheKey] = {
            'result': result,
            'timestamp': DateTime.now(),
          };
          
          _logger.info('Ruta calculada exitosamente', data: {
            'distance': result['distance']['text'],
            'duration': result['duration']['text']
          });
          
          return result;
        } else {
          _logger.warn('No se encontró ruta', data: {
            'status': data['status'],
            'origin': '${origin.latitude},${origin.longitude}',
            'destination': '${destination.latitude},${destination.longitude}'
          });
          return null;
        }
      } else {
        _logger.error('Error en cálculo de ruta HTTP', data: {
          'statusCode': response.statusCode,
          'body': response.body
        });
        return null;
      }
    } catch (e) {
      _logger.error('Error en calculateRoute', error: e);
      return null;
    }
  }

  /// Obtiene matriz de distancias entre múltiples orígenes y destinos
  static Future<Map<String, dynamic>?> getDistanceMatrix(
    List<LatLng> origins,
    List<LatLng> destinations, {
    String travelMode = 'driving',
  }) async {
    try {
      final originsStr = origins
          .map((point) => '${point.latitude},${point.longitude}')
          .join('|');
      final destinationsStr = destinations
          .map((point) => '${point.latitude},${point.longitude}')
          .join('|');

      final url = '$_baseUrl/distancematrix/json?'
          'origins=$originsStr&'
          'destinations=$destinationsStr&'
          'mode=$travelMode&'
          'key=$_apiKey&'
          'language=es&'
          'region=pe';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'OK') {
          _logger.info('Matriz de distancias obtenida', data: {
            'origins_count': origins.length,
            'destinations_count': destinations.length
          });
          
          return {
            'rows': data['rows'],
            'origin_addresses': data['origin_addresses'],
            'destination_addresses': data['destination_addresses'],
          };
        }
      }
      return null;
    } catch (e) {
      _logger.error('Error en getDistanceMatrix', error: e);
      return null;
    }
  }

  /// Busca lugares con autocompletado
  static Future<List<Map<String, dynamic>>> searchPlaces(
    String query, {
    LatLng? location,
    int radius = 50000,
    String? types,
  }) async {
    try {
      if (query.isEmpty) return [];

      String url = '$_baseUrl/place/autocomplete/json?'
          'input=${Uri.encodeComponent(query)}&'
          'key=$_apiKey&'
          'language=es&'
          'region=pe';

      if (location != null) {
        url += '&location=${location.latitude},${location.longitude}&radius=$radius';
      }

      if (types != null) {
        url += '&types=$types';
      }
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'OK' && data['predictions'] != null) {
          final predictions = data['predictions'] as List;
          
          _logger.info('Lugares encontrados', data: {
            'query': query,
            'count': predictions.length
          });
          
          return predictions.map<Map<String, dynamic>>((prediction) => {
            'place_id': prediction['place_id'],
            'description': prediction['description'],
            'main_text': prediction['structured_formatting']?['main_text'] ?? '',
            'secondary_text': prediction['structured_formatting']?['secondary_text'] ?? '',
            'types': prediction['types'],
          }).toList();
        }
      }
      return [];
    } catch (e) {
      _logger.error('Error en searchPlaces', error: e);
      return [];
    }
  }

  /// Obtiene detalles de un lugar por place_id
  static Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final url = '$_baseUrl/place/details/json?'
          'place_id=$placeId&'
          'fields=name,formatted_address,geometry,rating,photos,types&'
          'key=$_apiKey&'
          'language=es';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'OK' && data['result'] != null) {
          final result = data['result'];
          final location = result['geometry']['location'];
          
          return {
            'name': result['name'],
            'address': result['formatted_address'],
            'location': LatLng(location['lat'], location['lng']),
            'rating': result['rating'],
            'types': result['types'],
          };
        }
      }
      return null;
    } catch (e) {
      _logger.error('Error en getPlaceDetails', error: e);
      return null;
    }
  }

  /// Calcula la distancia en línea recta entre dos puntos (en metros)
  static double calculateStraightDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Radio de la Tierra en metros
    
    final lat1Rad = point1.latitude * math.pi / 180;
    final lat2Rad = point2.latitude * math.pi / 180;
    final deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;
    
    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Obtiene tiempo estimado de viaje considerando tráfico
  static Future<Duration?> getEstimatedTravelTime(
    LatLng origin,
    LatLng destination, {
    DateTime? departureTime,
  }) async {
    try {
      final route = await calculateRoute(origin, destination);
      if (route != null) {
        final durationInSeconds = route['duration']['value'] as int;
        
        // Ajustar por hora del día (simple implementación)
        final now = departureTime ?? DateTime.now();
        double trafficMultiplier = 1.0;
        
        // Horas pico en Lima (7-9 AM y 5-8 PM)
        if ((now.hour >= 7 && now.hour <= 9) || (now.hour >= 17 && now.hour <= 20)) {
          trafficMultiplier = 1.5; // 50% más tiempo en horas pico
        } else if (now.hour >= 22 || now.hour <= 5) {
          trafficMultiplier = 0.8; // 20% menos tiempo en madrugada
        }
        
        final adjustedSeconds = (durationInSeconds * trafficMultiplier).round();
        return Duration(seconds: adjustedSeconds);
      }
      return null;
    } catch (e) {
      _logger.error('Error en getEstimatedTravelTime', error: e);
      return null;
    }
  }

  /// Busca conductores cercanos en un radio específico
  static Future<List<Map<String, dynamic>>> findNearbyDrivers(
    LatLng userLocation,
    double radiusInKm, {
    String? vehicleType,
  }) async {
    try {
      // Simula búsqueda de conductores cercanos
      // En producción, esto consultaría Firestore con GeoQueries
      final List<Map<String, dynamic>> mockDrivers = [
        {
          'id': 'driver_001',
          'name': 'Carlos Mendoza',
          'location': LatLng(
            userLocation.latitude + (math.Random().nextDouble() - 0.5) * 0.01,
            userLocation.longitude + (math.Random().nextDouble() - 0.5) * 0.01,
          ),
          'rating': 4.8,
          'vehicleType': vehicleType ?? 'economic',
          'estimatedArrival': Duration(minutes: 3 + math.Random().nextInt(7)),
        },
        {
          'id': 'driver_002',
          'name': 'Ana López',
          'location': LatLng(
            userLocation.latitude + (math.Random().nextDouble() - 0.5) * 0.01,
            userLocation.longitude + (math.Random().nextDouble() - 0.5) * 0.01,
          ),
          'rating': 4.9,
          'vehicleType': vehicleType ?? 'standard',
          'estimatedArrival': Duration(minutes: 2 + math.Random().nextInt(5)),
        },
      ];

      // Calcular distancias reales
      for (var driver in mockDrivers) {
        final driverLocation = driver['location'] as LatLng;
        final distance = calculateStraightDistance(userLocation, driverLocation);
        driver['distance'] = distance;
        driver['distanceText'] = '${(distance / 1000).toStringAsFixed(1)} km';
      }

      // Filtrar por radio
      final nearbyDrivers = mockDrivers.where((driver) {
        final distance = driver['distance'] as double;
        return (distance / 1000) <= radiusInKm;
      }).toList();

      // Ordenar por distancia
      nearbyDrivers.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      _logger.info('Conductores cercanos encontrados', data: {
        'userLocation': '${userLocation.latitude},${userLocation.longitude}',
        'radius': radiusInKm,
        'count': nearbyDrivers.length
      });

      return nearbyDrivers;
    } catch (e) {
      _logger.error('Error en findNearbyDrivers', error: e);
      return [];
    }
  }

  /// Limpia el cache interno
  static void clearCache() {
    _cache.clear();
    _logger.info('Cache de GoogleMapsService limpiado');
  }

  /// Obtiene estadísticas del cache
  static Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int validEntries = 0;
    int expiredEntries = 0;

    for (var entry in _cache.values) {
      if (now.difference(entry['timestamp']) < _cacheTimeout) {
        validEntries++;
      } else {
        expiredEntries++;
      }
    }

    return {
      'total_entries': _cache.length,
      'valid_entries': validEntries,
      'expired_entries': expiredEntries,
      'cache_timeout_minutes': _cacheTimeout.inMinutes,
    };
  }

  /// Verifica si la API key es válida haciendo una petición simple
  static Future<bool> validateApiKey() async {
    try {
      final url = '$_baseUrl/geocode/json?address=Lima,Peru&key=$_apiKey';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isValid = data['status'] != 'REQUEST_DENIED';
        
        _logger.info('Validación de API Key', data: {
          'isValid': isValid,
          'status': data['status']
        });
        
        return isValid;
      }
      return false;
    } catch (e) {
      _logger.error('Error validando API Key', error: e);
      return false;
    }
  }
}

/// Utilidades adicionales para Google Maps
class GoogleMapsUtils {
  /// Convierte una polilínea codificada en lista de LatLng
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  /// Crea bounds que contengan todos los puntos dados
  static LatLngBounds boundsFromLatLngList(List<LatLng> points) {
    if (points.isEmpty) {
      throw ArgumentError('La lista de puntos no puede estar vacía');
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}