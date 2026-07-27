/// Wrapper único para llamar al backend proxy `mapsProxy` (Cloud Functions).
/// El backend hace cascada: OSRM (gratis ilimitado) → Mapbox (free 100k/mes) → Google (último recurso).
///
/// Reemplaza llamadas HTTP directas a `maps.googleapis.com` que iban por
/// la key móvil expuesta. Ahora todo va por backend → key oculta, costo $0.
///
/// USO desde código Flutter:
///   final result = await MapsService().getDirections(origin, destination);
///   final preds = await MapsService().autocomplete('Av Larco', sessionToken: 'xyz');
///   final place = await MapsService().placeDetails(predictionPlaceId);
library;

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import '../utils/logger.dart';
import 'rapi_api_client.dart';

class MapsService {
  static final MapsService _instance = MapsService._internal();
  factory MapsService() => _instance;
  MapsService._internal();

  final RapiApiClient _api = RapiApiClient.instance;

  // ───────────────────────────────────────────────────────────
  // DIRECTIONS: obtener polyline + distancia + duración
  // ───────────────────────────────────────────────────────────

  /// Retorna una ruta entre origin y destination usando el backend en cascada.
  /// `mode` puede ser 'driving', 'walking', 'cycling' (default 'driving').
  ///
  /// Retorna `null` si todos los proveedores fallaron (caller decide fallback).
  Future<DirectionsRoute?> getDirections({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving',
  }) async {
    try {
      final data = await _api.mapsDirections(
        originLat: origin.latitude,
        originLng: origin.longitude,
        destLat: destination.latitude,
        destLng: destination.longitude,
        mode: mode,
      );

      final polyline = data['polyline'] as String?;
      final distanceM = (data['distanceMeters'] as num?)?.toInt() ?? 0;
      final durationS = (data['durationSeconds'] as num?)?.toInt() ?? 0;
      final provider = data['provider'] as String? ?? 'unknown';

      if (polyline == null || polyline.isEmpty) return null;

      final decoded = PolylinePoints.decodePolyline(polyline);
      final points = decoded
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList(growable: false);

      AppLogger.debug('[MapsService] directions OK $provider ${distanceM}m ${durationS}s');
      return DirectionsRoute(
        points: points,
        encodedPolyline: polyline,
        distanceMeters: distanceM,
        durationSeconds: durationS,
        provider: provider,
      );
    } on RapiApiException catch (e) {
      AppLogger.warning('[MapsService] directions ${e.code}: ${e.message}');
      return null;
    } catch (e) {
      AppLogger.error('[MapsService] directions inesperado', e);
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────
  // REVERSE GEOCODE — coord → dirección legible
  // ───────────────────────────────────────────────────────────

  /// Convierte lat/lng en una dirección legible.
  /// Ronda 216: reemplaza la llamada directa a Google Geocoding que estaba
  /// en modern_passenger_home con la key expuesta. Ahora va por el proxy
  /// backend (Nominatim, gratis, sin key).
  Future<String?> reverseGeocode(LatLng location) async {
    try {
      final data = await _api.mapsReverseGeocode(
        lat: location.latitude,
        lng: location.longitude,
      );
      final address = data['address'] as String?;
      if (address != null && address.isNotEmpty) {
        AppLogger.debug('[MapsService] reverse-geocode OK ${data['provider']}');
        return address;
      }
      return null;
    } on RapiApiException catch (e) {
      AppLogger.warning('[MapsService] reverse-geocode ${e.code}: ${e.message}');
      return null;
    } catch (e) {
      AppLogger.error('[MapsService] reverse-geocode error', e);
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────
  // PLACES AUTOCOMPLETE
  // ───────────────────────────────────────────────────────────

  /// Cache LRU local de autocomplete — evita round-trip al backend si el usuario
  /// tipea el mismo query (incluyendo cuando borra y vuelve a tipear). Key es el
  /// query lowercase trim. Max 50 entradas (~10 KB en RAM, despreciable).
  /// El cache se reinicia al reabrir la app — aceptable porque el backend
  /// también cachea 1h (next request paga solo latencia de red, no de proveedor).
  final Map<String, List<PlacePrediction>> _autocompleteCache = <String, List<PlacePrediction>>{};
  static const int _maxAutocompleteCacheEntries = 50;

  /// Busca direcciones que coincidan con `query` (autocomplete tipo Places).
  ///
  /// [userLat]/[userLng]: ubicación actual del usuario. **CRÍTICO** para que el
  /// backend pase `proximity` a Mapbox y `location+radius` a Google, sesgando
  /// resultados a la cercanía. Sin esto, al buscar "av larco" desde Lima aparecen
  /// resultados de Trujillo, Arequipa, etc.
  ///
  /// [sessionToken] opcional — Google lo usa para tarifar autocomplete + place
  /// details como una sola sesión. Mapbox lo ignora pero no estorba.
  Future<List<PlacePrediction>> autocomplete(
    String query, {
    double? userLat,
    double? userLng,
    String? sessionToken,
    String languageCode = 'es',
    String countryCode = 'pe',
  }) async {
    if (query.trim().length < 2) return const <PlacePrediction>[];

    // Cache local — key incluye coords bucketizadas para no servir resultados
    // de otro barrio.
    final geoBucket = (userLat != null && userLng != null)
        ? '${userLat.toStringAsFixed(2)},${userLng.toStringAsFixed(2)}'
        : 'no-geo';
    final cacheKey = '${query.toLowerCase().trim()}|$geoBucket';
    final cached = _autocompleteCache[cacheKey];
    if (cached != null) {
      AppLogger.debug('[MapsService] autocomplete cache HIT "$query"');
      return cached;
    }

    try {
      final data = await _api.mapsAutocomplete(
        query: query,
        session: sessionToken,
        lat: userLat,
        lng: userLng,
      );
      final preds = (data['predictions'] as List?) ?? const [];

      // Ronda 258: el cliente DESCARTABA lat/lng aunque el backend los envía en
      // cada predicción. Al ignorarlos, la app hacía una segunda consulta
      // (placeDetails por placeId) que podía resolver a un lugar DISTINTO del
      // que el usuario acababa de tocar: se mostraba "Jirón Las Coralinas 870,
      // San Juan de Lurigancho" y se guardaba una coordenada del Callao.
      // Usando la coordenada que viene con el resultado, lo que se marca en el
      // mapa es exactamente lo que el usuario eligió.
      final predictions = preds.map((p) {
        final m = p as Map;
        return PlacePrediction(
          description: m['description'] as String? ?? '',
          placeId: m['placeId'] as String? ?? '',
          mainText: m['mainText'] as String? ?? '',
          secondaryText: m['secondaryText'] as String? ?? '',
          distanceMeters: (m['distanceMeters'] as num?)?.toInt(),
          lat: (m['lat'] as num?)?.toDouble(),
          lng: (m['lng'] as num?)?.toDouble(),
        );
      }).toList(growable: false);

      if (_autocompleteCache.length >= _maxAutocompleteCacheEntries) {
        _autocompleteCache.remove(_autocompleteCache.keys.first);
      }
      _autocompleteCache[cacheKey] = predictions;

      return predictions;
    } on RapiApiException catch (e) {
      AppLogger.warning('[MapsService] autocomplete ${e.code}: ${e.message}');
      return const <PlacePrediction>[];
    } catch (e) {
      AppLogger.error('[MapsService] autocomplete error', e);
      return const <PlacePrediction>[];
    }
  }

  // ───────────────────────────────────────────────────────────
  // PLACE DETAILS (coordenadas + dirección completa de un placeId)
  // ───────────────────────────────────────────────────────────

  /// Obtiene lat/lng + dirección formateada de un placeId devuelto por autocomplete.
  Future<PlaceDetails?> placeDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    if (placeId.isEmpty) return null;

    try {
      final data = await _api.mapsPlaceDetails(placeId);
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return PlaceDetails(
        placeId: data['placeId'] as String? ?? placeId,
        name: data['name'] as String? ?? '',
        formattedAddress: data['formattedAddress'] as String? ?? '',
        coordinates: LatLng(lat, lng),
      );
    } on RapiApiException catch (e) {
      AppLogger.warning('[MapsService] placeDetails ${e.code}: ${e.message}');
      return null;
    } catch (e) {
      AppLogger.error('[MapsService] placeDetails error', e);
      return null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Modelos de retorno
// ═══════════════════════════════════════════════════════════════

class DirectionsRoute {
  /// Puntos LatLng listos para dibujar como Polyline en GoogleMap.
  final List<LatLng> points;

  /// Polyline encoded original (útil para persistir en Firestore sin expandir).
  final String encodedPolyline;
  final int distanceMeters;
  final int durationSeconds;

  /// 'osrm' | 'mapbox' | 'google' — qué proveedor respondió en el backend.
  final String provider;

  const DirectionsRoute({
    required this.points,
    required this.encodedPolyline,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.provider,
  });

  double get distanceKm => distanceMeters / 1000.0;
  int get durationMinutes => (durationSeconds / 60).round();
}

class PlacePrediction {
  final String description;
  final String placeId;
  final String mainText;
  final String secondaryText;

  /// Distancia desde el `proximity` que se pasó al autocomplete (típicamente
  /// la ubicación del usuario). Null si no se pasó proximity o si Mapbox
  /// no devolvió distancia para esta suggestion.
  final int? distanceMeters;

  /// Ronda 258: coordenadas del propio resultado, tal como las devolvió el
  /// geocodificador. Usarlas evita una segunda consulta por placeId que puede
  /// resolver a un lugar distinto del que el usuario tocó.
  final double? lat;
  final double? lng;

  const PlacePrediction({
    required this.description,
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    this.distanceMeters,
    this.lat,
    this.lng,
  });
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final LatLng coordinates;

  const PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.coordinates,
  });
}
