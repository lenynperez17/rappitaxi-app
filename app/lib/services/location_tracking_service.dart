import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'rapi_api_client.dart';
import 'rapi_sse_client.dart';

/// Servicio de tracking de ubicación en tiempo real.
///
/// Antes: escribía a Firestore (`rides/{id}`) y `users/{id}` cada 5s.
/// Ahora: llama a `RapiApiClient.heartbeat(...)` cada 10s con la ubicación GPS
/// actual. El backend Node broadcast por SSE (RapiSseClient.driverLocations) a
/// los pasajeros suscritos al viaje.
///
/// Se conserva el Socket.IO para compatibilidad con listeners existentes,
/// pero ya no es la fuente de verdad de la ubicación (opcional).
class LocationTrackingService {
  static final LocationTrackingService _instance =
      LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  Timer? _trackingTimer;
  StreamSubscription<Position>? _positionStream;
  io.Socket? _socket;

  bool _isTracking = false;
  String? _currentRideId;
  Position? _lastPosition;

  // Configuración de tracking — heartbeat cada 10s
  final Duration _updateInterval = const Duration(seconds: 10);
  final double _distanceFilter = 10.0; // metros

  // Stream controllers
  final _locationController = StreamController<Position>.broadcast();
  final _trackingStatusController = StreamController<bool>.broadcast();

  // Getters
  Stream<Position> get locationStream => _locationController.stream;
  Stream<bool> get trackingStatusStream => _trackingStatusController.stream;
  bool get isTracking => _isTracking;
  String? get currentRideId => _currentRideId;
  Position? get lastPosition => _lastPosition;

  /// Inicializa el socket opcional (compatibilidad legado).
  /// El heartbeat de ubicación al backend Node NO usa este socket — usa HTTP.
  void initializeSocket(String serverUrl) {
    _socket = io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket?.on('connect', (_) {
      debugPrint('Socket conectado para tracking');
      _authenticateSocket();
    });

    _socket?.on('disconnect', (_) {
      debugPrint('Socket desconectado');
    });

    _socket?.on('location-error', (data) {
      debugPrint('Error de ubicación: $data');
    });

    _socket?.connect();
  }

  void _authenticateSocket() {
    if (_socket == null) return;
    if (!RapiApiClient.instance.isSignedIn) return;
    _socket?.emit('authenticate', {
      'token': RapiApiClient.instance.currentAccessToken,
      'userType': 'driver',
    });
  }

