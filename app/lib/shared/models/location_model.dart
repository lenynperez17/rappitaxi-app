import 'package:freezed_annotation/freezed_annotation.dart';

part 'location_model.freezed.dart';
part 'location_model.g.dart';

@freezed
class LocationModel with _$LocationModel {
  const factory LocationModel({
    required double latitude,
    required double longitude,
    required String address,
    String? placeId,
    String? name,
    String? details,
    String? city,
    String? state,
    String? country,
    String? postalCode,
  }) = _LocationModel;
  
  factory LocationModel.fromJson(Map<String, dynamic> json) =>
      _$LocationModelFromJson(json);
}

@freezed
class RouteModel with _$RouteModel {
  const factory RouteModel({
    required LocationModel origin,
    required LocationModel destination,
    required double distanceKm,
    required int durationMinutes,
    required String polyline,
    @Default([]) List<LocationModel> waypoints,
    Map<String, dynamic>? bounds,
  }) = _RouteModel;
  
  factory RouteModel.fromJson(Map<String, dynamic> json) =>
      _$RouteModelFromJson(json);
}