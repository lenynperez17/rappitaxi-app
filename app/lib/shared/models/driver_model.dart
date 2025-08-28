import 'package:freezed_annotation/freezed_annotation.dart';

part 'driver_model.freezed.dart';
part 'driver_model.g.dart';

@freezed
class DriverModel with _$DriverModel {
  const factory DriverModel({
    required String id,
    required String name,
    required String phone,
    String? photoUrl,
    required double rating,
    required int totalRides,
    required VehicleModel vehicle,
    required bool isOnline,
    required bool isAvailable,
    LocationData? currentLocation,
    @Default([]) List<String> languages,
    DateTime? memberSince,
  }) = _DriverModel;
  
  factory DriverModel.fromJson(Map<String, dynamic> json) =>
      _$DriverModelFromJson(json);
}

@freezed
class VehicleModel with _$VehicleModel {
  const factory VehicleModel({
    required String brand,
    required String model,
    required int year,
    required String plate,
    required String color,
    @Default('standard') String type, // standard, premium, xl
    @Default(4) int capacity,
    String? photoUrl,
  }) = _VehicleModel;
  
  factory VehicleModel.fromJson(Map<String, dynamic> json) =>
      _$VehicleModelFromJson(json);
}

@freezed
class LocationData with _$LocationData {
  const factory LocationData({
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    DateTime? lastUpdate,
  }) = _LocationData;
  
  factory LocationData.fromJson(Map<String, dynamic> json) =>
      _$LocationDataFromJson(json);
}