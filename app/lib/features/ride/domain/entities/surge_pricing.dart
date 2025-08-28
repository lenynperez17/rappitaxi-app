import 'package:freezed_annotation/freezed_annotation.dart';

part 'surge_pricing.freezed.dart';
part 'surge_pricing.g.dart';

/// Entidad para tarifas dinámicas estilo Uber
@freezed
class SurgePricing with _$SurgePricing {
  const factory SurgePricing({
    required String id,
    required String zoneId,
    required double latitude,
    required double longitude,
    required double radiusKm,
    required double surgeMultiplier,
    required int activeDrivers,
    required int pendingRequests,
    required DateTime startTime,
    required DateTime endTime,
    required SurgeReason reason,
    @Default(true) bool isActive,
    String? message,
    @Default({}) Map<String, dynamic> metadata,
  }) = _SurgePricing;

  factory SurgePricing.fromJson(Map<String, dynamic> json) =>
      _$SurgePricingFromJson(json);
}

enum SurgeReason {
  highDemand,
  lowSupply,
  peakHours,
  specialEvent,
  weatherConditions,
  manualOverride
}

/// Configuración de tarifas dinámicas
@freezed
class SurgePricingConfig with _$SurgePricingConfig {
  const factory SurgePricingConfig({
    @Default(true) bool enableSurgePricing,
    @Default(1.0) double minMultiplier,
    @Default(3.0) double maxMultiplier,
    @Default(0.1) double incrementStep,
    @Default(5) int demandThreshold, // Solicitudes pendientes para activar surge
    @Default(3) int supplyThreshold, // Mínimo de conductores para desactivar surge
    @Default(300) int updateIntervalSeconds,
    @Default(15) int zoneSizeKm,
    @Default(true) bool showSurgeWarning,
    @Default(true) bool allowUserOptOut,
    required Map<String, double> peakHours, // Hora -> Multiplicador
  }) = _SurgePricingConfig;

  factory SurgePricingConfig.fromJson(Map<String, dynamic> json) =>
      _$SurgePricingConfigFromJson(json);
}

/// Historial de tarifas dinámicas
@freezed
class SurgePricingHistory with _$SurgePricingHistory {
  const factory SurgePricingHistory({
    required String id,
    required String zoneId,
    required double multiplier,
    required DateTime timestamp,
    required int activeDrivers,
    required int pendingRequests,
    required SurgeReason reason,
    required double averageFare,
    required int completedRides,
  }) = _SurgePricingHistory;

  factory SurgePricingHistory.fromJson(Map<String, dynamic> json) =>
      _$SurgePricingHistoryFromJson(json);
}

/// Zona de tarifa dinámica
@freezed
class SurgeZone with _$SurgeZone {
  const factory SurgeZone({
    required String id,
    required String name,
    required double centerLatitude,
    required double centerLongitude,
    required double radiusKm,
    required double currentMultiplier,
    required int activeDrivers,
    required int pendingRequests,
    required DateTime lastUpdated,
    @Default(true) bool isActive,
    String? polygonGeojson, // Para zonas no circulares
    @Default([]) List<SurgePricingHistory> recentHistory,
  }) = _SurgeZone;

  factory SurgeZone.fromJson(Map<String, dynamic> json) =>
      _$SurgeZoneFromJson(json);
}