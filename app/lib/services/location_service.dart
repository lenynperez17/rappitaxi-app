import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/logger.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  StreamController<Position> _locationStreamController = StreamController<Position>.broadcast();
  StreamSubscription<Position>? _locationSubscription; // ✅ RESOURCE MANAGEMENT: Guardar subscription para cancelarla

  Stream<Position> get locationStream => _locationStreamController.stream;
  Position? get currentPosition => _currentPosition;

  // Inicializar el servicio de ubicación
  Future<void> initialize() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (hasPermission) {
        await getCurrentLocation();
        AppLogger.info('LocationService inicializado correctamente');
      } else {
        AppLogger.warning('LocationService no pudo inicializarse - permisos denegados');
      }
    } catch (e) {
      AppLogger.error('Error inicializando LocationService', e);
    }
  }

  // Solicitar permisos de ubicación
  Future<bool> requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Solicitar al usuario que habilite el servicio de ubicación
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Los permisos están permanentemente denegados
      return false;
    }

    return true;
  }

  // Obtener ubicación actual
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
      
      _locationStreamController.add(_currentPosition!);
      return _currentPosition;
    } catch (e) {
      AppLogger.error('Error obteniendo ubicación', e);
      return null;
    }
  }

  // Iniciar seguimiento de ubicación
  /// ✅ RESOURCE MANAGEMENT: Guarda la subscription para poder cancelarla correctamente
  void startLocationTracking() {
    // Si ya hay un tracking activo, no crear uno nuevo
    if (_locationSubscription != null) {
      AppLogger.warning('Location tracking ya está activo');
      return;
    }

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Actualizar cada 10 metros
      ),
    ).listen(
      (Position position) {
        _currentPosition = position;
        // Solo agregar al stream si el controller no está cerrado
        if (!_locationStreamController.isClosed) {
          _locationStreamController.add(position);
        }
      },
      onError: (error) {
        AppLogger.error('Error en location stream', error);
      },
    );
  }

  // Detener seguimiento
  /// ✅ RESOURCE MANAGEMENT: Cancela subscription y cierra el controller correctamente
  void stopLocationTracking() {
    // 1. Cancelar subscription de Geolocator primero
    _locationSubscription?.cancel();
    _locationSubscription = null;

    // 2. Cerrar el StreamController si no está cerrado
    if (!_locationStreamController.isClosed) {
      _locationStreamController.close();
    }

    // 3. Recrear controller solo si se va a reusar (para permitir restart)
    // ✅ LAZY INITIALIZATION: Solo se recrea cuando se llama startLocationTracking()
    _locationStreamController = StreamController<Position>.broadcast();

    AppLogger.info('Location tracking detenido');
  }

  // Convertir coordenadas a dirección
  Future<String> getAddressFromLatLng(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street ?? ''} ${place.subLocality ?? ''}, ${place.locality ?? ''}';
      }
    } catch (e) {
      AppLogger.error('Error obteniendo dirección', e);
    }
    return 'Ubicación desconocida';
  }

  // Buscar lugares por texto
  Future<List<Location>> searchPlaces(String query) async {
    try {
      List<Location> locations = await locationFromAddress(query);
      return locations;
    } catch (e) {
      AppLogger.error('Error buscando lugares', e);
      return [];
    }
  }

  // Calcular distancia entre dos puntos
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

  // Obtener bounds para ajustar la cámara del mapa
  LatLngBounds getBounds(LatLng start, LatLng end) {
    final southwest = LatLng(
      start.latitude <= end.latitude ? start.latitude : end.latitude,
      start.longitude <= end.longitude ? start.longitude : end.longitude,
    );
    final northeast = LatLng(
      start.latitude > end.latitude ? start.latitude : end.latitude,
      start.longitude > end.longitude ? start.longitude : end.longitude,
    );
    return LatLngBounds(southwest: southwest, northeast: northeast);
  }

  /// ✅ RESOURCE CLEANUP: Limpia todos los recursos para prevenir memory leaks
  void dispose() {
    AppLogger.info('LocationService: Iniciando limpieza de recursos...');

    // 1. Cancelar subscription de Geolocator
    _locationSubscription?.cancel();
    _locationSubscription = null;

    // 2. Cerrar StreamController
    if (!_locationStreamController.isClosed) {
      _locationStreamController.close();
    }

    AppLogger.info('LocationService: Recursos limpiados exitosamente');
  }
}