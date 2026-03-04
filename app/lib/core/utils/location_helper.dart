import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// Helper centralizado para operaciones de ubicación y coordenadas
class LocationHelper {
  
  /// Calcular distancia entre dos puntos en kilómetros
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  /// Calcular distancia entre LatLng
  static double calculateDistanceFromLatLng(LatLng point1, LatLng point2) {
    return calculateDistance(
      point1.latitude, point1.longitude,
      point2.latitude, point2.longitude,
    );
  }

  /// Calcular distancia entre Position
  static double calculateDistanceFromPosition(Position pos1, Position pos2) {
    return calculateDistance(
      pos1.latitude, pos1.longitude,
      pos2.latitude, pos2.longitude,
    );
  }

  /// Formatear distancia en texto legible
  static String formatDistance(double distanceInKm) {
    if (distanceInKm < 1.0) {
      return '${(distanceInKm * 1000).round()} m';
    } else if (distanceInKm < 10.0) {
      return '${distanceInKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceInKm.round()} km';
    }
  }

  /// Calcular tiempo estimado de viaje (asumiendo 30 km/h promedio en ciudad)
  static Duration calculateEstimatedTime(double distanceInKm, {double speedKmh = 30.0}) {
    final hours = distanceInKm / speedKmh;
    return Duration(minutes: (hours * 60).round());
  }

  /// Formatear tiempo estimado
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '$minutes min';
    }
  }

  /// Calcular punto medio entre dos ubicaciones
  static LatLng calculateMidpoint(LatLng point1, LatLng point2) {
    final lat1Rad = point1.latitude * (math.pi / 180);
    final lon1Rad = point1.longitude * (math.pi / 180);
    final lat2Rad = point2.latitude * (math.pi / 180);
    final lon2Diff = (point2.longitude - point1.longitude) * (math.pi / 180);

    final bx = math.cos(lat2Rad) * math.cos(lon2Diff);
    final by = math.cos(lat2Rad) * math.sin(lon2Diff);

    final lat3 = math.atan2(
      math.sin(lat1Rad) + math.sin(lat2Rad),
      math.sqrt((math.cos(lat1Rad) + bx) * (math.cos(lat1Rad) + bx) + by * by),
    );
    final lon3 = lon1Rad + math.atan2(by, math.cos(lat1Rad) + bx);

    return LatLng(lat3 * (180 / math.pi), lon3 * (180 / math.pi));
  }

  /// Calcular bounds que contengan múltiples puntos
  static LatLngBounds calculateBounds(List<LatLng> points) {
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

  /// Verificar si un punto está dentro de un área circular
  static bool isWithinRadius(
    LatLng center,
    LatLng point,
    double radiusKm,
  ) {
    final distance = calculateDistanceFromLatLng(center, point);
    return distance <= radiusKm;
  }

  /// Generar coordenadas aleatorias cerca de un punto (para testing)
  static LatLng generateNearbyPoint(
    LatLng center,
    double maxDistanceKm,
  ) {
    final random = math.Random();
    
    // Convertir distancia a grados aproximadamente
    final radiusInDegrees = maxDistanceKm / 111.32; // 1 grado ≈ 111.32 km
    
    final angle = random.nextDouble() * 2 * math.pi;
    final distance = random.nextDouble() * radiusInDegrees;
    
    final lat = center.latitude + (distance * math.cos(angle));
    final lng = center.longitude + (distance * math.sin(angle));
    
    return LatLng(lat, lng);
  }

  /// Convertir Position a LatLng
  static LatLng positionToLatLng(Position position) {
    return LatLng(position.latitude, position.longitude);
  }

  /// Convertir LatLng a Map para Firebase
  static Map<String, dynamic> latLngToMap(LatLng latLng) {
    return {
      'latitude': latLng.latitude,
      'longitude': latLng.longitude,
    };
  }

  /// Convertir Map de Firebase a LatLng
  static LatLng mapToLatLng(Map<String, dynamic> map) {
    return LatLng(
      (map['latitude'] as num).toDouble(),
      (map['longitude'] as num).toDouble(),
    );
  }

  /// Validar coordenadas
  static bool isValidLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  /// Formatear coordenadas para mostrar
  static String formatLatLng(LatLng latLng, {int decimals = 6}) {
    return '${latLng.latitude.toStringAsFixed(decimals)}, ${latLng.longitude.toStringAsFixed(decimals)}';
  }

  /// Calcular bearing (dirección) entre dos puntos
  static double calculateBearing(LatLng from, LatLng to) {
    final lat1Rad = from.latitude * (math.pi / 180);
    final lat2Rad = to.latitude * (math.pi / 180);
    final deltaLngRad = (to.longitude - from.longitude) * (math.pi / 180);

    final y = math.sin(deltaLngRad) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLngRad);

    final bearingRad = math.atan2(y, x);
    return (bearingRad * (180 / math.pi) + 360) % 360;
  }

  /// Obtener descripción textual de la dirección
  static String getBearingDescription(double bearing) {
    if (bearing >= 337.5 || bearing < 22.5) return 'Norte';
    if (bearing >= 22.5 && bearing < 67.5) return 'Noreste';
    if (bearing >= 67.5 && bearing < 112.5) return 'Este';
    if (bearing >= 112.5 && bearing < 157.5) return 'Sureste';
    if (bearing >= 157.5 && bearing < 202.5) return 'Sur';
    if (bearing >= 202.5 && bearing < 247.5) return 'Suroeste';
    if (bearing >= 247.5 && bearing < 292.5) return 'Oeste';
    return 'Noroeste';
  }

  /// Coordenadas de Lima (punto de referencia por defecto)
  static const LatLng limaCenter = LatLng(-12.0464, -77.0428);
  
  /// Coordenadas de aeropuerto Jorge Chávez
  static const LatLng limaAirport = LatLng(-12.0219, -77.1143);
}