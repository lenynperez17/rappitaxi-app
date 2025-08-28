import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/surge_pricing.dart';
import 'package:rappitaxi_app/shared/utils/logger.dart';

/// Servicio para manejar tarifas dinámicas estilo Uber
class SurgePricingService {
  final FirebaseFirestore _firestore;
  final Ref _ref;
  
  // Cache de zonas de surge para optimización
  final Map<String, SurgeZone> _surgeZonesCache = {};
  Timer? _updateTimer;
  
  SurgePricingService(this._firestore, this._ref);
  
  /// Inicializar el monitoreo de tarifas dinámicas
  void initialize() {
    // Actualizar cada 5 minutos
    _updateTimer = Timer.periodic(Duration(minutes: 5), (_) {
      _updateAllSurgeZones();
    });
    
    // Actualización inicial
    _updateAllSurgeZones();
  }
  
  /// Detener el monitoreo
  void dispose() {
    _updateTimer?.cancel();
  }
  
  /// Calcular el multiplicador de tarifa para una ubicación específica
  Future<double> calculateSurgeMultiplier({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Buscar zona de surge activa más cercana
      final activeZone = await _findActiveZone(latitude, longitude);
      
      if (activeZone == null) {
        // Si no hay zona activa, verificar si es hora pico
        return _getPeakHourMultiplier();
      }
      
      // Calcular multiplicador basado en oferta y demanda
      final demandSupplyRatio = activeZone.pendingRequests / 
          (activeZone.activeDrivers > 0 ? activeZone.activeDrivers : 1);
      
      double multiplier = 1.0;
      
      // Aplicar lógica de surge pricing
      if (demandSupplyRatio > 2.0) {
        multiplier = 2.5; // Surge alto
      } else if (demandSupplyRatio > 1.5) {
        multiplier = 2.0; // Surge medio
      } else if (demandSupplyRatio > 1.0) {
        multiplier = 1.5; // Surge bajo
      } else {
        multiplier = activeZone.currentMultiplier;
      }
      
      // Aplicar límites
      final config = await _getSurgePricingConfig();
      multiplier = multiplier.clamp(config.minMultiplier, config.maxMultiplier);
      
      // Guardar historial
      await _saveSurgeHistory(activeZone, multiplier);
      
      Logger.info('Surge multiplier calculado: ${multiplier}x para zona ${activeZone.name}');
      return multiplier;
      
    } catch (e) {
      Logger.error('Error calculando surge pricing: $e');
      return 1.0; // Sin surge en caso de error
    }
  }
  
  /// Crear o actualizar una zona de surge
  Future<void> createOrUpdateSurgeZone({
    required String zoneId,
    required String name,
    required double latitude,
    required double longitude,
    required double radiusKm,
    required double multiplier,
    required SurgeReason reason,
    String? message,
  }) async {
    try {
      final zone = SurgeZone(
        id: zoneId,
        name: name,
        centerLatitude: latitude,
        centerLongitude: longitude,
        radiusKm: radiusKm,
        currentMultiplier: multiplier,
        activeDrivers: await _countActiveDriversInZone(latitude, longitude, radiusKm),
        pendingRequests: await _countPendingRequestsInZone(latitude, longitude, radiusKm),
        lastUpdated: DateTime.now(),
        isActive: multiplier > 1.0,
      );
      
      await _firestore.collection('surge_zones').doc(zoneId).set(zone.toJson());
      _surgeZonesCache[zoneId] = zone;
      
      // Notificar a usuarios en la zona
      await _notifyUsersInZone(zone, message);
      
      Logger.info('Zona de surge actualizada: $name con multiplicador ${multiplier}x');
    } catch (e) {
      Logger.error('Error creando/actualizando zona de surge: $e');
      rethrow;
    }
  }
  
  /// Obtener todas las zonas de surge activas
  Future<List<SurgeZone>> getActiveSurgeZones() async {
    try {
      final snapshot = await _firestore
          .collection('surge_zones')
          .where('isActive', isEqualTo: true)
          .where('lastUpdated', isGreaterThan: 
              DateTime.now().subtract(Duration(hours: 1)))
          .get();
      
      return snapshot.docs
          .map((doc) => SurgeZone.fromJson(doc.data()))
          .toList();
    } catch (e) {
      Logger.error('Error obteniendo zonas de surge: $e');
      return [];
    }
  }
  
