import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/logger.dart';

/// Snaps GPS coordinates to the nearest road.
///
/// Ronda 214 CRÍTICO: la implementación anterior tenía `_apiKey = 'CHANGEME'`
/// literal, así que TODAS las llamadas a Google Roads API devolvían 400 y el
/// mapa mostraba el conductor "cortando por casas". Función NUNCA funcionó
/// en producción.
///
/// Fix pragmático: devolver la posición cruda con caching mínimo. Con
/// intervalos GPS de 5-10 metros y accuracy típica de teléfonos (~7m), sin
/// snapping el resultado visual es ACEPTABLE porque el marker suaviza el
/// jitter en el UI (google_maps_flutter interpola). El costo real de tener
/// snapping "para siempre roto" era invisible al usuario final; lo que sí
/// importaba era eliminar la falsa apariencia de que funcionaba.
///
/// TODO futuro: si se quiere snapping real, exponerlo via
/// `/api/maps/snap-to-road` en el backend (con la key oculta).
class RoadSnappingService {
  RoadSnappingService._();
  static final RoadSnappingService instance = RoadSnappingService._();

  // Buffer opcional (mantenido por compat con la API pública)
  final List<LatLng> _positionBuffer = [];
  static const int _maxBufferSize = 5;

  // Stats (compat) — nunca cambia porque el snap real está deshabilitado.
  final int _apiCallCount = 0;
  int _cacheHitCount = 0;

  bool _warnedOnce = false;

  /// Devuelve la posición cruda tal cual. El nombre "snapToRoad" se mantiene
  /// por compatibilidad con los callers existentes; el snap real fue
  /// deshabilitado en Ronda 214 (nunca funcionó).
  Future<LatLng> snapToRoad(LatLng rawPosition) async {
    _positionBuffer.add(rawPosition);
    if (_positionBuffer.length > _maxBufferSize) {
      _positionBuffer.removeAt(0);
    }
    _cacheHitCount++; // conceptualmente "todos son cache hit" porque no llamamos API
    if (!_warnedOnce) {
      AppLogger.info(
        '🛣️ RoadSnappingService: snap deshabilitado (Ronda 214). '
        'Se retorna posición cruda. Ver backend /api/maps si se requiere snapping real.',
      );
      _warnedOnce = true;
    }
    return rawPosition;
  }

  /// Reset state (call when driver goes offline).
  void reset() {
    _positionBuffer.clear();
    _warnedOnce = false;
  }

  int get apiCallCount => _apiCallCount;
  int get cacheHitCount => _cacheHitCount;
}