  /// Solicita permisos de ubicación (foreground + background en iOS).
  Future<bool> requestLocationPermissions() async {
    try {
      if (kIsWeb) return _requestWebLocationPermission();

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }

      if (permission == LocationPermission.deniedForever) {
        await openAppSettings();
        return false;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (Platform.isAndroid) {
          serviceEnabled = await Geolocator.openLocationSettings();
        }
        return serviceEnabled;
      }

      if (Platform.isIOS) {
        final backgroundStatus = await Permission.locationAlways.request();
        return backgroundStatus.isGranted;
      }

      return true;
    } catch (e) {
      debugPrint('Error solicitando permisos: $e');
      return false;
    }
  }

  Future<bool> _requestWebLocationPermission() async {
    try {
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Inicia tracking para un viaje. Envía heartbeat cada 10s al backend Node.
  Future<void> startTracking(String rideId) async {
    if (_isTracking) {
      debugPrint('Ya se está haciendo tracking');
      return;
    }

    final hasPermission = await requestLocationPermissions();
    if (!hasPermission) {
      throw Exception('No se otorgaron permisos de ubicación');
    }

    _currentRideId = rideId;
    _isTracking = true;
    _trackingStatusController.add(true);

    debugPrint('Iniciando tracking para viaje: $rideId');

    // Notificar al socket opcional
    _socket?.emit('join-ride', rideId);

    // Asegurar que el SSE está corriendo — para que el driver reciba
    // ride_updates del viaje activo.
    RapiSseClient.instance.start();

    // Stream nativo del OS para reaccionar rápido a cambios significativos
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _handleLocationUpdate(position);
      },
      onError: (error) {
        debugPrint('Error en stream de ubicación: $error');
      },
    );

    // Timer de heartbeat cada 10s (backend Node exige ritmo constante)
    _trackingTimer = Timer.periodic(_updateInterval, (_) async {
      if (!_isTracking) return;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        _handleLocationUpdate(position, forceHeartbeat: true);
      } catch (e) {
        debugPrint('Error obteniendo ubicación: $e');
      }
    });
  }

  /// Procesa una actualización de ubicación.
  /// - Emite en el stream local
  /// - Envía al socket opcional
  /// - Envía heartbeat al backend Node
  void _handleLocationUpdate(Position position,
      {bool forceHeartbeat = false}) {
    final lastPos = _lastPosition;
    if (!forceHeartbeat && lastPos != null) {
      final distance = Geolocator.distanceBetween(
        lastPos.latitude,
        lastPos.longitude,
        position.latitude,
        position.longitude,
      );
      if (distance < _distanceFilter) return;
    }

    _lastPosition = position;
    _locationController.add(position);

    // Socket opcional
    if (_socket != null && _currentRideId != null) {
      final locationData = {
        'rideId': _currentRideId,
        'lat': position.latitude,
        'lng': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
        'accuracy': position.accuracy,
      };
      _socket?.emit('update-location', locationData);
    }

    // Heartbeat al backend Node
    _sendHeartbeat(position);
  }

  /// Envía heartbeat al backend Node. Fire-and-forget con guardia.
  Future<void> _sendHeartbeat(Position position) async {
    if (!RapiApiClient.instance.isSignedIn) return;
    try {
      await RapiApiClient.instance.heartbeat(
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
        accuracy: position.accuracy,
        speed: position.speed,
        activeRideId: _currentRideId,
      );
      if (kDebugMode) {
        debugPrint(
            'Heartbeat enviado: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      debugPrint('Error enviando heartbeat: $e');
    }
  }

  /// Detiene el tracking.
  void stopTracking() {
    debugPrint('Deteniendo tracking');

    _isTracking = false;
    _trackingStatusController.add(false);

    _trackingTimer?.cancel();
    _trackingTimer = null;

    _positionStream?.cancel();
    _positionStream = null;

    if (_currentRideId != null) {
      _socket?.emit('leave-ride', _currentRideId);
    }

    _currentRideId = null;
  }

  /// Obtiene la ubicación actual una única vez.
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermissions();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _lastPosition = position;
      return position;
    } catch (e) {
      debugPrint('Error obteniendo ubicación actual: $e');
      return null;
    }
  }

  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Geocoding inverso — devuelve las coordenadas como string por ahora.
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      return '$lat, $lng';
    } catch (e) {
      return 'Ubicación desconocida';
    }
  }

  /// Habilita tracking en background.
  Future<void> enableBackgroundTracking() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      debugPrint('Configurando tracking en background para Android');
    } else if (Platform.isIOS) {
      debugPrint('Configurando tracking en background para iOS');
    }
  }

  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<bool> openLocationSettings() async {
    return Geolocator.openLocationSettings();
  }

  void dispose() {
    stopTracking();
    _locationController.close();
    _trackingStatusController.close();
    _socket?.disconnect();
    _socket?.dispose();
  }

  /// Reconecta el socket si se perdió la conexión.
  void reconnectSocket() {
    final socket = _socket;
    if (socket != null && !socket.connected) {
      socket.connect();
    }
  }

  bool get isSocketConnected => _socket?.connected ?? false;

  Map<String, dynamic> getTrackingStats() {
    return {
      'isTracking': _isTracking,
      'currentRideId': _currentRideId,
      'lastPosition': _lastPosition != null
          ? {
              'lat': _lastPosition?.latitude,
              'lng': _lastPosition?.longitude,
              'accuracy': _lastPosition?.accuracy,
              'speed': _lastPosition?.speed,
              'timestamp': _lastPosition?.timestamp,
            }
          : null,
      'socketConnected': isSocketConnected,
    };
  }
}