  /// Obtener configuración de surge pricing
  Future<SurgePricingConfig> _getSurgePricingConfig() async {
    try {
      final doc = await _firestore
          .collection('config')
          .doc('surge_pricing')
          .get();
      
      if (!doc.exists) {
        // Configuración por defecto
        return SurgePricingConfig(
          peakHours: {
            '7': 1.3,  // 7-8 AM
            '8': 1.5,  // 8-9 AM
            '18': 1.4, // 6-7 PM
            '19': 1.6, // 7-8 PM
            '20': 1.3, // 8-9 PM
          },
        );
      }
      
      return SurgePricingConfig.fromJson(doc.data()!);
    } catch (e) {
      Logger.error('Error obteniendo configuración de surge: $e');
      return SurgePricingConfig(peakHours: {});
    }
  }
  
  /// Encontrar zona activa para una ubicación
  Future<SurgeZone?> _findActiveZone(double lat, double lon) async {
    final zones = await getActiveSurgeZones();
    
    for (final zone in zones) {
      final distance = Geolocator.distanceBetween(
        lat, lon,
        zone.centerLatitude, zone.centerLongitude,
      );
      
      if (distance <= zone.radiusKm * 1000) {
        return zone;
      }
    }
    
    return null;
  }
  
  /// Obtener multiplicador por hora pico
  double _getPeakHourMultiplier() {
    final now = DateTime.now();
    final hour = now.hour;
    final dayOfWeek = now.weekday;
    
    // Fin de semana noche (viernes y sábado)
    if (dayOfWeek >= 5 && hour >= 22) {
      return 1.8;
    }
    
    // Horas pico entre semana
    if (dayOfWeek <= 5) {
      // Mañana
      if (hour >= 7 && hour <= 9) {
        return 1.5;
      }
      // Tarde
      if (hour >= 18 && hour <= 20) {
        return 1.6;
      }
    }
    
    // Madrugada con poca oferta
    if (hour >= 2 && hour <= 5) {
      return 1.4;
    }
    
    return 1.0; // Sin surge
  }
  
  /// Contar conductores activos en una zona
  Future<int> _countActiveDriversInZone(double lat, double lon, double radiusKm) async {
    try {
      // Obtener conductores online
      final driversSnapshot = await _firestore
          .collection('drivers')
          .where('status', isEqualTo: 'online')
          .where('available', isEqualTo: true)
          .get();
      
      int count = 0;
      for (final doc in driversSnapshot.docs) {
        final driverData = doc.data();
        if (driverData['location'] != null) {
          final driverLat = driverData['location']['latitude'];
          final driverLon = driverData['location']['longitude'];
          
          final distance = Geolocator.distanceBetween(
            lat, lon, driverLat, driverLon,
          );
          
          if (distance <= radiusKm * 1000) {
            count++;
          }
        }
      }
      
      return count;
    } catch (e) {
      Logger.error('Error contando conductores en zona: $e');
      return 0;
    }
  }
  
  /// Contar solicitudes pendientes en una zona
  Future<int> _countPendingRequestsInZone(double lat, double lon, double radiusKm) async {
    try {
      final requestsSnapshot = await _firestore
          .collection('ride_requests')
          .where('status', isEqualTo: 'pending')
          .where('createdAt', isGreaterThan: 
              DateTime.now().subtract(Duration(minutes: 10)))
          .get();
      
      int count = 0;
      for (final doc in requestsSnapshot.docs) {
        final requestData = doc.data();
        if (requestData['pickupLocation'] != null) {
          final pickupLat = requestData['pickupLocation']['latitude'];
          final pickupLon = requestData['pickupLocation']['longitude'];
          
          final distance = Geolocator.distanceBetween(
            lat, lon, pickupLat, pickupLon,
          );
          
          if (distance <= radiusKm * 1000) {
            count++;
          }
        }
      }
      
      return count;
    } catch (e) {
      Logger.error('Error contando solicitudes en zona: $e');
      return 0;
    }
  }
  
  /// Actualizar todas las zonas de surge
  Future<void> _updateAllSurgeZones() async {
    try {
      final zones = await getActiveSurgeZones();
      
      for (final zone in zones) {
        final activeDrivers = await _countActiveDriversInZone(
          zone.centerLatitude, 
          zone.centerLongitude, 
          zone.radiusKm,
        );
        
        final pendingRequests = await _countPendingRequestsInZone(
          zone.centerLatitude,
          zone.centerLongitude,
          zone.radiusKm,
        );
        
        // Actualizar zona con nuevos datos
        final updatedZone = zone.copyWith(
          activeDrivers: activeDrivers,
          pendingRequests: pendingRequests,
          lastUpdated: DateTime.now(),
        );
        
        await _firestore
            .collection('surge_zones')
            .doc(zone.id)
            .update(updatedZone.toJson());
        
        _surgeZonesCache[zone.id] = updatedZone;
      }
      
      Logger.info('Zonas de surge actualizadas: ${zones.length}');
    } catch (e) {
      Logger.error('Error actualizando zonas de surge: $e');
    }
  }
  
