import 'package:freezed_annotation/freezed_annotation.dart';

part 'shared_ride.freezed.dart';
part 'shared_ride.g.dart';

/// Entidad para viajes compartidos estilo Yango
@freezed
class SharedRide with _$SharedRide {
  const factory SharedRide({
    required String id,
    required String driverId,
    required List<SharedRidePassenger> passengers,
    required SharedRideStatus status,
    required String vehicleType,
    required int maxPassengers,
    required double totalDistance,
    required double currentDistance,
    required List<RouteSegment> routeSegments,
    required DateTime startTime,
    DateTime? endTime,
    required double baseFare,
    required Map<String, double> passengerFares, // passengerId -> fare
    @Default(0.7) double sharedRideDiscount, // 30% descuento por compartir
    @Default(true) bool allowNewPassengers,
    @Default(15) int maxDetourMinutes, // Máximo desvío permitido
    String? currentSegmentId,
    Map<String, dynamic>? currentLocation,
  }) = _SharedRide;

  factory SharedRide.fromJson(Map<String, dynamic> json) =>
      _$SharedRideFromJson(json);
}

enum SharedRideStatus {
  waitingPassengers,
  inProgress,
  completed,
  cancelled
}

/// Pasajero en viaje compartido
@freezed
class SharedRidePassenger with _$SharedRidePassenger {
  const factory SharedRidePassenger({
    required String passengerId,
    required String name,
    required String photoUrl,
    required double rating,
    required Map<String, dynamic> pickupLocation,
    required Map<String, dynamic> dropoffLocation,
    required DateTime requestTime,
    DateTime? pickupTime,
    DateTime? dropoffTime,
    required PassengerStatus status,
    required double fare,
    required double distance,
    required int seatCount,
    String? phoneNumber,
    String? notes,
    @Default(false) bool isPriority,
  }) = _SharedRidePassenger;

  factory SharedRidePassenger.fromJson(Map<String, dynamic> json) =>
      _$SharedRidePassengerFromJson(json);
}

enum PassengerStatus {
  pending,
  confirmed,
  pickedUp,
  droppedOff,
  cancelled,
  noShow
}

/// Segmento de ruta en viaje compartido
@freezed
class RouteSegment with _$RouteSegment {
  const factory RouteSegment({
    required String id,
    required String passengerId,
    required SegmentType type,
    required Map<String, dynamic> location,
    required int order,
    required double distanceFromPrevious,
    required int estimatedMinutesFromPrevious,
    DateTime? actualArrivalTime,
    @Default(false) bool isCompleted,
  }) = _RouteSegment;

  factory RouteSegment.fromJson(Map<String, dynamic> json) =>
      _$RouteSegmentFromJson(json);
}

enum SegmentType {
  pickup,
  dropoff
}

/// Solicitud para unirse a viaje compartido
@freezed
class SharedRideRequest with _$SharedRideRequest {
  const factory SharedRideRequest({
    required String id,
    required String passengerId,
    required Map<String, dynamic> pickupLocation,
    required Map<String, dynamic> dropoffLocation,
    required DateTime requestTime,
    required int passengerCount,
    @Default(SharedRideRequestStatus.pending) SharedRideRequestStatus status,
    String? matchedRideId,
    double? estimatedFare,
    double? estimatedWaitTime,
    double? estimatedTravelTime,
    @Default(300) int maxWaitTimeSeconds, // 5 minutos máximo de espera
    @Default(0.5) double maxDetourKm, // Máximo desvío aceptable
  }) = _SharedRideRequest;

  factory SharedRideRequest.fromJson(Map<String, dynamic> json) =>
      _$SharedRideRequestFromJson(json);
}

enum SharedRideRequestStatus {
  pending,
  matched,
  confirmed,
  rejected,
  expired,
  cancelled
}

/// Configuración de viajes compartidos
@freezed
class SharedRideConfig with _$SharedRideConfig {
  const factory SharedRideConfig({
    @Default(true) bool enableSharedRides,
    @Default(4) int maxPassengersPerRide,
    @Default(0.3) double discountPercent, // 30% descuento
    @Default(0.8) double driverBonusPercent, // 80% de tarifa total para conductor
    @Default(15) int maxDetourMinutes,
    @Default(2.0) double maxDetourKm,
    @Default(300) int matchingWindowSeconds, // Ventana para emparejar pasajeros
    @Default(true) bool allowDynamicRouting, // Reoptimizar ruta con nuevos pasajeros
    @Default(true) bool showOtherPassengers, // Mostrar info de otros pasajeros
    @Default(false) bool allowPassengerChat, // Chat entre pasajeros
    @Default(true) bool requireRatingAbove, // Requerir rating mínimo
    @Default(4.0) double minimumRating,
    @Default(10) int maxMatchingAttempts,
  }) = _SharedRideConfig;

  factory SharedRideConfig.fromJson(Map<String, dynamic> json) =>
      _$SharedRideConfigFromJson(json);
}

/// Algoritmo de emparejamiento de viajes
@freezed
class RideMatchingCriteria with _$RideMatchingCriteria {
  const factory RideMatchingCriteria({
    required double maxDetourPercent, // % máximo de desvío
    required double maxWaitTime, // Minutos máximos de espera
    required double compatibilityScore, // Score mínimo de compatibilidad
    required bool sameDirection, // Misma dirección general
    required double overlapPercent, // % de ruta compartida
  }) = _RideMatchingCriteria;

  factory RideMatchingCriteria.fromJson(Map<String, dynamic> json) =>
      _$RideMatchingCriteriaFromJson(json);
}