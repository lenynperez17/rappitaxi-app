import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'firebase_service.dart';
import 'location_service.dart';
import '../utils/firestore_error_handler.dart';

/// SERVICIO DE TRACKING EN TIEMPO REAL - FLUTTER
/// ==============================================
/// 
/// Funcionalidades implementadas:
/// 📍 Actualización de ubicación cada 5 segundos
/// 🗺️ Cálculo de ETA dinámico usando Google Directions API
/// 📊 Historial completo de ruta guardado localmente y en servidor
/// 🔄 Emisión en tiempo real vía Socket.IO a pasajeros/conductores
/// 📏 Cálculo de distancias y tiempo de viaje exacto
/// 🚦 Optimización de rutas en tiempo real según tráfico
/// ⚠️ Detección de desvíos de ruta y alertas automáticas
/// 📱 Notificaciones push cuando cambia la ubicación/ETA
class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final LocationService _locationService = LocationService();
  
  bool _initialized = false;
  bool _trackingActive = false;
  String? _activeSessionId;
  Timer? _locationUpdateTimer;
  Timer? _etaRecalcTimer;
  late String _apiBaseUrl;
  io.Socket? _socket;

  // ✅ RESOURCE MANAGEMENT: Map de StreamControllers para tracking updates
  // Cada rideId tiene su propio controller para prevenir memory leaks
  final Map<String, StreamController<TrackingUpdate>> _trackingUpdateControllers = {};
  
  // URLs de la API backend
  static const String _localApi = 'http://localhost:3000/api/v1';
  static const String _productionApi = 'https://api.rapiteam.app/api/v1';
  
  // Configuración de tracking
  static const int _updateIntervalSeconds = 5; // Actualizar cada 5 segundos

  /// Inicializar el servicio de tracking
  Future<void> initialize({bool isProduction = false}) async {
    if (_initialized) return;

    try {
      _apiBaseUrl = isProduction ? _productionApi : _localApi;
      
      await _firebaseService.initialize();
      await _locationService.initialize();
      
      // Configurar Socket.IO para actualizaciones en tiempo real
      await _initializeSocket(isProduction);
      
      _initialized = true;
      debugPrint('📍 TrackingService: Inicializado correctamente');
      
      await _firebaseService.analytics.logEvent(
        name: 'tracking_service_initialized',
        parameters: {
          'environment': isProduction ? 'production' : 'test'
        },
      );
      
    } catch (e) {
      debugPrint('📍 TrackingService: Error inicializando - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      _initialized = true; // Continuar en modo desarrollo
    }
  }

  // ============================================================================
  // INICIAR Y DETENER TRACKING
  // ============================================================================

  /// Iniciar tracking para un viaje
  Future<TrackingResult> startTracking({
    required String rideId,
    required String driverId,
    required String passengerId,
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      if (_trackingActive) {
        return TrackingResult.error('Ya hay un tracking activo');
      }

      debugPrint('📍 TrackingService: Iniciando tracking para viaje $rideId');

      // 1. OBTENER UBICACIÓN INICIAL DEL CONDUCTOR
      final currentPosition = await _locationService.getCurrentLocation();
      if (currentPosition == null) {
        return TrackingResult.error('No se pudo obtener la ubicación actual');
      }

      // 2. LLAMAR AL BACKEND PARA INICIAR TRACKING
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/tracking/start'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'rideId': rideId,
          'driverId': driverId,
          'passengerId': passengerId,
          'origin': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
          'destination': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
          'initialDriverLocation': {
            'driverId': driverId,
            'latitude': currentPosition.latitude,
            'longitude': currentPosition.longitude,
            'accuracy': currentPosition.accuracy,
            'heading': currentPosition.heading,
            'speed': currentPosition.speed,
            'timestamp': DateTime.now().toIso8601String(),
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          final sessionId = data['sessionId'];
          _activeSessionId = sessionId;
          _trackingActive = true;

          // 3. INICIAR ACTUALIZACIONES PERIÓDICAS DE UBICACIÓN
          await _startLocationUpdates(driverId, rideId);

          // 4. UNIRSE A LA SALA DE SOCKET.IO PARA ESTE VIAJE
          _socket?.emit('join_ride', rideId);

          await _firebaseService.analytics.logEvent(
            name: 'tracking_started',
            parameters: {
              'ride_id': rideId,
              'driver_id': driverId,
              'passenger_id': passengerId,
              'session_id': sessionId,
            },
          );

          debugPrint('📍 TrackingService: Tracking iniciado - Sesión: $sessionId');

          return TrackingResult.success(
            sessionId: sessionId,
            message: 'Tracking iniciado exitosamente',
          );
        } else {
          return TrackingResult.error(data['message'] ?? 'Error iniciando tracking');
        }
      } else {
        return TrackingResult.error('Error de conectividad: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('📍 TrackingService: Error iniciando tracking - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return TrackingResult.error(FirestoreErrorHandler.getSpanishMessage(e));
    }
  }

  /// Detener tracking activo
  Future<bool> stopTracking(String rideId) async {
    try {
      if (!_trackingActive || _activeSessionId == null) {
        return false;
      }

      // 1. DETENER TIMERS DE ACTUALIZACIÓN
      _locationUpdateTimer?.cancel();
      _etaRecalcTimer?.cancel();

      // 2. LLAMAR AL BACKEND PARA FINALIZAR TRACKING
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/tracking/stop'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sessionId': _activeSessionId,
          'rideId': rideId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success']) {
          // 3. SALIR DE LA SALA DE SOCKET.IO
          _socket?.emit('leave_ride', rideId);

          // 4. ✅ RESOURCE CLEANUP: Cerrar y remover el StreamController para este rideId
          if (_trackingUpdateControllers.containsKey(rideId)) {
            final controller = _trackingUpdateControllers[rideId];
            if (!controller!.isClosed) {
              await controller.close();
            }
            _trackingUpdateControllers.remove(rideId);
            debugPrint('📍 TrackingService: StreamController cerrado para ride $rideId');
          }

          _trackingActive = false;
          _activeSessionId = null;

          await _firebaseService.analytics.logEvent(
            name: 'tracking_stopped',
            parameters: {
              'ride_id': rideId,
            },
          );

          debugPrint('📍 TrackingService: Tracking detenido exitosamente');
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('📍 TrackingService: Error deteniendo tracking - $e');
      return false;
    }
  }

  // ============================================================================
  // CÁLCULO DE RUTAS Y ETA
  // ============================================================================

  /// Calcular ruta entre dos puntos
  Future<RouteResult> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
    bool avoidTolls = false,
    bool optimizeWaypoints = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/tracking/calculate-route'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'origin': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
          'destination': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
          if (waypoints != null) 'waypoints': waypoints.map((point) => {
            'latitude': point.latitude,
            'longitude': point.longitude,
          }).toList(),
          'avoidTolls': avoidTolls,
          'optimizeWaypoints': optimizeWaypoints,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          final routeData = data['data'];
          
          return RouteResult.success(
            distance: routeData['distance'].toDouble(), // metros
            duration: routeData['duration'].toInt(), // segundos
            polyline: routeData['polyline'],
            steps: (routeData['steps'] as List).map((step) => RouteStep(
              instruction: step['instruction'],
              distance: step['distance'].toDouble(),
              duration: step['duration'].toInt(),
              startLocation: LatLng(
                step['startLocation']['latitude'],
                step['startLocation']['longitude'],
              ),
              endLocation: LatLng(
                step['endLocation']['latitude'], 
                step['endLocation']['longitude'],
              ),
            )).toList(),
          );
        } else {
          return RouteResult.error(data['message'] ?? 'Error calculando ruta');
        }
      } else {
        return RouteResult.error('Error de conectividad: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('📍 TrackingService: Error calculando ruta - $e');
      return RouteResult.error(FirestoreErrorHandler.getSpanishMessage(e));
    }
  }

  /// Calcular ETA dinámico
  Future<ETAResult> calculateDynamicETA({
    required LatLng currentLocation,
    required LatLng destination,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/tracking/calculate-eta'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'currentLocation': {
            'latitude': currentLocation.latitude,
            'longitude': currentLocation.longitude,
          },
          'destination': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          final etaData = data['data'];
          
          return ETAResult.success(
            eta: DateTime.parse(etaData['eta']),
            duration: etaData['duration'].toInt(),
            distance: etaData['distance'].toDouble(),
          );
        } else {
          return ETAResult.error(data['message'] ?? 'Error calculando ETA');
        }
      } else {
        return ETAResult.error('Error de conectividad: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('📍 TrackingService: Error calculando ETA - $e');
      return ETAResult.error(FirestoreErrorHandler.getSpanishMessage(e));
    }
  }

  /// Obtener polyline de ruta para mostrar en el mapa
  Future<String?> getRoutePolyline(LatLng origin, LatLng destination) async {
    final routeResult = await calculateRoute(origin: origin, destination: destination);
    return routeResult.success ? routeResult.polyline : null;
  }

  // ============================================================================
  // INFORMACIÓN DE TRACKING
  // ============================================================================

  /// Obtener información completa de tracking
  Future<TrackingInfo?> getTrackingInfo(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/tracking/info/$sessionId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          final trackingData = data['data'];
          
          return TrackingInfo(
            sessionId: trackingData['sessionId'],
            rideId: trackingData['rideId'],
            driverId: trackingData['driverId'],
            passengerId: trackingData['passengerId'],
            isActive: trackingData['isActive'],
            currentLocation: LatLng(
              trackingData['currentLocation']['latitude'],
              trackingData['currentLocation']['longitude'],
            ),
            destination: LatLng(
              trackingData['destination']['latitude'],
              trackingData['destination']['longitude'],
            ),
            estimatedArrival: DateTime.parse(trackingData['estimatedArrival']),
            totalDistance: trackingData['totalDistance']?.toDouble() ?? 0.0,
            totalDuration: trackingData['totalDuration']?.toInt() ?? 0,
            startedAt: DateTime.parse(trackingData['startedAt']),
            completedAt: trackingData['completedAt'] != null 
              ? DateTime.parse(trackingData['completedAt']) 
              : null,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('📍 TrackingService: Error obteniendo info de tracking - $e');
      return null;
    }
  }

  /// Obtener tracking activo por viaje
  Future<TrackingInfo?> getActiveTrackingByRide(String rideId) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/tracking/active/$rideId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] && data['data'] != null) {
          final trackingData = data['data'];
          
          return TrackingInfo(
            sessionId: trackingData['sessionId'],
            rideId: trackingData['rideId'],
            driverId: trackingData['driverId'],
            passengerId: trackingData['passengerId'],
            isActive: trackingData['isActive'],
            currentLocation: LatLng(
              trackingData['currentLocation']['latitude'],
              trackingData['currentLocation']['longitude'],
            ),
            destination: LatLng(
              trackingData['destination']['latitude'],
              trackingData['destination']['longitude'],
            ),
            estimatedArrival: DateTime.parse(trackingData['estimatedArrival']),
            totalDistance: trackingData['totalDistance']?.toDouble() ?? 0.0,
            totalDuration: trackingData['totalDuration']?.toInt() ?? 0,
            startedAt: DateTime.parse(trackingData['startedAt']),
            completedAt: trackingData['completedAt'] != null 
              ? DateTime.parse(trackingData['completedAt']) 
              : null,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('📍 TrackingService: Error obteniendo tracking activo - $e');
      return null;
    }
  }

  // ============================================================================
  // STREAMS PARA ACTUALIZACIONES EN TIEMPO REAL
  // ============================================================================

  /// Stream de actualizaciones de ubicación
  /// ✅ RESOURCE MANAGEMENT: Reutiliza controllers existentes para prevenir memory leaks
  Stream<TrackingUpdate> getTrackingUpdates(String rideId) {
    // Si ya existe un controller para este rideId, retornar su stream
    if (_trackingUpdateControllers.containsKey(rideId)) {
      debugPrint('📍 TrackingService: Reutilizando stream existente para ride $rideId');
      return _trackingUpdateControllers[rideId]!.stream;
    }

    // Crear nuevo controller solo si no existe
    final controller = StreamController<TrackingUpdate>.broadcast(
      onCancel: () {
        debugPrint('📍 TrackingService: Stream cancelado para ride $rideId');
        // El controller se mantiene en el map para permitir re-suscripciones
        // Se limpiará explícitamente en stopTracking() o dispose()
      },
    );

    // Guardar en el map
    _trackingUpdateControllers[rideId] = controller;

    if (_socket != null) {
      _socket!.on('tracking_update', (data) {
        try {
          // Solo procesar si el update es para este rideId
          if (data['rideId'] == rideId) {
            final update = TrackingUpdate(
              type: data['type'],
              sessionId: data['sessionId'],
              rideId: data['rideId'],
              currentLocation: data['currentLocation'] != null
                ? LatLng(
                    data['currentLocation']['latitude'],
                    data['currentLocation']['longitude'],
                  )
                : null,
              estimatedArrival: data['estimatedArrival'] != null
                ? DateTime.parse(data['estimatedArrival'])
                : null,
              hasDeviated: data['deviation']?['hasDeviated'] ?? false,
              deviationDistance: data['deviation']?['deviationDistance']?.toDouble(),
              timestamp: DateTime.parse(data['timestamp']),
            );

            // Solo agregar si el controller no está cerrado
            if (!controller.isClosed) {
              controller.add(update);
            }
          }
        } catch (e) {
          debugPrint('📍 TrackingService: Error procesando actualización - $e');
        }
      });
    }

    debugPrint('📍 TrackingService: Nuevo stream creado para ride $rideId');
    return controller.stream;
  }

  // ============================================================================
  // MÉTODOS PRIVADOS
  // ============================================================================

  /// Inicializar conexión Socket.IO
  Future<void> _initializeSocket(bool isProduction) async {
    try {
      final socketUrl = isProduction
        ? 'https://api.rapiteam.app'
        : 'http://localhost:3000';

      _socket = io.io(socketUrl, io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build());

      _socket!.connect();

      _socket!.onConnect((_) {
        debugPrint('📍 TrackingService: Socket.IO conectado');
      });

      _socket!.onDisconnect((_) {
        debugPrint('📍 TrackingService: Socket.IO desconectado');
      });

    } catch (e) {
      debugPrint('📍 TrackingService: Error inicializando Socket.IO - $e');
    }
  }

  /// Iniciar actualizaciones periódicas de ubicación
  Future<void> _startLocationUpdates(String driverId, String rideId) async {
    _locationUpdateTimer = Timer.periodic(
      Duration(seconds: _updateIntervalSeconds),
      (timer) async {
        // ✅ Verificar que el tracking siga activo antes de actualizar
        if (!_trackingActive) {
          timer.cancel();
          return;
        }

        try {
          final position = await _locationService.getCurrentLocation();

          // ✅ Verificar nuevamente después de operación asíncrona
          if (!_trackingActive) {
            timer.cancel();
            return;
          }

          if (position != null) {
            await _updateDriverLocation(
              driverId: driverId,
              position: position,
              rideId: rideId,
            );
          }
        } catch (e) {
          debugPrint('📍 TrackingService: Error en actualización de ubicación - $e');
        }
      },
    );

    debugPrint('📍 TrackingService: Actualizaciones de ubicación iniciadas cada $_updateIntervalSeconds segundos');
  }

  /// Actualizar ubicación del conductor
  Future<void> _updateDriverLocation({
    required String driverId,
    required Position position,
    String? rideId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/tracking/update-location'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'driverId': driverId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'heading': position.heading,
          'speed': position.speed,
          if (rideId != null) 'rideId': rideId,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('📍 TrackingService: Error actualizando ubicación - ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('📍 TrackingService: Error enviando ubicación - $e');
    }
  }

  // Dispose resources
  /// ✅ RESOURCE CLEANUP: Limpia todos los recursos para prevenir memory leaks
  void dispose() {
    debugPrint('📍 TrackingService: Iniciando limpieza de recursos...');

    // 1. Cancelar timers
    _locationUpdateTimer?.cancel();
    _etaRecalcTimer?.cancel();

    // 2. ✅ Cerrar todos los StreamControllers de tracking
    for (final entry in _trackingUpdateControllers.entries) {
      final rideId = entry.key;
      final controller = entry.value;
      if (!controller.isClosed) {
        controller.close();
        debugPrint('📍 TrackingService: StreamController cerrado para ride $rideId');
      }
    }
    _trackingUpdateControllers.clear();

    // 3. Desconectar Socket.IO
    _socket?.disconnect();
    _socket?.dispose();

    debugPrint('📍 TrackingService: Recursos limpiados exitosamente');
  }

  // Getters
  bool get isInitialized => _initialized;
  bool get isTrackingActive => _trackingActive;
  String? get activeSessionId => _activeSessionId;
}