  /// Guardar historial de surge
  Future<void> _saveSurgeHistory(SurgeZone zone, double multiplier) async {
    try {
      final history = SurgePricingHistory(
        id: _firestore.collection('surge_history').doc().id,
        zoneId: zone.id,
        multiplier: multiplier,
        timestamp: DateTime.now(),
        activeDrivers: zone.activeDrivers,
        pendingRequests: zone.pendingRequests,
        reason: _determineSurgeReason(zone),
        averageFare: await _calculateAverageFare(zone.id),
        completedRides: await _countCompletedRides(zone.id),
      );
      
      await _firestore
          .collection('surge_history')
          .doc(history.id)
          .set(history.toJson());
    } catch (e) {
      Logger.error('Error guardando historial de surge: $e');
    }
  }
  
  /// Determinar la razón del surge
  SurgeReason _determineSurgeReason(SurgeZone zone) {
    final ratio = zone.pendingRequests / 
        (zone.activeDrivers > 0 ? zone.activeDrivers : 1);
    
    if (ratio > 2.0) {
      return SurgeReason.highDemand;
    } else if (zone.activeDrivers < 3) {
      return SurgeReason.lowSupply;
    } else if (_isPeakHour()) {
      return SurgeReason.peakHours;
    }
    
    return SurgeReason.highDemand;
  }
  
  /// Verificar si es hora pico
  bool _isPeakHour() {
    final hour = DateTime.now().hour;
    return (hour >= 7 && hour <= 9) || (hour >= 18 && hour <= 20);
  }
  
  /// Calcular tarifa promedio en una zona
  Future<double> _calculateAverageFare(String zoneId) async {
    // TODO: Implementar cálculo real basado en viajes recientes
    return 25.0 + Random().nextDouble() * 15;
  }
  
  /// Contar viajes completados en una zona
  Future<int> _countCompletedRides(String zoneId) async {
    // TODO: Implementar conteo real de la última hora
    return Random().nextInt(50) + 10;
  }
  
  /// Notificar a usuarios en zona de surge
  Future<void> _notifyUsersInZone(SurgeZone zone, String? customMessage) async {
    // TODO: Implementar notificaciones push
    final message = customMessage ?? 
        'Tarifa dinámica activa en ${zone.name}: ${zone.currentMultiplier}x';
    
    Logger.info('Notificación de surge: $message');
  }
  
  /// Obtener predicción de surge para las próximas horas
  Future<Map<DateTime, double>> getSurgePrediction({
    required double latitude,
    required double longitude,
    int hoursAhead = 6,
  }) async {
    final predictions = <DateTime, double>{};
    final now = DateTime.now();
    
    for (int i = 1; i <= hoursAhead; i++) {
      final futureTime = now.add(Duration(hours: i));
      final hour = futureTime.hour;
      final dayOfWeek = futureTime.weekday;
      
      double predictedMultiplier = 1.0;
      
      // Predicción basada en patrones históricos
      if (dayOfWeek <= 5) {
        // Entre semana
        if (hour == 7 || hour == 8) predictedMultiplier = 1.5;
        else if (hour == 18 || hour == 19) predictedMultiplier = 1.6;
      } else {
        // Fin de semana
        if (hour >= 22 || hour <= 2) predictedMultiplier = 1.8;
      }
      
      predictions[futureTime] = predictedMultiplier;
    }
    
    return predictions;
  }
}

// Provider para el servicio
final surgePricingServiceProvider = Provider<SurgePricingService>((ref) {
  final service = SurgePricingService(
    FirebaseFirestore.instance,
    ref,
  );
  service.initialize();
  return service;
});

// Provider para obtener el multiplicador actual
final currentSurgeMultiplierProvider = FutureProvider.family<double, Map<String, double>>(
  (ref, location) async {
    final service = ref.watch(surgePricingServiceProvider);
    return service.calculateSurgeMultiplier(
      latitude: location['latitude']!,
      longitude: location['longitude']!,
    );
  },
);