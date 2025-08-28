import 'package:freezed_annotation/freezed_annotation.dart';
import 'location_model.dart';

part 'ride_model.freezed.dart';
part 'ride_model.g.dart';

@freezed
class RideModel with _$RideModel {
  const factory RideModel({
    required String id,
    required String passengerId,
    required String driverId,
    required LocationModel pickup,
    required LocationModel destination,
    required DateTime requestedAt,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    required String status, // requested, accepted, arriving, in_progress, completed, cancelled
    required String vehicleType, // economy, standard, premium
    required double fare,
    required double distance, // en kilómetros
    required int duration, // en minutos
    required String paymentMethod,
    String? paymentIntentId,
    double? rating,
    String? comment,
    String? cancellationReason,
    String? cancelledBy, // passenger, driver, system
    DriverInfo? driverInfo,
    PassengerInfo? passengerInfo,
    RideVehicleInfo? vehicleInfo,
    @Default([]) List<RoutePoint> routePoints,
    Map<String, dynamic>? metadata,
  }) = _RideModel;
  
  factory RideModel.fromJson(Map<String, dynamic> json) =>
      _$RideModelFromJson(json);
      
  /// Crear RideModel desde documento de Firestore
  factory RideModel.fromFirestore(String id, Map<String, dynamic> data) {
    return RideModel.fromJson({
      'id': id,
      ...data,
    });
  }
}

@freezed
class DriverInfo with _$DriverInfo {
  const factory DriverInfo({
    required String id,
    required String name,
    required String phone,
    String? photoUrl,
    required double rating,
    required int totalRides,
  }) = _DriverInfo;
  
  factory DriverInfo.fromJson(Map<String, dynamic> json) =>
      _$DriverInfoFromJson(json);
}

@freezed
class RideVehicleInfo with _$RideVehicleInfo {
  const factory RideVehicleInfo({
    required String plate,
    required String brand,
    required String model,
    required String color,
    required int year,
  }) = _RideVehicleInfo;
  
  factory RideVehicleInfo.fromJson(Map<String, dynamic> json) =>
      _$RideVehicleInfoFromJson(json);
}

@freezed
class RoutePoint with _$RoutePoint {
  const factory RoutePoint({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) = _RoutePoint;
  
  factory RoutePoint.fromJson(Map<String, dynamic> json) =>
      _$RoutePointFromJson(json);
}

@freezed
class PassengerInfo with _$PassengerInfo {
  const factory PassengerInfo({
    required String id,
    required String name,
    required String phone,
    String? photoUrl,
    required double rating,
    required int totalRides,
  }) = _PassengerInfo;
  
  factory PassengerInfo.fromJson(Map<String, dynamic> json) =>
      _$PassengerInfoFromJson(json);
}