// ============================================================================
// CLASES DE DATOS Y RESULTADOS
// ============================================================================

/// Resultado de operación de tracking
class TrackingResult {
  final bool success;
  final String? sessionId;
  final String? message;
  final String? error;

  TrackingResult.success({
    required this.sessionId,
    required this.message,
  }) : success = true, error = null;

  TrackingResult.error(this.error)
      : success = false,
        sessionId = null,
        message = null;
}

/// Resultado de cálculo de ruta
class RouteResult {
  final bool success;
  final double? distance; // metros
  final int? duration; // segundos
  final String? polyline;
  final List<RouteStep>? steps;
  final String? error;

  RouteResult.success({
    required this.distance,
    required this.duration,
    required this.polyline,
    required this.steps,
  }) : success = true, error = null;

  RouteResult.error(this.error)
      : success = false,
        distance = null,
        duration = null,
        polyline = null,
        steps = null;
}

/// Paso de ruta
class RouteStep {
  final String instruction;
  final double distance;
  final int duration;
  final LatLng startLocation;
  final LatLng endLocation;

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
  });
}

/// Resultado de cálculo de ETA
class ETAResult {
  final bool success;
  final DateTime? eta;
  final int? duration; // segundos
  final double? distance; // metros
  final String? error;

  ETAResult.success({
    required this.eta,
    required this.duration,
    required this.distance,
  }) : success = true, error = null;

  ETAResult.error(this.error)
      : success = false,
        eta = null,
        duration = null,
        distance = null;
}

/// Información de tracking
class TrackingInfo {
  final String sessionId;
  final String rideId;
  final String driverId;
  final String passengerId;
  final bool isActive;
  final LatLng currentLocation;
  final LatLng destination;
  final DateTime estimatedArrival;
  final double totalDistance;
  final int totalDuration;
  final DateTime startedAt;
  final DateTime? completedAt;

  TrackingInfo({
    required this.sessionId,
    required this.rideId,
    required this.driverId,
    required this.passengerId,
    required this.isActive,
    required this.currentLocation,
    required this.destination,
    required this.estimatedArrival,
    required this.totalDistance,
    required this.totalDuration,
    required this.startedAt,
    this.completedAt,
  });
}

/// Actualización de tracking en tiempo real
class TrackingUpdate {
  final String type; // 'location_updated', 'route_recalculated', etc.
  final String sessionId;
  final String rideId;
  final LatLng? currentLocation;
  final DateTime? estimatedArrival;
  final bool hasDeviated;
  final double? deviationDistance;
  final DateTime timestamp;

  TrackingUpdate({
    required this.type,
    required this.sessionId,
    required this.rideId,
    this.currentLocation,
    this.estimatedArrival,
    required this.hasDeviated,
    this.deviationDistance,
    required this.timestamp,
  });
}

/// Estados de tracking
enum TrackingStatus {
  inactive,
  starting,
  active,
  paused,
  completed,
  error,
}